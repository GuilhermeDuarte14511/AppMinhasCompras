import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_task_runner.dart';

void main() {
  test(
    'independent writes overlap with a bounded number of requests',
    () async {
      var active = 0;
      var peak = 0;
      var completed = 0;
      await runSyncTasks(
        List.generate(
          17,
          (_) => () async {
            active++;
            if (active > peak) peak = active;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            active--;
            completed++;
          },
        ),
        concurrency: 4,
      );
      expect(peak, 4);
      expect(active, 0);
      expect(completed, 17);
    },
  );
  test(
    'a stalled SDK write returns a retryable error instead of waiting forever',
    () async {
      await expectLater(
        runSyncTasks([
          () => Completer<void>().future,
        ], timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test(
    'a failure waits for started writes and does not start another group',
    () async {
      var completed = false;
      var laterStarted = false;
      await expectLater(
        runSyncTasks([
          () async => throw StateError('unavailable'),
          () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            completed = true;
          },
          () async {
            laterStarted = true;
          },
        ], concurrency: 2),
        throwsStateError,
      );
      expect(completed, isTrue);
      expect(laterStarted, isFalse);
    },
  );
}
