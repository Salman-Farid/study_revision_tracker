import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/gemini_config.dart';
import 'package:flutter/foundation.dart';
part 'socket/gemini_socket_connect.dart';
part 'socket/gemini_socket_message_parse.dart';
part 'socket/gemini_socket_send.dart';

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

  String get lastError => _pendingError ?? '';

  void dispose() {
    disconnect();
    _audioController.close();
    _transcriptController.close();
    _stateController.close();
    _functionCallController.close();
    _turnCompleteController.close();
    _audioActivityController.close();
  }
}
