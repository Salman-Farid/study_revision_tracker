part of '../../voice_assistant_screen.dart';

/// Inline error/status strip under the header.
class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorBar(
      {required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppConstants.errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppConstants.errorColor, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon:
                Icon(Icons.refresh, color: AppConstants.errorColor, size: 16),
            label: Text('Retry',
                style:
                    TextStyle(color: AppConstants.errorColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
