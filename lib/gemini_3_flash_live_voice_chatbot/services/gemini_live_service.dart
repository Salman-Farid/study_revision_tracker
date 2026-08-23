import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../config/gemini_config.dart';
import '../core/audio/audio_player.dart';
import '../core/audio/audio_recorder.dart' as mic;
import '../core/websocket/gemini_socket.dart';

/// Central service for the Gemini Live voice session.
///
/// Responsibilities:
/// - Owns the WebSocket, mic recorder, and audio player
/// - Streams response audio, transcripts, and function calls
/// - Handles mic mute/unmute without tearing down the session
/// - Exposes [isMuted] flag — mic always streams, mute just suppresses sending
class GeminiLiveService {
  GeminiSocket? _socket;
  mic.MicRecorder? _recorder;
  PcmAudioPlayer? _player;

  StreamSubscription? _micSub;
  StreamSubscription? _responseAudioSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _functionCallSub;
  StreamSubscription? _audioActivitySub;
  StreamSubscription? _turnCompleteSub;

  final _responseAudioController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _functionCallController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();

  Stream<Uint8List> get responseAudioStream => _responseAudioController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<ConnectionState> get connectionStateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get functionCallStream => _functionCallController.stream;
  Stream<void> get turnCompleteStream => _turnCompleteController.stream;

  GeminiSocket? get socket => _socket;
  bool isMuted = false;
  bool _autoMutedByGemini = false;
  bool _sessionActive = false;

  /// Generation counter to prevent race between stopSession/startSession
  int _generation = 0;

  /// Start a live voice session.
  /// Mic opens once, streams continuously. Gemini VAD detects speech boundaries.
  Future<void> startSession({
    String voice = 'Kore',
    String? systemPrompt,
    bool streamMicrophone = true,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (_sessionActive) return;

    final gen = ++_generation;
    _sessionActive = true;

    _player = PcmAudioPlayer();

    _socket = GeminiSocket(
      apiKey: GeminiConfig.apiKey,
      systemPrompt: systemPrompt,
      voice: voice,
      tools: tools,
    );

    // Forward connection state
    _socket!.stateStream.listen((s) => _stateController.add(s));

    // Forward response audio → play immediately (streaming, not buffered)
    _responseAudioSub = _socket!.audioStream.listen((data) {
      _responseAudioController.add(data);
      _player?.addChunk(data);
    });

    // Forward transcripts
    _transcriptSub = _socket!.transcriptStream.listen((t) {
      _transcriptController.add(t);
    });

    // Forward function calls
    _functionCallSub = _socket!.functionCallStream.listen((call) {
      _functionCallController.add(call);
    });

    // Auto-mute mic when Gemini starts speaking (prevent feedback loop)
    _audioActivitySub = _socket!.audioActivityStream.listen((_) {
      if (!_autoMutedByGemini && !isMuted) {
        _autoMutedByGemini = true;
        isMuted = true;
        print('[Service] Auto-muted mic — Gemini is speaking');
      }
    });

    // Auto-unmute mic when Gemini finishes speaking
    _turnCompleteSub = _socket!.turnCompleteStream.listen((_) {
      _turnCompleteController.add(null);
      if (_autoMutedByGemini) {
        _autoMutedByGemini = false;
        isMuted = false;
        print('[Service] Auto-unmuted mic — Gemini finished speaking');
      }
    });

    await _socket!.connect();

    // Check if session was stopped while we were connecting
    if (gen != _generation) return;

    // Start mic streaming — opens once, streams forever
    if (streamMicrophone) {
      try {
        _recorder = mic.MicRecorder();
        final ok = await _recorder!.start();
        if (!ok) {
          _recorder = null;
          developer.log('Mic permission denied — voice input disabled');
          return;
        }
        _micSub = _recorder!.audioStream.listen((data) {
          if (!isMuted) {
            _socket?.sendAudio(data);
          }
        });
        developer.log('Mic streaming started');
      } catch (e) {
        developer.log('Mic start failed: $e');
        _recorder = null;
      }
    }
  }

  /// Send a text message (as if typed by user)
  void sendText(String text) {
    _socket?.sendText(text);
  }

  /// Send function call response back to Gemini
  void sendFunctionResponse(String callId, Map<String, dynamic> response) {
    _socket?.sendFunctionResponse(callId, response);
  }

  /// Manually send audio bytes
  void sendAudio(Uint8List pcm) {
    _socket?.sendAudio(pcm);
  }

  /// Signal end of current turn (Gemini will respond)
  void endTurn() {
    _socket?.endTurn();
  }

  /// Stop mic streaming but keep session alive (mute)
  void mute() {
    isMuted = true;
  }

  /// Resume mic streaming (unmute)
  void unmute() {
    isMuted = false;
  }

  /// Full teardown — stop everything, close streams, release resources
  Future<void> stopSession() async {
    final gen = ++_generation; // Invalidate any in-flight startSession
    _sessionActive = false;
    _autoMutedByGemini = false;
    isMuted = false;

    // Cancel mic subscription first, then stop recorder
    await _micSub?.cancel();
    _micSub = null;
    if (_recorder != null) {
      await _recorder!.stop();
      _recorder!.dispose();
      _recorder = null;
    }

    // Cancel all other subscriptions
    await _responseAudioSub?.cancel();
    _responseAudioSub = null;
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _functionCallSub?.cancel();
    _functionCallSub = null;
    await _audioActivitySub?.cancel();
    _audioActivitySub = null;
    await _turnCompleteSub?.cancel();
    _turnCompleteSub = null;

    // Disconnect socket
    await _socket?.disconnect();
    _socket = null;

    // Clear player
    _player?.clear();
    _player = null;
  }

  void dispose() {
    stopSession();
    _responseAudioController.close();
    _transcriptController.close();
    _stateController.close();
    _functionCallController.close();
    _recorder?.dispose();
    _player?.dispose();
    _socket?.dispose();
  }
}
