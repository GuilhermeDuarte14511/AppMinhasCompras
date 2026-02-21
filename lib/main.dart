import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        debugPrint('[Firebase] initializeApp iniciando...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[Firebase] initializeApp OK');

        if (kIsWeb) {
          debugPrint('[Firebase] setPersistence iniciando...');
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint('[Firebase] setPersistence OK');
        }

        debugPrint('[Firebase] obtendo FirebaseFirestore.instance...');
        final firestore = FirebaseFirestore.instance;

        // ✅ Mitigação forte para "INTERNAL ASSERTION FAILED" no Web
        if (kIsWeb) {
          firestore.settings = const Settings(
            persistenceEnabled: false,
            webExperimentalForceLongPolling: true,
            webExperimentalAutoDetectLongPolling: true,
          );
        }

        debugPrint(
          '[Firebase] FirebaseFirestore.instance OK — databaseId: ${firestore.databaseId}',
        );

        if (kIsWeb) {
          debugPrint('[Firebase] aguardando inicialização interna do SDK Web...');
          await Future<void>.delayed(const Duration(milliseconds: 300));
          debugPrint('[Firebase] SDK Web pronto.');
        }

        debugPrint('[SharedPreferences] pré-inicializando...');
        await SharedPreferences.getInstance();
        debugPrint('[SharedPreferences] OK');

        // ✅ No Web NÃO usa flutter_local_notifications
        final reminderService = kIsWeb
            ? const NoopShoppingReminderService()
            : LocalNotificationsReminderService();

        runApp(
          ShoppingListApp(
            backupService: const FilePickerShoppingBackupService(),
            reminderService: reminderService,
            firestoreInstance: firestore,
          ),
        );
      } catch (error) {
        debugPrint('[Bootstrap] erro: $error');
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
                  'Falha ao iniciar o app',
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
