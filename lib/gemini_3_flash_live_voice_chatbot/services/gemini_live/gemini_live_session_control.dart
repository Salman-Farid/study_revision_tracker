part of '../gemini_live_service.dart';

extension GeminiLiveSessionControl on GeminiLiveService {
  /// Start a live voice session.
  /// Mic opens once, streams continuously. Gemini VAD detects speech boundaries.
  Future<void> startSession({
    String voice = 'Kore',
    String? systemPrompt,
    bool streamMicrophone = true,
    List<Map<String, dynamic>>? tools,
  }) async {
    // Never silently no-op: if a session is still marked active (e.g. a
    // previous start raced a stop, or the socket died without a stop),
    // tear it down first so the new socket actually comes up.
    if (_sessionActive) {
      await stopSession();
    }

    final gen = ++_generation;
    _sessionActive = true;

    _player = PcmAudioPlayer();

    _socket = GeminiSocket(
      apiKey: GeminiConfig.apiKey,
      systemPrompt: systemPrompt,
      voice: voice,
      tools: tools,
    );

    // Forward connection state — keep the handle so stopSession can cancel
    // it (a leaked subscription let dead sockets keep flapping the UI), and
    // drop events from stale generations.
    _stateSub?.cancel();
    _stateSub = _socket!.stateStream.listen((s) {
      if (gen != _generation) return;
      _stateController.add(s);
    });

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
        debugPrint('[Service] Auto-muted mic — Gemini is speaking');
      }
    });

    // Auto-unmute mic when Gemini finishes speaking
    _turnCompleteSub = _socket!.turnCompleteStream.listen((_) {
      _turnCompleteController.add(null);
      if (_autoMutedByGemini) {
        _autoMutedByGemini = false;
        isMuted = false;
        debugPrint('[Service] Auto-unmuted mic — Gemini finished speaking');
      }
    });

    try {
      await _socket!.connect();
    } catch (_) {
      // Don't leave the session marked active after a failed connect —
      // that used to make the next startSession a silent no-op.
      if (gen == _generation) {
        _sessionActive = false;
      }
      rethrow;
    }

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

  /// Full teardown — stop everything, close streams, release resources
  Future<void> stopSession() async {
    _generation++; // Invalidate any in-flight startSession
    _sessionActive = false;
    _autoMutedByGemini = false;
    isMuted = false;

    // Cancel state forwarding FIRST — the disconnect below emits events, and
    // a leaked subscription kept pushing them into the UI after stop.
    await _stateSub?.cancel();
    _stateSub = null;

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
}
