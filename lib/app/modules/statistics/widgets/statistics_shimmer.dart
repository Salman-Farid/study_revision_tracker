import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../widgets/skeleton_loader.dart';

class StatisticsShimmerLoader extends StatelessWidget {
  final bool d;
  const StatisticsShimmerLoader({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    return ShimmerTheme.wrap(
      dark: d,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(S.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: S.streakCardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(S.radiusXl),
              ),
            ),
            SizedBox(height: S.xl),
            Container(
              height: 18,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            SizedBox(height: S.base),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: S.gridSpacing,
              mainAxisSpacing: S.gridSpacing,
              childAspectRatio: S.statCardAspectRatio,
              children: List.generate(
                4,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(S.radiusLg),
                  ),
                ),
              ),
            ),
            SizedBox(height: S.xxl),
            Container(
              height: 18,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            SizedBox(height: S.base),
            ...List.generate(
              3,
              (_) => Container(
                margin: EdgeInsets.only(bottom: S.md),
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(S.radiusLg),
                ),
              ),
            ),
            SizedBox(height: S.xxl),
            Container(
              height: 18,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            SizedBox(height: S.base),
            Container(
              width: double.infinity,
              height: S.chartHeight + S.xxxl,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(S.radiusLg),
              ),
            ),
            SizedBox(height: S.xxl),
            Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            SizedBox(height: S.base),
            Container(
              width: double.infinity,
              height: S.chartHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(S.radiusLg),
              ),
            ),
            SizedBox(height: S.xxl),
            Container(
              height: 18,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            SizedBox(height: S.base),
            ...List.generate(
              3,
              (_) => Container(
                margin: EdgeInsets.only(bottom: S.md),
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(S.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
