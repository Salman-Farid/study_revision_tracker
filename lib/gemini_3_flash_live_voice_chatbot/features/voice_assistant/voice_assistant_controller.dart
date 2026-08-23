import 'dart:async';
import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../app/data/repositories/subject_repository.dart';
import '../../../app/data/repositories/topic_repository.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../services/gemini_live_service.dart';

class VoiceAssistantController extends GetxController {
  GeminiLiveService get _service => Get.find<GeminiLiveService>();
  SubjectRepository get _subjectRepo => Get.find<SubjectRepository>();
  TopicRepository get _topicRepo => Get.find<TopicRepository>();

  final messages = <ChatMessage>[].obs;
  final connectionState = ws.ConnectionState.disconnected.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  bool _mutedByFunctionCall = false;

  StreamSubscription? _connectionSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _functionCallSub;
  StreamSubscription? _turnCompleteSub;

  final List<Map<String, dynamic>> _tools = [
    {
      'name': 'addSubject',
      'description': 'Add a new study subject. Call this when user wants to add a subject.',
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
      'name': 'deleteSubject',
      'description': 'Delete a subject by ID.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectId': {'type': 'string', 'description': 'Subject UUID'},
        },
        'required': ['subjectId'],
      },
    },
    {
      'name': 'listSubjects',
      'description': 'List all study subjects.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'addTopic',
      'description': 'Add a new topic to a subject. Use this when user wants to add a topic.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectId': {'type': 'string', 'description': 'Subject UUID'},
          'name': {'type': 'string', 'description': 'Topic name'},
          'difficulty': {
            'type': 'string',
            'enum': ['easy', 'medium', 'hard'],
            'description': 'Difficulty level',
          },
        },
        'required': ['subjectId', 'name'],
      },
    },
    {
      'name': 'deleteTopic',
      'description': 'Delete a topic by ID.',
      'parameters': {
        'type': 'object',
        'properties': {
          'topicId': {'type': 'string', 'description': 'Topic UUID'},
        },
        'required': ['topicId'],
      },
    },
    {
      'name': 'listTopics',
      'description': 'List all topics for a subject.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectId': {'type': 'string', 'description': 'Subject UUID'},
        },
        'required': ['subjectId'],
      },
    },
  ];

  @override
  void onInit() {
    super.onInit();
    _setupListeners();
  }

  void _setupListeners() {
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
        isProcessing.value = false;
        messages.add(ChatMessage(role: ChatRole.assistant, text: t));
      }
    });

    _audioSub = _service.responseAudioStream.listen((_) {});

    _functionCallSub = _service.functionCallStream.listen((call) {
      _handleFunctionCall(call['id'] as String, call['name'] as String, call['args'] as Map<String, dynamic>);
    });

    // Unmute after Gemini finishes speaking (turnComplete from Gemini)
    _turnCompleteSub = _service.turnCompleteStream.listen((_) {
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

  /// Start the live session with system prompt and tools
  Future<void> startSession() async {
    try {
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Connecting to Gemini...',
      ));

      const systemPrompt = '''
You are StudyBot, a friendly study revision assistant. You help students manage subjects, topics, and schedules.

The user may speak in English, Bengali, or a mix (Banglish). ALWAYS respond in the SAME language the user speaks. If they speak Bengali, respond in Bengali. If they mix, you mix. If they speak English, respond in English.

When the user asks to add a subject or topic, use the provided tools.

Be concise and natural in your responses. Speak as if having a casual conversation.
''';

      await _service.startSession(
        voice: 'Kore',
        systemPrompt: systemPrompt,
        tools: _tools,
      );

      messages.removeAt(0);
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

  /// Toggle mic mute/unmute (mic always streams, mute suppresses sending)
  void toggleListening() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _service.mute();
    } else {
      _service.unmute();
    }
  }

  /// Send a text message to Gemini
  void sendText(String text) {
    _service.sendText(text);
  }

  Future<void> _handleFunctionCall(String callId, String name, Map<String, dynamic> args) async {
    print('[Gemini] Handling function call: $name id=$callId');
    isProcessing.value = true;

    // Mute mic so Gemini doesn't interrupt itself with new audio
    _mutedByFunctionCall = !_isMuted;
    if (!_isMuted) {
      _isMuted = true;
      _service.mute();
      print('[Gemini] Mic muted for function call');
    }

    // Show processing message to user
    messages.add(ChatMessage(
      role: ChatRole.system,
      text: 'Executing your request...',
    ));

    try {
      switch (name) {
        case 'addSubject':
          await _addSubject(callId, args);
        case 'deleteSubject':
          await _deleteSubject(callId, args);
        case 'listSubjects':
          await _listSubjects(callId);
        case 'addTopic':
          await _addTopic(callId, args);
        case 'deleteTopic':
          await _deleteTopic(callId, args);
        case 'listTopics':
          await _listTopics(callId, args);
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

  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final color = args['color'] as String?;
    await _subjectRepo.create(
      name: name,
      colorHex: color ?? '#87CEEB',
    );
    _service.sendFunctionResponse(callId, {
      'name': 'addSubject',
      'result': {'success': true, 'message': 'Subject $name added'},
    });
    _service.endTurn();
  }

  Future<void> _deleteSubject(String callId, Map<String, dynamic> args) async {
    final subjectId = args['subjectId'] as String;
    await _subjectRepo.delete(subjectId);
    _service.sendFunctionResponse(callId, {
      'name': 'deleteSubject',
      'result': {'success': true, 'message': 'Subject deleted'},
    });
    _service.endTurn();
  }

  Future<void> _listSubjects(String callId) async {
    final subjects = await _subjectRepo.getAll();
    final names = subjects.map((s) => '${s.name} (${s.id})').join(', ');
    _service.sendFunctionResponse(callId, {
      'name': 'listSubjects',
      'result': {
        'success': true,
        'count': subjects.length,
        'subjects': names.isEmpty ? 'No subjects found' : names,
      },
    });
    _service.endTurn();
  }

  Future<void> _addTopic(String callId, Map<String, dynamic> args) async {
    final subjectId = args['subjectId'] as String;
    final name = args['name'] as String;
    await _topicRepo.create(
      subjectId: subjectId,
      name: name,
    );
    _service.sendFunctionResponse(callId, {
      'name': 'addTopic',
      'result': {'success': true, 'message': 'Topic $name added'},
    });
    _service.endTurn();
  }

  Future<void> _deleteTopic(String callId, Map<String, dynamic> args) async {
    final topicId = args['topicId'] as String;
    await _topicRepo.delete(topicId);
    _service.sendFunctionResponse(callId, {
      'name': 'deleteTopic',
      'result': {'success': true, 'message': 'Topic deleted'},
    });
    _service.endTurn();
  }

  Future<void> _listTopics(String callId, Map<String, dynamic> args) async {
    final subjectId = args['subjectId'] as String;
    final topics = await _topicRepo.getBySubject(subjectId);
    final names = topics.map((t) => '${t.name} (${t.id})').join(', ');
    _service.sendFunctionResponse(callId, {
      'name': 'listTopics',
      'result': {
        'success': true,
        'count': topics.length,
        'topics': names.isEmpty ? 'No topics found' : names,
      },
    });
    _service.endTurn();
  }

  Future<void> stopSession() async {
    await _service.stopSession();
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _isMuted = false;
      _service.unmute();
      print('[Gemini] Mic unmuted after function call');
    }
  }
}
