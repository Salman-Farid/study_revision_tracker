import 'package:flutter/material.dart';
import 'responsive.dart';

class S {
  S._();
  static double get xs => Responsive.scale(4);
  static double get sm => Responsive.scale(8);
  static double get md => Responsive.scale(12);
  static double get base => Responsive.scale(16);
  static double get lg => Responsive.scale(20);
  static double get xl => Responsive.scale(24);
  static double get xxl => Responsive.scale(32);
  static double get xxxl => Responsive.scale(48);
  static double get huge => Responsive.scale(64);

  static double get radiusXs => Responsive.scale(4);
  static double get radiusSm => Responsive.scale(8);
  static double get radiusMd => Responsive.scale(12);
  static double get radiusLg => Responsive.scale(16);
  static double get radiusXl => Responsive.scale(24);
  static double get radiusFull => Responsive.scale(999);

  static double get iconXs => Responsive.scale(14);
  static double get iconSm => Responsive.scale(18);
  static double get iconMd => Responsive.scale(22);
  static double get iconLg => Responsive.scale(28);
  static double get iconXl => Responsive.scale(36);
  static double get iconXxl => Responsive.scale(48);

  static double get buttonHeight => Responsive.scale(52);
  static double get cardMinHeight => Responsive.scale(120);
  static double get avatarSize => Responsive.scale(44);
  static int get gridCrossAxisCount => Responsive.isTablet ? 3 : 2;
  static double get gridChildAspectRatio => Responsive.isTablet ? 1.3 : 1.1;
  static double get gridSpacing => Responsive.scale(12);

  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: Colors.black.withOpacity(0.04),
      blurRadius: Responsive.scale(6), offset: Offset(0, Responsive.scale(2))),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(color: Colors.black.withOpacity(0.06),
      blurRadius: Responsive.scale(16), offset: Offset(0, Responsive.scale(4))),
  ];
}
