enum SyncPhase {
  idle,
  pending,
  synchronizing,
  waitingForRetry,
  offline,
  failed,
}

final class SyncState {
  const SyncState._({
    required this.phase,
    required this.pendingOperations,
    this.currentOperationId,
    this.nextAttemptAt,
    this.lastError,
  });

  const SyncState.idle() : this._(phase: SyncPhase.idle, pendingOperations: 0);

  const SyncState.pending({required int pendingOperations})
    : this._(phase: SyncPhase.pending, pendingOperations: pendingOperations);

  const SyncState.synchronizing({
    required int pendingOperations,
    required String currentOperationId,
  }) : this._(
         phase: SyncPhase.synchronizing,
         pendingOperations: pendingOperations,
         currentOperationId: currentOperationId,
       );

  const SyncState.waitingForRetry({
    required int pendingOperations,
    required DateTime nextAttemptAt,
  }) : this._(
         phase: SyncPhase.waitingForRetry,
         pendingOperations: pendingOperations,
         nextAttemptAt: nextAttemptAt,
       );

  const SyncState.offline({required int pendingOperations})
    : this._(phase: SyncPhase.offline, pendingOperations: pendingOperations);

  const SyncState.failed({
    required int pendingOperations,
    required String lastError,
    String? currentOperationId,
  }) : this._(
         phase: SyncPhase.failed,
         pendingOperations: pendingOperations,
         currentOperationId: currentOperationId,
         lastError: lastError,
       );

  final SyncPhase phase;
  final int pendingOperations;
  final String? currentOperationId;
  final DateTime? nextAttemptAt;
  final String? lastError;
}
