import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/payment_source_picker_sheet.dart';
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

  for (final kind in FinancePaymentSourceKind.values) {
    testWidgets('creates ${kind.wireValue} with exact real payload', (
      tester,
    ) async {
      final repo = _Repository();
      FinancePaymentSource? result;
      await _open(tester, repo, onResult: (value) => result = value);
      await tester.tap(
        find.byKey(ValueKey('payment_source_kind_${kind.wireValue}')),
      );
      await tester.pumpAndSettle();
      await _fill(
        tester,
        name: '  Meu ${kind.label}  ',
        credit: kind == FinancePaymentSourceKind.credit,
      );
      await _tap(tester, find.text('Criar e usar'));
      final request = repo.requests.single;
      expect(request.name, 'Meu ${kind.label}');
      expect(request.kind, kind);
      expect(request.availableCents, 500001);
      expect(
        request.lastDigits,
        kind == FinancePaymentSourceKind.credit ? '4092' : null,
      );
      expect(
        request.closingDay,
        kind == FinancePaymentSourceKind.credit ? 5 : null,
      );
      expect(
        request.dueDay,
        kind == FinancePaymentSourceKind.credit ? 10 : null,
      );
      expect(request.externalRequestId, isNotEmpty);
      expect(result!.id, 'created-id');
      expect(result!.kind, kind);
      expect(find.text('Novo meio de pagamento'), findsNothing);
    });
  }

  testWidgets('required fields and unsafe cents never invoke repository', (
    tester,
  ) async {
    final repo = _Repository();
    await _open(tester, repo);
    await _tap(tester, find.text('Criar e usar'));
    expect(find.text('Informe um nome.'), findsOneWidget);
    expect(find.text('Informe os quatro dígitos.'), findsOneWidget);
    expect(find.text('Informe um valor válido.'), findsOneWidget);
    await _fill(tester);
    await tester.enterText(
      find.byKey(const Key('payment_source_amount_field')),
      '9' * 320,
    );
    await _tap(tester, find.text('Criar e usar'));
    expect(find.text('Informe um valor válido.'), findsOneWidget);
    expect(repo.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'waiting disables mutation, dismissal and duplicate submissions',
    (tester) async {
      final pending = Completer<FinancePaymentSource>();
      final repo = _Repository()..submit = (_) => pending.future;
      FinancePaymentSource? result;
      await _open(tester, repo, onResult: (value) => result = value);
      await _fill(tester);
      await tester.ensureVisible(find.text('Criar e usar'));
      await tester.tap(find.text('Criar e usar'));
      await tester.pump();
      expect(repo.requests, hasLength(1));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('payment_source_name_field')),
            )
            .enabled,
        false,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('payment_source_amount_field')),
            )
            .enabled,
        false,
      );
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Fechar'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Criando...'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Criando...'), findsOneWidget);
      pending.complete(_source(repo.requests.single));
      await tester.pumpAndSettle();
      expect(result!.id, 'created-id');
      expect(repo.requests, hasLength(1));
    },
  );

  testWidgets(
    'retry keeps identity for same payload and regenerates after edits',
    (tester) async {
      final repo = _Repository()
        ..submit = (_) async => throw Exception('network');
      await _open(tester, repo);
      await _fill(tester);
      await _tap(tester, find.text('Criar e usar'));
      expect(
        find.text('Não foi possível criar no Minhas Finanças.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Criar e usar'));
      expect(
        repo.requests[1].externalRequestId,
        repo.requests[0].externalRequestId,
      );
      await tester.ensureVisible(
        find.byKey(const Key('payment_source_name_field')),
      );
      await tester.enterText(
        find.byKey(const Key('payment_source_name_field')),
        'Outro cartão',
      );
      await _tap(tester, find.text('Criar e usar'));
      expect(
        repo.requests[2].externalRequestId,
        isNot(repo.requests[1].externalRequestId),
      );
      expect(repo.requests[2].name, 'Outro cartão');
      expect(repo.requests[2].lastDigits, '4092');
      expect(repo.requests[2].availableCents, 500001);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('close, cancel, back and barrier cancel without creating', (
    tester,
  ) async {
    final repo = _Repository();
    for (final mode in ['close', 'cancel', 'back', 'barrier']) {
      var completed = false;
      FinancePaymentSource? result;
      await _open(
        tester,
        repo,
        onResult: (value) {
          completed = true;
          result = value;
        },
      );
      if (mode == 'close') await tester.tap(find.byTooltip('Fechar'));
      if (mode == 'cancel') await _tap(tester, find.text('Cancelar'));
      if (mode == 'back') await tester.binding.handlePopRoute();
      if (mode == 'barrier') await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(result, isNull);
    }
    expect(repo.requests, isEmpty);
  });

  testWidgets('Stitch light form shows real editable values', (tester) async {
    _size(tester, const Size(390, 844));
    await _open(tester, _Repository());
    await _fill(tester, name: 'Nubank Ultravioleta');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('create_payment_source_scroll')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/create_payment_source_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact dark keyboard form scrolls all controls with enlarged type',
    (tester) async {
      _size(tester, const Size(320, 700));
      await _open(tester, _Repository(), dark: true, scale: 1.3, inset: 220);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/create_payment_source_dark_keyboard_320.png',
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('payment_source_amount_field')),
      );
      await tester.enterText(
        find.byKey(const Key('payment_source_amount_field')),
        '12345',
      );
      await _tap(tester, find.text('Criar e usar'));
      expect(find.text('Informe um nome.'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect(find.text('Novo meio de pagamento'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(
  WidgetTester tester,
  _Repository repo, {
  bool dark = false,
  double scale = 1,
  double inset = 0,
  ValueChanged<FinancePaymentSource?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: inset),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final value = await showCreatePaymentSourceSheet(
                context,
                repository: repo,
              );
              onResult?.call(value);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Cartão real',
  bool credit = true,
}) async {
  for (final field in {
    'payment_source_name_field': name,
    'payment_source_digits_field': credit ? '4092' : '',
    'payment_source_amount_field': '500001',
  }.entries) {
    await tester.ensureVisible(find.byKey(Key(field.key)));
    await tester.enterText(find.byKey(Key(field.key)), field.value);
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

FinancePaymentSource _source(FinancePaymentSourceRequest request) =>
    FinancePaymentSource(
      id: 'created-id',
      kind: request.kind,
      name: request.name,
      availableCents: request.availableCents,
      colorHex: request.colorHex,
      lastDigits: request.lastDigits,
      closingDay: request.closingDay,
      dueDay: request.dueDay,
    );

class _Repository implements FinanceIntegrationRepository {
  final requests = <FinancePaymentSourceRequest>[];
  Future<FinancePaymentSource> Function(FinancePaymentSourceRequest)? submit;
  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) async {
    requests.add(request);
    return submit == null ? _source(request) : submit!(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
