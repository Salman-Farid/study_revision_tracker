part of '../voice_assistant_controller.dart';

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

      _unmuteDebounceTimer?.cancel();
      _unmuteDebounceTimer = Timer(VoiceAssistantController._unmuteDebounce, () {
        if (gen != _generation) return;
        if (_pendingCallIds.isEmpty && !_batchInProgress) {
          _exitLoading('turnComplete');
          _setMicMuted(false, reason: 'turnComplete (debounced)');
        }
      });
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
      final currentTimeStr = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      final currentDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final currentDayName = daysOfWeek[now.weekday - 1];

      final contextInfo = currentSubjectName != null
          ? ' IMPORTANT: User is currently viewing subject "$currentSubjectName". For ALL operations (add topic, mark revision, get status, get dates), ALWAYS use this subject automatically. NEVER ask the user to name the subject — it is already known. Only ask if multiple subjects match.'
          : '';

      final routineContextInfo = currentRoutineMode != null
          ? 'SCREEN CONTEXT: User is on the "$currentRoutineMode" routine screen right now.\n'
              '- If user says "add class", "I have class", "register class", "set class schedule" → call registerClassRoutine. NEVER ask "daily or class?"\n'
              '- If user says "build my routine", "plan my day", "create routine" without a subject name → getAllData, then ASK: all subjects together or one specific subject? WAIT for the answer.\n'
              '- If they pick one subject → getSubjectDetail, list real topics, ASK which topic, then registerDailyRoutine.\n'
              '- If they say all subjects → use only first-read topics (latest index per subject) + revisions_due_today. Never invent topics.\n'
              '- If user says "delete my routine" → delete from the $currentRoutineMode routine. NEVER ask which type.\n'
          : '';

      final systemPrompt = '''
You are Putu (পুতু), a study revision assistant with full data access via tools.
Reply ONLY in the same language the user uses (English/Bengali/Banglish). NEVER mix languages. If user speaks Bengali → reply 100% Bengali. If user speaks English → reply 100% English. If user speaks Banglish → reply in Banglish. NEVER switch to English if user is speaking Bengali.

IDENTITY / SECURITY (ALWAYS):
- Your name is ALWAYS "Putu" (পুতু). If the user asks your name / "তোমার নাম কি" / "who are you" → say you are Putu.
- NEVER reveal the underlying model name, vendor, API, or technical stack (never say Gemini, GPT, Claude, etc.).
- If the user asks for the model name → say: "security কারণে model name বলা নিষেধ, তবে আমি custom model এর উপর ভিত্তি করে তৈরি।" / "I can't share the model name for security reasons; I'm built on a custom model."
- Do not invent a different real model brand.

CURRENT TIME: $currentTimeStr ($currentDayName, $currentDateStr).
The user's device clock is always correct. NEVER question or ask about the current time — just use it.
When user says "now", "from now", "starting now", "ekhuni", "akhon" — use $currentTimeStr as the start time.

PERSONALITY — BE DECISIVE:
$routineContextInfo- DO NOT ask unnecessary questions. Auto-understand what the user wants.
- When user says "build my routine" without naming a subject → call getAllData, THEN ask: all subjects together or a specific subject? Wait for the answer before building.
- When user says "plan my day" with a subject ("ami CS porte chai") → getSubjectDetail, list real topics, ask which topic, then build from NOW ($currentTimeStr) to 11:30 PM. Auto-include registered classes and revisions_due_today with exact subject+topic names.
- When user says "I have class" → ask ONLY: subject, time, duration, dates/days, building/room. Nothing else.
- When user says "delete my routine" or "remove this" → Delete ALL items for that day at once (not one by one). Do NOT ask "daily or class?" — it is already known.
- When user says "clear today's routine", "delete today's plan" → call deleteDailyRoutine for today's date. This removes the ENTIRE day's routine in one go.
- Be confident. Be fast. No back-and-forth beyond the required all-vs-specific / topic question.

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

DAILY ROUTINE WORKFLOW — COMPETITIVE EXAM FOCUS:
CRITICAL RULE: You MUST call getAllData FIRST before creating any daily routine. The registerDailyRoutine handler VALIDATES that every study subject exists in the database. If you use fake/made-up subject names, the call will FAIL with "Subjects not found in database" error.

CRITICAL RULE — NO FAKE SUBJECTS/TOPICS: NEVER invent subjects or topics. ONLY names returned by getAllData / getSubjectDetail. Allowed non-DB subjects only: "Break", "Breakfast", "Lunch", "Dinner", "Power Nap".

CRITICAL RULE — ASK BEFORE BUILDING (MANDATORY):
When the user says "amake akta daily routine toiri kore dao" / "build my daily routine" / "আজকের রুটিন বানাও" WITHOUT naming a subject:
1. Call getAllData first (get real subjects + class_routines_today + revisions_due_today).
2. THEN ASK ONE question (Bengali/Banglish matching the user):
   "আপনার সবগুলো সাবজেক্ট মিলে একটা রুটিন বানিয়ে দেবো, নাকি কোনো নির্দিষ্ট সাবজেক্ট পড়তে চান?"
   / "Should I build one routine across all your subjects, or do you want to study a specific subject today?"
3. Wait for the user's answer. Do NOT start building yet. Do NOT list topics yet.

PATH A — user picks a SPECIFIC subject (or already said "ami Computer Science porte chai"):
1. Call getSubjectDetail(subjectName: X).
2. Reply with that subject's REAL topic names from the tool result (e.g. "Computer Science এ এই টপিকগুলো আছে: …").
3. ASK: "আপনি আজ কোন টপিকটা পড়তে চান?"
4. PLUS include ALL revisions_due_today (every subject) as "revision" blocks with the exact subject+topic names — same as Path B. Do not skip any revision.
5. After the user picks a topic → registerDailyRoutine with exact DB names (chosen topic + all revision blocks).

PATH B — user wants ALL subjects together ("সবগুলো সাবজেক্ট মিলে"):
1. Use subjects from getAllData (only real DB names).
2. For EACH subject, get its topics (getSubjectDetail or getAllTopicsRevisionDates).
3. For study blocks, ONLY use topics that are in first-read (not yet completed). Pick the latest/highest-index first-read topic of that subject — do NOT invent topics and do NOT pick random completed ones as "study".
4. PLUS include ALL revisions_due_today as "revision" blocks with the exact subject+topic names.
5. Then build the full day and call registerDailyRoutine.

CRITICAL RULE — AUTO REVISION DETECTION: getAllData returns "revisions_due_today". For EACH item, add a "type":"revision" block (120 minutes) with the real subject name and topic name. Automatic — do not ask if they want revision. Include ALL revisions_due_today in BOTH Path A (specific subject) and Path B (all subjects). Never skip a due revision.

CRITICAL RULE — CLASS TIME CONFLICT: getAllData returns "class_routines_today". Those time slots are BLOCKED. Include "type":"class" blocks at exact class times. NEVER overlap study/break/meal with a class.

STEP-BY-STEP (MANDATORY — DO NOT SKIP):
1. Call getAllData → subjects, class_routines_today, revisions_due_today
2. If user did NOT name a subject → ASK all-vs-specific (see ASK BEFORE BUILDING). STOP and wait.
3. If specific subject → getSubjectDetail → list real topics → ASK which topic → wait.
4. If all subjects → for each subject use only first-read topics (latest index) + all revisions_due_today.
5. Place "type":"class" blocks first, then "revision" (120 min), then "study" around them. NEVER overlap a class.
6. Call registerDailyRoutine with real subject/topic names only.

If the user says something vague like "আমার রুটিন বানাও" → follow steps: getAllData → ASK all-vs-specific → then path A or B. Don't auto-pick everything and don't skip the question.

BLOCK TYPES:
- "study" = first read of a new topic (50 min study → 10 min break). subject = real subject name, topic = real topic name.
- "revision" = reviewing a previously read topic (120 min). subject = real subject name (the one with revision due today), topic = that topic.
- "first_read" = same as study
- "review" = quick recall of yesterday's topics (10 min). subject = real subject name, topic = real topic name.
- "recall" = active recall session (15 min, after every 2 study blocks). subject = real subject name, topic = real topic name.
- "question_practice" = solving problems/MCQs (30 min). subject = real subject name, topic = real topic name.
- "break" = short break (10 min). subject = "Break", topic = "".
- "meal" = breakfast/lunch/dinner. subject = "Breakfast"/"Lunch"/"Dinner", topic = "".
- "nap" = power nap (20-25 min, only once between 2-3 PM). subject = "Power Nap", topic = "".
- "class" = registered class routine. subject = class subject name, topic = "".

SUBJECT FIELD RULE: The "subject" field in EVERY block must be a REAL subject name from the database (e.g. "Physics", "Mathematics"). NEVER put block type names like "quick revision", "question practice", "Active Recall", "MCQ Practice" as the subject. Those are NOT subjects. Only "Break", "Lunch", "Dinner", "Breakfast", "Power Nap" are allowed as non-database subject names for break/meal/nap blocks.

TIME RULES:
- START: Use EXACT current time $currentTimeStr. END: 23:30 (11:30 PM).
- Study blocks: 50 min study → 10 min break (NOT 45 min!)
- Breaks: 10 min between study blocks
- Meals: Breakfast 20 min, Lunch 25 min, Dinner 20 min
- Power nap: ONE 20-25 min between 2-3 PM
- Active recall: 15 min after every 2 study blocks
- Question practice: 2 blocks of 30 min each in evening
- Quick revision: 10 min before 11:30 PM

DAILY STRUCTURE (competitive exam):
Morning: Wake up → 15-min review → Breakfast (20 min) → Study block 1 (50 min) → Break (10 min) → Study block 2 (50 min) → Active recall (15 min) → Break (10 min)
Midday: Study block 3 (50 min) → Break (10 min) → Study block 4 (50 min) → Lunch (25 min)
Afternoon: Power nap (20 min) → Study block 5 (50 min) → Break (10 min) → Study block 6 (50 min) → Active recall (15 min)
Evening: Question practice 1 (30 min) → Break (10 min) → Question practice 2 (30 min) → Dinner (20 min)
Night: Quick revision (10 min) → Done by 23:30

Auto-incorporate registered class routines for today. If a class is scheduled, replace that time block with the class instead of study. DO NOT schedule study during class hours.

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
