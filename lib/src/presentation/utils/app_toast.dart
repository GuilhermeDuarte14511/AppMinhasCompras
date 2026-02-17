import 'package:flutter/material.dart';

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

    final (start, end) = switch (type) {
      AppToastType.success => (
        const Color(0xFF0A7E61),
        const Color(0xFF13A87E),
      ),
      AppToastType.warning => (
        const Color(0xFFB06A00),
        const Color(0xFFD88908),
      ),
      AppToastType.error => (const Color.fromARGB(255, 179, 38, 30), const Color(0xFFD43D33)),
      AppToastType.info => (colorScheme.primary, colorScheme.tertiary),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          duration: duration,
          content: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
