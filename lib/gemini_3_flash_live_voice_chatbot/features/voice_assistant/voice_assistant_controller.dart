import 'dart:async';
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

  bool _isMuted = false;
  bool get isMuted => _isMuted;
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
      if (t.startsWith('USER:')) {
        final text = t.substring(5);
        if (text.trim().isEmpty) return;
        messages.add(ChatMessage(role: ChatRole.user, text: text.trim()));
      } else {
        _removeExecutingMessage();
        isProcessing.value = false;
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
      _streamingMessage = null; // Finalize current message
      _removeExecutingMessage();
      isProcessing.value = false; // Always clear processing on turn complete
      _unmuteAfterFunctionCall();
    });
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
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
7. When user says "add topics A, B, C to X" → call addMultipleTopics.
8. When user says "add subject X" → call addSubject.
9. You have full knowledge of all data. NEVER say "I don't know" or ask for IDs. Use names only.
10. When a topic is added, revision dates are automatically set from today (Day 1, 2, 4, 7, 15, 30).
11. Be natural and conversational. Confirm what you did after each action.
12. If user asks about revision dates, counts, or anything → use getAllData to find the answer.
13. When adding topics, ALWAYS use the subject NAME. The system resolves names automatically.
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
    _isMuted = !_isMuted;
    if (_isMuted) {
      _service.mute();
    } else {
      _service.unmute();
    }
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
      print('[Gemini] Skipping duplicate call ID: $name id=$callId');
      return;
    }

    // Deduplicate by function name + args (Gemini may retry with different IDs)
    final argsHash = '$name:${args.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (_recentCalls.contains(argsHash)) {
      print('[Gemini] Skipping duplicate call (same args): $name');
      return;
    }
    _processedCallIds.add(callId);
    _recentCalls.add(argsHash);

    // Keep only last 50 IDs and 20 recent call hashes
    if (_processedCallIds.length > 50) {
      final toRemove = _processedCallIds.take(30).toList();
      for (final id in toRemove) {
        _processedCallIds.remove(id);
      }
    }
    if (_recentCalls.length > 20) {
      _recentCalls.removeRange(0, _recentCalls.length - 20);
    }

    print('[Gemini] Handling function call: $name id=$callId');
    isProcessing.value = true;

    _mutedByFunctionCall = !_isMuted;
    if (!_isMuted) {
      _isMuted = true;
      _service.mute();
      print('[Gemini] Mic muted for function call');
    }

    messages.add(ChatMessage(
      role: ChatRole.system,
      text: 'Executing your request...',
    ));

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
          await _deleteAllSubjects(callId);
        case 'deleteSubjectByName':
          await _deleteSubjectByName(callId, args);
        case 'deleteTopicByName':
          await _deleteTopicByName(callId, args);
      }
    } catch (e) {
      print('[Gemini] Function call error: $e');
      _service.sendFunctionResponse(callId, {
        'name': name,
        'result': {'success': false, 'error': e.toString()},
      });
      _service.endTurn();
      _unmuteAfterFunctionCall();
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

    _service.sendFunctionResponse(callId, {
      'name': 'getAllData',
      'result': {
        'success': true,
        'total_subjects': subjects.length,
        'data': allData,
      },
    });
    _service.endTurn();
  }

  // ── ADD SUBJECT ──
  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final color = args['color'] as String?;
    await _subjectRepo.create(name: name, colorHex: color ?? '#87CEEB');
    _subjectRepo.refresh();
    _service.sendFunctionResponse(callId, {
      'name': 'addSubject',
      'result': {'success': true, 'message': 'Subject "$name" added successfully'},
    });
    _service.endTurn();
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
      _service.sendFunctionResponse(callId, {
        'name': 'addTopic',
        'result': {'success': false, 'error': 'No subject specified. Please tell me which subject to add the topic to.'},
      });
      _service.endTurn();
      return;
    }

    final subject = await _findSubjectByName(subjectName);
    if (subject == null) {
      _service.sendFunctionResponse(callId, {
        'name': 'addTopic',
        'result': {'success': false, 'error': 'Subject "$subjectName" not found'},
      });
      _service.endTurn();
      return;
    }

    final t = await _topicRepo.create(subjectId: subject.id, name: name);
    await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: DateTime.now());
    _subjectRepo.refresh();
    _topicRepo.refresh();

    _service.sendFunctionResponse(callId, {
      'name': 'addTopic',
      'result': {
        'success': true,
        'message': 'Topic "$name" added to "${subject.name}" with 6 revision dates auto-set from today',
      },
    });
    _service.endTurn();
  }

  // ── ADD MULTIPLE TOPICS ──
  Future<void> _addMultipleTopics(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String;
    final topicNames = (args['topics'] as List).cast<String>();

    final subject = await _findSubjectByName(subjectName);
    if (subject == null) {
      _service.sendFunctionResponse(callId, {
        'name': 'addMultipleTopics',
        'result': {'success': false, 'error': 'Subject "$subjectName" not found'},
      });
      _service.endTurn();
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

    _service.sendFunctionResponse(callId, {
      'name': 'addMultipleTopics',
      'result': {
        'success': true,
        'message': '$added topics added to "${subject.name}" with revision dates auto-set',
      },
    });
    _service.endTurn();
  }

  // ── DELETE ALL SUBJECTS ──
  Future<void> _deleteAllSubjects(String callId) async {
    final subjects = await _subjectRepo.getAll();
    int count = 0;
    for (final sub in subjects) {
      await _subjectRepo.delete(sub.id);
      count++;
    }
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _service.sendFunctionResponse(callId, {
      'name': 'deleteAllSubjects',
      'result': {
        'success': true,
        'message': '$count subjects deleted',
      },
    });
    _service.endTurn();
  }

  // ── DELETE SUBJECT BY NAME ──
  Future<void> _deleteSubjectByName(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final subject = await _findSubjectByName(name);
    if (subject == null) {
      _service.sendFunctionResponse(callId, {
        'name': 'deleteSubjectByName',
        'result': {'success': false, 'error': 'Subject "$name" not found'},
      });
      _service.endTurn();
      return;
    }
    await _subjectRepo.delete(subject.id);
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _service.sendFunctionResponse(callId, {
      'name': 'deleteSubjectByName',
      'result': {'success': true, 'message': 'Subject "${subject.name}" deleted'},
    });
    _service.endTurn();
  }

  // ── DELETE TOPIC BY NAME ──
  Future<void> _deleteTopicByName(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String;
    final topicName = args['topicName'] as String;

    final subject = await _findSubjectByName(subjectName);
    if (subject == null) {
      _service.sendFunctionResponse(callId, {
        'name': 'deleteTopicByName',
        'result': {'success': false, 'error': 'Subject "$subjectName" not found'},
      });
      _service.endTurn();
      return;
    }

    final topic = await _findTopicByName(subject.id, topicName);
    if (topic == null) {
      _service.sendFunctionResponse(callId, {
        'name': 'deleteTopicByName',
        'result': {'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"'},
      });
      _service.endTurn();
      return;
    }

    await _topicRepo.delete(topic.id);
    _subjectRepo.refresh();
    _topicRepo.refresh();
    _service.sendFunctionResponse(callId, {
      'name': 'deleteTopicByName',
      'result': {'success': true, 'message': 'Topic "${topic.name}" deleted from "${subject.name}"'},
    });
    _service.endTurn();
  }

  Future<void> stopSession() async {
    final gen = ++_generation; // Invalidate any in-flight startSession
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    await _service.stopSession();
    messages.clear();
    connectionState.value = ws.ConnectionState.disconnected;
    isProcessing.value = false;
    errorMessage.value = '';
    _isMuted = false;
    _mutedByFunctionCall = false;
    currentSubjectName = null;
    _processedCallIds.clear();
    _recentCalls.clear();
    _streamingMessage = null;
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _isMuted = false;
      _service.unmute();
      print('[Gemini] Mic unmuted after function call');
    }
  }

  void _removeExecutingMessage() {
    messages.removeWhere(
        (m) => m.role == ChatRole.system && m.text == 'Executing your request...');
  }

  void _triggerUiUpdate() {
    messages.refresh();
  }
}
