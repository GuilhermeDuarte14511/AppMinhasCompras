import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/reminder_editor_dialog.dart';

final _now = DateTime(2026, 10, 10, 12);
final _future = DateTime(2026, 10, 11, 9, 30);

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

  testWidgets('editorial reference retains actual date and time', (
    tester,
  ) async {
    await _open(tester, initial: _future);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/reminder_stitch_390.png'),
    );
    expect(find.text(formatShortDate(_future)), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    for (final label in ['Salvar lembrete', 'Cancelar', 'Remover lembrete']) {
      final control = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('save preserves local scheduled date and default is disabled', (
    tester,
  ) async {
    ReminderEditorResult? result;
    await _open(tester, initial: _future, onResult: (value) => result = value);
    await tester.tap(find.text('Salvar lembrete'));
    await tester.pumpAndSettle();
    expect(result?.value?.scheduledAt, _future);
    expect(result?.clear, isFalse);
    await _open(tester, onResult: (value) => result = value);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Remover lembrete'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar lembrete'));
    await tester.pumpAndSettle();
    expect(result?.value?.scheduledAt, _now.add(const Duration(hours: 1)));
  });

  testWidgets('disable and remove clear while close and cancel dismiss', (
    tester,
  ) async {
    ReminderEditorResult? result;
    for (final action in ['disable', 'remove', 'close', 'cancel']) {
      var called = false;
      await _open(
        tester,
        initial: _future,
        onResult: (value) {
          called = true;
          result = value;
        },
      );
      if (action == 'disable') {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, formatShortDate(_future)),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Salvar lembrete'));
      } else {
        await tester.tap(
          action == 'remove'
              ? find.text('Remover lembrete')
              : action == 'close'
              ? find.byTooltip('Fechar')
              : find.text('Cancelar'),
        );
      }
      await tester.pumpAndSettle();
      expect(called, isTrue);
      if (action == 'disable' || action == 'remove') {
        expect(result?.clear, isTrue);
        expect(result?.value, isNull);
      } else {
        expect(result, isNull);
      }
    }
  });

  testWidgets(
    'past reminder opens bounded calendar without altering on cancel',
    (tester) async {
      final past = DateTime(2025, 3, 1, 9, 30);
      await _open(tester, initial: past);
      await tester.tap(find.text('Salvar lembrete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escolha uma data e horário no futuro.'),
        findsOneWidget,
      );
      await tester.tap(find.text(formatShortDate(past)));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.initialDate, DateTime(2026, 10, 10));
      expect(picker.firstDate, DateTime(2026, 10, 10));
      expect(picker.lastDate, DateTime(2041));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(find.text(formatShortDate(past)), findsOneWidget);
    },
  );

  testWidgets('date and time changes return selected schedule', (tester) async {
    ReminderEditorResult? result;
    await _open(tester, initial: _future, onResult: (value) => result = value);
    await tester.tap(find.text(formatShortDate(_future)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(formatShortDate(DateTime(2026, 10, 12))), findsOneWidget);
    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();
    final inputModeTooltip = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    ).inputTimeModeButtonLabel;
    await tester.tap(find.byTooltip(inputModeTooltip));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), '10');
    await tester.enterText(inputs.at(1), '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar lembrete'));
    await tester.pumpAndSettle();
    expect(result?.value?.scheduledAt, DateTime(2026, 10, 12, 10, 45));
  });

  testWidgets('compact dark enlarged keyboard leaves footer accessible', (
    tester,
  ) async {
    await _open(
      tester,
      initial: _now.subtract(const Duration(days: 1)),
      compact: true,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 150);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar lembrete'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Salvar lembrete', 'Cancelar', 'Remover lembrete']) {
      final finder = find.text(label);
      expect(tester.getBottomRight(finder).dy, lessThanOrEqualTo(418));
      expect(tester.getTopLeft(finder).dy, greaterThan(0));
    }
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Escolha uma data e horário no futuro.').hitTestable(),
      findsOneWidget,
    );
  });
}

Future<void> _open(
  WidgetTester tester, {
  DateTime? initial,
  bool compact = false,
  ValueChanged<ReminderEditorResult?>? onResult,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(compact ? 1.5 : 1),
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await showReminderEditorDialog(
                  context,
                  initialValue: initial == null
                      ? null
                      : ShoppingReminderConfig(scheduledAt: initial),
                  nowProvider: () => _now,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
