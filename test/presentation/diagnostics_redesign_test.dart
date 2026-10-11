import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync_diagnostics.dart';
import 'package:lista_compras_material/src/presentation/sync_diagnostics_page.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('diagnostics mobile editorial reference', (tester) async {
    await _open(tester);
    await expectLater(
      find.byType(SyncDiagnosticsPage),
      matchesGoldenFile('goldens/diagnostics_stitch_390.png'),
    );
    expect(find.text('Tudo sincronizado'), findsOneWidget);
    expect(
      find.text('Última verificação: 10/10/2026 às 10:30'),
      findsOneWidget,
    );
    expect(find.textContaining('Estável'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual sync blocks duplicate requests and refreshes status', (
    tester,
  ) async {
    final completion = Completer<void>();
    var syncCalls = 0;
    var refreshCalls = 0;
    await _open(
      tester,
      sync: () {
        syncCalls++;
        return completion.future;
      },
      refresh: () async {
        refreshCalls++;
        return _snapshot().copyWith(hasInternetConnection: false);
      },
    );
    await tester.tap(find.text('Sincronizar agora'));
    await tester.pump();
    expect(find.text('Sincronizando...'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Atualizar sincronização',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(syncCalls, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(refreshCalls, 1);
    expect(find.text('Modo offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed sync keeps snapshot and restores retry', (tester) async {
    await _open(
      tester,
      sync: () async => throw StateError('rede indisponível'),
    );
    await tester.tap(find.byTooltip('Atualizar sincronização'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo sincronizado'), findsOneWidget);
    expect(find.textContaining('Falha ao sincronizar agora:'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('copies refreshed real report rather than illustrative data', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final updated = _snapshot().copyWith(
      pendingSyncRecords: 3,
      hasPendingCloudSync: true,
    );
    await _open(tester, refresh: () async => updated);
    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar relatório'));
    await tester.pumpAndSettle();
    expect(copied, updated.buildSupportReport());
  });

  testWidgets('complete environment and shared diagnostics remain readable', (
    tester,
  ) async {
    await _open(tester);
    for (final label in [
      'E-mail',
      'UID do usuário',
      'Provedor de autenticação',
      'Projeto Firebase',
      'Versão do app',
      'Último sync compartilhadas',
      'Importar todas compartilhadas',
      'Mercado da semana',
      'Erro: Permissão negada',
    ]) {
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text(label),
        250,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dark layout at larger text has no overflow', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 568), scale: 1.5, dark: true);
    await tester.scrollUntilVisible(
      find.text('Erro: Permissão negada'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Sincronizar agora'),
      -250,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 884),
  double scale = 1,
  bool dark = false,
  Future<void> Function()? sync,
  Future<SyncDiagnosticsSnapshot?> Function()? refresh,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: SyncDiagnosticsPage(
        snapshot: _snapshot(),
        onSyncNow: sync ?? () async {},
        onRefreshSnapshot: refresh,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SyncDiagnosticsSnapshot _snapshot() => SyncDiagnosticsSnapshot(
  generatedAt: DateTime(2026, 10, 10, 10, 30),
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
  lastCloudSyncAt: DateTime(2026, 10, 10, 10, 20),
  lastSharedSyncAt: null,
  totalSyncRecords: 20,
  pendingSyncRecords: 0,
  listRecords: 5,
  historyRecords: 3,
  catalogRecords: 12,
  pantryRecords: 4,
  sharedListCount: 1,
  autoImportOwnedSharedCatalogs: true,
  autoImportAllSharedCatalogs: false,
  enabledSharedCatalogImportCount: 1,
  lastError: null,
  sharedLists: [
    SharedListDiagnosticEntry(
      id: 'shared-1',
      name: 'Mercado da semana',
      ownerUid: 'uid-123',
      isOwner: true,
      memberCount: 2,
      itemCount: 18,
      isCatalogImportEnabled: true,
      isMirroredLocally: true,
      updatedAt: DateTime(2026, 10, 10, 9),
      lastError: 'Permissão negada',
    ),
  ],
);
