import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync_diagnostics.dart';
import 'package:lista_compras_material/src/presentation/account_pages.dart';

void main() {
  testWidgets('options page opens sync diagnostics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppOptionsPage(
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
          autoImportOwnedSharedCatalogs: true,
          onAutoImportOwnedSharedCatalogsChanged: (_) {},
          syncDiagnostics: _snapshot(),
          onSyncNow: () async {},
          showCloudSyncStatus: true,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Sincronização e diagnóstico'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Sincronização e diagnóstico'));
    await tester.pumpAndSettle();

    expect(find.text('Tudo sincronizado'), findsOneWidget);
    expect(find.text('Copiar relatório'), findsOneWidget);
  });
}

SyncDiagnosticsSnapshot _snapshot() {
  return SyncDiagnosticsSnapshot(
    generatedAt: DateTime(2026, 6, 27, 10),
    userName: 'Guilherme',
    userEmail: 'gui@example.com',
    userUid: 'uid-123',
    providerId: 'google.com',
    projectId: 'minhascompras-3abbe',
    platformLabel: 'Android',
    appVersion: '1.0.0+1',
    hasInternetConnection: true,
    hasPendingCloudSync: false,
    isCloudSyncing: false,
    isPullingCloudSnapshot: false,
    isMirroringSharedLists: false,
    lastCloudSyncAt: DateTime(2026, 6, 27, 9, 55),
    lastSharedSyncAt: null,
    totalSyncRecords: 20,
    pendingSyncRecords: 0,
    listRecords: 5,
    historyRecords: 3,
    catalogRecords: 12,
    sharedListCount: 0,
    autoImportOwnedSharedCatalogs: true,
    autoImportAllSharedCatalogs: false,
    enabledSharedCatalogImportCount: 0,
    lastError: null,
    sharedLists: const [],
  );
}
