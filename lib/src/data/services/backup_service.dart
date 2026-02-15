import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../application/ports.dart';
import '../../domain/models_and_utils.dart';

class FilePickerShoppingBackupService implements ShoppingBackupService {
  const FilePickerShoppingBackupService();

  @override
  Future<BackupExportResult> exportBackup(String payload) async {
    final fileName =
        'minhas_compras_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    try {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );

      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        await File(selectedPath).writeAsString(payload, flush: true);
        return BackupExportResult(
          mode: BackupExportMode.file,
          location: selectedPath,
        );
      }
    } catch (_) {
      // fallback below
    }

    await Clipboard.setData(ClipboardData(text: payload));
    return const BackupExportResult(mode: BackupExportMode.clipboard);
  }

  @override
  Future<String?> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Importar backup',
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        return utf8.decode(bytes, allowMalformed: true);
      }

      final path = file.path;
      if (path == null || path.trim().isEmpty) {
        return null;
      }

      return File(path).readAsString();
    } catch (_) {
      return null;
    }
  }
}
