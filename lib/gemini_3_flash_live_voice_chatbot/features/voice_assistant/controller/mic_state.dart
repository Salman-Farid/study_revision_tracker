part of '../voice_assistant_controller.dart';

/// Mic mute/unmute, echo-guard, drift reconcile, and unmute timing.
///
/// MIC TIMING KNOBS — change these constants only:
const Duration _kUnmuteDebounce = Duration(milliseconds: 500);
const Duration _kEchoGuardWindow = Duration(seconds: 2);
const Duration _kMicReconcilePeriod = Duration(seconds: 2);

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
    if (DateTime.now().difference(_lastUnmuteAt!) > _kEchoGuardWindow) return false;

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
    _micReconcileTimer = Timer.periodic(_kMicReconcilePeriod, (_) {
      // While assistant owns the floor, FORCE mic closed — never drift open.
      if (assistantOwnsFloor) {
        if (!_service.isMuted || !_micMuted.value) {
          _setMicMuted(true, reason: 'assistant owns floor — force mute');
        }
        return;
      }
      if (_pendingCallIds.isEmpty && !_batchInProgress && !isLoading.value && !isProcessing.value) {
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
    _updateFloorStatus();
  }

  void _exitLoading(String reason) {
    if (isLoading.value) {
      isLoading.value = false;
      debugPrint('[Gemini] ✅ Loading ended ($reason)');
    }
    _updateFloorStatus();
  }

  void toggleListening() {
    // Never open the mic while thinking / searching / working / speaking.
    if (assistantOwnsFloor || isLoading.value || _pendingCallIds.isNotEmpty || _batchInProgress) {
      debugPrint('[Gemini] 🚫 Mic toggle blocked — assistant owns the floor');
      return;
    }
    if (connectionState.value != ws.ConnectionState.connected) {
      debugPrint('[Gemini] 🚫 Mic toggle blocked — not connected');
      return;
    }
    _setMicMuted(!_service.isMuted, reason: 'user toggle');
    _updateFloorStatus();
    _triggerUiUpdate();
  }

  void _unmuteAfterFunctionCall() {
    if (_mutedByFunctionCall) {
      _mutedByFunctionCall = false;
      _exitLoading('after function call');
    }
    // Only open mic if the user floor is free.
    if (!assistantOwnsFloor) {
      _setMicMuted(false, reason: 'after function call — user floor');
    }
    _updateFloorStatus();
  }

  /// Open the mic shortly after Gemini finishes — ONLY if nothing is pending.
  void scheduleUnmuteAfterTurn(int generation) {
    _unmuteDebounceTimer?.cancel();
    _unmuteDebounceTimer = Timer(_kUnmuteDebounce, () {
      if (generation != _generation) return;
      if (assistantOwnsFloor) {
        debugPrint('[Gemini] 🔒 Mic stays OFF — assistant still busy after turn');
        _updateFloorStatus();
        return;
      }
      if (_pendingCallIds.isEmpty && !_batchInProgress && !isProcessing.value && !isLoading.value) {
        _exitLoading('turnComplete');
        _setMicMuted(false, reason: 'turnComplete — user floor');
        _updateFloorStatus();
        _triggerUiUpdate();
      }
    });
  }
}
