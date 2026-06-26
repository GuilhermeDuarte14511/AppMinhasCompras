import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/firebase_user_data_repository.dart';

void main() {
  test('FirestoreUserAppSettings persists shared catalog import settings', () {
    final settings = FirestoreUserAppSettings(
      themeMode: 'dark',
      autoImportOwnedSharedCatalogs: false,
      autoImportSharedCatalogs: true,
      sharedCatalogImportListIds: {'shared-b', 'shared-a', ''},
    );

    final payload = settings.toFirestoreJson();

    expect(payload['themeMode'], 'dark');
    expect(payload['autoImportOwnedSharedCatalogs'], isFalse);
    expect(payload['autoImportSharedCatalogs'], isTrue);
    expect(payload['sharedCatalogImportListIds'], ['shared-a', 'shared-b']);

    final parsed = FirestoreUserAppSettings.fromJson({
      'themeMode': 'dark',
      'autoImportOwnedSharedCatalogs': false,
      'autoImportSharedCatalogs': true,
      'sharedCatalogImportListIds': ['shared-b', 'shared-a', '', 42],
      'updatedAt': '2026-06-24T10:00:00.000',
    });

    expect(parsed.themeMode, 'dark');
    expect(parsed.autoImportOwnedSharedCatalogs, isFalse);
    expect(parsed.autoImportSharedCatalogs, isTrue);
    expect(parsed.sharedCatalogImportListIds, {'shared-a', 'shared-b'});
    expect(parsed.hasData, isTrue);

    final parsedLegacy = FirestoreUserAppSettings.fromJson({
      'themeMode': 'light',
      'updatedAt': '2026-06-24T10:00:00.000',
    });

    expect(parsedLegacy.autoImportOwnedSharedCatalogs, isTrue);
  });
}
