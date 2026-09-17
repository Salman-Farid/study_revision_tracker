import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';

class TechniqueGuidanceBox extends StatelessWidget {
  final String technique;
  const TechniqueGuidanceBox({super.key, required this.technique});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.sm),
      decoration: BoxDecoration(
        color: AppConstants.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(S.xs),
        border: Border.all(
          color: AppConstants.infoColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.psychology_rounded,
            size: 14,
            color: AppConstants.infoColor,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              technique,
              style: TextStyle(
                fontSize: 12,
                color: AppConstants.infoColor,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
