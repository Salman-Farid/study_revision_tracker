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

// ── Top-level constants so regex is compiled once, not per-call ──
final _normalizeNonWord = RegExp(r'[^\w\s]');
final _normalizeWhitespace = RegExp(r'\s+');

final _cjkGlyphs = RegExp(r'[\u4e00-\u9fff]+');

String _sanitizeName(String s) => s.replaceAll(_cjkGlyphs, '').trim();

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

  final RxBool isLoading = false.obs;

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

  final LinkedHashSet<String> _processedCallIds = LinkedHashSet();
  final LinkedHashSet<String> _recentCalls = LinkedHashSet();
  final LinkedHashSet<String> _pendingCallIds = LinkedHashSet();
  final List<Map<String, dynamic>> _pendingResponses = [];
  Timer? _pendingCallsSafetyTimer;
  Timer? _batchFlushTimer;

  static const int _maxPendingCalls = 60;

  static const int _bulkChunkSize = 8;
  static const int _bulkConcurrency = 4;
  static const int _maxReportedFailures = 15;

  final Map<String, Completer<dynamic>> _subjectCreationCompleters = {};

  Timer? _uiRefreshDebounce;

  bool _batchInProgress = false;
  bool _batchJustCompleted = false;
  int _batchTotal = 0;
  int _batchCompleted = 0;
  int _batchCompletedCount = 0;
  int _batchRetryCount = 0;
  static const int _maxBatchRetries = 2;
  ChatMessage? _batchProgressMessage;
  ChatMessage? _thinkingMessage;

  ChatMessage? _streamingMessage;

  static const int _maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _userInitiatedStop = false;
  bool _isStopping = false;

  // ── FIX: _summaryCache is now actually read before querying the DB.
  // Previously it was written on every getAllData call but never read,
  // making it dead code. Now: cache hit → return immediately (no DB scan);
  // any write op (add/delete) sets _summaryCache = null to invalidate.
  Map<String, dynamic>? _summaryCache;

  final List<Map<String, dynamic>> _tools = [
    {
      'name': 'getAllData',
      'description': 'Get a compact SUMMARY of all subjects: name, topic count, pending revision count. Call this first for "what subjects/how many/overview" questions. For topic-level detail of ONE subject, call getSubjectDetail instead.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'getSubjectDetail',
          'description': 'Get full topic list with revision counts and next revision date for ONE subject by name. Use when the user asks about a specific subject\'s topics or revision schedule.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
        },
        'required': ['subjectName'],
      },
    },
    {
      'name': 'addSubjectsBulk',
      'description': 'Add one or more subjects, each optionally with its own topics, in ONE call. Use this for ANY request that adds subjects — a single subject or many (e.g. "add Physics with these 5 topics" -> one item in the array; "add 30 subjects with 10 topics each" -> 30 items, still ONE call). NEVER split this into multiple calls or loop it yourself, no matter how many subjects are requested. Creates each subject if it doesn\'t exist yet, or reuses it if it does. Revision dates for topics are auto-set from today.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjects': {
            'type': 'array',
            'description': 'One entry per subject to add',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string', 'description': 'Subject name'},
                'topics': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'Optional list of topic names for this subject',
                },
                'color': {'type': 'string', 'description': 'Optional hex color code like #87CEEB'},
              },
              'required': ['name'],
            },
          },
        },
        'required': ['subjects'],
      },
    },
    {
      'name': 'addSubject',
      'description': 'Add a new study subject with NO topics yet. Use only when the user wants just the subject, not topics too — for subject+topics together use addSubjectsBulk instead.',
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
      'description': 'Add a new topic to an EXISTING subject. Accepts subject NAME (not ID). If user is inside a subject (contextSubject is set), subjectName is optional - omit it to add to the current subject. If the subject doesn\'t exist yet, it will be auto-created. Revision dates are auto-set from today.',
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
      'description': 'Add multiple topics to an EXISTING subject. Accepts subject NAME. If the subject and topics are being added together for the first time, prefer addSubjectsBulk instead. If this subject doesn\'t exist yet, it will be auto-created. Revision dates are auto-set.',
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
    {
      'name': 'getTopicStatus',
      'description': 'Get detailed status of a topic: first read completion, revision progress (which revisions are completed/pending, next revision number and day). Use when the user asks about a topic\'s progress or before performing any completion action.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'markFirstReadCompleted',
      'description': 'Mark a topic\'s first read as completed. Use when user says "mark the topic as completed", "I\'ve read the topic", "first read done" or similar. The topic moves to revision tracking after this.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'markRevisionCompleted',
      'description': 'Mark the NEXT sequential revision as completed for a topic. Follows strict order: 1st(1day) → 2nd(3days) → 3rd(7days) → 4th(14days) → 5th(30days) → 6th(90days). Cannot skip incomplete previous revisions. Use when user says "mark revision as completed", "complete the revision", or similar.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'getAllTopicsRevisionDates',
      'description': 'Get revision dates for ALL topics in a subject. Use when user asks "what are all the revision dates?", "show me all revision dates", "when are all revisions due?", or similar. Returns each topic with its 6 revision dates and status.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
        },
        'required': ['subjectName'],
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
      if (isLoading.value) return;
      if (_pendingCallIds.isEmpty && !_batchInProgress) {
        final actual = _service.isMuted;
        if (_micMuted.value != actual) {
          print('[Gemini] 🔄 Mic state drift detected — reconciling ($actual)');
          _micMuted.value = actual;
        }
      }
    });
  }

  void _enterLoading(String reason) {
    if (!isLoading.value) {
      isLoading.value = true;
      print('[Gemini] ⏳ Loading started ($reason)');
    }
    if (!_service.isMuted) {
      _mutedByFunctionCall = true;
    }
    _setMicMuted(true, reason: 'loading:$reason');
  }

  void _exitLoading(String reason) {
    if (isLoading.value) {
      isLoading.value = false;
      print('[Gemini] ✅ Loading ended ($reason)');
    }
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
      if (!isLoading.value && _micMuted.value != _service.isMuted) {
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
        _showThinking();
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
      print('[Gemini] ⚠️ transcriptStream error: $e');
    });

    _audioSub = _service.responseAudioStream.listen((_) {}, onError: (e) {
      print('[Gemini] ⚠️ responseAudioStream error: $e');
    });

    _functionCallSub = _service.functionCallStream.listen((call) {
      if (gen != _generation) return;
      _showThinking();
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
      _clearThinking();
      print('[Gemini] 🔚 Turn complete');

      _unmuteDebounceTimer?.cancel();
      _unmuteDebounceTimer = Timer(_unmuteDebounce, () {
        if (gen != _generation) return;
        if (_pendingCallIds.isEmpty && !_batchInProgress) {
          _exitLoading('turnComplete');
          _setMicMuted(false, reason: 'turnComplete (debounced)');
        }
      });
    }, onError: (e) {
      print('[Gemini] ⚠️ turnCompleteStream error: $e');
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
      _clearThinking();
      isProcessing.value = false;
      _mutedByFunctionCall = false;
      _exitLoading('cleanup-after-$reason');
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
      _isStopping = false;
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
          ? ' IMPORTANT: User is currently viewing subject "$currentSubjectName". For ALL operations (add topic, mark revision, get status, get dates), ALWAYS use this subject automatically. NEVER ask the user to name the subject — it is already known. Only ask if multiple subjects match.'
          : '';

      final systemPrompt = '''
You are StudyBot, a study revision assistant with full data access via tools.
Reply in the same language the user uses (English/Bengali/Banglish).

DATA:
- "what subjects/overview/counts" → call getAllData (summary only).
- "topics in X / X's revision schedule" → call getSubjectDetail(subjectName: X).$contextInfo
- "topic status / progress of X" → call getTopicStatus(subjectName, topicName).
- Never say "I don't know" or ask for IDs — use names, tools resolve them.

FIRST READ & REVISION WORKFLOW:
- Topics have a "first read" phase and a "revision" phase (6 revisions: Day 1, 3, 7, 14, 30, 90).
- When user says "mark the topic as completed" or "I've read it" → call markFirstReadCompleted. This moves the topic from first read to revision tracking.
- When user says "mark revision as completed" or "complete the revision" → call markRevisionCompleted. This completes the NEXT sequential revision only.
- ALWAYS check getTopicStatus first if unsure about the current state before performing any action.
- Revisions MUST follow strict sequential order: 1st → 2nd → 3rd → 4th → 5th → 6th. Never skip.
- If user asks to mark a later revision but earlier ones are incomplete, explain which revisions are missing and offer to mark the correct next one.
- When user asks "when is my next revision?", "what dates are my revisions?", "when are the revision dates?" → call getTopicStatus. It returns `revision_schedule` with ACTUAL dates (YYYY-MM-DD) for all 6 revisions and `first_read_date`. Always read the dates from revision_schedule and tell the user. Never guess dates.
- When user asks "what are all the revision dates?", "show me all revision dates for all topics", "when are all revisions due?" → call getAllTopicsRevisionDates(subjectName). It returns each topic with its 6 revision dates and status. Read ALL dates and tell the user for each topic.

ACTIONS: addSubjectsBulk(subjects:[{name,topics?,color?}]) · addSubject(name,color?) · addTopic(subjectName?,name) · addMultipleTopics(subjectName,topics[]) · deleteAllSubjects() · deleteSubjectByName(name) · deleteTopicByName(subjectName,topicName) · getTopicStatus(subjectName,topicName) · getAllTopicsRevisionDates(subjectName) · markFirstReadCompleted(subjectName,topicName) · markRevisionCompleted(subjectName,topicName).
New topics get revision dates auto-set (Day 1,3,7,14,30,90) from today.

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
    if (isLoading.value || _pendingCallIds.isNotEmpty || _batchInProgress) {
      print('[Gemini] 🚫 Mic toggle blocked — loading/batch in progress');
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
      _showThinking();
      _service.sendText(text);
    } catch (e) {
      print('[Gemini] ⚠️ sendText failed: $e');
      _clearThinking();
      _exitLoading('sendText-failed');
      messages.add(ChatMessage(role: ChatRole.system, text: 'Failed to send message: $e'));
      _triggerUiUpdate();
    }
  }

  Future<dynamic> _findSubjectByName(String name, {bool retry = false}) async {
    final lower = name.toLowerCase().trim();

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

  Future<dynamic> _findOrCreateSubjectByName(String rawName, {String? color}) async {
    final name = _sanitizeName(rawName);
    final lower = name.toLowerCase();

    if (_subjectCreationCompleters.containsKey(lower)) {
      print('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing != null) return existing;
    }

    final found = await _querySubjectByName(lower);
    if (found != null) return found;

    if (_subjectCreationCompleters.containsKey(lower)) {
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing != null) return existing;
      return await _querySubjectByName(lower);
    }

    final completer = Completer<dynamic>();
    _subjectCreationCompleters[lower] = completer;
    try {
      final subject = await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      _summaryCache = null;
      completer.complete(subject);
      print('[Gemini] 🆕 Auto-created missing subject "$name" (model skipped addSubject)');

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

      return subject;
    } catch (e) {
      completer.complete(null);
      rethrow;
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<void> _handleFunctionCall(String callId, String name, Map<String, dynamic> args) async {
    final gen = _generation;

    _enterLoading('function-call:$name');

    if (_pendingCallIds.length >= _maxPendingCalls) {
      print('[Gemini] 🚫 Batch too large (${_pendingCallIds.length} pending) — refusing call $name');
      _respondToFunction(callId, name, {
        'success': false,
        'error': 'Batch size limit reached ($_maxPendingCalls). Split this into smaller requests.',
      }, params: args);
      return;
    }

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

    if (_processedCallIds.length > 50) {
      _processedCallIds.remove(_processedCallIds.first);
    }
    if (_recentCalls.length > 50) {
      _recentCalls.remove(_recentCalls.first);
    }

    _pendingCallIds.add(callId);

    if (name == 'addSubject') {
      final subjectName = (args['name'] as String?)?.trim().toLowerCase() ?? '';
      if (subjectName.isNotEmpty && !_subjectCreationCompleters.containsKey(subjectName)) {
        _subjectCreationCompleters[subjectName] = Completer<dynamic>();
      }
    }

    print('[Gemini] Handling function call: $name id=$callId (${_pendingCallIds.length} pending)');
    isProcessing.value = true;

    if (!_mutedByFunctionCall) {
      _mutedByFunctionCall = !_service.isMuted;
    }
    _setMicMuted(true, reason: 'function call in flight');

    if (_pendingCallIds.length == 1) {
      _clearThinking();
      _batchInProgress = true;
      _batchTotal = 1;
      _batchCompleted = 0;
      _batchProgressMessage = ChatMessage(role: ChatRole.system, text: _batchProgressText());
      messages.add(_batchProgressMessage!);
    } else {
      _batchTotal++;
    }
    _updateBatchProgress();

    try {
      switch (name) {
        case 'getAllData':
          await _getAllData(callId);
        case 'getSubjectDetail':
          await _getSubjectDetail(callId, args);
        case 'addSubjectsBulk':
          await _addSubjectsBulk(callId, args);
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
        case 'getTopicStatus':
          await _getTopicStatus(callId, args);
        case 'markFirstReadCompleted':
          await _markFirstReadCompleted(callId, args);
        case 'markRevisionCompleted':
          await _markRevisionCompleted(callId, args);
        case 'getAllTopicsRevisionDates':
          await _getAllTopicsRevisionDates(callId, args);
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

    final retryCountForService = _batchRetryCount;
    _batchRetryCount++;

    _batchInProgress = false;
    _batchJustCompleted = true;
    _batchCompletedCount = _batchCompleted;

    _subjectCreationCompleters.clear();

    final wireResponses = _pendingResponses
        .map((r) => {'id': r['id'], 'name': r['name'], 'result': r['result']})
        .toList();

    try {
      _service.sendBatchedFunctionResponses(wireResponses, retryCount: retryCountForService);
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
    if (_batchProgressMessage != null) {
      messages.remove(_batchProgressMessage);
      _batchProgressMessage = null;
    }
    isProcessing.value = false;
    _triggerUiUpdate();
  }

  String _batchProgressText() {
    final retryInfo = _batchRetryCount > 0 ? ' (retry #$_batchRetryCount)' : '';
    if (_batchCompleted < _batchTotal) {
      return '⚙️ Executing tasks$retryInfo... (Running task ${_batchCompleted + 1}/$_batchTotal)';
    }
    return '✅ $_batchTotal/$_batchTotal$retryInfo — finishing up...';
  }

  void _updateBatchProgress() {
    if (_batchProgressMessage != null) {
      _batchProgressMessage!.text = _batchProgressText();
      _triggerUiUpdate();
    }
  }

  // ── getAllData: returns cached result if available, otherwise queries DB.
  // Cache is invalidated (set to null) on every write (add/delete).
  Future<void> _getAllData(String callId) async {
    try {
      // ── FIX: actually use the cache on read ──
      if (_summaryCache != null) {
        print('[Gemini] ⚡ getAllData — returning cached summary');
        _respondToFunction(callId, 'getAllData', _summaryCache!, params: {});
        return;
      }

      final subjects = await _subjectRepo.getAll();
      final allSchedules = await _revRepo.getSchedules(topicId: null);

      final summary = <Map<String, dynamic>>[];
      for (final sub in subjects) {
        final topics = await _topicRepo.getBySubject(sub.id);
        final subSchedules = allSchedules.where((s) => s.subjectId == sub.id);
        final pendingCount = subSchedules.where((s) => s.status == 'pending').length;

        summary.add({
          's': sub.name,
          't': topics.length,
          'c': topics.where((t) => t.totalRevisions >= 6).length,
          'p': pendingCount,
          'fr': topics.where((t) => t.firstReadCompleted).length,
        });
      }

      final result = {
        'success': true,
        'total_subjects': subjects.length,
        'subjects': summary,
        'note': 'Compact summary (s=name,t=topics,c=completed,p=pending_revisions,fr=first_read_done). Call getSubjectDetail for full topic list of one subject.',
      };
      _summaryCache = result;
      _respondToFunction(callId, 'getAllData', result, params: {});
    } catch (e) {
      _respondToFunction(callId, 'getAllData', {'success': false, 'error': e.toString()}, params: {});
    }
  }

  Future<void> _getSubjectDetail(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      final topics = await _topicRepo.getBySubject(subject.id);
      final schedules = await _revRepo.getSchedules(topicId: null);
      final subSchedules = schedules.where((s) => s.subjectId == subject.id).toList();

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
          'first_read_done': t.firstReadCompleted,
          'pending': pending,
          'completed': completed,
          'next': nextDate != null ? '${nextDate.day}/${nextDate.month}/${nextDate.year}' : 'none',
        });
      }

      _respondToFunction(callId, 'getSubjectDetail', {
        'success': true,
        'subject': subject.name,
        'topics': topicList,
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _addSubjectsBulk(String callId, Map<String, dynamic> args) async {
    final rawList = args['subjects'];
    final items = (rawList is List ? rawList : const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    if (items.isEmpty) {
      _respondToFunction(callId, 'addSubjectsBulk', {
        'success': false,
        'error': 'subjects array is required and cannot be empty',
      }, params: args);
      return;
    }

    _batchTotal = items.length;
    _batchCompleted = 0;
    _updateBatchProgress();

    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i += _bulkChunkSize) {
      final chunk = items.skip(i).take(_bulkChunkSize).toList();

      for (var j = 0; j < chunk.length; j += _bulkConcurrency) {
        final slice = chunk.skip(j).take(_bulkConcurrency);
        final sliceResults = await Future.wait(slice.map(_processOneBulkSubject));
        results.addAll(sliceResults);
        _batchCompleted = results.length;
        _updateBatchProgress();
      }
    }

    _subjectCreationCompleters.clear();

    final succeeded = results.where((r) => r['success'] == true).toList();
    final failed = results.where((r) => r['success'] != true).toList();

    final reportedFailures = failed.length > _maxReportedFailures
        ? [
      ...failed.take(_maxReportedFailures),
      {
        'note': '+${failed.length - _maxReportedFailures} more failures — ask the user if they want full details',
      },
    ]
        : failed;

    print('[Gemini] 📦 addSubjectsBulk done — ${succeeded.length}/${items.length} succeeded');

    _respondToFunction(callId, 'addSubjectsBulk', {
      'success': failed.isEmpty,
      'total': items.length,
      'succeeded': succeeded.length,
      'failed_items': reportedFailures,
    }, params: args);
  }

  Future<Map<String, dynamic>> _processOneBulkSubject(Map<String, dynamic> item) async {
    final name = _sanitizeName((item['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      return {'name': '(unnamed)', 'success': false, 'error': 'Subject name cannot be empty'};
    }
    final rawTopics = item['topics'];
    final topicNames = (rawTopics is List ? rawTopics : const [])
        .map((e) => _sanitizeName(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final color = item['color'] as String?;
    final lower = name.toLowerCase();

    if (_subjectCreationCompleters.containsKey(lower)) {
      print('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing == null) {
        return {'name': name, 'success': false, 'error': 'Concurrent creation of this subject failed'};
      }
      return _addTopicsToSubject(existing, name, topicNames);
    }

    final completer = Completer<dynamic>();
    _subjectCreationCompleters[lower] = completer;
    try {
      var subject = await _querySubjectByName(lower);
      final createdNew = subject == null;
      subject ??= await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      _summaryCache = null;
      completer.complete(subject);

      if (createdNew) {
        ImageSearchService.searchSubjectImage(name).then((imageUrl) async {
          if (imageUrl != null) {
            try {
              await _subjectRepo.update(subject!.id, {'image_url': imageUrl});
              _subjectRepo.refresh();
            } catch (e) {
              print('[Gemini] ⚠️ Failed to attach image for "$name": $e');
            }
          }
        }).catchError((e) {
          print('[Gemini] ⚠️ Image search failed for "$name": $e');
        });
      }

      return await _addTopicsToSubject(subject, name, topicNames);
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      return {'name': name, 'success': false, 'error': e.toString()};
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<Map<String, dynamic>> _addTopicsToSubject(
      dynamic subject, String name, List<String> topicNames) async {
    if (topicNames.isEmpty) {
      return {'name': name, 'success': true, 'topics_added': 0};
    }
    try {
      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics.map((t) => t.name.toLowerCase()).toSet();

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      for (final trimmed in topicNames) {
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          continue;
        }
        try {
          final t = await _topicRepo.create(subjectId: subject.id, name: trimmed);
          await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
          existingLower.add(trimmed.toLowerCase());
          added++;
        } catch (e) {
          print('[Gemini] ⚠️ Failed to add topic "$trimmed" under "$name": $e');
          failedTopics.add(trimmed);
        }
      }
      _topicRepo.refresh();
      _summaryCache = null;

      return {
        'name': name,
        'success': true,
        'topics_added': added,
        if (skippedDuplicates > 0) 'topics_skipped_existing': skippedDuplicates,
        if (failedTopics.isNotEmpty) 'topics_failed': failedTopics,
      };
    } catch (e) {
      return {'name': name, 'success': false, 'error': 'Subject ok but topics failed: $e'};
    }
  }

  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = _sanitizeName((args['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': 'Subject name cannot be empty'}, params: args);
      return;
    }
    final lower = name.toLowerCase();
    final color = args['color'] as String?;
    final completer = _subjectCreationCompleters[lower];

    try {
      final subject = await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      _summaryCache = null;
      completer?.complete(subject);

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
      if (completer != null && !completer.isCompleted) completer.complete(null);
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': e.toString()}, params: args);
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<void> _addTopic(String callId, Map<String, dynamic> args) async {
    final name = _sanitizeName((args['name'] as String?)?.trim() ?? '');
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
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      final t = await _topicRepo.create(subjectId: subject.id, name: name);
      await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

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
    final topicNames = rawTopics
        .map((e) => _sanitizeName(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics.map((t) => t.name.toLowerCase()).toSet();

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      for (final trimmed in topicNames) {
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          continue;
        }
        try {
          final t = await _topicRepo.create(subjectId: subject.id, name: trimmed);
          await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
          existingLower.add(trimmed.toLowerCase());
          added++;
        } catch (e) {
          print('[Gemini] ⚠️ Failed to add topic "$trimmed": $e');
          failedTopics.add(trimmed);
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

      if (added == 0 && skippedDuplicates == 0) {
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': false,
          'error': 'Failed to add any topics to "${subject.name}"',
        }, params: args);
      } else {
        final dupNote = skippedDuplicates > 0 ? ' ($skippedDuplicates already existed, skipped)' : '';
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': true,
          'message': '$added topics added to "${subject.name}" with revision dates auto-set$dupNote'
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
      _summaryCache = null;
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
      _summaryCache = null;
      _respondToFunction(callId, 'deleteSubjectByName', {
        'success': true,
        'message': 'Subject "${subject.name}" deleted',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteTopicByName(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
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
      _summaryCache = null;
      _respondToFunction(callId, 'deleteTopicByName', {
        'success': true,
        'message': 'Topic "${topic.name}" deleted from "${subject.name}"',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _getTopicStatus(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'getTopicStatus', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getTopicStatus', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'getTopicStatus', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      final status = await _topicRepo.getTopicFullStatus(topic.id);
      final nextIdx = status['nextPendingRevisionIndex'] as int;
      final completedCount = status['completedRevisionCount'] as int;
      final totalCount = status['totalRevisions'] as int;
      final pendingBeforeNext = status['pendingBeforeNext'] as List<int>;
      final completedDays = status['completedDays'] as List<int>;
      final schedules = status['schedules'] as List<dynamic>;

      // Build revision schedule with actual dates
      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final revisionSchedule = <String>[];
      for (int i = 0; i < schedules.length; i++) {
        final s = schedules[i];
        final date = (s['scheduled_date'] as String).substring(0, 10); // YYYY-MM-DD
        final statusStr = s['status'] == 'completed' ? '✅ Done' : '⏳ Pending';
        revisionSchedule.add('${revisionLabels[i]}: $date ($statusStr)');
      }

      String nextRevisionInfo;
      if (nextIdx < 0) {
        nextRevisionInfo = 'All $totalCount revisions completed';
      } else {
        final nextDate = (schedules[nextIdx]['scheduled_date'] as String).substring(0, 10);
        nextRevisionInfo = 'Next: ${revisionLabels[nextIdx]} on $nextDate';
      }

      _respondToFunction(callId, 'getTopicStatus', {
        'success': true,
        'subject': subject.name,
        'topic': topic.name,
        'first_read_completed': topic.firstReadCompleted,
        'first_read_date': topic.firstReadDate?.toString().substring(0, 10),
        'completed_revisions': completedCount,
        'total_revisions': totalCount,
        'completed_revision_days': completedDays,
        'revision_schedule': revisionSchedule,
        'next_revision': nextRevisionInfo,
        'pending_before_next': pendingBeforeNext,
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'getTopicStatus', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _getAllTopicsRevisionDates(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'getAllTopicsRevisionDates', {
        'success': false, 'error': 'Subject name is required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getAllTopicsRevisionDates', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }

      final topics = await _topicRepo.getBySubject(subject.id);
      if (topics.isEmpty) {
        _respondToFunction(callId, 'getAllTopicsRevisionDates', {
          'success': true,
          'subject': subject.name,
          'topics': [],
          'message': 'No topics found in "${subject.name}".',
        }, params: args);
        return;
      }

      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final topicsData = <Map<String, dynamic>>[];

      for (final topic in topics) {
        final status = await _topicRepo.getTopicFullStatus(topic.id);
        final schedules = status['schedules'] as List<dynamic>;
        final completedCount = status['completedRevisionCount'] as int;

        final scheduleList = <String>[];
        for (int i = 0; i < schedules.length; i++) {
          final s = schedules[i];
          final date = (s['scheduled_date'] as String).substring(0, 10);
          final st = s['status'] == 'completed' ? 'Done' : 'Pending';
          scheduleList.add('${revisionLabels[i]}: $date ($st)');
        }

        topicsData.add({
          'topic': topic.name,
          'first_read_completed': topic.firstReadCompleted,
          'first_read_date': topic.firstReadDate?.toString().substring(0, 10),
          'completed_revisions': completedCount,
          'schedule': scheduleList,
        });
      }

      _respondToFunction(callId, 'getAllTopicsRevisionDates', {
        'success': true,
        'subject': subject.name,
        'topics': topicsData,
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'getAllTopicsRevisionDates', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _markFirstReadCompleted(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'markFirstReadCompleted', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      if (topic.firstReadCompleted) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': true,
          'already_completed': true,
          'message': 'First read for "${topic.name}" is already completed. You can now work on revisions.',
        }, params: args);
        return;
      }

      await _topicRepo.markFirstReadCompleted(topic.id);
      _topicRepo.refresh();
      _summaryCache = null;

      _respondToFunction(callId, 'markFirstReadCompleted', {
        'success': true,
        'already_completed': false,
        'message': 'First read for "${topic.name}" marked as completed. The topic is now in the revision phase with 6 scheduled revisions.',
      }, params: args);
    } catch (e, st) {
      print('[Gemini] markFirstReadCompleted FAILED: $e');
      print('[Gemini] Stacktrace: $st');
      _respondToFunction(callId, 'markFirstReadCompleted', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _markRevisionCompleted(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'markRevisionCompleted', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      final status = await _topicRepo.getTopicFullStatus(topic.id);
      final nextIdx = status['nextPendingRevisionIndex'] as int;
      final completedCount = status['completedRevisionCount'] as int;
      final totalCount = status['totalRevisions'] as int;
      final pendingBeforeNext = status['pendingBeforeNext'] as List<int>;

      if (nextIdx < 0) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false,
          'all_completed': true,
          'message': 'All $totalCount revisions for "${topic.name}" are already completed. Great job!',
        }, params: args);
        return;
      }

      if (pendingBeforeNext.isNotEmpty) {
        final dayLabels = {1: '1st', 3: '2nd', 7: '3rd', 14: '4th', 30: '5th', 90: '6th'};
        final pendingLabels = pendingBeforeNext.map((d) => '${dayLabels[d] ?? "Day $d"} revision').join(', ');
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false,
          'pending_before': pendingBeforeNext,
          'message': 'Cannot mark revision yet. You need to complete the $pendingLabels first. Revisions must follow the order: 1st → 2nd → 3rd → 4th → 5th → 6th.',
        }, params: args);
        return;
      }

      await _topicRepo.markNextRevisionCompleted(topic.id);
      _topicRepo.refresh();
      _summaryCache = null;

      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final justCompleted = revisionLabels[nextIdx];
      final newCompletedCount = completedCount + 1;

      String nextInfo;
      if (newCompletedCount >= totalCount) {
        nextInfo = 'All revisions completed!';
      } else {
        nextInfo = 'Next revision: ${revisionLabels[nextIdx + 1]}';
      }

      _respondToFunction(callId, 'markRevisionCompleted', {
        'success': true,
        'completed_revision': justCompleted,
        'completed_count': newCompletedCount,
        'total_revisions': totalCount,
        'next_revision': nextInfo,
        'message': '$justCompleted revision for "${topic.name}" completed ($newCompletedCount/$totalCount). $nextInfo',
      }, params: args);
    } catch (e) {
      _respondToFunction(callId, 'markRevisionCompleted', {'success': false, 'error': e.toString()}, params: args);
    }
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
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _exitLoading('after function call');
      _setMicMuted(false, reason: 'after function call');
    }
  }

  void _triggerUiUpdate() {
    _uiRefreshDebounce?.cancel();
    _uiRefreshDebounce = Timer(const Duration(milliseconds: 16), () {
      messages.refresh();
    });
  }
}