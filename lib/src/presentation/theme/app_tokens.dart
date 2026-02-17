import 'package:flutter/material.dart';

@immutable
final class AppTokens {
  const AppTokens._();

  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 22;

  static const double cardElevation = 1;
  static const double cardBorderWidth = 1;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;

  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);

  static BorderRadius radius(double value) => BorderRadius.circular(value);
}
