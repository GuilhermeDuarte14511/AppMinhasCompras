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
  testWidgets('online options shows real account and Stitch composition', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await tester.pumpWidget(_host(_page()));
    await tester.pumpAndSettle();
    expect(find.text('Ana Silva'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('Helena Ramos'), findsNothing);
    await expectLater(
      find.byType(AppOptionsPage),
      matchesGoldenFile('goldens/options_online_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'system theme is selectable and catalog still imports shared products',
    (tester) async {
      ThemeMode? selected;
      bool? catalog;
      await tester.pumpWidget(
        _host(
          _page(
            onTheme: (value) => selected = value,
            onCatalog: (value) => catalog = value,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Sistema'));
      await tester.tap(find.text('Sistema'));
      await tester.pump();
      expect(selected, ThemeMode.system);
      expect(find.text('Acompanha o tema do dispositivo'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(Switch), 300);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(catalog, false);
      expect(
        find.text(
          'Importar produtos adicionados às suas listas compartilhadas.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('globalmente'), findsNothing);
    },
  );
  testWidgets(
    'online sync uses supplied record counts and timestamp without finance badge',
    (tester) async {
      await tester.pumpWidget(_host(_page()));
      await tester.scrollUntilVisible(find.text('Tudo sincronizado'), 250);
      expect(find.text('10/10 10:30'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Minhas Finanças'), 250);
      expect(find.text('Conectado'), findsNothing);
      expect(find.text('Estável'), findsNothing);
      expect(find.textContaining('Há 2 minutos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('missing display name uses real email prefix', (tester) async {
    await tester.pumpWidget(_host(_page(name: '  ')));
    expect(find.text('ana'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Meus dados'), findsOneWidget);
  });
  testWidgets(
    'compact dark large text keeps controls accessible while scrolling',
    (tester) async {
      _size(tester, const Size(320, 568));
      await tester.pumpWidget(_host(_page(), dark: true, scale: 1.5));
      await tester.scrollUntilVisible(find.text('Sistema'), 200);
      for (final label in ['Claro', 'Escuro', 'Sistema']) {
        expect(
          tester.getSize(find.widgetWithText(TextButton, label)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.scrollUntilVisible(find.text('Minhas Finanças'), 250);
      await tester.scrollUntilVisible(find.text('Rever Onboarding'), 250);
      expect(tester.takeException(), isNull);
    },
  );
}

AppOptionsPage _page({
  String name = 'Ana Silva',
  ValueChanged<ThemeMode>? onTheme,
  ValueChanged<bool>? onCatalog,
}) => AppOptionsPage(
  themeMode: ThemeMode.light,
  onThemeModeChanged: onTheme ?? (_) {},
  autoImportOwnedSharedCatalogs: true,
  onAutoImportOwnedSharedCatalogsChanged: onCatalog ?? (_) {},
  userDisplayName: name,
  userEmail: 'ana@example.com',
  onSignOut: () async {},
  onReplayOnboarding: () {},
  showCloudSyncStatus: true,
  lastCloudSyncAt: DateTime(2026, 10, 10, 10, 30),
  totalSyncRecords: 12,
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
