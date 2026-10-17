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
        _reconnectGiveUpNotified = false;
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
        // sendText() already added this bubble — don't duplicate it.
        final last = messages.isNotEmpty ? messages.last : null;
        final alreadyShown =
            last != null && last.role == ChatRole.user && last.text == trimmed;
        if (!alreadyShown) {
          messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
        }
        _batchRetryCount = 0;
        if (_redriveEchoWindow) {
          // Echo of our own reconnect re-drive — not a genuinely new user turn.
          debugPrint('[Gemini] 🔁 Re-drive echo — keeping dedup cache');
        } else {
          _recentCalls.clear();
        }
        _lastBatchSummaries = [];
        _awaitingAssistantReply = true;
        isProcessing.value = true;
        // New user turn (incl. barge-in / re-drive echo): the previous
        // assistant turn is over — drop the streaming pointer so a stale
        // message can't shadow "Thinking..." for the new turn.
        _streamingMessage = null;
        _showThinking();
        debugPrint('[Gemini] 🆕 New user message — waiting for Pootu');
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
        if (t.trim().isNotEmpty) {
          _awaitingAssistantReply = false;
          _silentRecoverTimer?.cancel();
          _removeSilentNotices();
        }
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
      final hadReply = (_streamingMessage != null &&
              _streamingMessage!.text.trim().isNotEmpty) ||
          _assistantRepliedSinceUser();
      if (hadReply) {
        if (_streamingMessage != null && _streamingMessage!.text.trim().isNotEmpty) {
          _lastAssistantText = _streamingMessage!.text;
        }
        _awaitingAssistantReply = false;
        _silentRecoverTimer?.cancel();
        _removeSilentNotices();
      }
      _mutedByFunctionCall = false;
      _streamingMessage = null;
      _clearThinking();
      isProcessing.value = false;
      _exitLoading('turn-complete');
      debugPrint('[Gemini] 🔚 Turn complete (reply=$hadReply)');

      _batchFlushTimer?.cancel();
      if (_batchJustCompleted) {
        _finishBatchUi();
      }

      // Do NOT claim "did not reply" immediately — Gemini often streams
      // AFTER tool/turnComplete. Wait; if a reply shows up, notice is removed.
      if (!hadReply && _awaitingAssistantReply) {
        final delay = _batchJustCompleted
            ? const Duration(seconds: 10)
            : const Duration(seconds: 6);
        _scheduleSilentRecover(
          delay,
          reason:
              'Still waiting for Pootu… Tap mic or send again if it stays quiet.',
        );
      }

      scheduleUnmuteAfterTurn(gen);
      _updateFloorStatus();
      _triggerUiUpdate();
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
    _thinkingSafetyTimer?.cancel();
    _thinkingSafetyTimer = Timer(const Duration(seconds: 18), () {
      // Stuck tool calls were the main "Thinking forever" bug — force flush.
      if (_pendingCallIds.isNotEmpty || _batchInProgress) {
        debugPrint('[Gemini] ⏰ Thinking safety — force-flush stuck tools');
        final gen = _generation;
        _pendingCallIds.clear();
        _flushBatch(gen, forcedByTimeout: true);
      }
      if (_streamingMessage != null &&
          _streamingMessage!.text.trim().isNotEmpty) {
        _awaitingAssistantReply = false;
        _clearThinking();
        isProcessing.value = false;
        _exitLoading('thinking-reply-ok');
        return;
      }
      if (_assistantRepliedSinceUser()) {
        _awaitingAssistantReply = false;
        _clearThinking();
        isProcessing.value = false;
        _exitLoading('thinking-reply-ok');
        return;
      }
      _noteSilentTurn(
        reason:
            'Still waiting for Pootu… Tap mic or send again if it stays quiet.',
        force: true,
      );
    });
  }

  void _clearThinking() {
    _thinkingSafetyTimer?.cancel();
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
    if (_userInitiatedStop || _isStopping) return;
    if (_reconnectTimer?.isActive ?? false) return; // retry already scheduled — don't stack
    if (_reconnectAttempts >= VoiceAssistantController._maxReconnectAttempts) {
      if (!_reconnectGiveUpNotified) {
        _reconnectGiveUpNotified = true;
        debugPrint('[Gemini] ❌ Max reconnect attempts reached — giving up');
        messages.add(ChatMessage(
          role: ChatRole.system,
          text: 'Connection lost. Tap the mic to reconnect.',
        ));
        _triggerUiUpdate();
      }
      return;
    }
    _reconnectAttempts++;
    // Fast, aggressive reconnect: the first retry fires almost immediately so
    // a transient drop recovers before the user feels it; then back off.
    final delay = _reconnectAttempts == 1
        ? const Duration(milliseconds: 300)
        : _reconnectAttempts == 2
            ? const Duration(seconds: 1)
            : const Duration(seconds: 2);
    final delayLabel = delay.inMilliseconds < 1000
        ? '${delay.inMilliseconds}ms'
        : '${delay.inSeconds}s';
    debugPrint('[Gemini] 🔁 Reconnect attempt $_reconnectAttempts/${VoiceAssistantController._maxReconnectAttempts} in $delayLabel');
    _reconnectTimer?.cancel();
    final gen = _generation;
    _reconnectTimer = Timer(delay, () {
      if (gen != _generation || _userInitiatedStop) return;
      startSession(isReconnect: true);
    });
  }

  Future<void> startSession({bool isReconnect = false}) async {
    try {
      // Callers (e.g. RoutineController.openAssistant) fire stopSession()
      // + startSession() back-to-back without awaiting. Wait for any
      // in-flight stop to fully finish first — otherwise the stop tears
      // down the socket this start just created, and the UI gets stuck
      // on "Connecting" / flaps between states.
      while (_stopFuture != null) {
        await _stopFuture;
      }
      // Another start won the race while we were waiting.
      if (_isStarting) return;
      _isStarting = true;
      _userInitiatedStop = false;
      _isStopping = false;
      _sessionStartRequested = true;
      final gen = ++_generation;
      if (!isReconnect) {
        _reconnectAttempts = 0;
        _reconnectGiveUpNotified = false;
      }

      // Floor must say Connecting (not Offline) while the socket comes up.
      connectionState.value = ws.ConnectionState.connecting;
      _updateFloorStatus();

      _setupListeners();

      if (!isReconnect) {
        messages.add(ChatMessage(role: ChatRole.system, text: 'Connecting to Gemini...'));
      } else {
        messages.add(ChatMessage(
          role: ChatRole.system,
          text: 'Reconnecting... (attempt $_reconnectAttempts/${VoiceAssistantController._maxReconnectAttempts})',
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

      final topicContextInfo = (currentTopicName != null &&
              currentTopicName!.trim().isNotEmpty)
          ? ' TOPIC CONTEXT: User is on the SUBTOPIC screen for topic "${currentTopicName}"'
              '${currentSubjectName != null ? ' in subject "$currentSubjectName"' : ''}. '
              'Any request to add a subtopic / add something under this topic / "add X here" → '
              'call addSubtopics(subjectName: "${currentSubjectName ?? ''}", topicName: "${currentTopicName}", names: [user names]). '
              'NEVER addTopic/addMultipleTopics/addSubjectsBulk without parentTopicName while on this screen — '
              'that wrongly puts names on the SUBJECT instead of under the TOPIC. '
              'Subtopic ≠ Topic.\n'
          : '';

      final pendingAskInfo = pendingSubtopicAsks.isEmpty
          ? ''
          : '\nUNFINISHED DUTY (FIRST PRIORITY): You already created '
              '${pendingSubtopicAsks.map((e) => 'topic "${e['topic']}" under subject "${e['subject']}"').join('; ')} '
              'and have NOT yet asked about SUBTOPICS. '
              'Before any other topic write: ask in the user\'s language '
              '"Do you want any subtopics under <those topics>?" and WAIT. '
              'Yes + names → addSubtopics ONLY (topicName = parent). '
              'New unrelated topics → write tool with confirmNewTopics: true. '
              'Subtopic ≠ Topic — never put a subtopic on a subject.\n';

      final routineContextInfo = currentRoutineMode != null
          ? 'SCREEN CONTEXT: User is on the "$currentRoutineMode" routine screen right now.\n'
              '- If user says "add class", "I have class", "register class", "set class schedule" → call registerClassRoutine. NEVER ask "daily or class?"\n'
              '- If user ALREADY named subjects/topics ("ami CS er AI porte chai", "CS AI and Math probability") → build ONLY those. Do NOT ask all-vs-specific. Do NOT add any other subject/topic. Do NOT auto-include other subjects\' revisions.\n'
              '- If user says "build my routine", "plan my day", "create routine" WITHOUT any subject → getAllData, then ASK: all subjects together or specific subject(s)? WAIT.\n'
              '- If they pick one/many specific subject(s) → use ONLY those. If they named topics already, use those exact topics only. Never invent topics. Never pad with other subjects.\n'
              '- If they say all subjects → use only first-read topics (latest index per subject) + revisions_due_today. Never invent topics.\n'
              '- If user says "delete my routine" → delete from the $currentRoutineMode routine. NEVER ask which type.\n'
          : '';

      final subjectsModeInfo = toolMode == 'subjects'
          ? '\nSCREEN: Subjects tab.\n'
              'HIERARCHY (ABSOLUTE): Subject → Topic → Subtopic.\n'
              '- TOPIC = under SUBJECT (addTopic / addMultipleTopics / addSubjectsBulk topics).\n'
              '- SUBTOPIC = under TOPIC (addSubtopics). They are NOT the same thing.\n'
              '- After EVERY topic create you MUST ask (user language): "Do you want any subtopics under <topic>?" WAIT. Never skip. Never jump to another task first.\n'
              '- "subtopic under Y" / "Y er bhitore" / "topic er niche" → addSubtopics(subjectName, topicName: Y, names: [...]). NEVER subject-level addTopic for those names.\n'
              '- If write returns blocked=hierarchy_pending_subtopic_question → ask the question, or addSubtopics, or confirmNewTopics: true only for real new topics.\n'
              '- getAllData / getSubjectDetail for lists; answer in ONE language. Parent Done only when ALL subtopics finish first-read + 6 revisions.\n'
              '- Routine create/delete blocked here — open Routine tab.\n'
          : '';

      final systemPrompt = '''
You are Pootu (পুটু), a study revision assistant with full data access via tools.

LANGUAGE LOCK (ABSOLUTE #1 RULE — ONE LANGUAGE PER REPLY, NEVER DOUBLE):
$subjectsModeInfo- You are multilingual: you CAN use any language Gemini Live supports (English, Bengali, Hindi, Urdu, Arabic, Chinese, Japanese, Korean, Spanish, French, …). NEVER claim you only speak Bengali/English.
- Pick EXACTLY ONE language: the language of the USER's LAST message (or the language they just requested).
- Output that ONE language only — one script, one pass. STOPS when the answer is done.
- FORBIDDEN — this is why users get angry:
  • Do NOT reply in two languages in the same turn (e.g. Hindi THEN Bengali, or Hindi THEN English).
  • Do NOT translate your answer after speaking it.
  • Do NOT repeat the same sentence in another language.
  • Do NOT append an English gloss after a non-English reply.
  • Do NOT start in Hindi and finish in Bengali/English (or any other mix).
- ONE reply = ONE language = the detected/requested language. Full stop.
- Examples:
  • User: "मैं हिंदी में बात करना चाहता हूँ" → reply ONLY in Hindi (Devanagari). No Bengali. No English.
  • User: "আমি বাংলায় কথা বলতে চাই" → reply ONLY in Bengali (বাংলা). No Hindi. No English.
  • User: "Create my routine" → reply ONLY in English.
  • User: "routine banao" (Hindi/Banglish request for Hindi) → if they used Hindi words + asked Hindi → Hindi only.
- SCRIPT: Match the language's native script. Bengali → বাংলা only (never Devanagari). Hindi → Devanagari only. Chinese → Hanzi only.
- If asked which languages you speak → answer in THEIR language, short: you follow whatever language they use. Do not list languages in three scripts.
- Subject/topic names from the database may stay as stored (often English). Every other word = that one language.
- Tool JSON keys stay English. Your spoken/chat reply = that one language only.
- Every turn (routine, delete, create, greet, error): same single-language rule.

IDENTITY / SECURITY (ALWAYS):
- Your name is "Pootu" — say/write it naturally in the user's ONE language if needed (Pootu / পুটু / पूतु). Do not give a bilingual name intro.
- NEVER reveal model/vendor/API names.
- Model-name question → answer once, in their language only.
- Do not invent another real AI brand.

CURRENT TIME: $currentTimeSpeak ($currentDayName, $currentDateStr) — internal 24h key: $currentTimeStr.
TIME FORMAT RULE: Speak/write times in 12-hour AM/PM in the user's language (e.g. "2:30 PM" / "বিকাল ২:৩০"). Tool JSON `time` stays HH:mm 24h.
Device clock is always correct. "now" / "ekhuni" / "akhon" → $currentTimeSpeak.

PERSONALITY — BE DECISIVE:
$routineContextInfo- DO NOT ask unnecessary questions. Auto-understand what the user wants.
- LISTEN TO THE USER — NEVER ADD EXTRA STUDY SUBJECTS/TOPICS.
- TOPIC vs SUBTOPIC: topic is under a subject; subtopic is under a topic. After creating a topic, you MUST ask if they want subtopics under it. If they say add subtopics under X → addSubtopics only.
- REVISIONS: ONLY if revisions_due_today has items that day — ALL of them, each EXACTLY 30 minutes, ALL at the BEGINNING. If nothing due → no revision blocks. Never invent review.
- STUDY SESSIONS are required after due revisions (or at the start if no revisions).
- question_practice: maximum ONE block per day.
- BREAKS: after EACH study add break 10 ONLY if next block is not meal/nap/class. No daily cap. Never break without study. Never put Break before meal/class (meal covers the break). App merges adjacent breaks (never 10 then 6). GAPS: prefer STUDY (gap >= 20 min), else Active Recall (gap > 10), else Break (gap <= 10). Maximize study sessions.
- If the user already named subject+topic → build immediately from NOW until EXACTLY 11:30 PM. Do NOT read out the routine after saving.
- MEAL SLOTS (FIXED, 20 min each) — include ONLY if still upcoming at create time:
  Breakfast 8:00–8:20 AM · Lunch 1:30–1:50 PM · Snack 5:00–5:20 PM · Dinner 8:00–8:20 PM.
  Create at 9 PM → NO dinner (slot already gone). Create at 3 AM → all upcoming meals included.
  Never invent other meal times. App injects these slots automatically.
- DAY WINDOW: ALWAYS from the EXACT MINUTE of create (2:00 AM → starts 2:00) to EXACTLY 11:30 PM. HARD END 23:30 — the last block always ends at 11:30 PM.
- If user says "build my routine" with no subject → getAllData, then ask all-vs-specific IN THEIR LANGUAGE. Wait.
- When user says "I have class" → ask ONLY: subject, time, duration, dates/days, building/room — in their language.
- "delete my routine" / "clear today's plan" → deleteDailyRoutine for today. THEN always reply in the user's language that it was deleted (visible feedback). If they say "now create a new routine" in the same turn or immediately after → getAllData (fresh) → build only what they asked for → registerDailyRoutine. Do NOT re-delete. Do NOT sit in Thinking. Do NOT re-ask the same question twice.
- After ANY successful delete/create, UI refreshes automatically — tell the user what happened, then continue.

DATA:
- "what subjects/overview/counts" → getAllData.
- "topics in X" → getSubjectDetail(subjectName: X).$contextInfo$topicContextInfo
- "topic status" → getTopicStatus(subjectName, topicName).
- Never say "I don't know" — use names; tools resolve them.

SUBJECT / TOPIC MODE (when NOT on the routine screen):
- ONLY add subjects/topics, mark first-read/revision, or read status. NEVER create class/daily routine here.
- HIERARCHY LOCK: Subject → Topic → Subtopic. Subtopic lives UNDER a topic, never directly under a subject.
- After EVERY successful topic create (addTopic / addMultipleTopics / addSubjectsBulk topics) you MUST ask:
  "Do you want any subtopics under <topic names>?" in the user's language, then WAIT. Never skip. Never answer something else first.
- User: "subtopic under X" / "X er bhitore" / "topic er niche subtopic" → addSubtopics(subjectName, topicName: X, names: [...]).
  NEVER addTopic/addMultipleTopics/addSubjectsBulk for those names — that wrongly creates subject-level topics.
- If a write is blocked with hierarchy_pending_subtopic_question → ask the subtopic question, or use addSubtopics, or confirmNewTopics: true.
- Parent topic with subtopics: no own revision; Done when ALL subtopics complete first-read + all 6 revisions; ring % on the card.
- getSubjectDetail includes nested subtopics[].
- If the parent topic isn't found by name, call getSubjectDetail first to verify the exact topic name — never invent one.
$pendingAskInfo

FIRST READ & REVISION WORKFLOW:
- Revisions Day 1,3,7,14,30,90 only after first-read completed.
- Sequential order: 1st → 2nd → … Never skip.
- Dates come from getTopicStatus / getAllTopicsRevisionDates — never guess.

DAILY ROUTINE WORKFLOW — STUDY-FIRST:
CRITICAL: Call getAllData before creating any daily routine. Fake subject names FAIL validation.
NO FAKE SUBJECTS/TOPICS. Allowed non-DB labels: Break, Breakfast, Lunch, Snack, Dinner, Power Nap. NEVER invent names like "Study Gap Filler" / "Self Study" / "Final Study Gap Filler" as study subjects — use real subject names from getAllData only (e.g. Computer Science). App fills empty gaps itself.
ASK BEFORE BUILDING only when user named NOTHING: ask all-vs-specific in their language, WAIT.
WINDOW: ALWAYS from the EXACT MINUTE the user creates (7:20 AM → first block starts 7:20). HARD END: last block MUST finish at EXACTLY 11:30 PM (23:30) — never earlier, never later. App enforces this. NEVER start later than create time. NEVER start at 8:00 unless they create at 8:00.
FRESHEN UP: if create time is before 8:00 AM, app auto-inserts a 30-min Freshen Up at the start (7:20 → Freshen Up 7:20–7:50). Do NOT invent or omit it. After 8:00 AM → no Freshen Up.
NEVER SKIP A GAP: if a block does not fit the gap, use a short study or short break to fill it. App splits blocks automatically — never drop a study block, never leave empty holes between meals/classes.
MEALS (locked, 20 min): Breakfast 8:00 AM · Lunch 1:30 PM · Snack 5:00 PM · Dinner 8:00 PM.
Include a meal ONLY if create time is at/before its start. 9 PM create → no dinner. App places meals automatically — do not invent times.
PATH A (specific subjects/topics): STUDY only those. REVISIONS only if revisions_due_today non-empty → ALL, 30 min each, ALL first. END 11:30 PM.
PATH B (all subjects): first-read study topics + ALL due revisions (30 min, first) if any. END 11:30 PM.
REVISION RULE: empty due list → zero revision blocks. Due list → all of them, 30 min, back-to-back at the start. NEVER type "review".
STUDY BACKBONE: after revisions (or immediately if none) → Study 50 blocks on real topics. Day without study/revisions is invalid.
BREAK RULE (FIXED): EVERY study session gets a 10-min Break after it. Skip ONLY if the next block is meal/nap/class/freshen-up — those COVER the break (no extra Break, no Break right before Lunch/Dinner). Otherwise always 10-min Break after study. Never stacked. Never break without study. GAP FILL (prefer study): gap >= 20 min → STUDY session; gap > 10 min → Active Recall; gap <= 10 min → Break. Adjacent breaks are merged (no 10+6). Maximize study sessions over recall/breaks.
QUESTION PRACTICE: max 1/day, 50 min.
CLASS MUST APPEAR: if the user has class today (see class_routines_today in getAllData), that class MUST be in the daily routine at its exact time — fixed rule. CLASS slots blocked at registered times. Never overlap.
HARD END: last block ends EXACTLY 11:30 PM (23:30).
BLOCK TYPES: study/first_read=50 · revision=30 (due only, first) · break=10 · question_practice=50 max 1 · meal=20 (fixed slots only) · nap/class as scheduled. FORBIDDEN: review.
AFTER SUCCESS REPLY: YOU MUST say one clear line in THEIR language — that the routine is ready and how many blocks (e.g. "Done — your routine is ready, 12 blocks" / "রুটিন তৈরি হয়েছে"). NEVER stay silent. Do NOT recite every time slot — UI shows the plan.

BATCHING: one addSubjectsBulk / addMultipleTopics call per request — never split.
FEEDBACK: confirm what was created in the user's language; if some failed, name them and ask retry?
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

      if (gen != _generation) {
        _isStarting = false;
        return;
      }

      // Never post a false "Connected!" — the service can return without
      // throwing after a silent no-op or a mid-handshake kill. Verify the
      // socket is truly connected (synchronous read, no stream lag).
      if (_service.socket?.state != ws.ConnectionState.connected) {
        _isStarting = false;
        debugPrint('[Gemini] ⚠️ startSession returned but socket is not connected — treating as failure');
        messages.removeWhere((m) =>
        m.role == ChatRole.system &&
            (m.text == 'Connecting to Gemini...' || m.text.startsWith('Reconnecting...')));
        messages.add(ChatMessage(
            role: ChatRole.system, text: 'Connection failed: socket not connected'));
        _triggerUiUpdate();
        _maybeReconnect();
        return;
      }

      messages.removeWhere((m) =>
      m.role == ChatRole.system &&
          (m.text == 'Connecting to Gemini...' || m.text.startsWith('Reconnecting...')));

      messages.add(ChatMessage(
        role: ChatRole.system,
        text: isReconnect ? 'Reconnected! Tap mic to speak.' : 'Connected! Tap mic to speak.',
      ));
      _reconnectAttempts = 0;
      _reconnectGiveUpNotified = false;
      _triggerUiUpdate();
      // If we were waiting for a reply when the drop happened, the new
      // session has no context of the interrupted turn (no session resumption
      // yet). Re-send the last user message so the turn completes without
      // the user having to repeat themselves manually.
      if (isReconnect && _awaitingAssistantReply) {
        ChatMessage? lastUser;
        for (var i = messages.length - 1; i >= 0; i--) {
          if (messages[i].role == ChatRole.user) {
            lastUser = messages[i];
            break;
          }
        }
        if (lastUser != null && lastUser.text.trim().isNotEmpty) {
          debugPrint('[Gemini] 🔄 Re-driving interrupted turn after reconnect');
          _batchRetryCount = 0;
          // Do NOT clear _recentCalls here: the resumed session may re-issue
          // tool calls from the interrupted turn (new call ids, identical
          // args). The success-dedup cache must survive the reconnect so those
          // are answered from cache instead of re-executed — a re-executed
          // deleteDailyRoutine would fail with "nothing to delete" even though
          // it already succeeded before the drop.
          // The incoming USER: echo of this re-drive is not a new turn either.
          _redriveEchoWindow = true;
          _redriveEchoTimer?.cancel();
          _redriveEchoTimer = Timer(const Duration(seconds: 15), () {
            _redriveEchoWindow = false;
          });
          _removeSilentNotices();
          _silentRecoverTimer?.cancel();
          isProcessing.value = true;
          _awaitingAssistantReply = true;
          _setMicMuted(true, reason: 're-drive after reconnect');
          _showThinking();
          try {
            _service.sendText(lastUser.text);
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Re-drive send failed: $e');
          }
          messages.add(ChatMessage(
            role: ChatRole.system,
            text: 'Re-sent your last message after reconnect.',
          ));
          _updateFloorStatus();
          _triggerUiUpdate();
        }
      }
      _isStarting = false;
    } catch (e) {
      _isStarting = false;
      developer.log('Failed to start session: $e');
      errorMessage.value = e.toString();
      // Clear the service latch so the reconnect below isn't a silent no-op.
      try {
        await _service.stopSession();
      } catch (_) {}
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
      // Coalesce: a stop is already running. Return its future so
      // startSession's wait-for-stop loop resolves only when it truly ends.
      debugPrint('[Gemini] ⚠️ stopSession called while already stopping — joining in-flight stop');
      return _stopFuture ?? Future<void>.value();
    }
    _isStopping = true;
    _isStarting = false; // any in-flight start's socket is now dead; don't let the stale flag veto its replacement
    final done = Completer<void>();
    _stopFuture = done.future;
    try {
      _userInitiatedStop = userInitiated;
      _sessionStartRequested = false;
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
      pendingSubtopicAsks.clear();
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
      currentTopicName = null;
      _processedCallIds.clear();
      _recentCalls.clear();
      _redriveEchoTimer?.cancel();
      _redriveEchoWindow = false;
      _lastBatchSummaries = [];
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
      _reconnectGiveUpNotified = false;
      _lastAssistantText = '';
      _lastUnmuteAt = null;
      _summaryCache = null;
      isExpanded.value = false;
      dialogueOffsetInitialized = false;
      resetDialogueSize();
    } finally {
      // Always release the gate — a dropped stop left later stops silently
      // skipped and startSession waiting forever.
      _isStopping = false;
      _stopFuture = null;
      done.complete();
    }
  }

  void _triggerUiUpdate() {
    _updateFloorStatus();
    _uiRefreshDebounce?.cancel();
    _uiRefreshDebounce = Timer(const Duration(milliseconds: 50), () {
      messages.refresh();
    });
  }
}


