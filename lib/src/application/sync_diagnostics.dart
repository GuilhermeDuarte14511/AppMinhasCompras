enum SyncDiagnosticStatus { synced, syncing, attention, offline, notConfigured }

class SharedListDiagnosticEntry {
  const SharedListDiagnosticEntry({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.isOwner,
    required this.memberCount,
    required this.itemCount,
    required this.isCatalogImportEnabled,
    required this.isMirroredLocally,
    required this.updatedAt,
    required this.lastError,
  });

  final String id;
  final String name;
  final String ownerUid;
  final bool isOwner;
  final int memberCount;
  final int itemCount;
  final bool isCatalogImportEnabled;
  final bool isMirroredLocally;
  final DateTime? updatedAt;
  final String? lastError;

  String get roleLabel => isOwner ? 'Dono' : 'Participante';
}

class SyncDiagnosticsSnapshot {
  const SyncDiagnosticsSnapshot({
    required this.generatedAt,
    required this.userName,
    required this.userEmail,
    required this.userUid,
    required this.providerId,
    required this.projectId,
    required this.platformLabel,
    required this.appVersion,
    required this.hasInternetConnection,
    required this.hasPendingCloudSync,
    required this.isCloudSyncing,
    required this.isPullingCloudSnapshot,
    required this.isMirroringSharedLists,
    required this.lastCloudSyncAt,
    required this.lastSharedSyncAt,
    required this.totalSyncRecords,
    required this.pendingSyncRecords,
    required this.listRecords,
    required this.historyRecords,
    required this.catalogRecords,
    required this.sharedListCount,
    required this.autoImportOwnedSharedCatalogs,
    required this.autoImportAllSharedCatalogs,
    required this.enabledSharedCatalogImportCount,
    required this.lastError,
    required this.sharedLists,
  });

  final DateTime generatedAt;
  final String? userName;
  final String? userEmail;
  final String? userUid;
  final String? providerId;
  final String? projectId;
  final String platformLabel;
  final String appVersion;
  final bool hasInternetConnection;
  final bool hasPendingCloudSync;
  final bool isCloudSyncing;
  final bool isPullingCloudSnapshot;
  final bool isMirroringSharedLists;
  final DateTime? lastCloudSyncAt;
  final DateTime? lastSharedSyncAt;
  final int totalSyncRecords;
  final int pendingSyncRecords;
  final int listRecords;
  final int historyRecords;
  final int catalogRecords;
  final int sharedListCount;
  final bool autoImportOwnedSharedCatalogs;
  final bool autoImportAllSharedCatalogs;
  final int enabledSharedCatalogImportCount;
  final String? lastError;
  final List<SharedListDiagnosticEntry> sharedLists;

  SyncDiagnosticsSnapshot copyWith({
    DateTime? generatedAt,
    String? userName,
    String? userEmail,
    String? userUid,
    String? providerId,
    String? projectId,
    String? platformLabel,
    String? appVersion,
    bool? hasInternetConnection,
    bool? hasPendingCloudSync,
    bool? isCloudSyncing,
    bool? isPullingCloudSnapshot,
    bool? isMirroringSharedLists,
    DateTime? lastCloudSyncAt,
    DateTime? lastSharedSyncAt,
    int? totalSyncRecords,
    int? pendingSyncRecords,
    int? listRecords,
    int? historyRecords,
    int? catalogRecords,
    int? sharedListCount,
    bool? autoImportOwnedSharedCatalogs,
    bool? autoImportAllSharedCatalogs,
    int? enabledSharedCatalogImportCount,
    String? lastError,
    List<SharedListDiagnosticEntry>? sharedLists,
  }) {
    return SyncDiagnosticsSnapshot(
      generatedAt: generatedAt ?? this.generatedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userUid: userUid ?? this.userUid,
      providerId: providerId ?? this.providerId,
      projectId: projectId ?? this.projectId,
      platformLabel: platformLabel ?? this.platformLabel,
      appVersion: appVersion ?? this.appVersion,
      hasInternetConnection:
          hasInternetConnection ?? this.hasInternetConnection,
      hasPendingCloudSync: hasPendingCloudSync ?? this.hasPendingCloudSync,
      isCloudSyncing: isCloudSyncing ?? this.isCloudSyncing,
      isPullingCloudSnapshot:
          isPullingCloudSnapshot ?? this.isPullingCloudSnapshot,
      isMirroringSharedLists:
          isMirroringSharedLists ?? this.isMirroringSharedLists,
      lastCloudSyncAt: lastCloudSyncAt ?? this.lastCloudSyncAt,
      lastSharedSyncAt: lastSharedSyncAt ?? this.lastSharedSyncAt,
      totalSyncRecords: totalSyncRecords ?? this.totalSyncRecords,
      pendingSyncRecords: pendingSyncRecords ?? this.pendingSyncRecords,
      listRecords: listRecords ?? this.listRecords,
      historyRecords: historyRecords ?? this.historyRecords,
      catalogRecords: catalogRecords ?? this.catalogRecords,
      sharedListCount: sharedListCount ?? this.sharedListCount,
      autoImportOwnedSharedCatalogs:
          autoImportOwnedSharedCatalogs ?? this.autoImportOwnedSharedCatalogs,
      autoImportAllSharedCatalogs:
          autoImportAllSharedCatalogs ?? this.autoImportAllSharedCatalogs,
      enabledSharedCatalogImportCount:
          enabledSharedCatalogImportCount ??
          this.enabledSharedCatalogImportCount,
      lastError: lastError ?? this.lastError,
      sharedLists: sharedLists ?? this.sharedLists,
    );
  }

