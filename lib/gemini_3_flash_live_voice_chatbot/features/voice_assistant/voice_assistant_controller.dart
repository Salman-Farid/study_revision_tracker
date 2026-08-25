import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repositories/subject_repository.dart';
import '../../../app/data/repositories/topic_repository.dart';
import '../../../app/data/repositories/revision_repository.dart';
import '../../../app/data/services/image_search_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../services/gemini_live_service.dart';

// ── FIX #9: Top-level constants so regex is compiled once, not per-call ──
final _normalizeNonWord = RegExp(r'[^\w\s]');
final _normalizeWhitespace = RegExp(r'\s+');

class VoiceAssistantController extends GetxController with GetTickerProviderStateMixin {
  GeminiLiveService get _service => Get.find<GeminiLiveService>();
  SubjectRepository get _subjectRepo => Get.find<SubjectRepository>();
  TopicRepository get _topicRepo => Get.find<TopicRepository>();
  RevisionRepository get _revRepo => Get.find<RevisionRepository>();

  String? currentSubjectName;

  // ── UI controllers ──
  final textCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  final focusNode = FocusNode();
  AnimationController? _sheetAnimCtrl;
  AnimationController? _expandAnimCtrl;

  // ── Dialogue overlay state ──
  final isExpanded = false.obs;
  final dialogueOffset = Offset(12, 200).obs;
  bool dialogueOffsetInitialized = false;

  Animation<double>? get sheetFade => _sheetAnimCtrl != null
      ? CurvedAnimation(parent: _sheetAnimCtrl!, curve: Curves.easeOut)
      : null;
  Animation<Offset>? get sheetSlide => _sheetAnimCtrl != null
      ? Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
      .animate(CurvedAnimation(parent: _sheetAnimCtrl!, curve: Curves.easeOutCubic))
      : null;
  Animation<double>? get expandAnim => _expandAnimCtrl != null
      ? CurvedAnimation(parent: _expandAnimCtrl!, curve: Curves.easeInOutCubic)
      : null;

  void initSheetAnim() {
    _sheetAnimCtrl?.dispose();
    _sheetAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sheetAnimCtrl!.forward();
  }

  void initExpandAnim() {
    _expandAnimCtrl?.dispose();
    _expandAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  }

  void reverseSheetAnim() {
    _sheetAnimCtrl?.reverse().then((_) {
      stopSession();
      if (Get.context != null) Navigator.pop(Get.context!);
    });
  }

  void toggleExpanded() {
    isExpanded.value = !isExpanded.value;
    if (isExpanded.value) {
      _expandAnimCtrl?.forward();
    } else {
      _expandAnimCtrl?.reverse();
    }
  }

