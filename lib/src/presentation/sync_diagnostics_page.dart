import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/sync_diagnostics.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_toast.dart';

class SyncDiagnosticsPage extends StatefulWidget {
  const SyncDiagnosticsPage({
    super.key,
    required this.snapshot,
    required this.onSyncNow,
    this.onRefreshSnapshot,
  });

  final SyncDiagnosticsSnapshot snapshot;
  final Future<void> Function() onSyncNow;
  final Future<SyncDiagnosticsSnapshot?> Function()? onRefreshSnapshot;

  @override
  State<SyncDiagnosticsPage> createState() => _SyncDiagnosticsPageState();
}

class _SyncDiagnosticsPageState extends State<SyncDiagnosticsPage> {
  bool _isRunningSync = false;
  late SyncDiagnosticsSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(covariant SyncDiagnosticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      _snapshot = widget.snapshot;
    }
  }

  Future<void> _runSyncNow() async {
    if (_isRunningSync) {
      return;
    }
    setState(() {
      _isRunningSync = true;
    });
    try {
      await widget.onSyncNow();
      final refreshSnapshot = widget.onRefreshSnapshot;
      if (refreshSnapshot != null) {
        final refreshed = await refreshSnapshot();
        if (mounted && refreshed != null) {
          setState(() {
            _snapshot = refreshed;
          });
        }
      }
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: 'Sincronização concluída.',
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: 'Falha ao sincronizar agora: $error',
        type: AppToastType.error,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSync = false;
        });
      }
    }
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(
      ClipboardData(text: _snapshot.buildSupportReport()),
    );
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: 'Relatório copiado.',
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(builder: _buildEditorialPage),
    );
  }

  Widget _buildEditorialPage(BuildContext context) {
    final snapshot = _snapshot;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Sincronização e diagnóstico',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar sincronização',
            onPressed: _isRunningSync ? null : _runSyncNow,
            icon: const Icon(Icons.refresh, size: 22),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _StatusPanel(
                  snapshot: snapshot,
                  isRunning: _isRunningSync,
                  onSync: _runSyncNow,
                  onCopy: _copyReport,
                ),
                const _SectionTitle(title: 'Registros locais do app'),
                _LedgerRow(
                  label: 'Listas',
                  value: '${snapshot.listRecords} no aparelho',
                ),
                _LedgerRow(
                  label: 'Histórico',
                  value: '${snapshot.historyRecords} registros',
                ),
                _LedgerRow(
                  label: 'Catálogo',
                  value: '${snapshot.catalogRecords} itens',
                ),
                _LedgerRow(
                  label: 'Despensa',
                  value: '${snapshot.pantryRecords} itens',
                ),
                _LedgerRow(
                  label: 'Pendentes de sincronização',
                  value: '${snapshot.safePendingRecords} registros',
                ),
                _LedgerRow(
                  label: 'Sincronizados',
                  value:
                      '${snapshot.syncedRecords} de ${snapshot.safeTotalRecords}',
                ),
                const _SectionTitle(title: 'Identificação e ambiente'),
                _LedgerRow(
                  label: 'Usuário',
                  value: _fallback(snapshot.userName, 'Sem nome'),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'E-mail',
                  value: _fallback(snapshot.userEmail, 'Sem e-mail'),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'UID do usuário',
                  value: _fallback(snapshot.userUid, 'Sem UID'),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'Provedor de autenticação',
                  value: _fallback(snapshot.providerId, 'Indisponível'),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'Projeto Firebase',
                  value: _fallback(snapshot.projectId, 'Indisponível'),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'Plataforma',
                  value: snapshot.platformLabel,
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'Versão do app',
                  value: snapshot.appVersion,
                  stacked: true,
                ),
                const _SectionTitle(title: 'Sincronização'),
                _LedgerRow(
                  label: 'Internet',
                  value: snapshot.hasInternetConnection ? 'Online' : 'Offline',
                ),
                _LedgerRow(
                  label: 'Alterações locais pendentes',
                  value: snapshot.hasPendingCloudSync ? 'Sim' : 'Não',
                ),
                _LedgerRow(
                  label: 'Sincronização na nuvem',
                  value: snapshot.isCloudSyncing ? 'Em andamento' : 'Inativa',
                ),
                _LedgerRow(
                  label: 'Carregamento da nuvem',
                  value: snapshot.isPullingCloudSnapshot
                      ? 'Em andamento'
                      : 'Inativo',
                ),
                _LedgerRow(
                  label: 'Espelhamento de listas',
                  value: snapshot.isMirroringSharedLists
                      ? 'Em andamento'
                      : 'Inativo',
                ),
                _LedgerRow(
                  label: 'Último sync na nuvem',
                  value: _date(snapshot.lastCloudSyncAt),
                  stacked: true,
                ),
                _LedgerRow(
                  label: 'Último sync compartilhadas',
                  value: _date(snapshot.lastSharedSyncAt),
                  stacked: true,
                ),
                const _SectionTitle(title: 'Configurações de importação'),
                _LedgerRow(
                  label: 'Catálogo do dono',
                  value: _onOff(snapshot.autoImportOwnedSharedCatalogs),
                ),
                _LedgerRow(
                  label: 'Importar todas compartilhadas',
                  value: _onOff(snapshot.autoImportAllSharedCatalogs),
                ),
                _LedgerRow(
                  label: 'Listas com importação',
                  value: '${snapshot.enabledSharedCatalogImportCount}',
                ),
                const _SectionTitle(title: 'Listas compartilhadas'),
                _LedgerRow(
                  label: 'Total carregado',
                  value: '${snapshot.sharedListCount}',
                ),
                if (snapshot.sharedLists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhuma lista compartilhada carregada'),
                  )
                else
                  ...snapshot.sharedLists.map(
                    (entry) => _SharedListDiagnosticRow(entry: entry),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _onOff(bool value) => value ? 'Ligado' : 'Desligado';

  String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }
}

