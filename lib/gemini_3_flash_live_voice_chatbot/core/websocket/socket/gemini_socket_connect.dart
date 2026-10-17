part of '../gemini_socket.dart';

extension GeminiSocketConnect on GeminiSocket {
  Future<void> connect() async {
    if (_state == ConnectionState.connected) return;
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
          // Requested because we parse outputTranscription from serverContent.
          // Previously omitted (server sent it anyway); explicit per contract.
          'outputAudioTranscription': {},
          // Enable server-side session resumption. New sessions send {};
          // reconnects send the last handle so the server restores context
          // instead of starting cold.
          'sessionResumption': resumptionHandle != null && resumptionHandle!.isNotEmpty
              ? {'handle': resumptionHandle}
              : <String, dynamic>{},
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
      debugPrint('[Gemini] Setup resuming: ${resumptionHandle != null && resumptionHandle!.isNotEmpty}');
      _channel!.sink.add(setupJson);

      await _waitForSetup();
      debugPrint('[Gemini] Setup complete!');
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
    // Socket-level auto-reconnect removed: the controller owns reconnection
    // (session_lifecycle.dart). A second reconnect loop here created parallel
    // sockets that fought the controller's and caused constant flapping.
    _setState(ConnectionState.disconnected);
  }

  Future<void> disconnect() async {
    // Cancel any pending goAway close — the session is being torn down
    // deliberately; a stale timer must not close a replacement socket.
    _goAwayTimer?.cancel();
    _goAwayTimer = null;
    await _channel?.sink.close();
    _setupComplete = false;
    _setState(ConnectionState.disconnected);
  }
}
