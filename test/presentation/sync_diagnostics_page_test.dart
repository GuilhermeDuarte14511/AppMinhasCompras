import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync_diagnostics.dart';
import 'package:lista_compras_material/src/presentation/sync_diagnostics_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows status, shared lists and runs manual sync', (
    tester,
  ) async {
    var syncCalls = 0;
    final snapshot = _snapshot(
      sharedLists: const [
        SharedListDiagnosticEntry(
          id: 'shared-1',
          name: 'Mercado do mês',
          ownerUid: 'uid-123',
          isOwner: true,
          memberCount: 2,
          itemCount: 18,
          isCatalogImportEnabled: true,
          isMirroredLocally: true,
          updatedAt: null,
          lastError: null,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SyncDiagnosticsPage(
          snapshot: snapshot,
          onSyncNow: () async {
            syncCalls++;
          },
        ),
      ),
    );

    expect(find.text('Sincronização e diagnóstico'), findsOneWidget);
    expect(find.text('Atenção: há pendências'), findsOneWidget);
    expect(find.text('Sincronizar agora'), findsOneWidget);

    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();

    expect(syncCalls, 1);

    await tester.scrollUntilVisible(
      find.text('Mercado do mês'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Mercado do mês'), findsOneWidget);
  });

  testWidgets('copies support report to clipboard', (tester) async {
    final clipboardPayloads = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          clipboardPayloads.add(args['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SyncDiagnosticsPage(
          snapshot: _snapshot(),
          onSyncNow: () async {},
        ),
      ),
    );

    await tester.tap(find.text('Copiar relatório'));
    await tester.pumpAndSettle();

    expect(clipboardPayloads, hasLength(1));
    expect(clipboardPayloads.single, contains('App: Minhas Compras'));
    expect(clipboardPayloads.single, contains('UID: uid-123'));
  });

  testWidgets('refreshes diagnostics snapshot after manual sync', (
    tester,
  ) async {
    final refreshed = _snapshot().copyWith(
      hasPendingCloudSync: false,
      pendingSyncRecords: 0,
      lastCloudSyncAt: DateTime(2026, 6, 27, 10, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SyncDiagnosticsPage(
          snapshot: _snapshot(),
          onSyncNow: () async {},
          onRefreshSnapshot: () async => refreshed,
        ),
      ),
    );

    expect(find.text('Atenção: há pendências'), findsOneWidget);

    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();

    expect(find.text('Tudo sincronizado'), findsOneWidget);
  });
}

SyncDiagnosticsSnapshot _snapshot({
  List<SharedListDiagnosticEntry> sharedLists = const [],
}) {
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
    hasPendingCloudSync: true,
    isCloudSyncing: false,
    isPullingCloudSnapshot: false,
    isMirroringSharedLists: false,
    lastCloudSyncAt: DateTime(2026, 6, 27, 9, 55),
    lastSharedSyncAt: DateTime(2026, 6, 27, 9, 58),
    totalSyncRecords: 20,
    pendingSyncRecords: 2,
    listRecords: 5,
    historyRecords: 3,
    catalogRecords: 12,
    sharedListCount: sharedLists.length,
    autoImportOwnedSharedCatalogs: true,
    autoImportAllSharedCatalogs: false,
    enabledSharedCatalogImportCount: 1,
    lastError: null,
    sharedLists: sharedLists,
  );
}
