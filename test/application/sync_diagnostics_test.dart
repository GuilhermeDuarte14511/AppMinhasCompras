import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync_diagnostics.dart';

void main() {
  test('resolves attention status when there are pending records', () {
    final snapshot = SyncDiagnosticsSnapshot(
      generatedAt: DateTime(2026, 6, 27, 9, 30),
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
      lastCloudSyncAt: DateTime(2026, 6, 27, 9, 20),
      lastSharedSyncAt: DateTime(2026, 6, 27, 9, 21),
      totalSyncRecords: 15,
      pendingSyncRecords: 4,
      listRecords: 5,
      historyRecords: 2,
      catalogRecords: 8,
      sharedListCount: 1,
      autoImportOwnedSharedCatalogs: true,
      autoImportAllSharedCatalogs: false,
      enabledSharedCatalogImportCount: 0,
      lastError: null,
      sharedLists: const [
        SharedListDiagnosticEntry(
          id: 'shared-1',
          name: 'Mercado',
          ownerUid: 'uid-123',
          isOwner: true,
          memberCount: 2,
          itemCount: 12,
          isCatalogImportEnabled: true,
          isMirroredLocally: true,
          updatedAt: null,
          lastError: null,
        ),
      ],
    );

    expect(snapshot.status, SyncDiagnosticStatus.attention);
    expect(snapshot.statusTitle, 'Atenção: há pendências');
    expect(snapshot.syncedRecords, 11);
  });

  test('buildSupportReport includes sync, account and shared-list details', () {
    final snapshot = SyncDiagnosticsSnapshot(
      generatedAt: DateTime(2026, 6, 27, 9, 30),
      userName: 'Carol',
      userEmail: 'carol@example.com',
      userUid: 'uid-456',
      providerId: 'password',
      projectId: 'minhascompras-3abbe',
      platformLabel: 'Web',
      appVersion: '1.0.0+1',
      hasInternetConnection: false,
      hasPendingCloudSync: true,
      isCloudSyncing: false,
      isPullingCloudSnapshot: false,
      isMirroringSharedLists: false,
      lastCloudSyncAt: null,
      lastSharedSyncAt: null,
      totalSyncRecords: 6,
      pendingSyncRecords: 6,
      listRecords: 2,
      historyRecords: 1,
      catalogRecords: 3,
      sharedListCount: 1,
      autoImportOwnedSharedCatalogs: true,
      autoImportAllSharedCatalogs: true,
      enabledSharedCatalogImportCount: 1,
      lastError: 'permission-denied',
      sharedLists: const [
        SharedListDiagnosticEntry(
          id: 'shared-2',
          name: 'Lista Guilherme',
          ownerUid: 'uid-123',
          isOwner: false,
          memberCount: 2,
          itemCount: 30,
          isCatalogImportEnabled: true,
          isMirroredLocally: false,
          updatedAt: null,
          lastError: 'sem snapshot de itens',
        ),
      ],
    );

    final report = snapshot.buildSupportReport();

    expect(report, contains('Status: Modo offline'));
    expect(report, contains('Usuário: Carol'));
    expect(report, contains('UID: uid-456'));
    expect(report, contains('Listas locais: 2'));
    expect(report, contains('Catálogo: 3'));
    expect(report, contains('Listas compartilhadas: 1'));
    expect(report, contains('Lista Guilherme - Participante'));
    expect(report, contains('Último erro: permission-denied'));
  });

  test(
    'copyWith can refresh shared list details without losing sync state',
    () {
      final snapshot = SyncDiagnosticsSnapshot(
        generatedAt: DateTime(2026, 6, 27, 9, 30),
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
        lastCloudSyncAt: DateTime(2026, 6, 27, 9, 20),
        lastSharedSyncAt: null,
        totalSyncRecords: 10,
        pendingSyncRecords: 0,
        listRecords: 3,
        historyRecords: 1,
        catalogRecords: 6,
        sharedListCount: 0,
        autoImportOwnedSharedCatalogs: true,
        autoImportAllSharedCatalogs: false,
        enabledSharedCatalogImportCount: 0,
        lastError: null,
        sharedLists: const [],
      );

      final refreshed = snapshot.copyWith(
        sharedListCount: 1,
        sharedLists: const [
          SharedListDiagnosticEntry(
            id: 'shared-1',
            name: 'Mercado',
            ownerUid: 'uid-123',
            isOwner: true,
            memberCount: 2,
            itemCount: 4,
            isCatalogImportEnabled: true,
            isMirroredLocally: true,
            updatedAt: null,
            lastError: null,
          ),
        ],
      );

      expect(refreshed.status, SyncDiagnosticStatus.synced);
      expect(refreshed.sharedListCount, 1);
      expect(refreshed.sharedLists.single.itemCount, 4);
      expect(refreshed.catalogRecords, 6);
    },
  );
}
