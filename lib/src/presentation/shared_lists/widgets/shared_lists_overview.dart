import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../../../data/remote/shared_lists_repository.dart';

class SharedListsOverview extends StatelessWidget {
  const SharedListsOverview({
    super.key,
    required this.lists,
    required this.currentUid,
    required this.onJoin,
    required this.onOpen,
    this.loading = false,
    this.hasError = false,
    this.refreshing = false,
    this.onRetry,
  });
  final List<SharedShoppingListSummary> lists;
  final String currentUid;
  final VoidCallback onJoin;
  final ValueChanged<String> onOpen;
  final bool loading;
  final bool hasError;
  final bool refreshing;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.qr_code_rounded, size: 18),
          label: const Text('Entrar com código'),
        ),
        const SizedBox(height: 16),
        if (currentUid.isEmpty)
          _SharedOverviewNotice(
            icon: Icons.lock_outline_rounded,
            title: 'Entre para ver listas compartilhadas',
            description: 'Faça login para carregar seus convites e listas.',
          )
        else if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasError && lists.isEmpty)
          _SharedOverviewNotice(
            icon: Icons.sync_problem_rounded,
            title: 'Não foi possível carregar listas compartilhadas',
            description: 'Verifique a conexão e tente atualizar novamente.',
            action: TextButton(
              onPressed: refreshing ? null : onRetry,
              child: Text(refreshing ? 'Atualizando' : 'Atualizar'),
            ),
          )
        else if (lists.isEmpty)
          const _SharedOverviewNotice(
            icon: Icons.group_off_rounded,
            title: 'Nenhuma lista compartilhada',
            description:
                'Use "Entrar com código" ou compartilhe uma lista sua.',
          )
        else ...[
          Text(
            formatCountLabel(lists.length, 'lista exibida', 'listas exibidas'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: colors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onOpen(list.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                list.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.group_outlined,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${list.memberCount}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${list.isOwner(currentUid) ? 'Dono' : 'Membro'} · ${list.isClosed ? 'Fechada' : 'Aberta'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atualizada em ${formatDateTime(list.updatedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (list.hasBudget) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Orçamento: ${formatCurrency(list.budget!)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Abrir lista',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _SharedOverviewNotice extends StatelessWidget {
  const _SharedOverviewNotice({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        ?action,
      ],
    ),
  );
}
