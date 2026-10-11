import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/data/remote/http_finance_integration_repository.dart';

void main() {
  const baseUri = 'https://finance.example.test';

  test('preserves the deployed Cloud Function path in API requests', () async {
    final store = _MemoryFinanceIntegrationStore();
    final repository = HttpFinanceIntegrationRepository(
      baseUri: Uri.parse('$baseUri/shoppingIntegrationApi'),
      store: store,
      client: MockClient((request) async {
        expect(request.url.path, '/shoppingIntegrationApi/v1/link/exchange');
        return http.Response(
          jsonEncode({
            'token': 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12',
            'integration': {
              'id': 'integration-id',
              'householdId': 'household-id',
              'householdName': 'Casa',
              'ownerName': 'Gui',
              'permissions': const <String>[],
            },
          }),
          200,
        );
      }),
    );

    await repository.connect('ABCD-EFGH-IJKL');
  });

  test('exchanges the link code and stores only the returned token', () async {
    final store = _MemoryFinanceIntegrationStore();
    final repository = HttpFinanceIntegrationRepository(
      baseUri: Uri.parse(baseUri),
      store: store,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/link/exchange');
        expect(jsonDecode(request.body), {'code': 'ABCD-EFGH-IJKL'});
        return http.Response(
          jsonEncode({
            'token': 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12',
            'integration': {
              'id': 'integration-id',
              'householdId': 'household-id',
              'householdName': 'Casa',
              'ownerName': 'Gui',
              'permissions': ['cards:read', 'purchases:write'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final connection = await repository.connect('ABCD-EFGH-IJKL');

    expect(connection.householdName, 'Casa');
    expect(store.token, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12');
  });

  test(
    'loads payment sources and limits using the bearer credential',
    () async {
      final store = _MemoryFinanceIntegrationStore()
        ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12';
      final repository = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse(baseUri),
        store: store,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/payment-sources');
          expect(
            request.headers['authorization'],
            'Bearer abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12',
          );
          return http.Response(
            jsonEncode({
              'household': {'id': 'household-id', 'name': 'Casa'},
              'cards': [
                {
                  'id': 'card-id',
                  'name': 'Nubank',
                  'holderName': 'Gui',
                  'lastDigits': '1234',
                  'closingDay': 20,
                  'dueDay': 27,
                  'limitCents': 500000,
                  'usedCents': 125050,
                  'availableCents': 374950,
                  'colorHex': '#7B2CBF',
                  'currentInvoice': {
                    'id': 'invoice-id',
                    'totalCents': 125050,
                    'dueOn': '2026-09-27',
                  },
                },
              ],
              'paymentSources': [
                {
                  'id': 'card-id',
                  'kind': 'credit',
                  'name': 'Nubank',
                  'lastDigits': '1234',
                  'closingDay': 20,
                  'dueDay': 27,
                  'limitCents': 500000,
                  'usedCents': 125050,
                  'availableCents': 374950,
                  'colorHex': '#7B2CBF',
                },
                {
                  'id': 'vr-id',
                  'kind': 'mealVoucher',
                  'name': 'VR Alelo',
                  'lastDigits': '7788',
                  'availableCents': 85000,
                  'colorHex': '#0D7B9A',
                },
              ],
              'categories': [
                {
                  'id': 'category-id',
                  'name': 'Mercado',
                  'iconKey': 'shopping_cart',
                  'colorHex': '#00897B',
                },
              ],
              'asOf': '2026-09-01',
            }),
            200,
          );
        }),
      );

      final workspace = await repository.loadWorkspace();

      expect(workspace.householdName, 'Casa');
      expect(workspace.cards.single.availableCents, 374950);
      expect(workspace.cards.single.currentInvoice?.totalCents, 125050);
      expect(workspace.paymentSources, hasLength(2));
      expect(
        workspace.paymentSources.last.kind,
        FinancePaymentSourceKind.mealVoucher,
      );
      expect(workspace.categories.single.name, 'Mercado');
    },
  );

  test('creates a payment source in Minhas Finanças', () async {
    final store = _MemoryFinanceIntegrationStore()
      ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12';
    final repository = HttpFinanceIntegrationRepository(
      baseUri: Uri.parse(baseUri),
      store: store,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/payment-sources');
        expect(request.headers['authorization'], startsWith('Bearer '));
        expect(jsonDecode(request.body), {
          'externalRequestId': 'source-request-123',
          'kind': 'foodVoucher',
          'name': 'VA Flash',
          'availableCents': 70000,
          'lastDigits': '4455',
          'closingDay': null,
          'dueDay': null,
          'colorHex': '#0D7B9A',
        });
        return http.Response(
          jsonEncode({
            'created': true,
            'paymentSource': {
              'id': 'va-id',
              'kind': 'foodVoucher',
              'name': 'VA Flash',
              'lastDigits': '4455',
              'availableCents': 70000,
              'colorHex': '#0D7B9A',
            },
          }),
          201,
        );
      }),
    );

    final source = await repository.createPaymentSource(
      const FinancePaymentSourceRequest(
        externalRequestId: 'source-request-123',
        kind: FinancePaymentSourceKind.foodVoucher,
        name: 'VA Flash',
        availableCents: 70000,
        lastDigits: '4455',
      ),
    );

    expect(source.id, 'va-id');
    expect(source.kind, FinancePaymentSourceKind.foodVoucher);
    expect(source.availableCents, 70000);
  });

  test('submits a voucher purchase using the generic payment source', () async {
    final store = _MemoryFinanceIntegrationStore()
      ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12';
    final repository = HttpFinanceIntegrationRepository(
      baseUri: Uri.parse(baseUri),
      store: store,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/v1/purchases');
        expect(body['paymentSourceId'], 'vr-id');
        expect(body['paymentSourceKind'], 'mealVoucher');
        return http.Response(
          jsonEncode({
            'created': true,
            'financialEntryId': 'entry-id',
            'accountMovementId': 'movement-id',
          }),
          201,
        );
      }),
    );

    final submission = await repository.submitPurchase(
      FinancePurchaseRequest(
        externalPurchaseId: 'purchase-vr-123',
        cardId: 'vr-id',
        paymentSourceKind: FinancePaymentSourceKind.mealVoucher,
        description: 'Almoço',
        amountCents: 4590,
        purchasedOn: DateTime(2026, 9, 3),
      ),
    );

    expect(submission.queued, isFalse);
    expect(submission.accountMovementId, 'movement-id');
    expect(submission.cardChargeId, isNull);
  });

  test(
    'queues a purchase when the finance service is temporarily offline',
    () async {
      final store = _MemoryFinanceIntegrationStore()
        ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12';
      final repository = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse(baseUri),
        store: store,
        client: MockClient(
          (request) async => throw http.ClientException('offline'),
        ),
      );
      final purchase = FinancePurchaseRequest(
        externalPurchaseId: 'purchase_123',
        cardId: 'card-id',
        categoryId: 'category-id',
        description: 'Compra no Mercado Central',
        amountCents: 25990,
        purchasedOn: DateTime(2026, 9, 1),
      );

      final submission = await repository.submitPurchase(purchase);

      expect(submission.queued, isTrue);
      expect(store.pendingPurchases, [purchase]);
    },
  );

  test(
    'retries queued purchases and removes only successful entries',
    () async {
      final purchase = FinancePurchaseRequest(
        externalPurchaseId: 'purchase_123',
        cardId: 'card-id',
        description: 'Compra da semana',
        amountCents: 10990,
        purchasedOn: DateTime(2026, 9, 1),
      );
      final store = _MemoryFinanceIntegrationStore()
        ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12'
        ..pendingPurchases = [purchase];
      final repository = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse(baseUri),
        store: store,
        client: MockClient((request) async {
          expect(
            jsonDecode(request.body)['externalPurchaseId'],
            'purchase_123',
          );
          return http.Response(
            jsonEncode({
              'created': true,
              'financialEntryId': 'entry-id',
              'cardChargeId': 'charge-id',
              'invoiceId': 'invoice-id',
            }),
            201,
          );
        }),
      );

      final synced = await repository.retryPendingPurchases();

      expect(synced, 1);
      expect(store.pendingPurchases, isEmpty);
    },
  );

  test(
    'queues a purchase when a gateway returns a malformed server error',
    () async {
      final store = _MemoryFinanceIntegrationStore()
        ..token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO12';
      final repository = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse(baseUri),
        store: store,
        client: MockClient(
          (request) async => http.Response('<html>bad gateway</html>', 503),
        ),
      );
      final purchase = FinancePurchaseRequest(
        externalPurchaseId: 'purchase_503',
        cardId: 'card-id',
        description: 'Compra da semana',
        amountCents: 15990,
        purchasedOn: DateTime(2026, 9, 1),
      );

      final submission = await repository.submitPurchase(purchase);

      expect(submission.queued, isTrue);
      expect(store.pendingPurchases, [purchase]);
    },
  );
}

class _MemoryFinanceIntegrationStore implements FinanceIntegrationStore {
  List<FinancePurchaseSync> records = [];
  @override
  Future<String> readConnectionId() async => 'test-connection';
  @override
  Future<List<FinancePurchaseSync>> readPurchaseSync() async =>
      List.of(records);
  @override
  Future<void> writePurchaseSync(List<FinancePurchaseSync> values) async {
    records = List.of(values);
  }

  String? token;
  List<FinancePurchaseRequest> pendingPurchases = [];

  @override
  Future<void> clear() async {
    token = null;
    pendingPurchases = [];
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<List<FinancePurchaseRequest>> readPendingPurchases() async =>
      List.of(pendingPurchases);

  @override
  Future<void> writePendingPurchases(
    List<FinancePurchaseRequest> purchases,
  ) async {
    pendingPurchases = List.of(purchases);
  }
}
