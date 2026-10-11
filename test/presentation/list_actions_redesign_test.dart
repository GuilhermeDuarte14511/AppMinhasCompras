import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/list_editor_actions_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';
import 'package:lista_compras_material/src/presentation/utils/app_modal.dart';

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

  testWidgets('actions menu over actual editor matches Stitch', (tester) async {
    _size(tester, const Size(390, 884));
    await _editor(tester, _MemoryStorage());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/list_actions_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('close cancels menu without saving or mutating list', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _editor(tester, storage);
    final before = storage.saves;
    await tester.tap(find.byTooltip('Fechar menu de ações'));
    await tester.pumpAndSettle();
    expect(find.byType(ListEditorActionsSheet), findsNothing);
    expect(storage.saves, before);
    expect(storage.list.name, 'Compras da semana');
    expect(storage.list.items.single.isPurchased, isTrue);
  });

  testWidgets('clear purchased keeps existing confirmation and cancellation', (
    tester,
  ) async {
    await _editor(tester, _MemoryStorage());
    await _scroll(tester, 'Limpar comprados');
    await tester.tap(find.text('Limpar comprados'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed menu only offers existing read actions and reopen', (
    tester,
  ) async {
    ListEditorMenuAction? result;
    await _sheet(tester, closed: true, onResult: (value) => result = value);
    expect(find.text('Fechar compra'), findsNothing);
    expect(find.text('Importar cupom fiscal'), findsNothing);
    expect(find.text('CONFIGURAÇÕES'), findsNothing);
    expect(find.text('Abrir catálogo de produtos'), findsOneWidget);
    expect(find.text('Histórico mensal'), findsOneWidget);
    await tester.tap(find.text('Reabrir'));
    await tester.pumpAndSettle();
    expect(result, ListEditorMenuAction.reopenList);
  });

  testWidgets('linked list keeps editable settings and existing sync actions', (
    tester,
  ) async {
    ListEditorMenuAction? result;
    await _sheet(tester, shared: true, onResult: (value) => result = value);
    await _scroll(tester, 'Abrir lista compartilhada');
    await tester.tap(find.text('Abrir lista compartilhada'));
    await tester.pumpAndSettle();
    expect(result, ListEditorMenuAction.openSharedList);
    await _sheet(tester, shared: true);
    await _scroll(tester, 'Renomear lista');
    expect(find.text('Renomear lista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordering and purchased availability follow actual state', (
    tester,
  ) async {
    ListEditorMenuAction? result;
    await _sheet(
      tester,
      purchased: false,
      ordered: true,
      onResult: (value) => result = value,
    );
    expect(find.text('Limpar comprados'), findsNothing);
    await _scroll(tester, 'Desativar ordem de mercado');
    await tester.tap(find.text('Desativar ordem de mercado'));
    await tester.pumpAndSettle();
    expect(result, ListEditorMenuAction.toggleMarketOrdering);
  });

  testWidgets('compact dark enlarged text keeps settings and close reachable', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _sheet(tester, shared: true, dark: true, scale: 1.5);
    expect(tester.takeException(), isNull);
    await _scroll(tester, 'Renomear lista');
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byTooltip('Fechar menu de ações')).height,
      greaterThanOrEqualTo(48),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/list_actions_dark_320.png'),
    );
    await tester.tap(find.byTooltip('Fechar menu de ações'));
    await tester.pumpAndSettle();
    expect(find.byType(ListEditorActionsSheet), findsNothing);
  });

  testWidgets('landscape enlarged text scrolls header without overflow', (
    tester,
  ) async {
    _size(tester, const Size(568, 320));
    await _sheet(tester, scale: 1.5, shared: true);
    expect(tester.takeException(), isNull);
    await _scroll(tester, 'Renomear lista');
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byTooltip('Fechar menu de ações'),
      -180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('list_actions_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar menu de ações'));
    await tester.pumpAndSettle();
    expect(find.byType(ListEditorActionsSheet), findsNothing);
  });

  testWidgets('quick actions return real purchase routes', (tester) async {
    for (final entry in {
      'Fechar compra': ListEditorMenuAction.finalizePurchase,
      'Importar cupom': ListEditorMenuAction.importFiscalReceipt,
      'Modo compra': ListEditorMenuAction.openMarketMode,
    }.entries) {
      ListEditorMenuAction? result;
      await _sheet(tester, onResult: (value) => result = value);
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();
      expect(result, entry.value);
    }
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scroll(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    160,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('list_actions_scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _sheet(
  WidgetTester tester, {
  bool closed = false,
  bool shared = false,
  bool purchased = true,
  bool ordered = false,
  bool dark = false,
  double scale = 1,
  ValueChanged<ListEditorMenuAction?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        dark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData(useMaterial3: true),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result =
                  await showAppModalBottomSheet<ListEditorMenuAction>(
                    context: context,
                    showDragHandle: true,
                    useSafeArea: true,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest,
                    builder: (_) => ListEditorActionsSheet(
                      isClosed: closed,
                      isSharedLocked: shared,
                      hasReminder: false,
                      hasPurchasedItems: purchased,
                      marketOrderingEnabled: ordered,
                    ),
                  );
              onResult?.call(result);
            },
            child: const Text('Abrir menu'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir menu'));
  await tester.pumpAndSettle();
}

Future<void> _editor(WidgetTester tester, _MemoryStorage storage) async {
  await tester.pumpWidget(ShoppingListApp(storage: storage));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('dash_action_lists')));
  await tester.tap(find.byKey(const ValueKey('dash_action_lists')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compras da semana'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Ações da lista'));
  await tester.pumpAndSettle();
}

class _MemoryStorage implements ShoppingListsStorage {
  ShoppingListModel list = ShoppingListModel(
    id: 'weekly',
    name: 'Compras da semana',
    createdAt: DateTime(2026, 10, 9),
    updatedAt: DateTime(2026, 10, 9),
    budget: 250,
    items: const [
      ShoppingItem(
        id: 'rice',
        name: 'Arroz integral 1kg',
        quantity: 2,
        unitPrice: 11.90,
        isPurchased: true,
      ),
    ],
  );
  int saves = 0;
  @override
  Future<List<ShoppingListModel>> loadLists() async => [list];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    saves++;
    list = lists.first;
  }
}
