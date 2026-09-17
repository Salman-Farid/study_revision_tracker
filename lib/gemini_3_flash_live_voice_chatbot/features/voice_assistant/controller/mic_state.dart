part of '../voice_assistant_controller.dart';

/// Mic mute/unmute, echo-guard, and drift reconcile timer.
extension VoiceAssistantMicState on VoiceAssistantController {
  void _setMicMuted(bool muted, {String reason = ''}) {
    try {
      _service.isMuted = muted;
    } catch (e) {
      debugPrint('[Gemini] ⚠️ Failed to set service mic state: $e');
    }
    if (_micMuted.value != muted) {
      _micMuted.value = muted;
      if (!muted) _lastUnmuteAt = DateTime.now();
    }
    if (reason.isNotEmpty) {
      debugPrint('[Gemini] 🎙️ Mic ${muted ? "muted" : "unmuted"} ($reason)');
    }
  }

  bool _looksLikeSelfEcho(String candidate) {
    if (_lastAssistantText.isEmpty || _lastUnmuteAt == null) return false;
    if (DateTime.now().difference(_lastUnmuteAt!) > VoiceAssistantController._echoGuardWindow) return false;

    String normalize(String s) => s
        .toLowerCase()
        .replaceAll(_normalizeNonWord, '')
        .replaceAll(_normalizeWhitespace, ' ')
        .trim();

    final candNorm = normalize(candidate);
    if (candNorm.isEmpty) return true;

    final lastNorm = normalize(_lastAssistantText);
    final lastWords = lastNorm.split(' ');
    final tail = lastWords.length > 12
        ? lastWords.sublist(lastWords.length - 12).join(' ')
        : lastNorm;

    if (tail.contains(candNorm)) return true;

    final candWords = candNorm.split(' ').toSet();
    final tailWords = tail.split(' ').toSet();
    final overlap = candWords.intersection(tailWords).length;
    final ratio = overlap / candWords.length;
    final threshold = candWords.length <= 3 ? 0.9 : 0.6;
    return ratio >= threshold;
  }

  void _startMicReconcileTimer() {
    _micReconcileTimer?.cancel();
    _micReconcileTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isLoading.value) return;
      if (_pendingCallIds.isEmpty && !_batchInProgress) {
        final actual = _service.isMuted;
        if (_micMuted.value != actual) {
          debugPrint('[Gemini] 🔄 Mic state drift detected — reconciling ($actual)');
          _micMuted.value = actual;
        }
      }
    });
  }

  void _enterLoading(String reason) {
    if (!isLoading.value) {
      isLoading.value = true;
      debugPrint('[Gemini] ⏳ Loading started ($reason)');
    }
    if (!_service.isMuted) {
      _mutedByFunctionCall = true;
    }
    _setMicMuted(true, reason: 'loading:$reason');
  }

  void _exitLoading(String reason) {
    if (isLoading.value) {
      isLoading.value = false;
      debugPrint('[Gemini] ✅ Loading ended ($reason)');
    }
  }

  void toggleListening() {
    if (isLoading.value || _pendingCallIds.isNotEmpty || _batchInProgress) {
      debugPrint('[Gemini] 🚫 Mic toggle blocked — loading/batch in progress');
      return;
    }
    if (connectionState.value != ws.ConnectionState.connected) {
      debugPrint('[Gemini] 🚫 Mic toggle blocked — not connected');
      return;
    }
    _setMicMuted(!_service.isMuted, reason: 'user toggle');
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _exitLoading('after function call');
      _setMicMuted(false, reason: 'after function call');
    }
  }
}
