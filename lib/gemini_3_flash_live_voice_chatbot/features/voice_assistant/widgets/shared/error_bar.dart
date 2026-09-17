import 'package:flutter/material.dart';

import '../../../../../app/core/constants/app_constants.dart';

/// Shared error strip for full-screen and floating voice UIs.
/// [compact] = true matches the floating dialogue metrics.
class VoiceErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  final bool compact;

  const VoiceErrorBar({
    super.key,
    required this.message,
    required this.onRetry,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 4),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppConstants.errorColor,
            size: compact ? 16 : 18,
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppConstants.errorColor,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(
              Icons.refresh,
              color: AppConstants.errorColor,
              size: compact ? 14 : 16,
            ),
            label: Text(
              'Retry',
              style: TextStyle(
                color: AppConstants.errorColor,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
