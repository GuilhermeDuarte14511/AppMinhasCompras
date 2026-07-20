class SharedListsRefreshResult {
  const SharedListsRefreshResult({
    required this.revision,
    required this.refreshedAuthentication,
  });

  final int revision;
  final bool refreshedAuthentication;
}

class SharedListsRefreshCoordinator {
  Future<SharedListsRefreshResult>? _activeRefresh;
  int _revision = 0;

  bool get isRefreshing => _activeRefresh != null;
  int get revision => _revision;

  Future<SharedListsRefreshResult> retry({
    required bool refreshAuthentication,
    required Future<void> Function() refreshToken,
  }) {
    final active = _activeRefresh;
    if (active != null) {
      return active;
    }

    final operation = _performRetry(
      refreshAuthentication: refreshAuthentication,
      refreshToken: refreshToken,
    );
    _activeRefresh = operation;
    operation.then<void>(
      (_) => _clearIfActive(operation),
      onError: (Object _, StackTrace _) => _clearIfActive(operation),
    );
    return operation;
  }

  void _clearIfActive(Future<SharedListsRefreshResult> operation) {
    if (identical(_activeRefresh, operation)) {
      _activeRefresh = null;
    }
  }

  Future<SharedListsRefreshResult> _performRetry({
    required bool refreshAuthentication,
    required Future<void> Function() refreshToken,
  }) async {
    if (refreshAuthentication) {
      await refreshToken();
    }
    _revision++;
    return SharedListsRefreshResult(
      revision: _revision,
      refreshedAuthentication: refreshAuthentication,
    );
  }
}

class SharedListsStreamCache<T> {
  Stream<T>? _stream;
  Object? _sourceIdentity;
  String? _userId;
  int? _revision;

  Stream<T> resolve({
    required Object sourceIdentity,
    required String userId,
    required int revision,
    required Stream<T> Function() create,
  }) {
    final cached = _stream;
    if (cached != null &&
        identical(_sourceIdentity, sourceIdentity) &&
        _userId == userId &&
        _revision == revision) {
      return cached;
    }
    final created = create();
    _stream = created;
    _sourceIdentity = sourceIdentity;
    _userId = userId;
    _revision = revision;
    return created;
  }

  void clear() {
    _stream = null;
    _sourceIdentity = null;
    _userId = null;
    _revision = null;
  }
}
