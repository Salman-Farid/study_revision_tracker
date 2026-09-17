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

    final summaryParts = <String>[
      'BATCH_RESULT: ${succeeded.length} succeeded, ${failed.length} failed out of ${responses.length} total.',
    ];
    if (failed.isNotEmpty) {
      summaryParts.add('FAILED_ITEMS:');
      for (final f in failed) {
        final result = f['result'] as Map<String, dynamic>? ?? {};
        final name = f['name'] as String;
        final params = f['params'] as Map<String, dynamic>? ?? {};
        final error = result['error'] ?? 'unknown error';
        // Include original parameters so Gemini can retry with exact same data
        summaryParts.add('  - $name | params: $params | error: $error');
      }
      if (retryCount >= 3) {
        summaryParts.add('RETRY_LIMIT_REACHED: This batch has already been retried ${retryCount - 1} time(s) and still has failures. STOP. Do NOT retry again. Tell the user which items failed and ask them to try again manually later.');
      } else {
        summaryParts.add('To retry: call the SAME functions above with the SAME parameters. Do NOT call getAllData first — just retry the failed calls directly. Inform the user you are retrying ONLY the failed items.');
      }
    } else {
      summaryParts.add('ALL operations completed successfully. Confirm to the user what was created.');
    }
    final summaryText = summaryParts.join(' ');

    // Prepend summary as a text part, followed by all function response parts
    final allParts = <Map<String, dynamic>>[
      {'text': summaryText},
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
