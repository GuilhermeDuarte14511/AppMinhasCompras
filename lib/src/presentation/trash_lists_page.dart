import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/store_and_services.dart';
import '../domain/models_and_utils.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

class TrashListsPage extends StatefulWidget {
  const TrashListsPage({super.key, required this.store, this.nowProvider});

  final ShoppingListsStore store;
  final DateTime Function()? nowProvider;

  @override
  State<TrashListsPage> createState() => _TrashListsPageState();
}

class _TrashListsPageState extends State<TrashListsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.purgeExpiredTrash(now: widget.nowProvider?.call());
    });
  }

  Future<void> _restore(ShoppingListModel list) async {
    await widget.store.restoreList(list.id);
    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    AppToast.show(
      context,
      message: '“${list.name}” voltou para suas listas.',
      type: AppToastType.success,
    );
  }

  Future<void> _deleteForever(ShoppingListModel list) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: editorialWorkspaceTheme(Theme.of(context)),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Excluir definitivamente?'),
          content: Text(
            '“${list.name}” será apagada em todos os seus dispositivos e não poderá ser recuperada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA44438),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir definitivamente'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await widget.store.deleteListForever(list.id);
    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    AppToast.show(context, message: 'Lista excluída definitivamente.');
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final lists = widget.store.trashedLists;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Lixeira'),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1),
              ),
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: _TrashIntroduction()),
                      if (lists.isEmpty)
                        const SliverToBoxAdapter(child: _EmptyTrash())
                      else ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 24,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'Registro de exclusão',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    Text(
                                      formatCountLabel(
                                        lists.length,
                                        'lista excluída',
                                        'listas excluídas',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.builder(
                            itemCount: lists.length,
                            itemBuilder: (context, index) => _TrashListTile(
                              list: lists[index],
                              now: widget.nowProvider?.call() ?? DateTime.now(),
                              onRestore: () => _restore(lists[index]),
                              onDeleteForever: () =>
                                  _deleteForever(lists[index]),
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _TrashIntroduction extends StatelessWidget {
  const _TrashIntroduction();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Text(
      'Listas excluídas são mantidas por 30 dias antes da exclusão permanente.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _TrashListTile extends StatelessWidget {
  const _TrashListTile({
    required this.list,
    required this.now,
    required this.onRestore,
    required this.onDeleteForever,
  });
  final ShoppingListModel list;
  final DateTime now;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  int get _remainingDays =>
      (list.deletedAt!
                  .add(ShoppingListsStore.trashRetention)
                  .difference(now)
                  .inMilliseconds /
              Duration.millisecondsPerDay)
          .ceil()
          .clamp(0, 30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final deletedLabel =
        (DateFormat.localeExists('pt_BR')
                ? DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR')
                : DateFormat('dd/MM/yyyy'))
            .format(list.deletedAt!);
    final days = _remainingDays;
    final deadline = days == 0
        ? 'Expira hoje'
        : days == 1
        ? 'Expira em 1 dia'
        : 'Expira em $days dias';
    final destructive = colors.brightness == Brightness.dark
        ? const Color(0xFFF4B7BB)
        : const Color(0xFFA44438);
    return Semantics(
      container: true,
      label: '${list.name}, excluída em $deletedLabel, $deadline',
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(list.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Excluída em $deletedLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
                final badge = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deadline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: days <= 1 ? destructive : colors.onSurfaceVariant,
                    ),
                  ),
                );
                if (constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(12) > 15) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [content, const SizedBox(height: 8), badge],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 12),
                    badge,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: colors.primary,
                    backgroundColor: colors.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restaurar'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: destructive,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: onDeleteForever,
                  icon: const Icon(Icons.delete_forever_outlined, size: 16),
                  label: const Text('Excluir definitivamente'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: Column(
        children: [
          Icon(
            Icons.delete_sweep_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'A lixeira está vazia',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'As listas excluídas aparecerão aqui por 30 dias.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
