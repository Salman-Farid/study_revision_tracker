import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../app/data/repositories/subject_repository.dart';
import '../../../app/data/repositories/topic_repository.dart';
import '../../../app/data/repositories/revision_repository.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../services/gemini_live_service.dart';

class VoiceAssistantController extends GetxController {
  GeminiLiveService get _service => Get.find<GeminiLiveService>();
  SubjectRepository get _subjectRepo => Get.find<SubjectRepository>();
  TopicRepository get _topicRepo => Get.find<TopicRepository>();
  RevisionRepository get _revRepo => Get.find<RevisionRepository>();

  /// Current subject context - set when opened from subject detail screen
  String? currentSubjectName;

  final messages = <ChatMessage>[].obs;
  final connectionState = ws.ConnectionState.disconnected.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;

  /// Mic state — observable, always synced with service
  final RxBool _micMuted = false.obs;
  bool get isMuted => _micMuted.value;
  bool _mutedByFunctionCall = false;

  /// Generation counter to prevent race between stop/start
  int _generation = 0;

  StreamSubscription? _connectionSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _functionCallSub;
  StreamSubscription? _turnCompleteSub;

  /// Track processed call IDs to prevent duplicate execution
  final Set<String> _processedCallIds = {};
  /// Track recent function name+args to prevent Gemini sending same call with different IDs
  final List<String> _recentCalls = [];
  /// Track pending (in-flight) function call IDs — endTurn only when all are done
  final Set<String> _pendingCallIds = {};
  /// Buffer function responses — flushed as ONE batched message when all calls done
  final List<Map<String, dynamic>> _pendingResponses = [];
  /// Safety timer — if pending calls are stuck for too long, force endTurn + unmute
  Timer? _pendingCallsSafetyTimer;

  // ── Batch progress tracking ──
  bool _batchInProgress = false;
  bool _batchJustCompleted = false;
  int _batchTotal = 0;
  int _batchCompleted = 0;
  int _batchCompletedCount = 0;
  int _batchRetryCount = 0; // Track retries — stop after 2nd try
  static const int _maxBatchRetries = 2;
  ChatMessage? _batchProgressMessage;

