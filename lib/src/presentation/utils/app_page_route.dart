import 'package:flutter/material.dart';

PageRoute<T> buildAppPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  Offset beginOffset = const Offset(0.06, 0),
  double beginScale = 0.992,
  Duration duration = const Duration(milliseconds: 320),
  Duration reverseDuration = const Duration(milliseconds: 240),
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(fade);
      final scale = Tween<double>(begin: beginScale, end: 1).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}
