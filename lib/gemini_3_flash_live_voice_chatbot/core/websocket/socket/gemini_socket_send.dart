part of '../gemini_socket.dart';

extension GeminiSocketSend on GeminiSocket {
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

  /// Send a single function response WITHOUT turnComplete.
  /// The controller batches all responses and calls [endTurn] once at the end.
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
      },
    }));
  }

  void endTurn() {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode({
      'clientContent': {'turnComplete': true},
    }));
  }

  /// Send ALL function responses in a SINGLE message with turnComplete.
  /// This is critical for batch operations — sending individual responses
  /// confuses the Gemini protocol.
  /// [retryCount] — how many times this batch has been retried (0 = first try)
  void sendBatchedFunctionResponses(List<Map<String, dynamic>> responses, {int retryCount = 0}) {
    if (_state != ConnectionState.connected) return;
    if (responses.isEmpty) return;

    final functionParts = responses.map((r) => {
      'functionResponse': {
        'id': r['id'] as String,
        'name': r['name'] as String,
        'response': r['result'] as Map<String, dynamic>? ?? {},
      },
    }).toList();

    // Build a human-readable pass/fail summary so Gemini knows exactly what happened
    final succeeded = responses.where((r) {
      final result = r['result'] as Map<String, dynamic>? ?? {};
      return result['success'] == true;
    }).toList();
    final failed = responses.where((r) {
      final result = r['result'] as Map<String, dynamic>? ?? {};
      return result['success'] != true;
    }).toList();

    // Send ONLY functionResponse parts. The Live API treats any text part in a
    // tool-response turn as a barge-in (new user message), which makes the
    // server cancel the tool call (toolCallCancellation + interrupted) and can
    // corrupt turn state leading to 1011 closes. The result maps already carry
    // success/error info for the model to read.
    final allParts = <Map<String, dynamic>>[
      ...functionParts,
    ];

    _channel!.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': allParts,
          },
        ],
        'turnComplete': true,
      },
    }));
    debugPrint('[Gemini] Sent ${responses.length} batched function responses + turnComplete (${succeeded.length} ok, ${failed.length} fail)');
  }
}
