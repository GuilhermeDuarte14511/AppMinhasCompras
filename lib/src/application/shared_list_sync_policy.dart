enum SharedListMirrorAction { skip, pullSharedToLocal }

SharedListMirrorAction resolveOwnedSharedListMirrorAction({
  required bool hasSourceLocalListId,
  required bool hasLocalCopy,
  required DateTime? localUpdatedAt,
  required DateTime sharedUpdatedAt,
}) {
  if (!hasSourceLocalListId) {
    return SharedListMirrorAction.skip;
  }
  return SharedListMirrorAction.pullSharedToLocal;
}

SharedListMirrorAction resolveLinkedSharedSnapshotAction({
  required bool sourceMatchesLocalList,
  required bool isSyncingToShared,
  required DateTime localUpdatedAt,
  required DateTime sharedUpdatedAt,
}) {
  if (!sourceMatchesLocalList || isSyncingToShared) {
    return SharedListMirrorAction.skip;
  }
  if (localUpdatedAt.isAfter(sharedUpdatedAt)) {
    return SharedListMirrorAction.skip;
  }
  return SharedListMirrorAction.pullSharedToLocal;
}