String _date(DateTime? value) {
  if (value == null) {
    return 'Nunca';
  }
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} às ${two(local.hour)}:${two(local.minute)}';
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.snapshot,
    required this.isRunning,
    required this.onSync,
    required this.onCopy,
  });
  final SyncDiagnosticsSnapshot snapshot;
  final bool isRunning;
  final VoidCallback onSync;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, color) = switch (snapshot.status) {
      SyncDiagnosticStatus.synced => (
        Icons.cloud_done_outlined,
        colors.primary,
      ),
      SyncDiagnosticStatus.syncing => (Icons.sync, colors.primary),
      SyncDiagnosticStatus.attention => (
        Icons.sync_problem_outlined,
        colors.error,
      ),
      SyncDiagnosticStatus.offline => (Icons.cloud_off_outlined, colors.error),
      SyncDiagnosticStatus.notConfigured => (
        Icons.lock_outline,
        colors.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot.statusTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(snapshot.statusDescription, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              'Última verificação: ${_date(snapshot.generatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (snapshot.lastError != null) ...[
              const SizedBox(height: 12),
              _InlineWarning(message: 'Último erro: ${snapshot.lastError}'),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: isRunning ? null : onSync,
              icon: isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(isRunning ? 'Sincronizando...' : 'Sincronizar agora'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copiar relatório'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.value,
    this.stacked = false,
  });
  final String label;
  final String value;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical =
              stacked ||
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.2;
          if (vertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: text.bodyMedium),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: text.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SharedListDiagnosticRow extends StatelessWidget {
  const _SharedListDiagnosticRow({required this.entry});
  final SharedListDiagnosticEntry entry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.roleLabel} · ${entry.memberCount} membros · ${entry.itemCount} itens',
            style: theme.textTheme.bodySmall,
          ),
          _LedgerRow(
            label: 'Catálogo',
            value: entry.isCatalogImportEnabled ? 'Ligado' : 'Desligado',
          ),
          _LedgerRow(
            label: 'Espelho local',
            value: entry.isMirroredLocally ? 'Sim' : 'Não',
          ),
          _LedgerRow(label: 'Atualizada em', value: _date(entry.updatedAt)),
          if (entry.lastError != null) ...[
            const SizedBox(height: 8),
            _InlineWarning(message: 'Erro: ${entry.lastError}'),
          ],
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: colors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ),
      ],
    );
  }
}
