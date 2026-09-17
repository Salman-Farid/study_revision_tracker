part of '../voice_assistant_screen.dart';

extension VoiceAssistantSheetLayout on VoiceAssistantSheet {
  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _buildSheetHeader(VoiceAssistantController c, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
              bottom: BorderSide(
                  color:
                      isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1)),
        ),
        child: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
              child: Icon(Icons.smart_toy_rounded,
                  color: AppConstants.primaryColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Study Assistant',
                    style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Obx(() {
                  final st = c.connectionState.value;
                  final processing = c.isProcessing.value;
                  final (color, label) = switch (processing) {
                    true => (AppConstants.warningColor, 'Processing...'),
                    false => switch (st) {
                      ws.ConnectionState.connecting =>
                        (AppConstants.warningColor, 'Connecting...'),
                      ws.ConnectionState.connected =>
                        (AppConstants.successColor, 'Listening'),
                      ws.ConnectionState.error =>
                        (AppConstants.errorColor, 'Offline'),
                      _ => (AppColors.textMutedDark, 'Offline'),
                    },
                  };
                  return Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color)),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ]);
                }),
              ])),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            onPressed: () => c.reverseSheetAnim(),
          ),
        ]),
      );

  Widget _buildInputRow(VoiceAssistantController c, bool isDark) {
    return Obx(() {
      final st = c.connectionState.value;
      if (st == ws.ConnectionState.connecting) return const SizedBox.shrink();
      final muted = c.isMuted;
      final processing = c.isProcessing.value;
      final statusText = processing
          ? 'Processing...'
          : muted
              ? 'Muted — tap mic'
              : 'Listening...';
      final statusColor = processing
          ? AppConstants.warningColor
          : muted
              ? AppColors.textMutedDark
              : AppConstants.successColor;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => c.toggleListening(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: muted
                    ? AppConstants.warningColor
                    : AppConstants.successColor,
                boxShadow: !muted
                    ? [
                        BoxShadow(
                            color:
                                AppConstants.successColor.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2)
                      ]
                    : [],
              ),
              child: Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: TextField(
              controller: c.textCtrl,
              focusNode: c.focusNode,
              textInputAction: TextInputAction.send,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontSize: 15),
              decoration: InputDecoration(
                hintText: statusText,
                hintStyle: TextStyle(
                    color: !muted
                        ? statusColor.withOpacity(0.6)
                        : (isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => c.sendTextFromInput(),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: c.sendTextFromInput,
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppConstants.primaryColor),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20)),
          ),
        ]),
      );
    });
  }
}
