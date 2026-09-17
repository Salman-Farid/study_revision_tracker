part of '../../study_assistant_dialogue.dart';

/// Floating draggable/resizable panel chrome.
extension DialoguePanelLayout on _StudyAssistantDialogueState {
  Widget _panelShell({
    required VoiceAssistantController c,
    required bool isDark,
    required double screenW,
    required double screenH,
    required double dialogueW,
    required double currentH,
    required bool allowResize,
  }) {
    return GestureDetector(
      // Move by dragging the panel; corner grip steals the gesture to resize.
      onPanUpdate: (details) {
        if (c.isResizingDialogue.value) return;
        c.updateDialogueOffset(
            details.delta, screenW, screenH, dialogueW, currentH);
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogueW,
          height: currentH,
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark : AppColors.bgLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(c, isDark, context),
                  Expanded(child: _buildMessages(c, isDark)),
                  Obx(() {
                    final st = c.connectionState.value;
                    if (st == ws.ConnectionState.error) {
                      final err = c.errorMessage.value;
                      return _ErrorBar(
                        message: err.isNotEmpty ? err : 'Connection lost',
                        onRetry: () => c.startSession(),
                        isDark: isDark,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  if (!allowResize)
                    GestureDetector(
                      onTap: () => c.toggleExpanded(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Obx(() => AnimatedRotation(
                                  turns: c.isExpanded.value ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeInOutCubic,
                                  child: Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 16,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  _buildInputRow(c, isDark),
                  const SizedBox(height: 10),
                ],
              ),
              // Four corner resize grips (desktop/tablet only).
              if (allowResize) ...[
                _cornerGrip(
                  c: c,
                  isDark: isDark,
                  screenW: screenW,
                  screenH: screenH,
                  corner: 'topLeft',
                  alignment: Alignment.topLeft,
                  cursor: SystemMouseCursors.resizeUpLeft,
                ),
                _cornerGrip(
                  c: c,
                  isDark: isDark,
                  screenW: screenW,
                  screenH: screenH,
                  corner: 'topRight',
                  alignment: Alignment.topRight,
                  cursor: SystemMouseCursors.resizeUpRight,
                ),
                _cornerGrip(
                  c: c,
                  isDark: isDark,
                  screenW: screenW,
                  screenH: screenH,
                  corner: 'bottomLeft',
                  alignment: Alignment.bottomLeft,
                  cursor: SystemMouseCursors.resizeDownLeft,
                ),
                _cornerGrip(
                  c: c,
                  isDark: isDark,
                  screenW: screenW,
                  screenH: screenH,
                  corner: 'bottomRight',
                  alignment: Alignment.bottomRight,
                  cursor: SystemMouseCursors.resizeDownRight,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerGrip({
    required VoiceAssistantController c,
    required bool isDark,
    required double screenW,
    required double screenH,
    required String corner,
    required Alignment alignment,
    required MouseCursor cursor,
  }) {
    return Align(
      alignment: alignment,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => c.startDialogueResize(),
          onPanEnd: (_) => c.endDialogueResize(),
          onPanCancel: () => c.endDialogueResize(),
          onPanUpdate: (details) => c.resizeDialogueFromCorner(
            corner: corner,
            delta: details.delta,
            screenW: screenW,
            screenH: screenH,
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _CornerGripPainter(isDark: isDark, corner: corner)),
          ),
        ),
      ),
    );
  }
}
