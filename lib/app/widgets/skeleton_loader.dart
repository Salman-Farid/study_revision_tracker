import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../core/constants/size_constants.dart';

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  const SkeletonGrid({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: d ? AppColors.surfaceDark : Colors.grey[200]!,
      highlightColor: d ? const Color(0xFF232730) : Colors.grey[100]!,
      child: GridView.builder(padding: EdgeInsets.all(S.base),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: S.gridCrossAxisCount, crossAxisSpacing: S.gridSpacing,
          mainAxisSpacing: S.gridSpacing, childAspectRatio: S.gridChildAspectRatio),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg)))));
  }
}
