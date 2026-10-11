import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/application/finance_purchase_bridge.dart';
import 'package:lista_compras_material/src/data/remote/http_finance_integration_repository.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

final purchase = CompletedPurchase(
  id: 'purchase_split_1',
  listId: 'list',
  listName: 'Mercado',
  closedAt: DateTime(2026, 9, 7),
  items: const [
    ShoppingItem(
      id: 'a',
      name: 'Compra',
      quantity: 1,
      unitPrice: 120,
      isPurchased: true,
    ),
  ],
);
const allocations = [
  FinancePaymentAllocation(
    sourceId: 'va',
    sourceKind: 'foodVoucher',
    sourceName: 'Alelo',
    amountCents: 9600,
  ),
  FinancePaymentAllocation(
    sourceId: 'credit',
    sourceKind: 'credit',
    sourceName: 'Visa',
    amountCents: 2400,
  ),
];

void main() {
  test(
    'legacy queue is bound before reconnect and cannot leak into new household',
    () async {
      final store = MemorySyncStore()
        ..pending = [
          buildFinancePurchaseRequest(purchase: purchase, cardId: 'va'),
        ];
      var posts = 0;
      final repo = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse('https://example.test'),
        store: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/link/exchange') {
            return http.Response(
              jsonEncode({
                'token': 'new-token',
                'integration': {
                  'id': 'new',
                  'householdId': 'new-household',
                  'householdName': 'Outra casa',
                  'ownerName': 'Owner',
                  'permissions': ['purchases:write'],
                },
              }),
              200,
            );
          }
          posts++;
          return http.Response('{"financialEntryId":"unexpected"}', 201);
        }),
      );
      await repo.connect('CODE-EXAMPLE');
      await repo.retryPendingPurchases();
      expect(posts, 0);
      expect(store.records.single.status, FinanceSyncStatus.attention);
    },
  );

  test(
    'malformed successful receipt remains pending, never falsely confirmed',
    () async {
      final store = MemorySyncStore();
      final repo = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse('https://example.test'),
        store: store,
        client: MockClient((_) async => http.Response('{}', 201)),
      );
      await repo.submitPurchasePlan(
        buildFinancePurchasePlan(purchase: purchase, allocations: allocations),
      );
      expect(
        store.records.every((r) => r.status == FinanceSyncStatus.pending),
        isTrue,
      );
    },
  );

  test(
    'a recovered checkout intent keeps its binding after JSON round trip',
    () async {
      final snapshot = CompletedPurchase.fromJson({
        ...purchase.toJson(),
        'financeIntent': const FinanceCheckoutIntent(
          connectionId: 'original',
          allocations: allocations,
        ).toJson(),
      });
      final copy = snapshot.copyWith();
      final plan = buildFinancePurchasePlan(
        purchase: copy,
        allocations: copy.financeIntent!.allocations,
      );
      expect(plan.first.connectionId, 'original');
      final store = MemorySyncStore();
      var posts = 0;
      final repo = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse('https://example.test'),
        store: store,
        client: MockClient((_) async {
          posts++;
          return http.Response('{}', 201);
        }),
      );
      await expectLater(
        repo.submitPurchasePlan(plan),
        throwsA(isA<FinanceIntegrationException>()),
      );
      expect(posts, 0);
    },
  );

  test('concurrent attempts for same plan cannot double post', () async {
    final store = MemorySyncStore();
    var posts = 0;
    final repo = HttpFinanceIntegrationRepository(
      baseUri: Uri.parse('https://example.test'),
      store: store,
      client: MockClient((_) async {
        posts++;
        return http.Response('{"financialEntryId":"entry"}', 201);
      }),
    );
    final plan = buildFinancePurchasePlan(
      purchase: purchase,
      allocations: allocations,
    );
    await Future.wait([
      repo.submitPurchasePlan(plan),
      repo.submitPurchasePlan(plan),
    ]);
    expect(posts, 2);
  });

  test('split sums exact cents and keeps stable distinct request IDs', () {
    final plan = buildFinancePurchasePlan(
      purchase: purchase,
      allocations: allocations,
    );
    expect(plan.map((part) => part.request.amountCents), [9600, 2400]);
    expect(
      plan.map((part) => part.request.externalPurchaseId).toSet().length,
      2,
    );
    expect(plan.first.purchaseId, purchase.id);
    expect(
      buildFinancePurchasePlan(
        purchase: purchase,
        allocations: allocations,
      ).first.request.toJson(),
      plan.first.request.toJson(),
    );
    expect(
      () => buildFinancePurchasePlan(
        purchase: purchase,
        allocations: [allocations.first],
      ),
      throwsArgumentError,
    );
    expect(
      () => buildFinancePurchasePlan(
        purchase: purchase,
        allocations: [
          allocations.first,
          const FinancePaymentAllocation(
            sourceId: 'va',
            sourceKind: 'foodVoucher',
            sourceName: 'Alelo',
            amountCents: 2400,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test(
    'persists whole plan before sending; restart retries only pending part',
    () async {
      final store = MemorySyncStore();
      final calls = <String>[];
      var offlineCredit = true;
      final client = MockClient((request) async {
        expect(store.records.length, 2);
        final id = jsonDecode(request.body)['externalPurchaseId'] as String;
        calls.add(id);
        if (id.endsWith('_2') && offlineCredit) return http.Response('{}', 503);
        return http.Response(
          '{"created":true,"financialEntryId":"entry"}',
          201,
        );
      });
      HttpFinanceIntegrationRepository repository() =>
          HttpFinanceIntegrationRepository(
            baseUri: Uri.parse('https://example.test'),
            store: store,
            client: client,
          );
      final plan = buildFinancePurchasePlan(
        purchase: purchase,
        allocations: allocations,
      );
      await repository().submitPurchasePlan(plan);
      expect(store.records.map((r) => r.status), [
        FinanceSyncStatus.synced,
        FinanceSyncStatus.pending,
      ]);
      offlineCredit = false;
      await repository().retryPurchase(purchase.id);
      expect(calls, [
        plan[0].request.externalPurchaseId,
        plan[1].request.externalPurchaseId,
        plan[1].request.externalPurchaseId,
      ]);
      expect(
        store.records.every((r) => r.status == FinanceSyncStatus.synced),
        isTrue,
      );
      await repository().submitPurchasePlan(plan);
      expect(calls.length, 3);
    },
  );

  test(
    'does not replay old connection records into a new connection',
    () async {
      final store = MemorySyncStore();
      var posts = 0;
      final repo = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse('https://example.test'),
        store: store,
        client: MockClient((request) async {
          posts++;
          return http.Response('{}', 503);
        }),
      );
      await repo.submitPurchasePlan(
        buildFinancePurchasePlan(purchase: purchase, allocations: allocations),
      );
      final before = posts;
      store.connectionId = 'another-connection';
      await repo.retryPurchase(purchase.id);
      expect(posts, before);
      expect(
        store.records.every((r) => r.status == FinanceSyncStatus.attention),
        isTrue,
      );
    },
  );

  test(
    'rejects a changed split after an attempt, even if nothing confirmed',
    () async {
      final store = MemorySyncStore();
      final repo = HttpFinanceIntegrationRepository(
        baseUri: Uri.parse('https://example.test'),
        store: store,
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await repo.submitPurchasePlan(
        buildFinancePurchasePlan(purchase: purchase, allocations: allocations),
      );
      await expectLater(
        repo.submitPurchasePlan(
          buildFinancePurchasePlan(
            purchase: purchase,
            allocations: const [
              FinancePaymentAllocation(
                sourceId: 'va',
                sourceKind: 'foodVoucher',
                sourceName: 'Alelo',
                amountCents: 9500,
              ),
              FinancePaymentAllocation(
                sourceId: 'credit',
                sourceKind: 'credit',
                sourceName: 'Visa',
                amountCents: 2500,
              ),
            ],
          ),
        ),
        throwsA(isA<FinanceIntegrationException>()),
      );
    },
  );
}

class MemorySyncStore implements FinanceIntegrationStore {
  String? token = 'test-token';
  String connectionId = 'connection-1';
  List<FinancePurchaseRequest> pending = [];
  List<FinancePurchaseSync> records = [];
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> writeToken(String value) async {
    token = value;
    connectionId = 'new-connection';
  }

  @override
  Future<String> readConnectionId() async => connectionId;
  @override
  Future<List<FinancePurchaseRequest>> readPendingPurchases() async =>
      List.of(pending);
  @override
  Future<void> writePendingPurchases(
    List<FinancePurchaseRequest> values,
  ) async {
    pending = List.of(values);
  }

  @override
  Future<List<FinancePurchaseSync>> readPurchaseSync() async =>
      List.of(records);
  @override
  Future<void> writePurchaseSync(List<FinancePurchaseSync> values) async {
    records = List.of(values);
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
