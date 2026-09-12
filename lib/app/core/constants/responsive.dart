import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static double _sw = 390, _sh = 844;

  /// Phone reference width used for scale math.
  static const double designWidth = 390;

  // Breakpoints
  static const double mobileBreak = 600;
  static const double railBreak = 760;
  static const double splitBreak = 980;
  static const double desktopBreak = 1180;
  static const double tripleBreak = 1480;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _sw = mq.size.width;
    _sh = mq.size.height;
  }

  static double get width => _sw;
  static double get height => _sh;

  static bool get isWeb => kIsWeb;
  static bool get isMobile => _sw < mobileBreak;
  static bool get isTablet => _sw >= mobileBreak && _sw < desktopBreak;
  static bool get isDesktop => _sw >= desktopBreak;
  static bool get isWide => _sw >= tripleBreak;

  /// Bottom bar on phones; NavigationRail from tablet/web mid-width up.
  static bool get useBottomNav => _sw < railBreak;
  static bool get useNavRail => _sw >= railBreak;

  /// Merge 2 screens side-by-side.
  static bool get useSplitLayout => _sw >= splitBreak;

  /// Merge 3 screens side-by-side on large desktops.
  static bool get useTripleLayout => _sw >= tripleBreak;

  /// Content density: keep phone-sized UI on large screens so panes
  /// don't turn into huge empty cards.
  static double scale(double size) {
    if (_sw >= desktopBreak) return size * 1.0;
    if (_sw >= splitBreak) return size * (_sw / designWidth).clamp(0.95, 1.12);
    return size * (_sw / designWidth).clamp(0.85, 1.35);
  }

  static double fontScale(double size) {
    if (_sw >= desktopBreak) return size * 1.0;
    if (_sw >= splitBreak) return size * (_sw / designWidth).clamp(0.95, 1.1);
    return size * (_sw / designWidth).clamp(0.9, 1.25);
  }

  /// Max width for a single full-width page (settings, auth).
  static double get pageMaxWidth => 720;

  /// Combined max width of the split workspace.
  static double get workspaceMaxWidth => 1440;
}
