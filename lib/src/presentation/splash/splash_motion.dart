import 'package:flutter/material.dart';

/// One decorative sequence; it never reports application load progress.
abstract final class SplashMotion {
  static const duration = Duration(milliseconds: 1800);
  static const entrance = Interval(0, .2, curve: Curves.easeOutCubic);
  static const bag = Interval(.62, 1, curve: Curves.easeOutCubic);
  static double row(int index, double progress) => Interval(
    .12 + index * .12,
    .34 + index * .12,
    curve: Curves.easeOutCubic,
  ).transform(progress);
  static double check(int index, double progress) => Interval(
    .32 + index * .13,
    .52 + index * .13,
    curve: Curves.easeOutCubic,
  ).transform(progress);
}
