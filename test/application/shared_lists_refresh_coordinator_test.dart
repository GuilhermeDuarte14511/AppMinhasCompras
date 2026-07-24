import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/shared_lists_refresh_coordinator.dart';

void main() {
  test('ordinary retry resubscribes without forcing token refresh', () async {
    final coordinator = SharedListsRefreshCoordinator();
    var refreshCalls = 0;

    final result = await coordinator.retry(
      refreshAuthentication: false,
      refreshToken: () async {
        refreshCalls++;
      },
    );

    expect(refreshCalls, 0);
    expect(result.refreshedAuthentication, isFalse);
    expect(result.revision, 1);
    expect(coordinator.isRefreshing, isFalse);
  });

  test(
    'authentication retry refreshes token once before resubscribing',
    () async {
      final coordinator = SharedListsRefreshCoordinator();
      var refreshCalls = 0;

      final result = await coordinator.retry(
        refreshAuthentication: true,
        refreshToken: () async {
          refreshCalls++;
        },
      );

      expect(refreshCalls, 1);
      expect(result.refreshedAuthentication, isTrue);
      expect(coordinator.revision, 1);
    },
  );

  test('concurrent retries share the same token refresh operation', () async {
    final coordinator = SharedListsRefreshCoordinator();
    final refreshCompleter = Completer<void>();
    var refreshCalls = 0;

    Future<void> refreshToken() {
      refreshCalls++;
      return refreshCompleter.future;
    }

    final first = coordinator.retry(
      refreshAuthentication: true,
      refreshToken: refreshToken,
    );
    final second = coordinator.retry(
      refreshAuthentication: true,
      refreshToken: refreshToken,
    );
    expect(coordinator.isRefreshing, isTrue);
    expect(refreshCalls, 1);

    refreshCompleter.complete();
    final results = await Future.wait([first, second]);

    expect(results[0].revision, 1);
    expect(results[1].revision, 1);
    expect(coordinator.revision, 1);
    expect(coordinator.isRefreshing, isFalse);
  });

  test('failed token refresh does not advance stream revision', () async {
    final coordinator = SharedListsRefreshCoordinator();

    await expectLater(
      coordinator.retry(
        refreshAuthentication: true,
        refreshToken: () async => throw StateError('offline'),
      ),
      throwsStateError,
    );

    expect(coordinator.revision, 0);
    expect(coordinator.isRefreshing, isFalse);
  });

  test('stream cache reuses subscription across repeated rebuilds', () {
    final cache = SharedListsStreamCache<int>();
    final source = Object();
    var createCalls = 0;

    Stream<int> create() {
      createCalls++;
      return Stream<int>.fromIterable(const <int>[]);
    }

    final first = cache.resolve(
      sourceIdentity: source,
      userId: 'user-1',
      revision: 0,
      create: create,
    );
    final second = cache.resolve(
      sourceIdentity: source,
      userId: 'user-1',
      revision: 0,
      create: create,
    );

    expect(identical(first, second), isTrue);
    expect(createCalls, 1);
  });

  test(
    'stream cache creates a new subscription only for explicit revision',
    () {
      final cache = SharedListsStreamCache<int>();
      final source = Object();
      var createCalls = 0;

      Stream<int> create() {
        createCalls++;
        return Stream<int>.fromIterable(const <int>[]);
      }

      final first = cache.resolve(
        sourceIdentity: source,
        userId: 'user-1',
        revision: 0,
        create: create,
      );
      final refreshed = cache.resolve(
        sourceIdentity: source,
        userId: 'user-1',
        revision: 1,
        create: create,
      );

      expect(identical(first, refreshed), isFalse);
      expect(createCalls, 2);
    },
  );
}
