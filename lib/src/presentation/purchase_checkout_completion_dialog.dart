import 'package:flutter/material.dart';

import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';

Future<void> showPurchaseCompletionDialog(
  BuildContext context, {
  String? financeMessage,
}) {
  final message =
      financeMessage ??
      'Compra salva no histórico. A sincronização da conta continua em segundo plano.';
  final normalized = message.toLowerCase();
  final needsAttention =
      normalized.contains('não foi') || normalized.contains('precisa');
  final progress = RegExp(
    r'(\d+) de (\d+) pagamentos sincronizados',
  ).firstMatch(normalized);
  final isPartial =
      progress != null && int.parse(progress[1]!) < int.parse(progress[2]!);
  final isPending =
      normalized.contains('pendente') ||
      normalized.contains('parcial') ||
      isPartial;
  final financeSynced = normalized.contains('lançada no minhas finanças');
  final title = needsAttention
      ? 'Compra salva com atenção'
      : isPending
      ? 'Compra salva · envio pendente'
      : 'Compra concluída';
  final theme = editorialWorkspaceTheme(Theme.of(context));
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          final compact = MediaQuery.sizeOf(context).width <= 600;
          if (isPending && !needsAttention) {
            return _PendingCompletionDialog(
              title: title,
              message: message,
              isPartial: isPartial,
              onConclude: () => Navigator.pop(dialogContext),
            );
          }
          return Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 24,
              vertical: compact ? 0 : 24,
            ),
            constraints: const BoxConstraints(maxWidth: 390),
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(title, style: text.titleLarge),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          needsAttention
                              ? Icons.error_outline_rounded
                              : isPending
                              ? Icons.cloud_upload_outlined
                              : Icons.check_circle_outline_rounded,
                          color: needsAttention ? colors.error : colors.primary,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Compra salva no histórico',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 20),
                          _StatusRow(
                            label: 'Histórico de compras',
                            value: 'Registrado',
                            icon: Icons.save_outlined,
                          ),
                          _StatusRow(
                            label: 'Sincronização da conta',
                            value: 'Em segundo plano',
                            icon: Icons.sync_rounded,
                          ),
                          if (financeMessage != null &&
                              (needsAttention || isPending || financeSynced))
                            _StatusRow(
                              label: 'Integração financeira',
                              value: needsAttention
                                  ? 'Requer atenção'
                                  : isPending
                                  ? isPartial
                                        ? 'Envio parcial'
                                        : 'Envio pendente'
                                  : 'Lançada',
                              icon: needsAttention
                                  ? Icons.error_outline_rounded
                                  : Icons.cloud_upload_outlined,
                              attention: needsAttention,
                            ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: needsAttention
                                    ? colors.error
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SelectableText(
                                  message,
                                  style: text.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Concluir'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _PendingCompletionDialog extends StatelessWidget {
  const _PendingCompletionDialog({
    required this.title,
    required this.message,
    required this.isPartial,
    required this.onConclude,
  });

  final String title;
  final String message;
  final bool isPartial;
  final VoidCallback onConclude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 340),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Icon(
                          Icons.cloud_outlined,
                          color: colors.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.titleLarge?.copyWith(fontSize: 21),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 48,
                          child: Divider(
                            height: 1,
                            color: colors.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    const _PendingStatusRow(
                      icon: Icons.check_rounded,
                      label: 'Salva no histórico',
                      description: 'Os itens e valores foram gravados no app.',
                    ),
                    const SizedBox(height: 16),
                    const _PendingStatusRow(
                      icon: Icons.schedule_outlined,
                      label: 'Sincronização da conta em segundo plano',
                      description:
                          'A sincronização da conta continua em segundo plano.',
                      muted: true,
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              isPartial ? 'Envio parcial' : 'Envio pendente',
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              message,
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onConclude,
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingStatusRow extends StatelessWidget {
  const _PendingStatusRow({
    required this.icon,
    required this.label,
    required this.description,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    this.attention = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: attention
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: attention
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
