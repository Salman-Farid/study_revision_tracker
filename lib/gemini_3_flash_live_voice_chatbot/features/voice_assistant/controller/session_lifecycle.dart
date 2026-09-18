part of '../voice_assistant_controller.dart';

/// WebSocket session: listeners, reconnect, start/stop.
extension VoiceAssistantSessionLifecycle on VoiceAssistantController {
  void _setupListeners() {
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();

    final gen = _generation;

    _connectionSub = _service.connectionStateStream.listen((s) {
      if (gen != _generation) return;
      connectionState.value = s;
      if (s == ws.ConnectionState.error) {
        errorMessage.value = _service.socket?.lastError ?? 'Unknown error';
        _maybeReconnect();
      } else if (s == ws.ConnectionState.connected) {
        errorMessage.value = '';
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
      } else if (s == ws.ConnectionState.disconnected) {
        _cleanupOrphanedBatchState(reason: 'disconnected');
        if (!_userInitiatedStop) _maybeReconnect();
      }
    }, onError: (e) {
      debugPrint('[Gemini] ⚠️ connectionStateStream error: $e');
      errorMessage.value = e.toString();
    });

    _transcriptSub = _service.transcriptStream.listen((t) {
      if (gen != _generation) return;
      if (!isLoading.value && _micMuted.value != _service.isMuted) {
        _micMuted.value = _service.isMuted;
      }

      if (t.startsWith('USER:')) {
        final text = t.substring(5);
        final trimmed = text.trim();
        if (trimmed.isEmpty) return;
        if (_looksLikeSelfEcho(trimmed)) {
          debugPrint('[Gemini] 🔇 Discarding likely self-echo: "$trimmed"');
          return;
        }
        messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
        _batchRetryCount = 0;
        _recentCalls.clear();
        _showThinking();
        debugPrint('[Gemini] 🆕 New user message — retry count reset, dedup cache cleared');
      } else {
        if (_batchJustCompleted) {
          debugPrint('[Gemini] 📦 Batch completed — processing Gemini response');
          if (_batchProgressMessage != null) {
            _batchProgressMessage!.text = '✅ All done — $_batchCompletedCount operations completed';
            _batchProgressMessage = null;
          }
          _batchJustCompleted = false;
          isProcessing.value = false;
        }
        _clearThinking();
        if (_streamingMessage != null) {
          _streamingMessage!.text += t;
        } else {
          _streamingMessage = ChatMessage(role: ChatRole.assistant, text: t);
          messages.add(_streamingMessage!);
        }
        _triggerUiUpdate();
      }
    }, onError: (e) {
      debugPrint('[Gemini] ⚠️ transcriptStream error: $e');
    });

    _audioSub = _service.responseAudioStream.listen((_) {}, onError: (e) {
      debugPrint('[Gemini] ⚠️ responseAudioStream error: $e');
    });

    _functionCallSub = _service.functionCallStream.listen((call) {
      if (gen != _generation) return;
      _showThinking();
      try {
        _handleFunctionCall(call['id'] as String, call['name'] as String, call['args'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Gemini] ⚠️ Malformed function call payload: $e');
      }
    }, onError: (e) {
      debugPrint('[Gemini] ⚠️ functionCallStream error: $e');
    });

    _turnCompleteSub = _service.turnCompleteStream.listen((_) {
      if (gen != _generation) return;
      if (_streamingMessage != null && _streamingMessage!.text.trim().isNotEmpty) {
        _lastAssistantText = _streamingMessage!.text;
      }
      _mutedByFunctionCall = false;
      _streamingMessage = null;
      _clearThinking();
      debugPrint('[Gemini] 🔚 Turn complete');

      // Cancel batch safety timer — Gemini responded
      _batchFlushTimer?.cancel();
      if (_batchJustCompleted) {
        _finishBatchUi();
      }

      // Mic reopen timing lives in mic_state.dart (scheduleUnmuteAfterTurn).
      scheduleUnmuteAfterTurn(gen);
    }, onError: (e) {
      debugPrint('[Gemini] ⚠️ turnCompleteStream error: $e');
    });
  }

  void _showThinking() {
    _enterLoading('thinking');
    if (_thinkingMessage == null && _batchProgressMessage == null) {
      _thinkingMessage = ChatMessage(role: ChatRole.system, text: '🧠 Thinking...');
      messages.add(_thinkingMessage!);
      _triggerUiUpdate();
    }
  }

  void _clearThinking() {
    if (_thinkingMessage != null) {
      messages.remove(_thinkingMessage);
      _thinkingMessage = null;
      _triggerUiUpdate();
    }
  }

  void _cleanupOrphanedBatchState({required String reason}) {
    if (_batchInProgress || _pendingCallIds.isNotEmpty || isProcessing.value || isLoading.value) {
      debugPrint('[Gemini] 🔌 Cleaning up orphaned batch state ($reason)');
      _pendingCallsSafetyTimer?.cancel();
      _batchFlushTimer?.cancel();
      _pendingCallIds.clear();
      _pendingResponses.clear();
      _subjectCreationCompleters.clear();
      _batchInProgress = false;
      _batchJustCompleted = false;
      _batchTotal = 0;
      _batchCompleted = 0;
      if (_batchProgressMessage != null) {
        _batchProgressMessage!.text = '⚠️ Interrupted — connection lost mid-task';
        _batchProgressMessage = null;
      }
      _clearThinking();
      isProcessing.value = false;
      _mutedByFunctionCall = false;
      _exitLoading('cleanup-after-$reason');
      _setMicMuted(false, reason: 'cleanup-after-$reason');
    }
  }

  void _maybeReconnect() {
    if (_userInitiatedStop) return;
    if (_reconnectAttempts >= VoiceAssistantController._maxReconnectAttempts) {
      debugPrint('[Gemini] ❌ Max reconnect attempts reached — giving up');
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connection lost. Tap the mic to reconnect.',
      ));
      _triggerUiUpdate();
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    debugPrint('[Gemini] 🔁 Reconnect attempt $_reconnectAttempts/$VoiceAssistantController._maxReconnectAttempts in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    final gen = _generation;
    _reconnectTimer = Timer(delay, () {
      if (gen != _generation || _userInitiatedStop) return;
      startSession(isReconnect: true);
    });
  }

  Future<void> startSession({bool isReconnect = false}) async {
    try {
      _userInitiatedStop = false;
      _isStopping = false;
      final gen = ++_generation;

      _setupListeners();

      if (!isReconnect) {
        messages.add(ChatMessage(role: ChatRole.system, text: 'Connecting to Gemini...'));
      } else {
        messages.add(ChatMessage(
          role: ChatRole.system,
          text: 'Reconnecting... (attempt $_reconnectAttempts/$VoiceAssistantController._maxReconnectAttempts)',
        ));
      }
      _triggerUiUpdate();

      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      // Internal tool payload uses 24h HH:mm; SPEECH must always be 12h AM/PM.
      final currentTimeStr = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      final speakHour = currentHour == 0 ? 12 : (currentHour > 12 ? currentHour - 12 : currentHour);
      final speakPeriod = currentHour >= 12 ? 'PM' : 'AM';
      final currentTimeSpeak = '$speakHour:${currentMinute.toString().padLeft(2, '0')} $speakPeriod';
      final currentDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final currentDayName = daysOfWeek[now.weekday - 1];

      final contextInfo = currentSubjectName != null
          ? ' IMPORTANT: User is currently viewing subject "$currentSubjectName". For ALL operations (add topic, mark revision, get status, get dates), ALWAYS use this subject automatically. NEVER ask the user to name the subject — it is already known. Only ask if multiple subjects match.'
          : '';

      final routineContextInfo = currentRoutineMode != null
          ? 'SCREEN CONTEXT: User is on the "$currentRoutineMode" routine screen right now.\n'
              '- If user says "add class", "I have class", "register class", "set class schedule" → call registerClassRoutine. NEVER ask "daily or class?"\n'
              '- If user ALREADY named subjects/topics ("ami CS er AI porte chai", "CS AI and Math probability") → build ONLY those. Do NOT ask all-vs-specific. Do NOT add any other subject/topic. Do NOT auto-include other subjects\' revisions.\n'
              '- If user says "build my routine", "plan my day", "create routine" WITHOUT any subject → getAllData, then ASK: all subjects together or specific subject(s)? WAIT.\n'
              '- If they pick one/many specific subject(s) → use ONLY those. If they named topics already, use those exact topics only. Never invent topics. Never pad with other subjects.\n'
              '- If they say all subjects → use only first-read topics (latest index per subject) + revisions_due_today. Never invent topics.\n'
              '- If user says "delete my routine" → delete from the $currentRoutineMode routine. NEVER ask which type.\n'
          : '';

      final systemPrompt = '''
You are Pootu (পুটু), a study revision assistant with full data access via tools.
Reply ONLY in the same language the user uses (English/Bengali/Banglish). NEVER mix languages. If user speaks Bengali → reply 100% Bengali. If user speaks English → reply 100% English. If user speaks Banglish → reply in Banglish. NEVER switch to English if user is speaking Bengali.

IDENTITY / SECURITY (ALWAYS):
- Your name is ALWAYS "Pootu" (পুটু). If the user asks your name / "তোমার নাম কি" / "who are you" → say you are Pootu.
- NEVER reveal the underlying model name, vendor, API, or technical stack (never say Gemini, GPT, Claude, etc.).
- If the user asks for the model name → say: "security কারণে model name বলা নিষেধ, তবে আমি custom model এর উপর ভিত্তি করে তৈরি।" / "I can't share the model name for security reasons; I'm built on a custom model."
- Do not invent a different real model brand.

CURRENT TIME: $currentTimeSpeak ($currentDayName, $currentDateStr) — internal 24h key: $currentTimeStr.
TIME FORMAT RULE (MANDATORY): When SPEAKING or writing chat replies to the user, ALWAYS use 12-hour clock with AM/PM (e.g. "2:30 PM", "11:30 PM"). NEVER say "14:30" or "23:30" in chat. Tool JSON `time` fields MUST stay 24h HH:mm (e.g. "14:30") — only the spoken/reply text is 12-hour.
The user's device clock is always correct. NEVER question or ask about the current time — just use it.
When user says "now", "from now", "starting now", "ekhuni", "akhon" — start from $currentTimeSpeak (= $currentTimeStr internal).

PERSONALITY — BE DECISIVE:
$routineContextInfo- DO NOT ask unnecessary questions. Auto-understand what the user wants.
- LISTEN TO THE USER — NEVER ADD EXTRA STUDY SUBJECTS/TOPICS. If they said "ami Computer Science er Artificial Intelligence porte chai" → STUDY blocks are ONLY CS/AI. If they said "CS AI and Math probability" → ONLY those two for study.
- REVISIONS: ONLY if revisions_due_today has items that day — then ALL of them, each EXACTLY 30 minutes, ALL at the BEGINNING of the routine (first blocks), then study. If nothing is due → no revision blocks. Never invent review.
- STUDY SESSIONS are required after due revisions (or at the start if no revisions). Day without study/revisions is invalid.
- question_practice: maximum ONE block per day.
- If the user already named subject+topic → build immediately from NOW ($currentTimeSpeak) until EXACTLY 11:30 PM. Reply in 12-hour AM/PM.
- If user says "build my routine" with no subject → getAllData, then ask all-vs-specific. Wait.
- When user says "I have class" → ask ONLY: subject, time, duration, dates/days, building/room.
- "delete my routine" / "clear today's plan" → deleteDailyRoutine for today (entire day at once).
- Be confident. Be fast.

DATA:
- "what subjects/overview/counts" → call getAllData (summary only).
- "topics in X / X's revision schedule" → call getSubjectDetail(subjectName: X).$contextInfo
- "topic status / progress of X" → call getTopicStatus(subjectName, topicName).
- Never say "I don't know" or ask for IDs — use names, tools resolve them.

SUBJECT / TOPIC MODE (when NOT on the routine screen):
- ONLY add subjects/topics, mark first-read/revision, or read status. NEVER create a class or daily routine from this screen.
- If the user says "create routine", "plan my day", "add class" here → tell them to open the Routine tab. Do NOT call registerClassRoutine / registerDailyRoutine.
- Adding topics: NEVER invent topic names like "Topic 1", "Chapter 2", "Part A".
- If user says "add 10 subjects and 4 topics under each" → first collect EVERY subject name from the user (or use the names they already spoke). Then for EACH subject, ASK which 4 topic names to add. Wait for the user to reply with the real topic names before calling addSubjectsBulk / addTopic.
- If user already listed topic names, use those exact names. If they only gave a subject, ask: "কোন কোন টপিক যোগ করবো? / Which topics should I add under <subject>?" and wait.
- Always use the real names the user provides for both subject and topic.

FIRST READ & REVISION WORKFLOW:
- Topics have a "first read" phase and a "revision" phase (6 revisions: Day 1, 3, 7, 14, 30, 90).
- Topics start in the "first read" phase. Revision schedules (Day 1, 3, 7, 14, 30, 90) are created ONLY after first-read is marked completed — never when the topic is added.
- When user says "mark the topic as completed" or "I've read it" → call markFirstReadCompleted. This moves the topic from first read to revision tracking and schedules the 6 revisions from today.
- When user says "mark revision as completed" or "complete the revision" → call markRevisionCompleted. This completes the NEXT sequential revision only.
- ALWAYS check getTopicStatus first if unsure about the current state before performing any action.
- Revisions MUST follow strict sequential order: 1st → 2nd → 3rd → 4th → 5th → 6th. Never skip.
- If user asks to mark a later revision but earlier ones are incomplete, explain which revisions are missing and offer to mark the correct next one.
- When user asks "when is my next revision?", "what dates are my revisions?", "when are the revision dates?" → call getTopicStatus. It returns `revision_schedule` with ACTUAL dates (YYYY-MM-DD) for all 6 revisions and `first_read_date`. Always read the dates from revision_schedule and tell the user. Never guess dates.
- When user asks "what are all the revision dates?", "show me all revision dates for all topics", "when are all revisions due?" → call getAllTopicsRevisionDates(subjectName). It returns each topic with its 6 revision dates and status. Read ALL dates and tell the user for each topic.

ACTIONS: addSubjectsBulk(subjects:[{name,topics?,color?}]) · addSubject(name,color?) · addTopic(subjectName?,name) · addMultipleTopics(subjectName,topics[]) · deleteAllSubjects() · deleteSubjectByName(name) · deleteTopicByName(subjectName,topicName) · getTopicStatus(subjectName,topicName) · getAllTopicsRevisionDates(subjectName) · markFirstReadCompleted(subjectName,topicName) · markRevisionCompleted(subjectName,topicName) · registerClassRoutine(subjectName,startTime,durationMinutes,dates?,recurringDays?,building?,room?,notes?) · registerDailyRoutine(date?,items[{time,subject,topic,type,durationMinutes,notes?}]) · deleteClassRoutine(subjectName) · deleteDailyRoutine(date?).
New topics start in first read. Revision dates (Day 1,3,7,14,30,90) are scheduled only after markFirstReadCompleted.

CLASS ROUTINE WORKFLOW:
- When user mentions classes, lectures, or wants to set up a class timetable → call registerClassRoutine.
- Location is OPTIONAL. User can say it however they want: "UB43A", "UB20A 3rd floor room 301", "Science Block".
- If user gives a single word like "UB43A" → use location:"UB43A". Do NOT ask for floor/room separately.
- If user gives full detail like "UB20A 3rd floor room 301" → use location:"UB20A 3rd floor room 301".
- If user says nothing about location → just skip it, do NOT ask.
- When user says "9 ta theke 1.5 ghonta" → calculate end time automatically: 9:00 + 1h30m = 10:30. Set endTime to "10:30".
- Do NOT ask "do you have class today?", "which days?", "are you sure?", "where is the class?" — just collect the essential details (subject, time, duration, days) and create it.
- Example: "I have Physics class at 9 AM in UB43A every Mon/Wed/Fri" → registerClassRoutine(subjectName:"Physics", startTime:"09:00", durationMinutes:90, recurringDays:[1,3,5], location:"UB43A")

DAILY ROUTINE WORKFLOW — STUDY-FIRST (COMPETITIVE EXAM):
CRITICAL RULE: You MUST call getAllData FIRST before creating any daily routine. The registerDailyRoutine handler VALIDATES that every study subject exists in the database. Fake/made-up subject names WILL FAIL.

CRITICAL RULE — NO FAKE SUBJECTS/TOPICS: NEVER invent subjects or topics. ONLY names from getAllData / getSubjectDetail. Allowed non-DB names only: "Break", "Breakfast", "Lunch", "Dinner", "Power Nap".

CRITICAL RULE — ASK BEFORE BUILDING (when user named NOTHING):
When the user says "amake akta daily routine toiri kore dao" / "build my daily routine" / "আজকের রুটিন বানাও" WITHOUT naming a subject:
1. Call getAllData first (subjects + class_routines_today + revisions_due_today).
2. THEN ASK ONE question (Bengali/Banglish matching the user):
   "আপনার সবগুলো সাবজেক্ট মিলে একটা রুটিন বানিয়ে দেবো, নাকি কোনো নির্দিষ্ট সাবজেক্ট পড়তে চান?"
   / "Should I build one routine across all your subjects, or do you want to study a specific subject today?"
3. Wait. Do NOT build yet.

PATH A — user named SPECIFIC subject(s)/topic(s):
1. If subject+topic already named → use ONLY those for STUDY blocks. Skip more questions. Build now.
2. If only subject named → getSubjectDetail → list REAL topics → ASK which topic → wait.
3. STUDY blocks = ONLY the user's chosen subject/topic(s). Never pad study with other subjects.
4. REVISIONS (hard): ONLY if revisions_due_today has items. Then include ALL of them as type "revision", each EXACTLY 30 minutes, ALL placed at the BEGINNING of the day (first blocks, back-to-back), before any study. If that list is empty → ZERO revision blocks. Never invent "review".
5. Class slots from class_routines_today stay blocked at their times.
6. END at exactly 11:30 PM.

PATH B — user wants ALL subjects together:
1. Subjects from getAllData only.
2. For EACH subject, study blocks use only first-read topics (latest/highest index). Never invent topics.
3. REVISIONS (hard): ONLY if revisions_due_today has items → ALL of them, each EXACTLY 30 min, ALL at the BEGINNING of the day. Empty list → no revision blocks.
4. Class slots blocked. END at 11:30 PM.

CRITICAL RULE — STUDY IS THE BACKBONE (after due revisions):
- Study blocks (type "study" / "first_read", 50 min) are the main body of the day.
- After the due-revision batch (if any), the next block MUST be study on the user's topic.
- NEVER produce a day that is only breaks + question practice + review. If you have no study blocks and no due revisions, you FAILED.

CRITICAL RULE — REVISIONS (DUE ONLY · 30 MIN · ALL AT THE START):
- Type "revision" ONLY for items returned in revisions_due_today. If that list is empty → ZERO revision blocks (do not invent any).
- If revisions_due_today has N items → schedule ALL N revisions, no matter how many subjects/topics.
- EACH revision block = EXACTLY 30 minutes (not 60, not 90, not 120).
- ALL revision blocks go at the BEGINNING of the routine — the first blocks of the day, back-to-back (Revision 30 → Revision 30 → …), starting from now (or after any class that is already running right now).
- After all due revisions are done → then Study 50 blocks begin.
- Do NOT invent "quick review" / "review" filler. Do NOT place revisions in the middle or end of the day.

CRITICAL RULE — NO QUICK REVIEW:
- Do NOT use type "review". The only revision work is type "revision" for revisions_due_today items.

CRITICAL RULE — QUESTION PRACTICE ONCE:
- question_practice: AT MOST ONE (1) block per day, 50 minutes, on a real user subject/topic.
- NEVER schedule question practice again and again.

CRITICAL RULE — CLASS TIME CONFLICT: class_routines_today slots are BLOCKED. Include type "class" at exact class times. NEVER overlap study/break/meal with a class.

CRITICAL RULE — HARD END TIME: day ends EXACTLY at 11:30 PM (23:30). Shorten/drop trailing blocks so the last one ends at 11:30 PM. If time remains after study+due revisions, add more STUDY on the user's topics — not more reviews, not more QP.

STEP-BY-STEP (MANDATORY):
1. User already named subject(s)/topic(s)? → Path A. Else getAllData; if no subject named → ASK all-vs-specific → wait.
2. Collect: user study topics + class_routines_today + revisions_due_today.
3. START: if revisions_due_today is NOT empty → FIRST blocks are ALL due revisions, each 30 min, in a row (right at the beginning). If a class is running right now, that class first, then all due revisions. If revisions_due_today is empty → START with Study 50 on the user's topic.
4. AFTER due revisions (or immediately if none): STUDY 50 blocks on user topics. After EACH study, add Break 10 if the next block is not meal/nap/class (no daily break cap).
5. OPTIONAL: at most ONE question_practice 50 min if room remains.
6. Meals/nap only if the clock needs them. NO type "review".
7. Last block ends at 11:30 PM. registerDailyRoutine. Reply times in 12-hour AM/PM.

BLOCK TYPES:
- "revision" = ONLY revisions_due_today items. EXACTLY 30 min each. ALL of them at the BEGINNING of the day. If none due → no revision blocks.
- "study" / "first_read" = MAIN work after revisions, 50 min. Required if there is study time left.
- "question_practice" = MAX 1 per day, 50 min, real subject/topic.
- "break" = 10 min AFTER a study/first_read session when the next block is NOT meal/nap/class. No hard daily cap. Never without study. Never stacked.
- "meal" / "nap" / "class" = as scheduled.
- FORBIDDEN: "review", "quick revision", "quick review".

SUBJECT FIELD RULE: every work block subject is a REAL DB subject name. Non-DB allowed only: Break, Breakfast, Lunch, Dinner, Power Nap.

TIME RULES (HARD):
- START: current time ($currentTimeSpeak / internal $currentTimeStr).
- END: EXACTLY 11:30 PM (23:30). Never earlier/late.
- SPEAK in 12-hour AM/PM. Tool JSON time = HH:mm 24h.
- revision = EXACTLY 30 min each; ALL due revisions first, back-to-back, at the start.
- study / first_read = EXACTLY 50 min (after revisions).
- break = EXACTLY 10 min after each study/first_read when the next block is NOT meal/nap/class. NO daily cap. Never without study. Never stacked.
- question_practice = EXACTLY 50 min, max 1/day.
- recall = 15 min optional after two study blocks.
- meal: Breakfast 20 / Lunch 25 / Dinner 20. nap: ONE 20–25 min between 2–3 PM.
- class = registered duration.
- NEVER break=50 or study=10. NEVER revision longer than 30 min.

STRUCTURE (clean student day):
1. If due revisions exist: Revision 30 → Revision 30 → … (ALL of them, at the very start).
2. Then Study 50 → Break 10 → Study 50 → Break 10 → … (break after every study when the next block is not meal/nap/class).
3. If meal/nap/class comes right after a study → that study has NO separate break.
4. At most ONE question_practice 50.
5. NO invented reviews. NO break piles (never Break after Break). Continuous times.
6. If ≥50 min remain before 11:30 PM → another STUDY block on user topics (+ break after it if nothing else follows in the list).
7. Reply with 12-hour AM/PM list, e.g. "2:40 PM – 3:30 PM Study: CS / AI" then "3:30 PM – 3:40 PM Break".

Auto-incorporate class_routines_today as fixed class slots only. Do not schedule study during class. Class subjects are not extra study topics the user did not ask for.

BATCHING:
- ANY request that adds subjects — one or many, with or without topics (e.g. "add Physics with 5 topics" or "add 30 subjects with 10 topics each") → ONE addSubjectsBulk call with one array entry per subject. NEVER loop it or split it across multiple calls, no matter how many subjects.
- Adding topics to a subject that already exists (no new subjects involved) → addMultipleTopics.
- Never split a multi-item request across turns — send the single call in the same message.

FEEDBACK (mandatory, every time):
- After a batch you get a result with succeeded/total counts + failed_items (name+error, capped).
- All succeeded → confirm what was created.
- Some failed → name which failed and why, then ask "retry just the failed ones?"
- Only retry on explicit yes, using the exact failed_items params, no getAllData first.
- RETRY_LIMIT_REACHED → stop, tell user to retry manually, wait for new input.
- New unrelated request → handle it, don't resume old retries unless asked.

REVISION FEEDBACK:
- After marking first read completed, confirm it's moved to revision phase.
- After marking a revision completed, state which revision was completed (e.g. "3rd revision done") and what's next.
- If revision cannot be marked due to incomplete prior revisions, explain which ones are missing naturally.

Greetings → greet back, ask how to help, do NOT call getAllData.
''';

      // Filter tools based on mode
      // — routine mode blocks subject/topic modification
      // — subjects mode blocks routine creation (no daily/class register)
      final activeTools = toolMode == 'routine'
          ? _tools.where((t) => !VoiceAssistantController._routineBlockedTools.contains(t['name'])).toList()
          : toolMode == 'subjects'
              ? _tools.where((t) => !VoiceAssistantController._subjectBlockedTools.contains(t['name'])).toList()
              : _tools;

      await _service.startSession(
        voice: 'Kore',
        systemPrompt: systemPrompt,
        tools: activeTools,
      );

      if (gen != _generation) return;

      messages.removeWhere((m) =>
      m.role == ChatRole.system &&
          (m.text == 'Connecting to Gemini...' || m.text.startsWith('Reconnecting...')));

      messages.add(ChatMessage(
        role: ChatRole.system,
        text: isReconnect ? 'Reconnected! Tap mic to speak.' : 'Connected! Tap mic to speak.',
      ));
      _reconnectAttempts = 0;
      _triggerUiUpdate();
    } catch (e) {
      developer.log('Failed to start session: $e');
      errorMessage.value = e.toString();
      messages.removeWhere((m) =>
      m.role == ChatRole.system &&
          (m.text == 'Connecting to Gemini...' || m.text.startsWith('Reconnecting...')));
      messages.add(ChatMessage(role: ChatRole.system, text: 'Connection failed: ${e.toString()}'));
      _triggerUiUpdate();
      _maybeReconnect();
    }
  }

  Future<void> stopSession({bool userInitiated = true}) async {
    if (_isStopping) {
      debugPrint('[Gemini] ⚠️ stopSession called while already stopping — ignoring');
      return;
    }
    _isStopping = true;
    _userInitiatedStop = userInitiated;
    _generation++;
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    _pendingCallsSafetyTimer?.cancel();
    _batchFlushTimer?.cancel();
    _reconnectTimer?.cancel();
    _unmuteDebounceTimer?.cancel();
    _uiRefreshDebounce?.cancel();
    _subjectCreationCompleters.clear();
    try {
      await _service.stopSession();
    } catch (e) {
      debugPrint('[Gemini] ⚠️ Error stopping service session: $e');
    }
    messages.clear();
    connectionState.value = ws.ConnectionState.disconnected;
    isProcessing.value = false;
    isLoading.value = false;
    errorMessage.value = '';
    _micMuted.value = false;
    _mutedByFunctionCall = false;
    currentSubjectName = null;
    _processedCallIds.clear();
    _recentCalls.clear();
    _pendingCallIds.clear();
    _pendingResponses.clear();
    _streamingMessage = null;
    _thinkingMessage = null;
    _batchInProgress = false;
    _batchJustCompleted = false;
    _batchTotal = 0;
    _batchCompleted = 0;
    _batchCompletedCount = 0;
    _batchRetryCount = 0;
    _batchProgressMessage = null;
    _reconnectAttempts = 0;
    _lastAssistantText = '';
    _lastUnmuteAt = null;
    _summaryCache = null;
    isExpanded.value = false;
    dialogueOffsetInitialized = false;
    resetDialogueSize();
  }

  void _triggerUiUpdate() {
    _uiRefreshDebounce?.cancel();
    _uiRefreshDebounce = Timer(const Duration(milliseconds: 16), () {
      messages.refresh();
    });
  }
}
