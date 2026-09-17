part of '../../voice_assistant_screen.dart';

/// Thin wrapper → [VoiceErrorBar] at full-screen density.
class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorBar(
      {required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) => VoiceErrorBar(
        message: message,
        onRetry: onRetry,
        isDark: isDark,
        compact: false,
      );
}
