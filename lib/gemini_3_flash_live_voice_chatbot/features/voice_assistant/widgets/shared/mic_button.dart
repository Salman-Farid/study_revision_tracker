/// Mic FAB with mute state.
import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const MicButton({
    super.key,
    required this.isActive,
    required this.onTap,
    this.size = 72,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: isActive ? 32 : 16,
          spreadRadius: isActive ? 6 : 2,
        ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isActive ? Icons.stop_rounded : Icons.mic_rounded,
            key: ValueKey(isActive),
            color: Colors.white,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }
}
