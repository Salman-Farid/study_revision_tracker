part of '../gemini_socket.dart';

extension GeminiSocketSend on GeminiSocket {
  /// Serialize every socket write through this guard: never throw on a
  /// closed/closing socket, never force-unwrap the channel. A send racing a
  /// disconnect must be a silent drop, not a StateError crashing the caller.
  void _safeSend(Map<String, dynamic> message) {
    if (_state != ConnectionState.connected) return;
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[Gemini] ⚠️ send failed (socket closing?): $e');
    }
  }

  void sendAudio(Uint8List pcmData) {
    _safeSend({
      'realtimeInput': {
        'audio': {
          'data': base64Encode(pcmData),
          'mimeType': 'audio/pcm;rate=${GeminiConfig.sampleRate}',
        },
      },
    });
  }

  void sendText(String text) {
    if (GeminiConfig.debugWire) {
      debugPrint('[Gemini][wire] clientContent >>> $text');
    }
    _safeSend({
      'clientContent': {
        'turns': [
          {'role': 'user', 'parts': [{'text': text}]},
        ],
        'turnComplete': true,
      },
    });
  }

  /// Send a single function response via the dedicated `toolResponse` message.
  /// Per the Live API contract, bidi function calling uses the dedicated
  /// `toolResponse` message — NOT `clientContent` parts. `toolResponse`
  /// carries no turnComplete; the model resumes automatically.
  void sendFunctionResponse(String callId, Map<String, dynamic> response) {
    _safeSend({
      'toolResponse': {
        'functionResponses': [
          {
            'id': callId,
            'name': response['name'] as String? ?? '',
            'response': response['result'] as Map<String, dynamic>? ?? <String, dynamic>{},
          },
        ],
      },
    });
  }

  void endTurn() {
    _safeSend({
      'clientContent': {'turnComplete': true},
    });
  }

  /// Send ALL function responses in a SINGLE `toolResponse` message.
  /// This is critical for batch operations — and per the API contract the
  /// message must be `toolResponse`, not `clientContent`. Wrapping function
  /// responses in `clientContent` makes the server treat them as a new user
  /// turn (barge-in), which triggers toolCallCancellation + interrupted and
  /// corrupts turn state, eventually causing 1011 closes.
  /// [retryCount] — how many times this batch has been retried (0 = first try)
  void sendBatchedFunctionResponses(List<Map<String, dynamic>> responses, {int retryCount = 0}) {
    if (responses.isEmpty) return;

    final functionResponses = responses.map((r) => {
      'id': r['id'] as String? ?? '',
      'name': r['name'] as String? ?? '',
      'response': r['result'] as Map<String, dynamic>? ?? <String, dynamic>{},
    }).toList();

    _safeSend({
      'toolResponse': {
        'functionResponses': functionResponses,
      },
    });
    if (GeminiConfig.debugWire) {
      debugPrint('[Gemini][wire] toolResponse >>> ${jsonEncode(functionResponses)}');
    }
    debugPrint('[Gemini] Sent ${responses.length} batched tool responses (toolResponse)');
  }
}
