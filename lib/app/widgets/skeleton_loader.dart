import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/constants/size_constants.dart';

/// Shared shimmer base/highlight colors used by all screen loaders.
class ShimmerTheme {
  const ShimmerTheme._();

  static Color base(bool dark) =>
      dark ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4);

  static Color highlight(bool dark) =>
      dark ? const Color(0xFF3D4250) : const Color(0xFFF0F3F8);

  static Widget wrap({
    required bool dark,
    required Widget child,
  }) {
    return Shimmer.fromColors(
      baseColor: base(dark),
      highlightColor: highlight(dark),
      child: child,
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  const SkeletonGrid({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return ShimmerTheme.wrap(
      dark: d,
      child: GridView.builder(
        padding: EdgeInsets.all(S.base),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: S.gridCrossAxisCount,
          crossAxisSpacing: S.gridSpacing,
          mainAxisSpacing: S.gridSpacing,
          childAspectRatio: S.gridChildAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(S.radiusLg),
          ),
        ),
      ),
    );
  }
}

/// Simple placeholder rectangle used inside shimmer loaders.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
