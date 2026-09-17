part of '../study_assistant_dialogue.dart';

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorBar(
      {required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: AppConstants.errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: AppConstants.errorColor, fontSize: 11),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh,
                color: AppConstants.errorColor, size: 14),
            label: Text('Retry',
                style: TextStyle(
                    color: AppConstants.errorColor, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
