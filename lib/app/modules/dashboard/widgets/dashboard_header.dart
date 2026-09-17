import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';

class DashboardShimmerLoader extends StatelessWidget {
  final bool d;
  const DashboardShimmerLoader({super.key, required this.d});

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
            // Header shimmer
            Row(children: [
              Container(width: S.avatarSize, height: S.avatarSize,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusMd))),
              SizedBox(width: S.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 12, width: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                SizedBox(height: S.sm),
                Container(height: 16, width: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ])),
            ]),
            SizedBox(height: S.lg),
            // Hero card shimmer
            Container(width: double.infinity, height: 140,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.lg),
            // Stats grid shimmer
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing, childAspectRatio: 1.25,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))))),
            SizedBox(height: S.lg),
            // Actions shimmer
            Container(height: 16, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            SizedBox(height: S.md),
            Container(height: 64, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusMd))),
          ],
        ),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  final bool d;
  final String greeting;
  const DashboardHeader({super.key, required this.d, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.fromLTRB(S.xl, S.xl, S.xl, S.sm),
      child: Row(children: [
        Container(width: S.avatarSize, height: S.avatarSize, decoration: BoxDecoration(
          gradient:  LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
          borderRadius: BorderRadius.circular(S.radiusMd)),
          child: Icon(Icons.person, color: Colors.white, size: S.iconLg)),
        SizedBox(width: S.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
          Text('smartRevisionTracker'.tr, style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(d))),
        ])),
      ]));
  }
}
