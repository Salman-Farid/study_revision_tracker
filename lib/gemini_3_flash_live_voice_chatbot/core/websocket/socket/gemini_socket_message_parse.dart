part of '../gemini_socket.dart';

extension GeminiSocketMessageParse on GeminiSocket {
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
      debugPrint('[Gemini] Received message (${text.length} chars): ${text.length > 500 ? text.substring(0, 500) + '...' : text}');
      final msg = jsonDecode(text) as Map<String, dynamic>;
      if (GeminiConfig.debugWire) {
        final type = msg.keys.isNotEmpty ? msg.keys.first : 'empty';
        final extras = msg.keys.length > 1 ? '+${msg.keys.skip(1).join(",")}' : '';
        debugPrint('[Gemini][wire] recv type=$type$extras keys=${msg.keys.toList()}');
        // Audio payloads are huge and unhelpful — dump everything else in full.
        if (type != 'serverContent' || text.length < 4000) {
          debugPrint('[Gemini][wire] recv >>> $text');
        }
      }

      if (msg.containsKey('setupComplete')) {
        _setupComplete = true;
        debugPrint('[Gemini] Received setupComplete');
        return;
      }

      if (msg.containsKey('sessionResumptionUpdate')) {
        final update = msg['sessionResumptionUpdate'] as Map<String, dynamic>?;
        final handle = update?['newHandle'] as String?;
        if (handle != null && handle.isNotEmpty) {
          resumptionHandle = handle;
          debugPrint('[Gemini] Session resumption handle updated');
        }
        return;
      }

      if (msg.containsKey('error')) {
        final error = msg['error'] as Map<String, dynamic>?;
        final code = error?['code'] ?? 'unknown';
        final message = error?['message'] ?? 'No message';
        final status = error?['status'] ?? 'unknown';
        debugPrint('[Gemini] Server error: code=$code status=$status message=$message');
        _pendingError = 'Gemini error ($code): $message';
        _setState(ConnectionState.error);
        return;
      }

      if (msg.containsKey('toolCall')) {
        final toolCall = msg['toolCall'] as Map<String, dynamic>?;
        final functionCalls = toolCall?['functionCalls'] as List<dynamic>? ?? [];
        for (final fc in functionCalls) {
          final fcMap = fc as Map<String, dynamic>;
          final callId = fcMap['id'] as String? ?? '';
          final name = fcMap['name'] as String? ?? '';
          final args = fcMap['args'] as Map<String, dynamic>? ?? {};
          debugPrint('[Gemini] toolCall: $name id=$callId args=$args');
          _functionCallController.add({
            'id': callId,
            'name': name,
            'args': args,
          });
        }
        return;
      }

      if (msg.containsKey('toolCallCancellation')) {
        final cancel = msg['toolCallCancellation'] as Map<String, dynamic>?;
        final ids = cancel?['ids'] as List<dynamic>? ?? [];
        debugPrint('[Gemini] toolCallCancellation: ids=$ids');
        return;
      }

      if (msg.containsKey('goAway')) {
        final goAway = msg['goAway'] as Map<String, dynamic>?;
        final timeLeft = goAway?['timeLeft'] ?? 'unknown';
        debugPrint('[Gemini] ⚠️ goAway received — timeLeft=$timeLeft. Server wants session to end.');
        // Gracefully close — send endTurn so Gemini can wrap up, then close sink
        try {
          endTurn();
        } catch (_) {}
        // Close after a short delay to let endTurn go through. Stored so
        // disconnect() can cancel it (a stale timer must never close a
        // replacement socket).
        _goAwayTimer?.cancel();
        _goAwayTimer = Timer(const Duration(seconds: 2), () {
          _goAwayTimer = null;
          if (_state == ConnectionState.connected) {
            debugPrint('[Gemini] Closing connection after goAway');
            _channel?.sink.close(1000, 'Session ended after goAway');
          }
        });
        return;
      }

      if (msg.containsKey('serverContent')) {
        final sc = msg['serverContent'] as Map<String, dynamic>?;
        if (sc == null) return;

        if (sc['modelTurn'] != null) {
          final modelTurn = sc['modelTurn'] as Map<String, dynamic>;
          for (final part in modelTurn['parts'] ?? []) {
            if (part is Map<String, dynamic>) {
              if (part['inlineData'] != null) {
                final inlineData = part['inlineData'] as Map<String, dynamic>?;
                final dataStr = inlineData?['data'] as String?;
                if (dataStr != null && dataStr.isNotEmpty) {
                  final audioBytes = base64Decode(dataStr);
                  _audioController.add(audioBytes);
                  _audioActivityController.add(null);
                }
              }
              if (part['functionCall'] != null) {
                final functionCall = part['functionCall'] as Map<String, dynamic>;
                final callId = functionCall['id'] as String? ?? '';
                debugPrint('[Gemini] Function call: ${functionCall['name']} id=$callId');
                _functionCallController.add({
                  'id': callId,
                  'name': functionCall['name'] as String? ?? '',
                  'args': functionCall['args'] as Map<String, dynamic>? ?? {},
                });
              }
            }
          }
        }

        if (sc['outputTranscription'] != null) {
          final ot = sc['outputTranscription'] as Map<String, dynamic>?;
          final text = ot?['text'] as String? ?? '';
          if (text.isNotEmpty) _transcriptController.add(text);
        }

        if (sc['inputTranscription'] != null) {
          final it = sc['inputTranscription'] as Map<String, dynamic>?;
          final text = it?['text'] as String? ?? '';
          if (text.isNotEmpty) _transcriptController.add('USER:$text');
        }

        if (sc['generationComplete'] == true) {
          _drainTrailing();
        }

        if (sc['interrupted'] == true) {
          // Server aborted the current turn. Treat like a turn end so the
          // controller doesn't wait forever for a reply that will never come.
          // (The turnComplete handler is idempotent — a following real
          // turnComplete just re-runs the same checks.)
          debugPrint('[Gemini] Interrupted — treating as turn end');
          _turnCompleteController.add(null);
        }

        if (sc['turnComplete'] == true) {
          debugPrint('[Gemini] turnComplete received');
          _turnCompleteController.add(null);
        }
      }
    } catch (e) {
      debugPrint('[Gemini] _onMessage error: $e');
    }
  }

  Future<void> _drainTrailing() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
