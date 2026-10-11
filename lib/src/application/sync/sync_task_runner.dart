/// Runs independent writes in bounded groups, waiting for all started writes
/// before reporting failure. A failed group must remain in the durable outbox.
Future<void> runSyncTasks(
  Iterable<Future<void> Function()> tasks, {
  int concurrency = 8,
  Duration timeout = const Duration(seconds: 45),
}) async {
  if (concurrency < 1) throw ArgumentError.value(concurrency, 'concurrency');
  final pending = tasks.toList();
  for (var start = 0; start < pending.length; start += concurrency) {
    await Future.wait([
      for (final task in pending.skip(start).take(concurrency))
        Future<void>.sync(task).timeout(timeout),
    ]);
  }
}
