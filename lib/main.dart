import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';
import 'src/app/shopping_list_app.dart';
import 'src/data/services/backup_service.dart';
import 'src/data/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
}
