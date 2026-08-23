import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/gemini_config.dart';

enum ConnectionState { disconnected, connecting, connected, error }

class GeminiSocket {
  GeminiSocket({
    required this.apiKey,
    this.systemPrompt,
    this.voice = 'Kore',
    this.tools,
  });

  final String apiKey;
  final String? systemPrompt;
  final String voice;
  final List<Map<String, dynamic>>? tools;

  WebSocketChannel? _channel;
  bool _setupComplete = false;
  ConnectionState _state = ConnectionState.disconnected;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _functionCallController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();
  final _audioActivityController = StreamController<void>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get functionCallStream => _functionCallController.stream;
  Stream<void> get turnCompleteStream => _turnCompleteController.stream;
  Stream<void> get audioActivityStream => _audioActivityController.stream;
  ConnectionState get state => _state;

  String? _pendingError;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  String get lastError => _pendingError ?? '';

  Future<void> connect({bool reconnect = true}) async {
    if (_state == ConnectionState.connected) return;
    _manualDisconnect = false;
    _setState(ConnectionState.connecting);
    _pendingError = null;

    try {
      final uri = Uri.parse(GeminiConfig.wsUrl);
      print('[Gemini] Connecting to: ${uri.toString().replaceAll(RegExp(r'key=.*'), 'key=***')}');
      print('[Gemini] Model: ${GeminiConfig.model}, Voice: $voice');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(GeminiConfig.connectTimeout);
      print('[Gemini] WebSocket connected, sending setup...');

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      final setupMsg = {
        'setup': {
          'model': 'models/${GeminiConfig.model}',
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': voice},
              },
            },
          },
          'inputAudioTranscription': {},
          if (systemPrompt != null)
            'systemInstruction': {
              'parts': [{'text': systemPrompt}],
            },
          if (tools != null && tools!.isNotEmpty)
            'tools': [{'functionDeclarations': tools}],
        },
      };
      final setupJson = jsonEncode(setupMsg);
      print('[Gemini] Sending setup JSON: ${setupJson.length} chars');
      print('[Gemini] Setup model: models/${GeminiConfig.model}');
      print('[Gemini] Setup tools count: ${(setupMsg['setup']?['tools'] as List?)?.length ?? 0}');
      _channel!.sink.add(setupJson);

      await _waitForSetup();
      print('[Gemini] Setup complete!');
      _reconnectAttempt = 0;
      _setState(ConnectionState.connected);
    } catch (e) {
      final errorMsg = _pendingError ?? e.toString();
      print('[Gemini] Connect error: $errorMsg');
      _setState(ConnectionState.error);
      _pendingError = errorMsg;
      rethrow;
    }
  }

  void _onMessage(dynamic data) {
    try {
      final String text;
      if (data is String) {
        text = data;
      } else if (data is List<int>) {
        text = utf8.decode(data, allowMalformed: true);
      } else {
        text = data.toString();
      }
      print('[Gemini] Received message (${text.length} chars): ${text.length > 500 ? text.substring(0, 500) + '...' : text}');
      final msg = jsonDecode(text) as Map<String, dynamic>;

      if (msg.containsKey('setupComplete')) {
        _setupComplete = true;
        print('[Gemini] Received setupComplete');
        return;
      }

      if (msg.containsKey('error')) {
        final error = msg['error'] as Map<String, dynamic>;
        final code = error['code'] ?? 'unknown';
        final message = error['message'] ?? 'No message';
        final status = error['status'] ?? 'unknown';
        print('[Gemini] Server error: code=$code status=$status message=$message');
        _pendingError = 'Gemini error ($code): $message';
        _setState(ConnectionState.error);
        return;
      }

      if (msg.containsKey('toolCall')) {
        final toolCall = msg['toolCall'] as Map<String, dynamic>;
        final functionCalls = toolCall['functionCalls'] as List<dynamic>? ?? [];
        for (final fc in functionCalls) {
          final fcMap = fc as Map<String, dynamic>;
          final callId = fcMap['id'] as String? ?? '';
          final name = fcMap['name'] as String? ?? '';
          final args = fcMap['args'] as Map<String, dynamic>? ?? {};
          print('[Gemini] toolCall: $name id=$callId args=$args');
          _functionCallController.add({
            'id': callId,
            'name': name,
            'args': args,
          });
        }
        return;
      }

      if (msg.containsKey('toolCallCancellation')) {
        final cancel = msg['toolCallCancellation'] as Map<String, dynamic>;
        final ids = cancel['ids'] as List<dynamic>? ?? [];
        print('[Gemini] toolCallCancellation: ids=$ids');
        return;
      }

      if (msg.containsKey('serverContent')) {
        final sc = msg['serverContent'] as Map<String, dynamic>;

        if (sc['modelTurn'] != null) {
          final modelTurn = sc['modelTurn'] as Map<String, dynamic>;
          for (final part in modelTurn['parts'] ?? []) {
            if (part is Map<String, dynamic>) {
              if (part['inlineData'] != null) {
                final audioBytes = base64Decode(part['inlineData']['data'] as String);
                _audioController.add(audioBytes);
                _audioActivityController.add(null);
              }
              if (part['functionCall'] != null) {
                final functionCall = part['functionCall'] as Map<String, dynamic>;
                final callId = functionCall['id'] as String? ?? '';
                print('[Gemini] Function call: ${functionCall['name']} id=$callId');
                _functionCallController.add({
                  'id': callId,
                  'name': functionCall['name'] as String,
                  'args': functionCall['args'] as Map<String, dynamic>? ?? {},
                });
              }
            }
          }
        }

        if (sc['outputTranscription'] != null) {
          final text = sc['outputTranscription']['text'] as String? ?? '';
          if (text.isNotEmpty) _transcriptController.add(text);
        }

        if (sc['inputTranscription'] != null) {
          final text = sc['inputTranscription']['text'] as String? ?? '';
          if (text.isNotEmpty) _transcriptController.add('USER:$text');
        }

        if (sc['generationComplete'] == true) {
          _drainTrailing();
        }

        if (sc['turnComplete'] == true) {
          print('[Gemini] turnComplete received');
          _turnCompleteController.add(null);
        }
      }
    } catch (e) {
      print('[Gemini] _onMessage error: $e');
    }
  }

  Future<void> _drainTrailing() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _waitForSetup() async {
    int attempts = 0;
    while (!_setupComplete && attempts < GeminiConfig.setupMaxAttempts) {
      if (_pendingError != null) {
        throw Exception(_pendingError);
      }
      await Future.delayed(GeminiConfig.setupPollInterval);
      attempts++;
    }
    if (!_setupComplete) {
      throw TimeoutException('Gemini Live setup timed out. ${_pendingError ?? "No setupComplete received — check API key and model name."}');
    }
  }

  void sendAudio(Uint8List pcmData) {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode({
      'realtimeInput': {
        'audio': {
          'data': base64Encode(pcmData),
          'mimeType': 'audio/pcm;rate=${GeminiConfig.sampleRate}',
        },
      },
    }));
  }

  void sendText(String text) {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {'role': 'user', 'parts': [{'text': text}]},
        ],
        'turnComplete': true,
      },
    }));
  }

  void sendFunctionResponse(String callId, Map<String, dynamic> response) {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'id': callId,
                  'name': response['name'] as String? ?? '',
                  'response': response['result'] as Map<String, dynamic>? ?? {},
                },
              },
            ],
          },
        ],
        'turnComplete': true,
      },
    }));
  }

  void endTurn() {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode({
      'clientContent': {'turnComplete': true},
    }));
  }

  void _setState(ConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void _onError(Object e) {
    print('[Gemini] WebSocket error: $e');
    _pendingError = 'WebSocket error: $e';
    _setState(ConnectionState.error);
  }

  void _onDone() {
    print('[Gemini] WebSocket closed. setupComplete=$_setupComplete state=$_state closeCode=${_channel?.closeCode} closeReason=${_channel?.closeReason}');
    if (!_setupComplete) {
      _pendingError ??= 'Connection closed before setup completed (code=${_channel?.closeCode}, reason=${_channel?.closeReason})';
    }
    _setState(ConnectionState.disconnected);

    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempt++;
    final delayMs = (1000 * (1 << (_reconnectAttempt - 1))).clamp(1000, 30000);
    print('[Gemini] Scheduling reconnect #$_reconnectAttempt in ${delayMs}ms');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_manualDisconnect || _state == ConnectionState.connected) return;
      try {
        _setupComplete = false;
        _pendingError = null;
        await connect(reconnect: false);
        print('[Gemini] Reconnect succeeded');
      } catch (e) {
        print('[Gemini] Reconnect failed: $e');
        if (_reconnectAttempt < 5 && !_manualDisconnect) {
          _scheduleReconnect();
        }
      }
    });
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _setupComplete = false;
    _setState(ConnectionState.disconnected);
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    disconnect();
    _audioController.close();
    _transcriptController.close();
    _stateController.close();
    _functionCallController.close();
    _turnCompleteController.close();
    _audioActivityController.close();
  }
}
