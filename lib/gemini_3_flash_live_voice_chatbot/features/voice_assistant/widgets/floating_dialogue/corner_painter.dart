part of '../../study_assistant_dialogue.dart';

/// Custom painter for the resizable dialogue corner.
class _CornerGripPainter extends CustomPainter {
  _CornerGripPainter({required this.isDark, required this.corner});
  final bool isDark;
  final String corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const inset = 5.0;
    const len = 8.0;
    switch (corner) {
      case 'topLeft':
        canvas.drawLine(const Offset(inset, inset + len), Offset(inset, inset), paint);
        canvas.drawLine(const Offset(inset, inset), Offset(inset + len, inset), paint);
        break;
      case 'topRight':
        canvas.drawLine(Offset(size.width - inset - len, inset), Offset(size.width - inset, inset), paint);
        canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + len), paint);
        break;
      case 'bottomLeft':
        canvas.drawLine(Offset(inset, size.height - inset - len), Offset(inset, size.height - inset), paint);
        canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + len, size.height - inset), paint);
        break;
      case 'bottomRight':
      default:
        canvas.drawLine(Offset(size.width - inset - len, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
        canvas.drawLine(Offset(size.width - inset, size.height - inset - len), Offset(size.width - inset, size.height - inset), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CornerGripPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.corner != corner;
}
