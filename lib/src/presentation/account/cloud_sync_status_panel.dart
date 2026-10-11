import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Presents repository sync state without implying that queued work is running.
class CloudSyncStatusPanel extends StatelessWidget {
  const CloudSyncStatusPanel({
    super.key,
    required this.hasInternetConnection,
    required this.hasPendingCloudSync,
    required this.isCloudSyncing,
    required this.lastCloudSyncAt,
    required this.totalRecords,
    required this.pendingRecords,
    required this.listRecords,
    required this.historyRecords,
    required this.catalogRecords,
    required this.pantryRecords,
    required this.compact,
  });

  final bool hasInternetConnection;
  final bool hasPendingCloudSync;
  final bool isCloudSyncing;
  final DateTime? lastCloudSyncAt;
  final int totalRecords;
  final int pendingRecords;
  final int listRecords;
  final int historyRecords;
  final int catalogRecords;
  final int pantryRecords;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = max(0, totalRecords);
    final pending = min(max(0, pendingRecords), total);
    final active = hasInternetConnection && isCloudSyncing;
    final waiting = hasPendingCloudSync || pending > 0;
    final formatted = lastCloudSyncAt == null
        ? null
        : DateFormat('dd/MM HH:mm').format(lastCloudSyncAt!.toLocal());
    final synced = total == 0
        ? '0'
        : formatted == null
        ? '—'
        : '${total - pending}';
    final title = !hasInternetConnection
        ? 'Modo offline'
        : active
        ? 'Sincronizando online'
        : waiting
        ? 'Alterações pendentes'
        : formatted != null
        ? 'Tudo sincronizado'
        : 'Pronto para sincronizar';
    final description = !hasInternetConnection
        ? pending > 0
              ? 'Sem internet. $pending registros aguardam conexão.'
              : 'Sem internet. Alterações continuam salvas no aparelho.'
        : active
        ? pending > 0
              ? 'Enviando dados para nuvem. Faltam $pending registros.'
              : 'Enviando dados para nuvem.'
        : waiting
        ? pending > 0
              ? '$pending registros aguardando sincronização.'
              : 'Alterações aguardando sincronização.'
        : formatted != null
        ? 'Dados online atualizados em $formatted.'
        : 'Suas listas serão sincronizadas automaticamente online.';
    final icon = !hasInternetConnection
        ? Icons.cloud_off_outlined
        : active
        ? Icons.cloud_upload_outlined
        : waiting
        ? Icons.sync_outlined
        : formatted != null
        ? Icons.cloud_done_outlined
        : Icons.cloud_queue_outlined;
    final accent = !hasInternetConnection ? colors.error : colors.primary;
    Widget metric(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall?.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: text.bodySmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label:
          'Status da sincronização: $title. $description. Total: $total registros. Pendentes: $pending. ${formatted == null ? 'Sem sincronização anterior confirmada.' : '$synced registros sincronizados.'}',
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!hasInternetConnection)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: colors.error.withValues(alpha: .3),
                                ),
                              ),
                              child: Text(
                                'Sem rede',
                                style: text.bodySmall?.copyWith(
                                  color: colors.onErrorContainer,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(description, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(12) > 15;
                final metrics = [
                  metric(
                    hasInternetConnection
                        ? 'Aguardando sincronização'
                        : 'Aguardando conexão',
                    '$pending registros',
                  ),
                  metric(
                    'Última sincronização',
                    formatted ?? 'Nunca sincronizado',
                  ),
                ];
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          metrics[0],
                          const SizedBox(height: 12),
                          metrics[1],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: metrics[0]),
                          const SizedBox(width: 12),
                          Expanded(child: metrics[1]),
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Total: $total', style: text.bodySmall),
                Text('Sincronizados: $synced', style: text.bodySmall),
                Text('Faltando: $pending', style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            if (!hasInternetConnection)
              Text(
                'Listas: ${max(0, listRecords)} · Histórico: ${max(0, historyRecords)} · Catálogo: ${max(0, catalogRecords)} · Despensa: ${max(0, pantryRecords)}',
                style: text.bodySmall,
              )
            else ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: colors.outlineVariant),
              for (final entry in {
                'Listas': listRecords,
                'Histórico': historyRecords,
                'Catálogo': catalogRecords,
                'Despensa': pantryRecords,
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key, style: text.bodySmall)),
                      Text(
                        '${max(0, entry.value)}',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (active) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                color: colors.primary,
                backgroundColor: colors.outlineVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