  void updateDialogueOffset(Offset delta, double screenW, double screenH, double dialogueW, double currentH) {
    dialogueOffset.value = Offset(
      (dialogueOffset.value.dx + delta.dx).clamp(0, screenW - dialogueW),
      (dialogueOffset.value.dy + delta.dy).clamp(0, screenH - currentH),
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendTextFromInput() {
    final text = textCtrl.text.trim();
    if (text.isEmpty) return;
    sendText(text);
    textCtrl.clear();
    focusNode.unfocus();
    scrollToBottom();
  }

  final messages = <ChatMessage>[].obs;
  final connectionState = ws.ConnectionState.disconnected.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;

  final RxBool _micMuted = false.obs;
  bool get isMuted => _micMuted.value;
  bool _mutedByFunctionCall = false;

  int _generation = 0;

  StreamSubscription? _connectionSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _functionCallSub;
  StreamSubscription? _turnCompleteSub;

  Timer? _micReconcileTimer;

  String _lastAssistantText = '';
  DateTime? _lastUnmuteAt;
  Timer? _unmuteDebounceTimer;
  static const Duration _unmuteDebounce = Duration(milliseconds: 500);
  static const Duration _echoGuardWindow = Duration(seconds: 2);

  // ── FIX #1 & #2: LinkedHashSet for O(1) contains + ordered eviction ──
  final LinkedHashSet<String> _processedCallIds = LinkedHashSet();
  // FIX #1: HashSet for O(1) dedup lookups instead of O(n) List.contains
  final LinkedHashSet<String> _recentCalls = LinkedHashSet();
  final LinkedHashSet<String> _pendingCallIds = LinkedHashSet();
  final List<Map<String, dynamic>> _pendingResponses = [];
  Timer? _pendingCallsSafetyTimer;
  Timer? _batchFlushTimer;

  static const int _maxPendingCalls = 60;

  // ── FIX #3: Per-name completers so concurrent addMultipleTopics calls
  // wait on the SAME addSubject future instead of each polling the DB ──
  final Map<String, Completer<dynamic>> _subjectCreationCompleters = {};

  // ── FIX #4: Debounced UI refresh to avoid 60 re-renders per batch ──
  Timer? _uiRefreshDebounce;

  bool _batchInProgress = false;
  bool _batchJustCompleted = false;
  // FIX #5: Atomic counter, not derived from Set size mid-flight
  int _batchTotal = 0;
  int _batchCompleted = 0;
  int _batchCompletedCount = 0;
  // FIX #10: Track whether current batch IS a retry (not incremented for first batch)
  int _batchRetryCount = 0;
  static const int _maxBatchRetries = 2;
  ChatMessage? _batchProgressMessage;

  ChatMessage? _streamingMessage;

  static const int _maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _userInitiatedStop = false;
  // FIX #8: Guard against double stopSession calls
  bool _isStopping = false;

  final List<Map<String, dynamic>> _tools = [
    {
      'name': 'getAllData',
      'description': 'Get ALL subjects and their topics with revision schedules. Use this to answer ANY question about what subjects exist, what topics are in each subject, revision dates, counts, etc. Always call this first when user asks about their data.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'addSubject',
      'description': 'Add a new study subject. Call when user says to add/create a subject.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Subject name'},
          'color': {'type': 'string', 'description': 'Hex color code like #87CEEB'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'addTopic',
      'description': 'Add a new topic to a subject. Accepts subject NAME (not ID). If user is inside a subject (contextSubject is set), subjectName is optional - omit it to add to the current subject. Revision dates are auto-set from today.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name (optional if contextSubject is provided)'},
          'name': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'addMultipleTopics',
      'description': 'Add multiple topics to a subject at once. Accepts subject NAME. Use when user lists several topics. Revision dates are auto-set.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topics': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of topic names to add',
          },
        },
        'required': ['subjectName', 'topics'],
      },
    },
    {
      'name': 'deleteAllSubjects',
      'description': 'Delete ALL subjects and their topics. Use when user says to delete everything or all subjects.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'deleteSubjectByName',
      'description': 'Delete a subject by its NAME. Use when user says to delete a specific subject by name.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Subject name to delete'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'deleteTopicByName',
      'description': 'Delete a topic by its NAME from a subject.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name to delete'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
  ];

  @override
  void onInit() {
    super.onInit();
    _setupListeners();
    _startMicReconcileTimer();
  }

  // ───────────────────────── Mic state ─────────────────────────

  void _setMicMuted(bool muted, {String reason = ''}) {
    try {
      _service.isMuted = muted;
    } catch (e) {
      print('[Gemini] ⚠️ Failed to set service mic state: $e');
    }
    if (_micMuted.value != muted) {
      _micMuted.value = muted;
      if (!muted) _lastUnmuteAt = DateTime.now();
    }
    if (reason.isNotEmpty) {
      print('[Gemini] 🎙️ Mic ${muted ? "muted" : "unmuted"} ($reason)');
    }
  }

  // FIX #9: Uses top-level compiled regex constants instead of closure-local ones
  bool _looksLikeSelfEcho(String candidate) {
    if (_lastAssistantText.isEmpty || _lastUnmuteAt == null) return false;
    if (DateTime.now().difference(_lastUnmuteAt!) > _echoGuardWindow) return false;

    String normalize(String s) => s
        .toLowerCase()
        .replaceAll(_normalizeNonWord, '')
        .replaceAll(_normalizeWhitespace, ' ')
        .trim();

    final candNorm = normalize(candidate);
    if (candNorm.isEmpty) return true;

    final lastNorm = normalize(_lastAssistantText);
    final lastWords = lastNorm.split(' ');
    final tail = lastWords.length > 12
        ? lastWords.sublist(lastWords.length - 12).join(' ')
        : lastNorm;

    if (tail.contains(candNorm)) return true;

    final candWords = candNorm.split(' ').toSet();
    final tailWords = tail.split(' ').toSet();
    final overlap = candWords.intersection(tailWords).length;
    final ratio = overlap / candWords.length;
    final threshold = candWords.length <= 3 ? 0.9 : 0.6;
    return ratio >= threshold;
  }

  void _startMicReconcileTimer() {
    _micReconcileTimer?.cancel();
    _micReconcileTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_pendingCallIds.isEmpty && !_batchInProgress) {
        final actual = _service.isMuted;
        if (_micMuted.value != actual) {
          print('[Gemini] 🔄 Mic state drift detected — reconciling ($actual)');
          _micMuted.value = actual;
        }
      }
    });
  }

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
      print('[Gemini] ⚠️ connectionStateStream error: $e');
      errorMessage.value = e.toString();
    });

    _transcriptSub = _service.transcriptStream.listen((t) {
      if (gen != _generation) return;
      if (_micMuted.value != _service.isMuted) {
        _micMuted.value = _service.isMuted;
      }

      if (t.startsWith('USER:')) {
        final text = t.substring(5);
        final trimmed = text.trim();
        if (trimmed.isEmpty) return;
        if (_looksLikeSelfEcho(trimmed)) {
          print('[Gemini] 🔇 Discarding likely self-echo: "$trimmed"');
          return;
        }
        messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
        _batchRetryCount = 0;
        _recentCalls.clear();
        print('[Gemini] 🆕 New user message — retry count reset, dedup cache cleared');
      } else {
        if (_batchJustCompleted) {
          print('[Gemini] 📦 Batch completed — processing Gemini response');
          if (_batchProgressMessage != null) {
            _batchProgressMessage!.text = '✅ All done — $_batchCompletedCount operations completed';
            _batchProgressMessage = null;
          }
          _batchJustCompleted = false;
          isProcessing.value = false;
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
      print('[Gemini] ⚠️ transcriptStream error: $e');
    });

    _audioSub = _service.responseAudioStream.listen((_) {}, onError: (e) {
      print('[Gemini] ⚠️ responseAudioStream error: $e');
    });

    _functionCallSub = _service.functionCallStream.listen((call) {
      if (gen != _generation) return;
      try {
        _handleFunctionCall(call['id'] as String, call['name'] as String, call['args'] as Map<String, dynamic>);
      } catch (e) {
        print('[Gemini] ⚠️ Malformed function call payload: $e');
      }
    }, onError: (e) {
      print('[Gemini] ⚠️ functionCallStream error: $e');
    });

    _turnCompleteSub = _service.turnCompleteStream.listen((_) {
      if (gen != _generation) return;
      if (_streamingMessage != null && _streamingMessage!.text.trim().isNotEmpty) {
        _lastAssistantText = _streamingMessage!.text;
      }
      _mutedByFunctionCall = false;
      _streamingMessage = null;
      print('[Gemini] 🔚 Turn complete');

      _unmuteDebounceTimer?.cancel();
      _unmuteDebounceTimer = Timer(_unmuteDebounce, () {
        if (gen != _generation) return;
        if (_pendingCallIds.isEmpty) {
          _setMicMuted(false, reason: 'turnComplete (debounced)');
        }
      });
    }, onError: (e) {
      print('[Gemini] ⚠️ turnCompleteStream error: $e');
    });
  }

  void _cleanupOrphanedBatchState({required String reason}) {
    if (_batchInProgress || _pendingCallIds.isNotEmpty || isProcessing.value) {
      print('[Gemini] 🔌 Cleaning up orphaned batch state ($reason)');
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
      isProcessing.value = false;
      _mutedByFunctionCall = false;
      _setMicMuted(false, reason: 'cleanup-after-$reason');
    }
  }

  void _maybeReconnect() {
    if (_userInitiatedStop) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[Gemini] ❌ Max reconnect attempts reached — giving up');
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connection lost. Tap the mic to reconnect.',
      ));
      _triggerUiUpdate();
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    print('[Gemini] 🔁 Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    final gen = _generation;
    _reconnectTimer = Timer(delay, () {
      if (gen != _generation || _userInitiatedStop) return;
      startSession(isReconnect: true);
    });
  }

  @override
  void onClose() {
    _generation++;
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    _pendingCallsSafetyTimer?.cancel();
    _batchFlushTimer?.cancel();
    _micReconcileTimer?.cancel();
    _reconnectTimer?.cancel();
    _unmuteDebounceTimer?.cancel();
    _uiRefreshDebounce?.cancel();
    _sheetAnimCtrl?.dispose();
    _expandAnimCtrl?.dispose();
    textCtrl.dispose();
    scrollCtrl.dispose();
    focusNode.dispose();
    _service.stopSession();
    super.onClose();
  }

  Future<void> startSession({bool isReconnect = false}) async {
    try {
      _userInitiatedStop = false;
      _isStopping = false; // FIX #8: reset stop guard on new session
      final gen = ++_generation;

      _setupListeners();

      if (!isReconnect) {
        messages.add(ChatMessage(role: ChatRole.system, text: 'Connecting to Gemini...'));
      } else {
        messages.add(ChatMessage(
          role: ChatRole.system,
          text: 'Reconnecting... (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
        ));
      }
      _triggerUiUpdate();

      final contextInfo = currentSubjectName != null
          ? '\n3a. The user is currently INSIDE the subject "$currentSubjectName". When they say "add topic X" WITHOUT specifying a subject, add it to "$currentSubjectName" automatically. Only ask which subject if the topic name is ambiguous.'
          : '';

      final systemPrompt = '''
You are StudyBot, a smart study revision assistant. You have FULL ACCESS to the student's data.

RULES:
1. The user may speak in English, Bengali, or a mix (Banglish). ALWAYS respond in the SAME language the user speaks.
2. When user asks "what subjects do I have" or "amar ki ki subject ase" → call getAllData first, then answer.
3. When user asks "what topics are in X" → call getAllData, find subject X, list its topics.$contextInfo
4. When user says "delete all subjects" or "shob subject muche de" → call deleteAllSubjects.
5. When user says "delete subject X" → call deleteSubjectByName with name X.
6. When user says "add topic X to subject Y" → call addTopic with subjectName Y, name X.
7. When user says "add topics A, B, C to X" → call addMultipleTopics (send ALL topics in ONE call).
8. When user says "add subject X" → call addSubject.
9. You have full knowledge of all data. NEVER say "I don't know" or ask for IDs. Use names only.
10. When a topic is added, revision dates are automatically set from today (Day 1, 2, 4, 7, 15, 30).
11. Be natural and conversational. Confirm what you did after each action.
12. If user asks about revision dates, counts, or anything → use getAllData to find the answer.
13. When adding topics, ALWAYS use the subject NAME. The system resolves names automatically.

CRITICAL BATCH RULES:
14. When user asks to add MULTIPLE subjects AND topics, send ALL function calls in ONE SINGLE message. Do NOT split across multiple turns. Example: "add 10 subjects with 10 topics each" → send 10 addSubject calls + 10 addMultipleTopics calls ALL IN ONE toolCall message.
15. Always use addMultipleTopics when adding multiple topics to a subject. Never call addTopic in a loop.
16. NEVER send partial batches. If user asks for 10 subjects, send ALL 10 in one go.

CRITICAL FEEDBACK RULES — YOU MUST ALWAYS DO THIS:
17. AFTER every batch execution, you WILL receive a BATCH_RESULT message telling you exactly how many succeeded and how many failed, plus a list of FAILED_ITEMS with their original parameters.
18. You MUST ALWAYS give feedback to the user after EVERY task execution — success, failure, or partial. NEVER stay silent. NEVER skip feedback.
19. If ALL operations succeeded → tell the user what was created and confirm. Example: "Done! I added 10 subjects with 10 topics each."
20. If SOME operations failed → tell the user EXACTLY which items failed and WHY. Then ask: "Do you want me to retry only the failed items?"
21. ONLY retry the FAILED items when the user explicitly says yes. Do NOT retry successful items.
22. TO RETRY: Look at the FAILED_ITEMS in the BATCH_RESULT. Each failed item shows the function name and its original parameters (e.g., "addMultipleTopics | params: {subjectName: Physics, topics: [Ch1, Ch2, ...]}"). Call the EXACT SAME functions with the EXACT SAME parameters. Do NOT call getAllData first — just retry the failed calls directly.
23. If RETRY_LIMIT_REACHED error appears → STOP immediately. Tell the user: "I've tried multiple times but some items still failed. Please try again manually." Then WAIT for new instructions. Do NOT retry again.
24. When the user says something NEW (not about retrying), respond to their NEW request. Do NOT go back to retrying old failed items unless they specifically ask.

GREETING RULES:
25. When user greets (hello, hi, eki, hey, etc.) → greet back warmly and ask how you can help. Do NOT call getAllData on greeting.
''';

      await _service.startSession(
        voice: 'Kore',
        systemPrompt: systemPrompt,
        tools: _tools,
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

  void toggleListening() {
    if (_pendingCallIds.isNotEmpty || _batchInProgress) {
      print('[Gemini] 🚫 Mic toggle blocked — batch in progress');
      return;
    }
    if (connectionState.value != ws.ConnectionState.connected) {
      print('[Gemini] 🚫 Mic toggle blocked — not connected');
      return;
    }
    _setMicMuted(!_service.isMuted, reason: 'user toggle');
  }

  void _respondToFunction(String callId, String name, Map<String, dynamic> result, {Map<String, dynamic>? params}) {
    _pendingResponses.add({'id': callId, 'name': name, 'result': result, 'params': params ?? {}});
  }

  void sendText(String text) {
    if (connectionState.value != ws.ConnectionState.connected) {
      print('[Gemini] 🚫 Cannot send text — not connected');
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Not connected yet — please wait a moment and try again.',
      ));
      _triggerUiUpdate();
      return;
    }
    try {
      _service.sendText(text);
    } catch (e) {
      print('[Gemini] ⚠️ sendText failed: $e');
      messages.add(ChatMessage(role: ChatRole.system, text: 'Failed to send message: $e'));
      _triggerUiUpdate();
    }
  }

  // ── FIX #3: Subject lookup with completer-based coordination ──
  // If addSubject and addMultipleTopics run concurrently (same batch),
  // addMultipleTopics waits on the SAME Completer that addSubject will complete,
  // instead of each independently polling the DB up to 10 seconds.
  Future<dynamic> _findSubjectByName(String name, {bool retry = false}) async {
    final lower = name.toLowerCase().trim();

    // Check if there's an in-flight creation for this subject name —
    // if so, await its completer instead of polling the DB.
    if (_subjectCreationCompleters.containsKey(lower)) {
      print('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      return await _subjectCreationCompleters[lower]!.future;
    }

    return _querySubjectByName(lower, retry: retry);
  }

  Future<dynamic> _querySubjectByName(String lower, {bool retry = false}) async {
    final subjects = await _subjectRepo.getAll();
    for (final s in subjects) {
      if (s.name.toLowerCase() == lower) return s;
    }
    for (final s in subjects) {
      if (s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase())) return s;
    }
    if (retry) {
      // Reduced to 3 retries at 1.5s (4.5s max) — sufficient for most DB writes
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        final retrySubjects = await _subjectRepo.getAll();
        for (final s in retrySubjects) {
          if (s.name.toLowerCase() == lower) return s;
        }
        for (final s in retrySubjects) {
          if (s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase())) return s;
        }
      }
    }
    return null;
  }

  Future<dynamic> _findTopicByName(String subjectId, String topicName) async {
    final topics = await _topicRepo.getBySubject(subjectId);
    final lower = topicName.toLowerCase().trim();
    for (final t in topics) {
      if (t.name.toLowerCase() == lower) return t;
    }
    for (final t in topics) {
      if (t.name.toLowerCase().contains(lower) || lower.contains(t.name.toLowerCase())) return t;
    }
    return null;
  }

  Future<void> _handleFunctionCall(String callId, String name, Map<String, dynamic> args) async {
    final gen = _generation;

    if (_pendingCallIds.length >= _maxPendingCalls) {
      print('[Gemini] 🚫 Batch too large (${_pendingCallIds.length} pending) — refusing call $name');
      _respondToFunction(callId, name, {
        'success': false,
        'error': 'Batch size limit reached ($_maxPendingCalls). Split this into smaller requests.',
      }, params: args);
      return;
    }

    // FIX #1 & #2: LinkedHashSet.contains is O(1); eviction removes the OLDEST entry
    if (_processedCallIds.contains(callId)) {
      print('[Gemini] ⏭️ SKIP duplicate call ID: $name id=$callId');
      return;
    }

    final sortedArgs = SplayTreeMap<String, dynamic>.from(args);
    final argsHash = '$name:${jsonEncode(sortedArgs)}';
    if (_recentCalls.contains(argsHash)) {
      print('[Gemini] ⏭️ SKIP duplicate call (same args): $name hash=$argsHash');
      return;
    }
    _processedCallIds.add(callId);

    // FIX #2: LinkedHashSet preserves insertion order — first() is oldest
    if (_processedCallIds.length > 50) {
      _processedCallIds.remove(_processedCallIds.first);
    }
    if (_recentCalls.length > 50) {
      _recentCalls.remove(_recentCalls.first);
    }

    _pendingCallIds.add(callId);

    // Register a Completer for addSubject calls BEFORE any await, so concurrent
    // addMultipleTopics calls that check _subjectCreationCompleters in
    // _findSubjectByName are guaranteed to see it regardless of call ordering.
    if (name == 'addSubject') {
      final subjectName = (args['name'] as String?)?.trim().toLowerCase() ?? '';
      if (subjectName.isNotEmpty && !_subjectCreationCompleters.containsKey(subjectName)) {
        _subjectCreationCompleters[subjectName] = Completer<dynamic>();
        // If Gemini sends two addSubject calls with the same name in one batch,
        // the second skips registration here. Both DB writes still run; any
        // waiting addMultipleTopics resolves against whichever finishes first.
        // Harmless in practice — dedup-by-args-hash prevents this at the
        // transcript level before it ever reaches this point.
      }
    }

    print('[Gemini] Handling function call: $name id=$callId (${_pendingCallIds.length} pending)');
    isProcessing.value = true;

    if (!_mutedByFunctionCall) {
      _mutedByFunctionCall = !_service.isMuted;
    }
    if (!_service.isMuted) {
      _setMicMuted(true, reason: 'function call in flight');
    }

    // ── FIX #5: Atomically increment total before any async work ──
    if (_pendingCallIds.length == 1) {
      _batchInProgress = true;
      _batchTotal = 1;
      _batchCompleted = 0;
      // FIX #10: Only increment retry count AFTER the first batch completes
      // (incremented in _flushBatch instead of here)
      final retryInfo = _batchRetryCount > 0 ? ' (retry #$_batchRetryCount)' : '';
      _batchProgressMessage = ChatMessage(
        role: ChatRole.system,
        text: '⏳ Executing batch$retryInfo... (0 done)',
      );
      messages.add(_batchProgressMessage!);
    } else {
      // Atomic increment rather than re-deriving from _pendingCallIds.length +
      // _batchCompleted. The Set is mutated async so re-deriving mid-batch
      // undercounts when calls complete faster than new ones are registered.
      // Every path that touches _pendingCallIds increments/decrements this
      // counter in lockstep, so they can't drift under the current code.
      _batchTotal++;
    }
    _updateBatchProgress();

    try {
      switch (name) {
        case 'getAllData':
          await _getAllData(callId);
        case 'addSubject':
          await _addSubject(callId, args);
        case 'addTopic':
          await _addTopic(callId, args);
        case 'addMultipleTopics':
          await _addMultipleTopics(callId, args);
        case 'deleteAllSubjects':
          await _deleteAllSubjects(callId, args);
        case 'deleteSubjectByName':
          await _deleteSubjectByName(callId, args);
        case 'deleteTopicByName':
          await _deleteTopicByName(callId, args);
        default:
          print('[Gemini] ⚠️ Unknown function: $name');
          _respondToFunction(callId, name, {'success': false, 'error': 'Unknown function "$name"'}, params: args);
      }
    } catch (e) {
      print('[Gemini] Function call error: $e');
      _respondToFunction(callId, name, {'success': false, 'error': e.toString()}, params: args);
    } finally {
      if (gen != _generation) return;

      _pendingCallIds.remove(callId);

      final respIdx = _pendingResponses.indexWhere((r) => r['id'] == callId);
      if (respIdx != -1 && _pendingResponses[respIdx]['result']['success'] == true) {
        _recentCalls.add(argsHash);
        print('[Gemini] ✅ Cached SUCCESS for dedup: $name hash=$argsHash');
      } else {
        print('[Gemini] ⚠️ NOT caching FAILED call — retry allowed: $name hash=$argsHash');
      }

      _batchCompleted++;
      _updateBatchProgress();
      print('[Gemini] Done: $name (${_pendingCallIds.length} pending, $_batchCompleted/$_batchTotal done)');

      if (_pendingCallIds.isEmpty) {
        _flushBatch(gen);
      } else {
        _pendingCallsSafetyTimer?.cancel();
        _pendingCallsSafetyTimer = Timer(const Duration(seconds: 30), () {
          if (gen != _generation) return;
          print('[Gemini] ⏰ Safety timeout: ${_pendingCallIds.length} calls stuck — forcing flush');
          _pendingCallIds.clear();
          _flushBatch(gen, forcedByTimeout: true);
        });
      }
    }
  }

  void _flushBatch(int gen, {bool forcedByTimeout = false}) {
    if (gen != _generation) return;
    _pendingCallsSafetyTimer?.cancel();
    final okCount = _pendingResponses
        .where((r) => (r['result'] as Map<String, dynamic>?)?['success'] == true)
        .length;
    final failCount = _pendingResponses.length - okCount;
    print('[Gemini] 📦 Flushing batch — ${_pendingResponses.length} responses ($okCount ok, $failCount fail)'
        '${forcedByTimeout ? " [forced by timeout]" : ""}');

    // _batchRetryCount is 0 on the first attempt, 1 on first retry, etc.
    // Capture BEFORE incrementing so the service receives the correct value.
    final retryCountForService = _batchRetryCount;
    _batchRetryCount++; // incremented after flush so next batch's label is correct

    _batchInProgress = false;
    _batchJustCompleted = true;
    _batchCompletedCount = _batchCompleted;

    // Clean up any subject-creation completers that are still pending
    // (shouldn't happen in normal flow, but guards against a stuck batch)
    _subjectCreationCompleters.clear();

    try {
      _service.sendBatchedFunctionResponses(_pendingResponses, retryCount: retryCountForService);
    } catch (e) {
      print('[Gemini] ⚠️ Failed to send batched responses: $e');
    }
    _pendingResponses.clear();

    if (forcedByTimeout) {
      _unmuteAfterFunctionCall();
      _finishBatchUi();
      return;
    }

    _batchTotal = 0;
    _batchCompleted = 0;
    _batchFlushTimer?.cancel();
    _batchFlushTimer = Timer(const Duration(seconds: 5), () {
      if (gen != _generation) return;
      if (_batchJustCompleted) {
        _finishBatchUi();
        _unmuteAfterFunctionCall();
      }
    });
  }

  void _finishBatchUi() {
    _batchJustCompleted = false;
    // FIX #7: Remove by reference (O(1)) instead of scanning the full list (O(n))
    if (_batchProgressMessage != null) {
      messages.remove(_batchProgressMessage);
      _batchProgressMessage = null;
    }
    isProcessing.value = false;
    _triggerUiUpdate();
  }

  void _updateBatchProgress() {
    if (_batchProgressMessage != null) {
      _batchProgressMessage!.text = '⏳ Executing batch... ($_batchCompleted/$_batchTotal done)';
      _triggerUiUpdate();
    }
  }

  // ── getAllData ──
  Future<void> _getAllData(String callId) async {
    try {
      final subjects = await _subjectRepo.getAll();
      final allData = <Map<String, dynamic>>[];

      for (final sub in subjects) {
        final topics = await _topicRepo.getBySubject(sub.id);
        // Fetches all schedules then filters in Dart. To push this to the DB,
        // add a subjectId param to RevisionRepository.getSchedules and pass sub.id.
        final allSchedules = await _revRepo.getSchedules(topicId: null);
        final subSchedules = allSchedules.where((s) => s.subjectId == sub.id).toList();

        final topicList = <Map<String, dynamic>>[];
        for (final t in topics) {
          final topicSchedules = subSchedules.where((s) => s.topicId == t.id).toList();
          final pending = topicSchedules.where((s) => s.status == 'pending').length;
          final completed = topicSchedules.where((s) => s.status == 'completed').length;
          final nextDate = topicSchedules
              .where((s) => s.status == 'pending')
              .map((s) => s.scheduledDate)
              .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

          topicList.add({
            'name': t.name,
            'id': t.id,
            'mastery': (t.masteryLevel * 100).round(),
            'revisions_done': t.totalRevisions,
            'pending_revisions': pending,
            'completed_revisions': completed,
            'next_revision': nextDate != null
                ? '${nextDate.day}/${nextDate.month}/${nextDate.year}'
                : 'none',
            'first_read': t.firstReadDate != null
                ? '${t.firstReadDate!.day}/${t.firstReadDate!.month}/${t.firstReadDate!.year}'
                : 'not set',
          });
        }

        allData.add({
          'subject': sub.name,
          'subject_id': sub.id,
          'total_topics': topics.length,
          'completed_topics': sub.completedTopics,
          'topics': topicList,
        });
      }

      _respondToFunction(callId, 'getAllData', {
        'success': true,
        'total_subjects': subjects.length,
        'data': allData,
      }, params: {});
    } catch (e) {
      _respondToFunction(callId, 'getAllData', {'success': false, 'error': e.toString()}, params: {});
    }
  }

  // ── FIX #3: addSubject registers a Completer so concurrent addMultipleTopics
  //    calls await it instead of polling the DB repeatedly ──
  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': 'Subject name cannot be empty'}, params: args);
      return;
    }
    final lower = name.toLowerCase();
    final color = args['color'] as String?;
    // Completer was already registered in _handleFunctionCall before any await,
    // so concurrent addMultipleTopics calls are guaranteed to see it.
    final completer = _subjectCreationCompleters[lower];

    try {
      final subject = await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      completer?.complete(subject); // unblocks any waiting addMultipleTopics

      ImageSearchService.searchSubjectImage(name).then((imageUrl) async {
        if (imageUrl != null) {
          try {
            await _subjectRepo.update(subject.id, {'image_url': imageUrl});
            _subjectRepo.refresh();
          } catch (e) {
            print('[Gemini] ⚠️ Failed to attach image for "$name": $e');
          }
        }
      }).catchError((e) {
        print('[Gemini] ⚠️ Image search failed for "$name": $e');
      });

      _respondToFunction(callId, 'addSubject', {
        'success': true,
        'message': 'Subject "$name" added successfully',
      }, params: args);
    } catch (e) {
      // complete(null) instead of completeError: callers treat null as "not found"
      // and fall through to their own error handling — no unhandled throw.
      if (completer != null && !completer.isCompleted) completer.complete(null);
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': e.toString()}, params: args);
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<void> _addTopic(String callId, Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': 'Topic name cannot be empty'}, params: args);
      return;
    }
    var subjectName = args['subjectName'] as String?;

    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
      print('[Gemini] Using context subject: $subjectName');
    }

    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addTopic', {
        'success': false,
        'error': 'No subject specified. Please tell me which subject to add the topic to.',
      }, params: args);
      return;
    }

    try {
      final subject = await _findSubjectByName(subjectName, retry: true);
      if (subject == null) {
        _respondToFunction(callId, 'addTopic', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      final t = await _topicRepo.create(subjectId: subject.id, name: name);
      await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
      _subjectRepo.refresh();
      _topicRepo.refresh();

      _respondToFunction(callId, 'addTopic', {
        'success': true,
        'message': 'Topic "$name" added to "${subject.name}" with 6 revision dates auto-set from today',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _addMultipleTopics(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    final rawTopics = args['topics'];
    if (rawTopics is! List || rawTopics.isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'At least one topic name is required'}, params: args);
      return;
    }
    final topicNames = rawTopics.map((e) => e.toString()).toList();

    try {
      // FIX #3: _findSubjectByName will await the Completer if addSubject is in-flight
      final subject = await _findSubjectByName(subjectName, retry: true);
      if (subject == null) {
        _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      int added = 0;
      final failedTopics = <String>[];
      for (final name in topicNames) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) continue;
        try {
          final t = await _topicRepo.create(subjectId: subject.id, name: trimmed);
          await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
          added++;
        } catch (e) {
          print('[Gemini] ⚠️ Failed to add topic "$trimmed": $e');
          failedTopics.add(trimmed);
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();

      if (added == 0) {
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': false,
          'error': 'Failed to add any topics to "${subject.name}"',
        }, params: args);
      } else {
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': true,
          'message': '$added topics added to "${subject.name}" with revision dates auto-set'
              '${failedTopics.isNotEmpty ? " (failed: ${failedTopics.join(", ")})" : ""}',
        }, params: args);
      }
    } catch (e) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteAllSubjects(String callId, Map<String, dynamic> args) async {
    try {
      final subjects = await _subjectRepo.getAll();
      int count = 0;
      for (final sub in subjects) {
        try {
          await _subjectRepo.delete(sub.id);
          count++;
        } catch (e) {
          print('[Gemini] ⚠️ Failed to delete subject "${sub.name}": $e');
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _respondToFunction(callId, 'deleteAllSubjects', {
        'success': true,
        'message': '$count subjects deleted',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'deleteAllSubjects', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteSubjectByName(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(name);
      if (subject == null) {
        _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': 'Subject "$name" not found'}, params: args);
        return;
      }
      await _subjectRepo.delete(subject.id);
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _respondToFunction(callId, 'deleteSubjectByName', {
        'success': true,
        'message': 'Subject "${subject.name}" deleted',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteTopicByName(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'deleteTopicByName', {
        'success': false,
        'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }

    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'deleteTopicByName', {
          'success': false,
          'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      await _topicRepo.delete(topic.id, subjectId: subject.id);
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _respondToFunction(callId, 'deleteTopicByName', {
        'success': true,
        'message': 'Topic "${topic.name}" deleted from "${subject.name}"',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  // FIX #8: Guard against double-call (e.g. two rapid taps, or onClose + user tap)
  Future<void> stopSession({bool userInitiated = true}) async {
    if (_isStopping) {
      print('[Gemini] ⚠️ stopSession called while already stopping — ignoring');
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
      print('[Gemini] ⚠️ Error stopping service session: $e');
    }
    messages.clear();
    connectionState.value = ws.ConnectionState.disconnected;
    isProcessing.value = false;
    errorMessage.value = '';
    _micMuted.value = false;
    _mutedByFunctionCall = false;
    currentSubjectName = null;
    _processedCallIds.clear();
    _recentCalls.clear();
    _pendingCallIds.clear();
    _pendingResponses.clear();
    _streamingMessage = null;
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
    isExpanded.value = false;
    dialogueOffsetInitialized = false;
    // _isStopping is reset in startSession, not here, so a redundant second
    // stopSession call during teardown doesn't slip through.
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _setMicMuted(false, reason: 'after function call');
    }
  }

  // FIX #4: Debounced refresh — collapses 60 individual refresh() calls
  // during a batch into at most one per 16ms frame (60fps budget)
  void _triggerUiUpdate() {
    _uiRefreshDebounce?.cancel();
    _uiRefreshDebounce = Timer(const Duration(milliseconds: 16), () {
      messages.refresh();
    });
  }
}