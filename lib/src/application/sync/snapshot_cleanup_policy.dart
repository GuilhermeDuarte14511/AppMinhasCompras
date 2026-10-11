final class IncompleteRemoteSnapshotException implements Exception {
  const IncompleteRemoteSnapshotException();

  @override
  String toString() =>
      'The remote snapshot must be loaded before deletions are acknowledged.';
}

Set<String> planSnapshotDeletes({
  required Set<String> localIds,
  required Set<String>? remoteIds,
}) {
  if (remoteIds == null) {
    throw const IncompleteRemoteSnapshotException();
  }
  return remoteIds.difference(localIds);
}
