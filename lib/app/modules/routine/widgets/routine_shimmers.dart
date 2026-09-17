import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../widgets/skeleton_loader.dart';

class DailyShimmer extends StatelessWidget {
  final bool d;
  const DailyShimmer({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final baseColor = ShimmerTheme.base(d);
    final highlightColor = ShimmerTheme.highlight(d);

    return ShimmerTheme.wrap(
      dark: d,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: 6,
        itemBuilder: (_, i) => Container(
          margin: EdgeInsets.only(bottom: S.sm),
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(S.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: highlightColor),
                        SizedBox(width: 6),
                        Container(width: 100, height: 10, color: highlightColor),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      color: highlightColor,
                    ),
                    SizedBox(height: 6),
                    Container(width: 140, height: 10, color: highlightColor),
                  ],
                ),
              ),
              SizedBox(width: S.sm),
              Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(S.radiusSm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassShimmer extends StatelessWidget {
  final bool d;
  const ClassShimmer({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final baseColor = ShimmerTheme.base(d);
    final highlightColor = ShimmerTheme.highlight(d);

    return ShimmerTheme.wrap(
      dark: d,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: 5,
        itemBuilder: (_, i) => Container(
          margin: EdgeInsets.only(bottom: S.sm),
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(S.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 160, height: 14, color: highlightColor),
              SizedBox(height: S.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 60, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 40, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: highlightColor),
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 80, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 50, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: highlightColor),
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 50, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 30, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
