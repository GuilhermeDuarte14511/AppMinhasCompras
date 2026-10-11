import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/market_shopping_session.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/local/storages.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recupera preço, quantidade e item pego do armazenamento ao reabrir',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPrefsShoppingListsStorage();
      await storage.saveLists([_list()]);
      final store = _store(storage);
      await store.load();
      final session = MarketShoppingSession(
        initialList: store.findById('weekly')!,
        onSave: store.upsertList,
      );
      session.updateItem(
        session.list.items.single.copyWith(
          quantity: 3,
          unitPrice: 25.90,
          isPurchased: true,
        ),
      );
      expect(await session.flush(), isTrue);
      session.dispose();
      store.dispose();
      final reopened = _store(SharedPrefsShoppingListsStorage());
      await reopened.load();
      final restored = reopened.findById('weekly')!;
      expect(restored.items.single.quantity, 3);
      expect(restored.items.single.unitPrice, 25.90);
      expect(restored.items.single.isPurchased, isTrue);
      expect(restored.isClosed, isFalse);
      expect(reopened.purchaseHistory, isEmpty);
      reopened.dispose();
    },
  );

  test('grava alterações em ordem antes de sair da compra', () async {
    final firstSave = Completer<void>();
    final saved = <ShoppingListModel>[];
    final session = MarketShoppingSession(
      initialList: _list(),
      onSave: (list) async {
        if (saved.isEmpty) await firstSave.future;
        saved.add(list);
      },
    );
    session.updateItem(session.list.items.single.copyWith(quantity: 2));
    session.updateItem(session.list.items.single.copyWith(unitPrice: 25.90));
    expect(session.isSaving, isTrue);
    firstSave.complete();
    expect(await session.flush(), isTrue);
    expect(saved.map((list) => list.items.single.quantity), [2, 2]);
    expect(saved.last.items.single.unitPrice, 25.90);
    expect(session.hasUnsavedChanges, isFalse);
    session.dispose();
  });

  test(
    'falha preserva rascunho e nova tentativa grava a última alteração',
    () async {
      var fail = true;
      ShoppingListModel? saved;
      final session = MarketShoppingSession(
        initialList: _list(),
        onSave: (list) async {
          if (fail) throw StateError('storage unavailable');
          saved = list;
        },
      );
      session.updateItem(session.list.items.single.copyWith(isPurchased: true));
      expect(await session.flush(), isFalse);
      expect(session.saveError, isNotNull);
      expect(session.list.items.single.isPurchased, isTrue);
      fail = false;
      session.retrySave();
      expect(await session.flush(), isTrue);
      expect(saved!.items.single.isPurchased, isTrue);
      expect(session.saveError, isNull);
      session.dispose();
    },
  );

  test('gravação já iniciada termina mesmo se a tela for descartada', () async {
    final gate = Completer<void>();
    ShoppingListModel? saved;
    final session = MarketShoppingSession(
      initialList: _list(),
      onSave: (list) async {
        await gate.future;
        saved = list;
      },
    );
    session.updateItem(session.list.items.single.copyWith(quantity: 3));
    session.dispose();
    gate.complete();
    expect(await session.flush(), isTrue);
    expect(saved!.items.single.quantity, 3);
  });
}

ShoppingListModel _list() => ShoppingListModel(
  id: 'weekly',
  name: 'Compra semanal',
  createdAt: DateTime(2026, 9, 10),
  updatedAt: DateTime(2026, 9, 10),
  items: const [
    ShoppingItem(
      id: 'rice',
      name: 'Arroz',
      quantity: 1,
      unitPrice: 20,
      isPurchased: false,
    ),
  ],
);

ShoppingListsStore _store(ShoppingListsStorage storage) => ShoppingListsStore(
  storage,
  reminderService: const NoopShoppingReminderService(),
  productCatalog: ProductCatalogRepository(InMemoryProductCatalogStorage()),
  historyStorage: InMemoryPurchaseHistoryStorage(),
  lookupService: _Lookup(),
  homeWidgetService: const NoopShoppingHomeWidgetService(),
);

class _Lookup implements ProductLookupService {
  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async => null;
}
