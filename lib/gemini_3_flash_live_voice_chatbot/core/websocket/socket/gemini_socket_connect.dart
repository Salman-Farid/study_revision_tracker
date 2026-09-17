part of '../gemini_socket.dart';

extension GeminiSocketConnect on GeminiSocket {
  Future<void> connect({bool reconnect = true}) async {
    if (_state == ConnectionState.connected) return;
    _manualDisconnect = false;
    _setState(ConnectionState.connecting);
    _pendingError = null;

    try {
      final uri = Uri.parse(GeminiConfig.wsUrl);
      debugPrint('[Gemini] Connecting to: ${uri.toString().replaceAll(RegExp(r'key=.*'), 'key=***')}');
      debugPrint('[Gemini] Model: ${GeminiConfig.model}, Voice: $voice');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(GeminiConfig.connectTimeout);
      debugPrint('[Gemini] WebSocket connected, sending setup...');

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
          'tools': [
            if (tools != null && tools!.isNotEmpty)
              {'functionDeclarations': tools},
          ],
        },
      };
      final setupJson = jsonEncode(setupMsg);
      debugPrint('[Gemini] Sending setup JSON: ${setupJson.length} chars');
      debugPrint('[Gemini] Setup model: models/${GeminiConfig.model}');
      debugPrint('[Gemini] Setup tools count: ${(setupMsg['setup']?['tools'] as List?)?.length ?? 0}');
      _channel!.sink.add(setupJson);

      await _waitForSetup();
      debugPrint('[Gemini] Setup complete!');
      _reconnectAttempt = 0;
      _setState(ConnectionState.connected);
    } catch (e) {
      final errorMsg = _pendingError ?? e.toString();
      debugPrint('[Gemini] Connect error: $errorMsg');
      _setState(ConnectionState.error);
      _pendingError = errorMsg;
      rethrow;
    }
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

  void _setState(ConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void _onError(Object e) {
    debugPrint('[Gemini] WebSocket error: $e');
    _pendingError = 'WebSocket error: $e';
    _setState(ConnectionState.error);
  }

  void _onDone() {
    debugPrint('[Gemini] WebSocket closed. setupComplete=$_setupComplete state=$_state closeCode=${_channel?.closeCode} closeReason=${_channel?.closeReason}');
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
    debugPrint('[Gemini] Scheduling reconnect #$_reconnectAttempt in ${delayMs}ms');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_manualDisconnect || _state == ConnectionState.connected) return;
      try {
        _setupComplete = false;
        _pendingError = null;
        await connect(reconnect: false);
        debugPrint('[Gemini] Reconnect succeeded');
      } catch (e) {
        debugPrint('[Gemini] Reconnect failed: $e');
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
}
