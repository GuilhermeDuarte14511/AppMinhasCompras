import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app/shopping_list_app.dart';
import 'src/data/services/backup_service.dart';
import 'src/data/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(label: '[FlutterError]', stackTrace: details.stack);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher] $error');
    debugPrintStack(label: '[PlatformDispatcher]', stackTrace: stack);
    return true;
  };

  await runZonedGuarded(
    () async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        }

        final localReminderService = LocalNotificationsReminderService();
        final reminderService = localReminderService;

        runApp(
          ShoppingListApp(
            backupService: const FilePickerShoppingBackupService(),
            reminderService: reminderService,
          ),
        );
      } catch (error) {
        runApp(_BootstrapErrorApp(error: error.toString()));
      }
    },
    (error, stack) {
      debugPrint('[runZonedGuarded] $error');
      debugPrintStack(label: '[runZonedGuarded]', stackTrace: stack);
    },
  );
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Falha ao iniciar o Firebase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(error, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
