import 'package:flutter/material.dart';

/// Smooth slowmo expand/collapse card shell.
class ExpandableCard extends StatefulWidget {
  final Widget Function(BuildContext context, bool isExpanded, VoidCallback toggleExpand, AnimationController animController) builder;

  const ExpandableCard({super.key, required this.builder});

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      reverseDuration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isExpanded, _toggle, _controller);
  }
}

/// Wraps expanded content with slowmo fade + slide animation
class AnimatedExpanded extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const AnimatedExpanded({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final fadeAnim = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.value == 0.0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: fadeAnim.value,
            child: FadeTransition(
              opacity: fadeAnim,
              child: SlideTransition(
                position: slideAnim,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
