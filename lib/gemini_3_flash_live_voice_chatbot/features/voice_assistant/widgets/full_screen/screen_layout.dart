part of '../../voice_assistant_screen.dart';

/// Full-screen chat scaffold body layout.
extension VoiceAssistantScreenLayout on VoiceAssistantScreen {
  Widget _buildHeader(VoiceAssistantController c, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            onPressed: () {
              c.stopSession();
              Navigator.pop(Get.context!);
            },
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
            child: Icon(Icons.smart_toy_rounded,
                color: AppConstants.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                  return Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
