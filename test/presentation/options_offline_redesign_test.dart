import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/account/cloud_sync_status_panel.dart';
import 'package:lista_compras_material/src/presentation/account_pages.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

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

  testWidgets(
    'offline editorial options reference uses actual counters and date',
    (tester) async {
      _size(tester, const Size(390, 884));
      await tester.pumpWidget(_host(_options(), dark: true));
      await tester.pumpAndSettle();
      expect(find.text('Modo offline'), findsOneWidget);
      expect(find.text('Sem rede'), findsOneWidget);
      expect(find.text('2 registros'), findsOneWidget);
      expect(find.text('10/10 10:30'), findsOneWidget);
      expect(find.text('Há 42 minutos'), findsNothing);
      expect(find.text('Orçamento ativo'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/options_offline_stitch_390.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline overrides a stale syncing flag and never animates upload',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Scaffold(body: _panel(online: false, syncing: true, pending: 3)),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Modo offline'), findsOneWidget);
      expect(find.text('Sincronizando online'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text('Sem internet. 3 registros aguardam conexão.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('online queued work is idle until a real sync starts', (
    tester,
  ) async {
    await tester.pumpWidget(_host(Scaffold(body: _panel(pending: 3))));
    await tester.pumpAndSettle();
    expect(find.text('Alterações pendentes'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(
      _host(Scaffold(body: _panel(pending: 3, syncing: true))),
    );
    await tester.pump();
    expect(find.text('Sincronizando online'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('pending boolean with unknown count uses honest description', (
    tester,
  ) async {
    await tester.pumpWidget(_host(Scaffold(body: _panel(pendingFlag: true))));
    await tester.pumpAndSettle();
    expect(find.text('Alterações aguardando sincronização.'), findsOneWidget);
    expect(find.text('0 registros aguardando sincronização.'), findsNothing);
  });

  testWidgets(
    'received sync dates and counters update without fabricated history',
    (tester) async {
      await tester.pumpWidget(_host(Scaffold(body: _panel())));
      await tester.pumpAndSettle();
      expect(find.text('Pronto para sincronizar'), findsOneWidget);
      expect(find.text('Nunca sincronizado'), findsOneWidget);
      expect(find.text('Sincronizados: —'), findsOneWidget);
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: _panel(lastSync: DateTime(2026, 10, 10, 14, 5), pending: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('14:05'), findsNothing);
      expect(find.text('10/10 14:05'), findsOneWidget);
      expect(find.text('Sincronizados: 10'), findsOneWidget);
      await tester.pumpWidget(
        _host(Scaffold(body: _panel(lastSync: DateTime(2026, 10, 10, 14, 5)))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tudo sincronizado'), findsOneWidget);
      expect(find.text('Sincronizados: 12'), findsOneWidget);
    },
  );

  testWidgets('invalid counters are bounded and empty offline remains local', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: _panel(online: false, total: -2, pending: 10, categories: -3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total: 0'), findsOneWidget);
    expect(find.text('Sincronizados: 0'), findsOneWidget);
    expect(find.text('Faltando: 0'), findsOneWidget);
    expect(
      find.text('Listas: 0 · Histórico: 0 · Catálogo: 0 · Despensa: 0'),
      findsOneWidget,
    );
    expect(
      find.text('Sem internet. Alterações continuam salvas no aparelho.'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      _host(Scaffold(body: _panel(total: 4, pending: 50))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Faltando: 4'), findsOneWidget);
    expect(find.text('Sincronizados: —'), findsOneWidget);
  });

  testWidgets(
    'compact dark options allow large text and scrolling to support',
    (tester) async {
      _size(tester, const Size(320, 568));
      await tester.pumpWidget(_host(_options(), dark: true, scale: 1.5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Modo offline'), 200);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Rever Onboarding'), 200);
      expect(find.text('Rever Onboarding'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

CloudSyncStatusPanel _panel({
  bool online = true,
  bool syncing = false,
  bool pendingFlag = false,
  int pending = 0,
  int total = 12,
  int categories = 3,
  DateTime? lastSync,
}) => CloudSyncStatusPanel(
  hasInternetConnection: online,
  hasPendingCloudSync: pendingFlag || pending > 0,
  isCloudSyncing: syncing,
  lastCloudSyncAt: lastSync,
  totalRecords: total,
  pendingRecords: pending,
  listRecords: categories,
  historyRecords: categories,
  catalogRecords: categories,
  pantryRecords: categories,
  compact: true,
);

AppOptionsPage _options() => AppOptionsPage(
  themeMode: ThemeMode.dark,
  onThemeModeChanged: (_) {},
  autoImportOwnedSharedCatalogs: true,
  onAutoImportOwnedSharedCatalogsChanged: (_) {},
  onSignOut: () async {},
  onReplayOnboarding: () {},
  userDisplayName: 'Ana Silva',
  userEmail: 'ana@example.com',
  showCloudSyncStatus: true,
  hasInternetConnection: false,
  hasPendingCloudSync: true,
  lastCloudSyncAt: DateTime(2026, 10, 10, 10, 30),
  totalSyncRecords: 12,
  pendingSyncRecords: 2,
  listRecords: 3,
  historyRecords: 2,
  catalogRecords: 5,
  pantryRecords: 2,
);

Widget _host(Widget child, {bool dark = false, double scale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    );

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
