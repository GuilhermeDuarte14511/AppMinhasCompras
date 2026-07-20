import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/sync_diagnostics.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';
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
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronização e diagnóstico')),
      body: AppGradientScene(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _StatusPanel(snapshot: snapshot),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _isRunningSync ? null : _runSyncNow,
                    icon: _isRunningSync
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _isRunningSync ? 'Sincronizando...' : 'Sincronizar agora',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _copyReport,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar relatório'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionTitle(
                title: 'Dados locais',
                subtitle: 'Resumo do que está salvo neste aparelho.',
              ),
              _DiagnosticsPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: 'Listas',
                      value: '${snapshot.listRecords}',
                    ),
                    _MetricChip(
                      label: 'Histórico',
                      value: '${snapshot.historyRecords}',
                    ),
                    _MetricChip(
                      label: 'Catálogo',
                      value: '${snapshot.catalogRecords}',
                    ),
                    _MetricChip(
                      label: 'Despensa',
                      value: '${snapshot.pantryRecords}',
                    ),
                    _MetricChip(
                      label: 'Pendentes',
                      value: '${snapshot.safePendingRecords}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionTitle(
                title: 'Configurações',
                subtitle: 'Preferências que afetam importação e sync.',
              ),
              _DiagnosticsPanel(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.inventory_2_rounded,
                      label: 'Catálogo do dono',
                      value: _onOff(snapshot.autoImportOwnedSharedCatalogs),
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.group_rounded,
                      label: 'Importar todas compartilhadas',
                      value: _onOff(snapshot.autoImportAllSharedCatalogs),
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.fact_check_rounded,
                      label: 'Listas com importação',
                      value: '${snapshot.enabledSharedCatalogImportCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionTitle(
                title: 'Conta e ambiente',
                subtitle: 'Informações úteis para suporte.',
              ),
              _DiagnosticsPanel(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Usuário',
                      value: _fallback(snapshot.userName, 'Sem nome'),
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'UID',
                      value: _fallback(snapshot.userUid, 'Sem UID'),
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.cloud_rounded,
                      label: 'Firebase',
                      value: _fallback(snapshot.projectId, 'Indisponível'),
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      icon: Icons.devices_rounded,
                      label: 'Plataforma',
                      value: snapshot.platformLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionTitle(
                title: 'Listas compartilhadas',
                subtitle: 'Estado das listas que podem impactar catálogo.',
              ),
              if (snapshot.sharedLists.isEmpty)
                const _DiagnosticsPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_off_rounded),
                    title: Text('Nenhuma lista compartilhada carregada'),
                    subtitle: Text(
                      'Entre em uma lista ou aguarde o carregamento do sync.',
                    ),
                  ),
                )
              else
                ...snapshot.sharedLists.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SharedListDiagnosticCard(entry: entry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _onOff(bool value) => value ? 'Ligado' : 'Desligado';

  String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.snapshot});

  final SyncDiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final presentation = _statusPresentation(context, snapshot.status);
    final textTheme = Theme.of(context).textTheme;
    return _DiagnosticsPanel(
      borderColor: presentation.color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: presentation.color.withValues(alpha: 0.14),
                foregroundColor: presentation.color,
                child: Icon(presentation.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snapshot.statusTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.statusDescription,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Sincronizados',
                value: '${snapshot.syncedRecords}',
              ),
              _MetricChip(
                label: 'Total',
                value: '${snapshot.safeTotalRecords}',
              ),
              _MetricChip(
                label: 'Compartilhadas',
                value: '${snapshot.sharedListCount}',
              ),
            ],
          ),
          if (snapshot.lastError != null) ...[
            const SizedBox(height: 12),
            _InlineWarning(message: 'Último erro: ${snapshot.lastError}'),
          ],
        ],
      ),
    );
  }

  _StatusPresentation _statusPresentation(
    BuildContext context,
    SyncDiagnosticStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case SyncDiagnosticStatus.synced:
        return _StatusPresentation(
          icon: Icons.cloud_done_rounded,
          color: colorScheme.tertiary,
        );
      case SyncDiagnosticStatus.syncing:
        return _StatusPresentation(
          icon: Icons.sync_rounded,
          color: colorScheme.primary,
        );
      case SyncDiagnosticStatus.attention:
        return _StatusPresentation(
          icon: Icons.sync_problem_rounded,
          color: colorScheme.primary,
        );
      case SyncDiagnosticStatus.offline:
        return _StatusPresentation(
          icon: Icons.cloud_off_rounded,
          color: colorScheme.error,
        );
      case SyncDiagnosticStatus.notConfigured:
        return _StatusPresentation(
          icon: Icons.lock_outline_rounded,
          color: colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _SharedListDiagnosticCard extends StatelessWidget {
  const _SharedListDiagnosticCard({required this.entry});

  final SharedListDiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.isOwner ? Icons.verified_user_rounded : Icons.group_rounded,
            ),
            title: Text(entry.name),
            subtitle: Text(entry.roleLabel),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: 'Membros', value: '${entry.memberCount}'),
              _MetricChip(label: 'Itens', value: '${entry.itemCount}'),
              _MetricChip(
                label: 'Catálogo',
                value: entry.isCatalogImportEnabled ? 'Ligado' : 'Desligado',
              ),
              _MetricChip(
                label: 'Espelho local',
                value: entry.isMirroredLocally ? 'Sim' : 'Não',
              ),
            ],
          ),
          if (entry.lastError != null) ...[
            const SizedBox(height: 10),
            _InlineWarning(message: 'Erro: ${entry.lastError}'),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color:
              borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      backgroundColor: colorScheme.surfaceContainerHighest,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
