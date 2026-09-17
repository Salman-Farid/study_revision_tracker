import 'package:flutter/material.dart';

import '../../../../../app/core/constants/app_constants.dart';
import '../../../../../app/theme/app_theme.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../shared/widgets/thinking_dots.dart';

/// Shared chat bubble for full-screen assistant and floating dialogue.
///
/// [compact] = true matches the floating card metrics (slightly tighter).
/// [compact] = false matches the full-screen chat metrics.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final bool compact;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.system) {
      return SystemChatBubble(text: message.text, isDark: isDark, compact: compact);
    }
    if (message.isUser) {
      return UserChatBubble(text: message.text, isDark: isDark, compact: compact);
    }
    return AssistantChatBubble(text: message.text, isDark: isDark, compact: compact);
  }
}

class SystemChatBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool compact;

  const SystemChatBubble({
    super.key,
    required this.text,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isThinking = text.endsWith('...');
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isThinking) ...[
              SizedBox(
                width: compact ? 12 : 14,
                height: compact ? 12 : 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppConstants.primaryColor,
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserChatBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool compact;

  const UserChatBubble({
    super.key,
    required this.text,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(
          bottom: compact ? 6 : 8,
          left: compact ? 50 : 60,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(compact ? 16 : 18)
              .copyWith(bottomRight: const Radius.circular(4)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 14 : 15,
            height: 1.4,
            // Floating dialogue historically used this font family.
            fontFamily: compact ? 'NotoSansBengali' : null,
          ),
        ),
      ),
    );
  }
}

class AssistantChatBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool compact;

  const AssistantChatBubble({
    super.key,
    required this.text,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: compact ? 6 : 8,
          right: compact ? 50 : 60,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(compact ? 16 : 18)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: compact ? 14 : 15,
            height: 1.4,
            fontFamily: compact ? 'NotoSansBengali' : null,
          ),
        ),
      ),
    );
  }
}

class ThinkingChatBubble extends StatelessWidget {
  final bool compact;

  const ThinkingChatBubble({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: compact ? 6 : 8,
          right: compact ? 50 : 60,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(compact ? 16 : 18)
              .copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: const ThinkingDots(),
      ),
    );
  }
}
