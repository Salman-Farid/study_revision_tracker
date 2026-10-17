import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../config/gemini_config.dart';
import '../core/audio/audio_player.dart';
import '../core/audio/audio_recorder.dart' as mic;
import '../core/websocket/gemini_socket.dart';
import 'package:flutter/foundation.dart';
part 'gemini_live/gemini_live_session_control.dart';

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

  StreamSubscription? _stateSub;
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

  /// Send a text message (as if typed by user)
  void sendText(String text) {
    _socket?.sendText(text);
  }

  /// Send function call response back to Gemini
  void sendFunctionResponse(String callId, Map<String, dynamic> response) {
    _socket?.sendFunctionResponse(callId, response);
  }

  /// Send ALL function responses in one message + turnComplete (batch mode)
  void sendBatchedFunctionResponses(List<Map<String, dynamic>> responses, {int retryCount = 0}) {
    _socket?.sendBatchedFunctionResponses(responses, retryCount: retryCount);
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
