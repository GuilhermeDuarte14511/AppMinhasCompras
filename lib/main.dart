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

        // Usa sempre o banco (default) em todas as plataformas.
        debugPrint('[Firebase] obtendo FirebaseFirestore.instance...');
        final firestore = FirebaseFirestore.instance;
        debugPrint('[Firebase] FirebaseFirestore.instance OK — databaseId: ${firestore.databaseId}');

        if (kIsWeb) {
          // Aguarda o SDK Web do Firestore terminar de inicializar internamente.
          // Sem esse delay, o primeiro acesso ao Firestore (mesmo que seja apenas
          // um Future.delayed dentro do _waitForStoreLoaded) causa
          // LateInitializationError no campo 'late' interno do delegate do SDK.
          // 1500ms garante margem suficiente mesmo em conexões mais lentas.
          debugPrint('[Firebase] aguardando inicialização interna do SDK Web...');
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          debugPrint('[Firebase] SDK Web pronto.');
        }

        // Pré-inicializa o SharedPreferences para garantir que o singleton
        // interno já esteja pronto antes do primeiro uso. Na Web em modo
        // release (dart2js com --omit-late-names), o SharedPreferences usa
        // um campo 'late' internamente que lança LateInitializationError se
        // acessado antes de ser inicializado — o que ocorria dentro do
        // importBackupJson → saveProducts logo após o login.
        debugPrint('[SharedPreferences] pré-inicializando...');
        await SharedPreferences.getInstance();
        debugPrint('[SharedPreferences] OK');

        final localReminderService = LocalNotificationsReminderService();
        final reminderService = localReminderService;

        runApp(
          ShoppingListApp(
            backupService: const FilePickerShoppingBackupService(),
            reminderService: reminderService,
            firestoreInstance: firestore,
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
