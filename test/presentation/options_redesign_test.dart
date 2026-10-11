import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('options editorial mobile reference keeps real sync data', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _page(
                    cloud: true,
                    lastSync: DateTime(2026, 10, 10, 10, 30),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/options_stitch_390.png'),
    );
    expect(find.text('Tudo sincronizado'), findsOneWidget);
    expect(find.text('Última sincronização'), findsOneWidget);
    expect(find.text('10/10 10:30'), findsOneWidget);
    expect(find.textContaining('(Conectado)'), findsNothing);
    expect(find.textContaining('há 2 min'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('theme and automatic catalog setting preserve callbacks', (
    tester,
  ) async {
    ThemeMode? mode;
    bool? auto;
    await tester.pumpWidget(
      _host(
        _page(
          onTheme: (value) => mode = value,
          onAuto: (value) => auto = value,
        ),
      ),
    );
    await tester.tap(find.text('Escuro'));
    await tester.pump();
    expect(mode, ThemeMode.dark);
    await tester.scrollUntilVisible(find.byType(Switch), 250);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(auto, false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
  testWidgets('sign out disables duplicate requests while pending', (
    tester,
  ) async {
    var calls = 0;
    final done = Completer<void>();
    await tester.pumpWidget(
      _host(
        _page(
          onSignOut: () {
            calls++;
            return done.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Deslogar'));
    await tester.pump();
    expect(find.text('Saindo...'), findsOneWidget);
    await tester.tap(find.text('Saindo...'));
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('Deslogar'), findsOneWidget);
  });
  testWidgets('offline pending and unavailable sync use actual flags', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_page(cloud: true, online: false, pending: 2)),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Modo offline'), 250);
    expect(find.text('Modo offline'), findsOneWidget);
    expect(
      find.text('Sem internet. 2 registros aguardam conexão.'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      _host(_page(cloud: true, syncing: true, pending: 2)),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Sincronizando online'), 250);
    expect(find.text('Sincronizando online'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(_host(_page()));
    await tester.pumpAndSettle();
    expect(
      find.text('Sincronização em nuvem indisponível no momento.'),
      findsOneWidget,
    );
    expect(find.text('Sincronização e diagnóstico'), findsNothing);
  });
  testWidgets('onboarding closes options and invokes existing replay', (
    tester,
  ) async {
    var replay = 0;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _page(onReplay: () => replay++),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rever Onboarding'), 250);
    await tester.tap(find.text('Rever Onboarding'));
    await tester.pumpAndSettle();
    expect(replay, 1);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text('Opções'), findsNothing);
  });
  testWidgets(
    'compact dark large text and received system mode do not overflow',
    (tester) async {
      _size(tester, const Size(320, 568));
      await tester.pumpWidget(
        _host(
          _page(theme: ThemeMode.system, cloud: true, pending: 2),
          dark: true,
          scale: 1.5,
        ),
      );
      await tester.pump();
      expect(find.text('Sistema'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Rever Onboarding'), 250);
      expect(tester.takeException(), isNull);
    },
  );
}

AppOptionsPage _page({
  ThemeMode theme = ThemeMode.light,
  ValueChanged<ThemeMode>? onTheme,
  ValueChanged<bool>? onAuto,
  Future<void> Function()? onSignOut,
  VoidCallback? onReplay,
  bool cloud = false,
  bool online = true,
  bool syncing = false,
  int pending = 0,
  DateTime? lastSync,
}) => AppOptionsPage(
  themeMode: theme,
  onThemeModeChanged: onTheme ?? (_) {},
  autoImportOwnedSharedCatalogs: true,
  onAutoImportOwnedSharedCatalogsChanged: onAuto ?? (_) {},
  onSignOut: onSignOut ?? () async {},
  onReplayOnboarding: onReplay ?? () {},
  userDisplayName: 'Ana Silva',
  userEmail: 'ana@example.com',
  showCloudSyncStatus: cloud,
  hasInternetConnection: online,
  isCloudSyncing: syncing,
  hasPendingCloudSync: pending > 0,
  lastCloudSyncAt: lastSync,
  totalSyncRecords: 12,
  pendingSyncRecords: pending,
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
