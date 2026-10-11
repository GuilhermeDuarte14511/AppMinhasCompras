import 'package:cloud_firestore/cloud_firestore.dart';
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

  testWidgets('personal data mobile editorial reference', (tester) async {
    await _open(tester);
    await expectLater(
      find.byType(MyProfilePage),
      matchesGoldenFile('goldens/profile_stitch_390.png'),
    );
    expect(find.text('Ficha do titular'), findsOneWidget);
    expect(find.text('Escolher foto'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('profile_email')),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid name preserves validation before contacting Firebase', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('profile_name')), 'A');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um nome válido.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile_name')), 'A' * 81);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Nome muito longo (máximo 80).'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo removal clears actual URL and disabling state', (
    tester,
  ) async {
    await _open(tester, photo: '');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Remover'))
          .onPressed,
      isNull,
    );
    // A nonempty URL enables the existing removal action immediately. Clear it
    // before the network image request completes, so this test has no network.
    await tester.enterText(
      find.byKey(const Key('profile_photo_url')),
      'https://example.com/avatar.jpg',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Remover'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile_photo_url')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Remover'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dark large text and keyboard keep save reachable', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile_name')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile_name')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(find.text('Salvar alterações').hitTestable(), findsOneWidget);
    expect(
      tester
          .getRect(find.widgetWithText(FilledButton, 'Salvar alterações'))
          .bottom,
      lessThanOrEqualTo(568 - 220),
    );
    await tester.enterText(find.byKey(const Key('profile_name')), '');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um nome válido.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email remains read only and back preserves navigation', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MyProfilePage), findsNothing);
    expect(find.text('Abrir perfil'), findsOneWidget);
  });
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 884),
  bool dark = false,
  double scale = 1,
  String? photo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyProfilePage(
                  initialDisplayName: 'Helena Ramos',
                  initialEmail: 'helena.ramos@exemplo.com.br',
                  initialPhotoUrl: photo,
                  firestoreInstance: _Firestore(),
                ),
              ),
            ),
            child: const Text('Abrir perfil'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir perfil'));
  await tester.pumpAndSettle();
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
