import 'package:flutter/material.dart';

class Responsive {
  Responsive._();
  static double _sw = 390, _sh = 844;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _sw = mq.size.width;
    _sh = mq.size.height;
  }

  static double get width => _sw;
  static double get height => _sh;
  static bool get isTablet => _sw >= 600;

  static double scale(double size) {
    return size * (_sw / 390).clamp(0.85, 1.35);
  }

  static double fontScale(double size) {
    return size * (_sw / 390).clamp(0.9, 1.25);
  }
}