  /// Streaming message accumulator — assistant text accumulates here until turnComplete
  ChatMessage? _streamingMessage;

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
  }

  void _setupListeners() {
    // Cancel existing subscriptions first (safe to call multiple times)
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();

    _connectionSub = _service.connectionStateStream.listen((s) {
      connectionState.value = s;
      if (s == ws.ConnectionState.error) {
        errorMessage.value = _service.socket?.lastError ?? 'Unknown error';
      } else if (s == ws.ConnectionState.connected) {
        errorMessage.value = '';
      }
    });

    _transcriptSub = _service.transcriptStream.listen((t) {
      // Sync observable mic state from service (service auto-mutes on Gemini speech)
      _micMuted.value = _service.isMuted;

      if (t.startsWith('USER:')) {
        final text = t.substring(5);
        if (text.trim().isEmpty) return;
        messages.add(ChatMessage(role: ChatRole.user, text: text.trim()));
        // New user instruction = reset retry count AND clear dedup cache
        // so Gemini can retry previously failed calls if needed
        _batchRetryCount = 0;
        _recentCalls.clear();
        print('[Gemini] 🆕 New user message — retry count reset, dedup cache cleared');
      } else {
        // When batch just finished, update the progress message in-place
        if (_batchJustCompleted) {
          print('[Gemini] 📦 Batch completed — processing Gemini response');
          if (_batchProgressMessage != null) {
            _batchProgressMessage!.text = '✅ All done — $_batchCompletedCount operations completed';
            _batchProgressMessage = null;
          }
          _batchJustCompleted = false;
          isProcessing.value = false;
        }
        // Accumulate assistant text into one message (streaming)
        if (_streamingMessage != null) {
          _streamingMessage!.text += t;
        } else {
          _streamingMessage = ChatMessage(role: ChatRole.assistant, text: t);
          messages.add(_streamingMessage!);
        }
        _triggerUiUpdate();
      }
    });

    _audioSub = _service.responseAudioStream.listen((_) {});

    _functionCallSub = _service.functionCallStream.listen((call) {
      _handleFunctionCall(call['id'] as String, call['name'] as String, call['args'] as Map<String, dynamic>);
    });

    _turnCompleteSub = _service.turnCompleteStream.listen((_) {
      // Sync observable mic state from service (service auto-unmutes on turnComplete)
      _micMuted.value = _service.isMuted;
      _streamingMessage = null; // Finalize current message
      print('[Gemini] 🔚 Turn complete — streaming finalized');
      // Batch state is already cleared in _handleFunctionCall's finally block
      // (before endTurn), so transcript listener can process Gemini's response.
      // turnComplete just finalizes any streaming message.
    });
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    _pendingCallsSafetyTimer?.cancel();
    _service.stopSession();
    super.onClose();
  }

  Future<void> startSession() async {
    try {
      final gen = ++_generation;

      // Re-establish stream subscriptions (they were cancelled in stopSession)
      _setupListeners();

      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connecting to Gemini...',
      ));

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

      // If stopSession was called while we were connecting, don't update UI
      if (gen != _generation) return;

      // Remove "Connecting..." message (find it by text, not index)
      final connIdx = messages.indexWhere(
          (m) => m.role == ChatRole.system && m.text == 'Connecting to Gemini...');
      if (connIdx != -1) messages.removeAt(connIdx);

      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connected! Tap mic to speak.',
      ));
    } catch (e) {
      developer.log('Failed to start session: $e');
      errorMessage.value = e.toString();
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connection failed: ${e.toString()}',
      ));
    }
  }

  void toggleListening() {
    // Don't allow mic toggle while batch function calls are in-flight
    if (_pendingCallIds.isNotEmpty) return;
    _service.isMuted = !_service.isMuted;
    _micMuted.value = _service.isMuted;
  }

  /// Buffer a function response — will be sent as ONE batched message when all calls finish
  void _respondToFunction(String callId, String name, Map<String, dynamic> result, {Map<String, dynamic>? params}) {
    _pendingResponses.add({'id': callId, 'name': name, 'result': result, 'params': params ?? {}});
  }

  void sendText(String text) {
    _service.sendText(text);
  }

  // ── Find subject by name (fuzzy match) ──
  Future<dynamic> _findSubjectByName(String name) async {
    final subjects = await _subjectRepo.getAll();
    final lower = name.toLowerCase().trim();
    // Exact match first
    for (final s in subjects) {
      if (s.name.toLowerCase() == lower) return s;
    }
    // Partial match
    for (final s in subjects) {
      if (s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase())) return s;
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
    // Deduplicate by call ID
    if (_processedCallIds.contains(callId)) {
      print('[Gemini] ⏭️ SKIP duplicate call ID: $name id=$callId');
      return;
    }

    // Deduplicate by function name + sorted args (robust against key ordering)
    // NOTE: _recentCalls is populated ONLY AFTER success (see finally block)
    // so that FAILED calls can be retried by Gemini.
    final sortedArgs = SplayTreeMap<String, dynamic>.from(args);
    final argsHash = '$name:${jsonEncode(sortedArgs)}';
    if (_recentCalls.contains(argsHash)) {
      print('[Gemini] ⏭️ SKIP duplicate call (same args): $name hash=$argsHash');
      return;
    }
    _processedCallIds.add(callId);

    // Keep only last 50 IDs and 50 recent call hashes
    if (_processedCallIds.length > 50) {
      final toRemove = _processedCallIds.take(30).toList();
      for (final id in toRemove) {
        _processedCallIds.remove(id);
      }
    }
    if (_recentCalls.length > 50) {
      _recentCalls.removeRange(0, _recentCalls.length - 30);
    }

    // Track this call as pending — endTurn will be called only when ALL pending calls finish
    _pendingCallIds.add(callId);

    print('[Gemini] Handling function call: $name id=$callId (${_pendingCallIds.length} pending)');
    isProcessing.value = true;

    // Only capture original mic state on the FIRST pending call —
    // subsequent calls must NOT overwrite it or _unmuteAfterFunctionCall() won't fire
    if (!_mutedByFunctionCall) {
      _mutedByFunctionCall = !_service.isMuted;
    }
    if (!_service.isMuted) {
      _service.isMuted = true;
      _micMuted.value = true;
      print('[Gemini] Mic muted for function call');
    }

    // ── Batch progress tracking ──
    if (_pendingCallIds.length == 1) {
      // First call of a new batch — start batch mode
      _batchInProgress = true;
      _batchTotal = 1;
      _batchCompleted = 0;
      _batchRetryCount++;
      final retryInfo = _batchRetryCount > 1 ? ' (retry #${_batchRetryCount - 1})' : '';
      _batchProgressMessage = ChatMessage(
        role: ChatRole.system,
        text: '⏳ Executing batch$retryInfo... (0 done)',
      );
      messages.add(_batchProgressMessage!);
    } else {
      // Subsequent call — update total count
      _batchTotal = _pendingCallIds.length + _batchCompleted;
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
      }
    } catch (e) {
      print('[Gemini] Function call error: $e');
      _respondToFunction(callId, name, {'success': false, 'error': e.toString()}, params: args);
    } finally {
      // Remove this call from pending; only call endTurn when ALL pending calls are done
      _pendingCallIds.remove(callId);

      // Only cache SUCCESSFUL calls for dedup — failed calls MUST be retryable
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
        _pendingCallsSafetyTimer?.cancel();
        final okCount = _pendingResponses.where((r) => (r['result'] as Map<String, dynamic>?)?['success'] == true).length;
        final failCount = _pendingResponses.length - okCount;
        print('[Gemini] 📦 All function calls done — ${_pendingResponses.length} responses (${okCount} ok, $failCount fail)');

        // CRITICAL: Clear batch state BEFORE sending so transcript listener
        // can process Gemini's response (transcript arrives BEFORE turnComplete)
        _batchInProgress = false;
        _batchJustCompleted = true;
        _batchCompletedCount = _batchCompleted;
        // Send ALL responses in ONE message + turnComplete (required by Gemini Live API)
        _service.sendBatchedFunctionResponses(_pendingResponses, retryCount: _batchRetryCount);
        _pendingResponses.clear();
        _unmuteAfterFunctionCall();
        // Safety: if Gemini doesn't respond within 5s, force-clear
        _batchTotal = 0;
        _batchCompleted = 0;
        Future.delayed(const Duration(seconds: 5), () {
          if (_batchJustCompleted) {
            _batchJustCompleted = false;
            _removeExecutingMessage();
            isProcessing.value = false;
            if (_batchProgressMessage != null) {
              _batchProgressMessage!.text = '✅ All done — $_batchCompletedCount operations completed';
              _batchProgressMessage = null;
            }
          }
        });
      } else {
        // Reset safety timer — if pending calls are stuck for 30s, force endTurn + unmute
        _pendingCallsSafetyTimer?.cancel();
        _pendingCallsSafetyTimer = Timer(const Duration(seconds: 30), () {
          print('[Gemini] ⏰ Safety timeout: ${_pendingCallIds.length} calls stuck — forcing flush');
          _pendingCallIds.clear();
          _batchInProgress = false;
          _batchJustCompleted = true;
          _batchCompletedCount = _batchCompleted;
          _batchTotal = 0;
          _batchCompleted = 0;
          _service.sendBatchedFunctionResponses(_pendingResponses, retryCount: _batchRetryCount);
          _pendingResponses.clear();
          _unmuteAfterFunctionCall();
          Future.delayed(const Duration(seconds: 5), () {
            if (_batchJustCompleted) {
              _batchJustCompleted = false;
              _removeExecutingMessage();
              isProcessing.value = false;
              if (_batchProgressMessage != null) {
                _batchProgressMessage!.text = '✅ All done — $_batchCompletedCount operations completed';
                _batchProgressMessage = null;
              }
            }
          });
        });
      }
    }
  }

  void _updateBatchProgress() {
    if (_batchProgressMessage != null) {
      _batchProgressMessage!.text = '⏳ Executing batch... ($_batchCompleted/$_batchTotal done)';
      _triggerUiUpdate();
    }
  }

  // ── GET ALL DATA ──
  Future<void> _getAllData(String callId) async {
    final subjects = await _subjectRepo.getAll();
    final allData = <Map<String, dynamic>>[];

    for (final sub in subjects) {
      final topics = await _topicRepo.getBySubject(sub.id);
      final schedules = await _revRepo.getSchedules(topicId: null);
      final subSchedules = schedules.where((s) => s.subjectId == sub.id).toList();

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
          'next_revision': nextDate != null ? '${nextDate.day}/${nextDate.month}/${nextDate.year}' : 'none',
          'first_read': t.firstReadDate != null ? '${t.firstReadDate!.day}/${t.firstReadDate!.month}/${t.firstReadDate!.year}' : 'not set',
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
  }

  // ── ADD SUBJECT ──
  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final color = args['color'] as String?;
    await _subjectRepo.create(name: name, colorHex: color ?? '#87CEEB');
    _subjectRepo.refresh();
    _respondToFunction(callId, 'addSubject', {'success': true, 'message': 'Subject "$name" added successfully'}, params: args);
  }

  // ── ADD TOPIC (by subject name, with context fallback) ──
  Future<void> _addTopic(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    var subjectName = args['subjectName'] as String?;

    // Fallback to context subject if not provided
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
      print('[Gemini] Using context subject: $subjectName');
    }

    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': 'No subject specified. Please tell me which subject to add the topic to.'}, params: args);
      return;
    }

    final subject = await _findSubjectByName(subjectName);
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
  }

  // ── ADD MULTIPLE TOPICS ──
  Future<void> _addMultipleTopics(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String;
    final topicNames = (args['topics'] as List).cast<String>();

    final subject = await _findSubjectByName(subjectName);
    if (subject == null) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
      return;
    }

    int added = 0;
    for (final name in topicNames) {
      if (name.trim().isEmpty) continue;
      final t = await _topicRepo.create(subjectId: subject.id, name: name.trim());
      await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
      added++;
    }
    _subjectRepo.refresh();
    _topicRepo.refresh();

    _respondToFunction(callId, 'addMultipleTopics', {
      'success': true,
      'message': '$added topics added to "${subject.name}" with revision dates auto-set',
    }, params: args);
  }

  // ── DELETE ALL SUBJECTS ──
  Future<void> _deleteAllSubjects(String callId, Map<String, dynamic> args) async {
    final subjects = await _subjectRepo.getAll();
    int count = 0;
    for (final sub in subjects) {
      await _subjectRepo.delete(sub.id);
      count++;
    }
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _respondToFunction(callId, 'deleteAllSubjects', {
      'success': true,
      'message': '$count subjects deleted',
    }, params: args);
  }

  // ── DELETE SUBJECT BY NAME ──
  Future<void> _deleteSubjectByName(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final subject = await _findSubjectByName(name);
    if (subject == null) {
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': 'Subject "$name" not found'}, params: args);
      return;
    }
    await _subjectRepo.delete(subject.id);
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _respondToFunction(callId, 'deleteSubjectByName', {'success': true, 'message': 'Subject "${subject.name}" deleted'}, params: args);
  }

  // ── DELETE TOPIC BY NAME ──
  Future<void> _deleteTopicByName(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String;
    final topicName = args['topicName'] as String;

    final subject = await _findSubjectByName(subjectName);
    if (subject == null) {
      _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
      return;
    }

    final topic = await _findTopicByName(subject.id, topicName);
    if (topic == null) {
      _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"'}, params: args);
      return;
    }

    await _topicRepo.delete(topic.id);
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _respondToFunction(callId, 'deleteTopicByName', {'success': true, 'message': 'Topic "${topic.name}" deleted from "${subject.name}"'}, params: args);
  }

  Future<void> stopSession() async {
    final gen = ++_generation; // Invalidate any in-flight startSession
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    _pendingCallsSafetyTimer?.cancel();
    await _service.stopSession();
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
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _service.unmute();
      _micMuted.value = false;
      print('[Gemini] Mic unmuted after function call');
    }
  }

  void _removeExecutingMessage() {
    messages.removeWhere((m) =>
        m.role == ChatRole.system &&
        (m.text == 'Executing your request...' ||
         m.text.startsWith('⏳ Executing batch') ||
         m.text.startsWith('✅ All done')));
  }

  void _triggerUiUpdate() {
    messages.refresh();
  }
}