  int get safeTotalRecords => totalSyncRecords < 0 ? 0 : totalSyncRecords;

  int get safePendingRecords {
    final pending = pendingSyncRecords < 0 ? 0 : pendingSyncRecords;
    if (safeTotalRecords == 0) {
      return pending;
    }
    return pending > safeTotalRecords ? safeTotalRecords : pending;
  }

  int get syncedRecords {
    final synced = safeTotalRecords - safePendingRecords;
    return synced < 0 ? 0 : synced;
  }

  bool get hasLoggedUser => (userUid ?? '').trim().isNotEmpty;

  SyncDiagnosticStatus get status {
    if (!hasLoggedUser) {
      return SyncDiagnosticStatus.notConfigured;
    }
    if (isCloudSyncing || isPullingCloudSnapshot || isMirroringSharedLists) {
      return SyncDiagnosticStatus.syncing;
    }
    if (!hasInternetConnection) {
      return SyncDiagnosticStatus.offline;
    }
    if (lastError != null || hasPendingCloudSync || safePendingRecords > 0) {
      return SyncDiagnosticStatus.attention;
    }
    return SyncDiagnosticStatus.synced;
  }

  String get statusTitle {
    switch (status) {
      case SyncDiagnosticStatus.synced:
        return 'Tudo sincronizado';
      case SyncDiagnosticStatus.syncing:
        return 'Sincronizando...';
      case SyncDiagnosticStatus.attention:
        return 'Atenção: há pendências';
      case SyncDiagnosticStatus.offline:
        return 'Modo offline';
      case SyncDiagnosticStatus.notConfigured:
        return 'Conta não conectada';
    }
  }

  String get statusDescription {
    switch (status) {
      case SyncDiagnosticStatus.synced:
        return 'Dados locais e online estão alinhados.';
      case SyncDiagnosticStatus.syncing:
        return 'O app está atualizando dados locais, nuvem ou listas compartilhadas.';
      case SyncDiagnosticStatus.attention:
        return 'Existem alterações pendentes ou um erro recente para revisar.';
      case SyncDiagnosticStatus.offline:
        return 'Sem internet. As alterações ficam salvas no aparelho.';
      case SyncDiagnosticStatus.notConfigured:
        return 'Entre na conta para usar sincronização em nuvem.';
    }
  }

  String buildSupportReport() {
    final buffer = StringBuffer()
      ..writeln('App: Minhas Compras')
      ..writeln('Versão: $appVersion')
      ..writeln('Gerado em: ${_formatDateTime(generatedAt)}')
      ..writeln('Status: $statusTitle')
      ..writeln('Plataforma: $platformLabel')
      ..writeln('Projeto Firebase: ${_fallback(projectId, 'indisponível')}')
      ..writeln('Usuário: ${_fallback(userName, 'sem nome')}')
      ..writeln('E-mail: ${_fallback(userEmail, 'sem e-mail')}')
      ..writeln('UID: ${_fallback(userUid, 'sem uid')}')
      ..writeln('Provider: ${_fallback(providerId, 'indisponível')}')
      ..writeln('Internet: ${hasInternetConnection ? 'online' : 'offline'}')
      ..writeln(
        'Último sync nuvem: ${_formatNullableDateTime(lastCloudSyncAt)}',
      )
      ..writeln(
        'Último sync compartilhadas: ${_formatNullableDateTime(lastSharedSyncAt)}',
      )
      ..writeln('Registros totais: $safeTotalRecords')
      ..writeln('Registros sincronizados: $syncedRecords')
      ..writeln('Registros pendentes: $safePendingRecords')
      ..writeln('Listas locais: $listRecords')
      ..writeln('Histórico: $historyRecords')
      ..writeln('Catálogo: $catalogRecords')
      ..writeln('Listas compartilhadas: $sharedListCount')
      ..writeln(
        'Auto importar catálogo do dono: ${_formatBool(autoImportOwnedSharedCatalogs)}',
      )
      ..writeln(
        'Auto importar listas compartilhadas: ${_formatBool(autoImportAllSharedCatalogs)}',
      )
      ..writeln(
        'Listas com importação habilitada: $enabledSharedCatalogImportCount',
      )
      ..writeln('Último erro: ${_fallback(lastError, 'nenhum')}');

    if (sharedLists.isNotEmpty) {
      buffer.writeln('Detalhes das listas compartilhadas:');
      for (final entry in sharedLists) {
        buffer.writeln(
          '- ${entry.name} - ${entry.roleLabel} - membros: ${entry.memberCount} - itens: ${entry.itemCount} - catálogo: ${_formatBool(entry.isCatalogImportEnabled)} - espelhada: ${_formatBool(entry.isMirroredLocally)} - erro: ${_fallback(entry.lastError, 'nenhum')}',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  static String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  static String _formatBool(bool value) => value ? 'ligado' : 'desligado';

  static String _formatNullableDateTime(DateTime? value) {
    if (value == null) {
      return 'nunca';
    }
    return _formatDateTime(value);
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
