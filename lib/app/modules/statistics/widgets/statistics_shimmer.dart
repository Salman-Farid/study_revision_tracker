import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/size_constants.dart';

class StatisticsShimmerLoader extends StatelessWidget {
  final bool d;
  const StatisticsShimmerLoader({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final baseColor = d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4);
    final highlightColor = d ? const Color(0xFF3D4250) : const Color(0xFFF0F3F8);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(S.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak card shimmer
            Container(width: double.infinity, height: S.streakCardHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusXl))),
            SizedBox(height: S.xl),
            // Overview title
            Container(height: 18, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Stats grid shimmer
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing,
              childAspectRatio: S.statCardAspectRatio,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))))),
            SizedBox(height: S.xxl),
            // Subject Progress title
            Container(height: 18, width: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Subject progress shimmer items
            ...List.generate(3, (_) => Container(
              margin: EdgeInsets.only(bottom: S.md), height: 72, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg)))),
            SizedBox(height: S.xxl),
            // Mastery title
            Container(height: 18, width: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Mastery chart shimmer
            Container(width: double.infinity, height: S.chartHeight + S.xxxl,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.xxl),
            // Weekly title
            Container(height: 18, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Weekly chart shimmer
            Container(width: double.infinity, height: S.chartHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.xxl),
            // Insights title
            Container(height: 18, width: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Insight items shimmer
            ...List.generate(3, (_) => Container(
              margin: EdgeInsets.only(bottom: S.md), height: 64, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg)))),
          ],
        ),
      ),
    );
  }
}
