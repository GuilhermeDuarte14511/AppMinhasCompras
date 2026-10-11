import 'package:flutter/material.dart';

import '../application/finance_integration.dart';
import '../core/utils/format_utils.dart';

/// A local receipt, not a claim about purchases sent from another device.
class FinancePurchaseSyncPanel extends StatelessWidget {
  const FinancePurchaseSyncPanel({
    super.key,
    required this.records,
    required this.onRetry,
    this.busy = false,
    this.error,
    this.loading = false,
    this.hasIntent = false,
  });
  final List<FinancePurchaseSync> records;
  final VoidCallback onRetry;
  final bool busy;
  final bool loading;
  final bool hasIntent;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final synced = records
        .where((r) => r.status == FinanceSyncStatus.synced)
        .length;
    final hasAttention = records.any(
      (r) => r.status == FinanceSyncStatus.attention,
    );
    final complete = records.isNotEmpty && synced == records.length;
    final title = loading
        ? 'Consultando envio ao Finanças…'
        : error != null
        ? 'Não foi possível consultar o envio'
        : records.isEmpty
        ? hasIntent
              ? 'Envio ainda não confirmado neste aparelho'
              : 'Sem comprovante de envio neste aparelho'
        : complete
        ? 'Sincronizado com o Finanças'
        : synced > 0
        ? 'Sincronização parcial · $synced/${records.length}'
        : hasAttention
        ? 'Envio precisa de atenção'
        : 'Envio pendente';
    final icon = complete
        ? Icons.cloud_done_outlined
        : hasAttention || error != null
        ? Icons.error_outline
        : Icons.cloud_upload_outlined;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: hasAttention ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${record.request.paymentSourceKind.label} · ${record.sourceName} · '
                  '${formatCurrency(record.request.amountCents / 100)} — '
                  '${switch (record.status) {
                    FinanceSyncStatus.synced => 'Confirmado',
                    FinanceSyncStatus.pending => 'Pendente',
                    FinanceSyncStatus.attention => 'Verificar',
                  }}'
                  '${record.message == null ? '' : '\n${record.message}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if ((!complete && (records.isNotEmpty || hasIntent)) || error != null)
            TextButton.icon(
              onPressed: busy || loading ? null : onRetry,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                busy
                    ? 'Reenviando…'
                    : error != null
                    ? 'Consultar novamente'
                    : 'Reenviar pendentes',
              ),
            ),
        ],
      ),
    );
  }
}
