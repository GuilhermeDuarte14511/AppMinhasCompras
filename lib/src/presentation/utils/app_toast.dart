import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppToastType { info, success, warning, error }

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    showWithMessenger(
      messenger,
      message: message,
      type: type,
      duration: duration,
    );
  }

  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final context = messenger.context;
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (type) {
      AppToastType.success => Icons.check_circle_rounded,
      AppToastType.warning => Icons.wifi_tethering_error_rounded,
      AppToastType.error => Icons.error_rounded,
      AppToastType.info => Icons.info_rounded,
    };

    final (start, end, border, iconBg) = switch (type) {
      AppToastType.success => (
        const Color(0xFF0A7E61),
        const Color(0xFF13A87E),
        const Color(0xCC72E2C4),
        const Color(0x3DFFFFFF),
      ),
      AppToastType.warning => (
        const Color(0xFFB06A00),
        const Color(0xFFD88908),
        const Color(0xFFF2C36A),
        const Color(0x3DFFFFFF),
      ),
      AppToastType.error => (
        const Color.fromARGB(255, 179, 38, 30),
        const Color(0xFFD43D33),
        const Color(0xFFF2A29D),
        const Color(0x38FFFFFF),
      ),
      AppToastType.info => (
        colorScheme.primary,
        colorScheme.tertiary,
        colorScheme.primaryContainer.withValues(alpha: 0.95),
        Colors.white.withValues(alpha: 0.18),
      ),
    };
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            0,
            AppTokens.spaceLg,
            max(AppTokens.spaceLg, bottomInset + AppTokens.spaceSm),
          ),
          duration: duration,
          content: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              gradient: LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: border.withValues(alpha: 0.8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
