import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'responsive.dart';

class S {
  S._();
  // GetX-based viewport shortcuts (responsive width/height via Get).
  static double get w => Get.width;
  static double get h => Get.height;

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

  /// 2 cols in phone / split panes; 3 only on mid tablet full-width.
  static int get gridCrossAxisCount {
    if (Responsive.useSplitLayout) return 2;
    if (Responsive.width >= Responsive.mobileBreak) return 3;
    return 2;
  }

  static double get gridChildAspectRatio =>
      (Responsive.width >= Responsive.mobileBreak && !Responsive.useSplitLayout)
          ? 1.2
          : 0.9;
  static double get gridSpacing => Responsive.scale(12);

  // ── Metric/stat cards (history + dashboard) ──
  /// Wider-taller ratio so text never overflows on small screens.
  static double get statCardAspectRatio =>
      (Responsive.isTablet && !Responsive.useSplitLayout)
          ? 1.45
          : (Get.height < 700 ? 0.95 : 1.05);
  /// Fixed minimum height fallback for metric cards.
  static double get statCardMinHeight => Responsive.scale(148);
  static double get streakCardHeight => Responsive.scale(120);
  static double get chartHeight => Responsive.scale(220);

  /// Flat UI — no drop shadows on cards/containers.
  static List<BoxShadow> get shadowSm => const <BoxShadow>[];
  static List<BoxShadow> get shadowMd => const <BoxShadow>[];
}

