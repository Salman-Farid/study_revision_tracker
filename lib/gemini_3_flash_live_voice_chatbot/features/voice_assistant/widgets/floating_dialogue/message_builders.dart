part of '../../study_assistant_dialogue.dart';

/// Builds ChatMessage → bubble widgets + actions.
extension DialogueMessageBuilders on _StudyAssistantDialogueState {
  Widget _buildHeader(VoiceAssistantController c, bool isDark, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppConstants.primaryColor.withOpacity(0.15),
                child: Icon(Icons.smart_toy_rounded,
                    color: AppConstants.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Assistant',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Obx(() {
                      final busy = c.floorBusy.value;
                      final label = c.floorLabel.value;
                      final color = switch (label) {
                        'Listening' => AppConstants.successColor,
                        'Offline' => AppConstants.errorColor,
                        _ when busy => AppConstants.warningColor,
                        _ => AppColors.textMutedDark,
                      };
                      return Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: color),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    size: 20),
                onPressed: () {
                  try { c.stopSession(); } catch (_) {}
                  c.showDialogue.value = false;
                  // Pop only if this is a dialog route (subjects screen).
                  // In routine screen it's embedded — Obx hides it.
                  final route = ModalRoute.of(context);
                  if (route is PopupRoute) {
                    Navigator.of(context).pop();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessages(VoiceAssistantController c, bool isDark) {
    return Obx(() {
      final msgs = c.messages;
      final processing = c.isProcessing.value;

      if (msgs.isEmpty &&
          c.connectionState.value == ws.ConnectionState.connecting) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppConstants.primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting...',
                style: TextStyle(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }

      // Don't call scrollToBottom() here — it schedules a rebuild during build.
      return ListView.builder(
        controller: c.scrollCtrl,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: msgs.length + (processing ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= msgs.length) {
            return const _ThinkingBubble();
          }
          return _ChatBubble(message: msgs[i], isDark: isDark);
        },
      );
    });
  }

  Widget _buildInputRow(VoiceAssistantController c, bool isDark) {
    return Obx(() {
      final st = c.connectionState.value;
      if (st == ws.ConnectionState.connecting) return const SizedBox.shrink();

      final busy = c.floorBusy.value;
      final muted = c.micIconOff;
      final statusText = c.floorLabel.value;
      final statusColor = busy
          ? AppConstants.warningColor
          : (c.isMuted
              ? AppColors.textMutedDark
              : AppConstants.successColor);

      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => c.toggleListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Mic closed (off) whenever assistant owns the floor.
                  color: muted
                      ? AppConstants.warningColor
                      : AppConstants.successColor,
                                  ),
                child: Icon(
                    muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: TextField(
                  controller: c.textCtrl,
                  focusNode: c.focusNode,
                  textInputAction: TextInputAction.send,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: statusText,
                    hintStyle: TextStyle(
                      color: !muted
                          ? statusColor.withOpacity(0.6)
                          : (isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => c.sendTextFromInput(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: c.sendTextFromInput,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );
    });
  }
}
