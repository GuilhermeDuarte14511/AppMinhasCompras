import 'package:flutter/widgets.dart';

import 'src/app/shopping_list_app.dart';
import 'src/data/services/backup_service.dart';
import 'src/data/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localReminderService = LocalNotificationsReminderService();
  final reminderService = localReminderService;

  runApp(
    ShoppingListApp(
      backupService: const FilePickerShoppingBackupService(),
      reminderService: reminderService,
    ),
  );
}
