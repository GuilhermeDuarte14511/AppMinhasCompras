import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../../utils/app_modal.dart';
import '../../theme/editorial_workspace_theme.dart';
import 'item_unit_price_sheet.dart';

Future<void> showPendingDraftsReviewSheet(
  BuildContext context, {
  required List<ShoppingItemDraft> drafts,
  required ValueChanged<List<ShoppingItemDraft>> onChanged,
}) => showAppModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: editorialWorkspaceTheme(
    Theme.of(context),
  ).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
  ),
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _PendingDraftsReviewSheet(drafts: drafts, onChanged: onChanged),
  ),
);

class _PendingDraftsReviewSheet extends StatefulWidget {
  const _PendingDraftsReviewSheet({
    required this.drafts,
    required this.onChanged,
  });
  final List<ShoppingItemDraft> drafts;
  final ValueChanged<List<ShoppingItemDraft>> onChanged;

  @override
  State<_PendingDraftsReviewSheet> createState() =>
      _PendingDraftsReviewSheetState();
}

class _PendingDraftsReviewSheetState extends State<_PendingDraftsReviewSheet> {
  late final _drafts = List<ShoppingItemDraft>.of(widget.drafts);

  void _change(VoidCallback change) {
    setState(change);
    widget.onChanged(List<ShoppingItemDraft>.unmodifiable(_drafts));
  }

  Future<void> _editPrice(ShoppingItemDraft draft) async {
    final price = await showItemUnitPriceSheet(
      context,
      name: draft.name,
      unitPrice: draft.unitPrice,
    );
    if (!mounted || price == null) return;
    final index = _drafts.indexOf(draft);
    if (index < 0) return;
    _change(
      () => _drafts[index] = ShoppingItemDraft(
        name: draft.name,
        quantity: draft.quantity,
        unitPrice: price,
        category: draft.category,
        barcode: draft.barcode,
        isPurchased: draft.isPurchased,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _drafts.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.unitPrice,
    );
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.85),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Fechar revisão',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        'Revisar itens',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Altere preços ou exclua itens antes de concluir.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ),
              Flexible(
                child: _drafts.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum item na seleção.\nVolte para adicionar produtos.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _drafts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final draft = _drafts[index];
                          return _PendingDraftRow(
                            key: ObjectKey(draft),
                            draft: draft,
                            onEdit: () => _editPrice(draft),
                            onRemove: () =>
                                _change(() => _drafts.remove(draft)),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${_drafts.length} ${_drafts.length == 1 ? 'item rascunhado' : 'itens rascunhados'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Total: '),
                                TextSpan(
                                  text: formatCurrency(total),
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Continuar adicionando',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDraftRow extends StatelessWidget {
  const _PendingDraftRow({
    super.key,
    required this.draft,
    required this.onEdit,
    required this.onRemove,
  });
  final ShoppingItemDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numericStyle = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final quantity = draft.quantity.toString();
    final total = Text(
      formatCurrency(draft.quantity * draft.unitPrice),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final remove = IconButton(
      onPressed: onRemove,
      tooltip: 'Excluir ${draft.name}',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        Icons.delete_outline,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
    final details = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$quantity un', style: numericStyle),
        Tooltip(
          message: 'Editar preço de ${draft.name}',
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: numericStyle?.copyWith(fontWeight: FontWeight.w500),
            ),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 15),
            iconAlignment: IconAlignment.end,
            label: Text('${formatCurrency(draft.unitPrice)}/un'),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(15) > 18;
          final name = Text(
            draft.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: name),
                    remove,
                  ],
                ),
                details,
                total,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [name, details],
                ),
              ),
              const SizedBox(width: 8),
              total,
              remove,
            ],
          );
        },
      ),
    );
  }
}
