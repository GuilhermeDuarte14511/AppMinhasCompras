import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';

class ShoppingMarketModePage extends StatefulWidget {
  const ShoppingMarketModePage({super.key, required this.initialList});

  final ShoppingListModel initialList;

  @override
  State<ShoppingMarketModePage> createState() => _ShoppingMarketModePageState();
}

class _ShoppingMarketModePageState extends State<ShoppingMarketModePage> {
  late ShoppingListModel _list;
  late final TextEditingController _searchController;
  bool _showOnlyPending = true;

  String get _searchQuery => _searchController.text.trim();

  List<ShoppingItem> get _visibleItems {
    final normalizedQuery = normalizeQuery(_searchQuery);
    final filtered = _list.items
        .where((item) {
          final matchesPending = _showOnlyPending ? !item.isPurchased : true;
          final matchesQuery = normalizedQuery.isEmpty
              ? true
              : normalizeQuery(item.name).contains(normalizedQuery);
          return matchesPending && matchesQuery;
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      if (a.isPurchased != b.isPurchased) {
        return a.isPurchased ? 1 : -1;
      }
      final byCategory = a.category.marketOrder.compareTo(
        b.category.marketOrder,
      );
      if (byCategory != 0) {
        return byCategory;
      }
      return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
    });

    return filtered;
  }

  int get _pendingProductsCount =>
      _list.items.where((item) => !item.isPurchased).length;
  int get _purchasedProductsCount =>
      _list.items.where((item) => item.isPurchased).length;
  int get _pendingUnits => _list.items
      .where((item) => !item.isPurchased)
      .fold<int>(0, (unitTotal, item) => unitTotal + item.quantity);
  double get _pendingValue => _list.items
      .where((item) => !item.isPurchased)
      .fold<double>(0, (total, item) => total + item.subtotal);
  double get _completion =>
      _list.items.isEmpty ? 0 : _purchasedProductsCount / _list.items.length;

  @override
  void initState() {
    super.initState();
    _list = widget.initialList.deepCopy();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePurchased(ShoppingItem item, bool isPurchased) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final updatedItems = [..._list.items];
    updatedItems[index] = item.copyWith(isPurchased: isPurchased);
    setState(() {
      _list = _list.copyWith(items: updatedItems);
    });
  }

  void _changeQuantity(ShoppingItem item, int delta) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final updatedItems = [..._list.items];
    final nextQuantity = max(1, item.quantity + delta);
    updatedItems[index] = item.copyWith(quantity: nextQuantity);
    setState(() {
      _list = _list.copyWith(items: updatedItems);
    });
  }

  void _finishAndReturn() {
    Navigator.pop(context, _list.copyWith(updatedAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _finishAndReturn();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _finishAndReturn,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Modo compra'),
          actions: [
            IconButton(
              tooltip: _showOnlyPending
                  ? 'Mostrar todos os itens'
                  : 'Mostrar apenas pendentes',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _showOnlyPending = !_showOnlyPending;
                });
              },
              icon: Icon(
                _showOnlyPending
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
            TextButton.icon(
              onPressed: _finishAndReturn,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Concluir'),
            ),
          ],
        ),
        body: AppGradientScene(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _MarketModeSummaryCard(
                    completion: _completion,
                    pendingProductsCount: _pendingProductsCount,
                    purchasedProductsCount: _purchasedProductsCount,
                    pendingUnits: _pendingUnits,
                    pendingValue: _pendingValue,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _MarketModeContentPanel(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar item na compra',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                      ),
                    ),
                  ),
                ),
                if (_showOnlyPending && _purchasedProductsCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _MarketModeInlineInfoBanner(
                      icon: Icons.visibility_outlined,
                      message: _purchasedProductsCount == 1
                          ? '1 item comprado está oculto para facilitar a compra.'
                          : '$_purchasedProductsCount itens comprados estão ocultos para facilitar a compra.',
                      actionLabel: 'Mostrar',
                      onAction: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _showOnlyPending = false;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: visibleItems.isEmpty
                      ? _EmptyMarketModeState(
                          showOnlyPending: _showOnlyPending,
                          hasQuery: _searchQuery.isNotEmpty,
                          onShowAllPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _showOnlyPending = false;
                            });
                          },
                          onClearSearch: _searchController.clear,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: visibleItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return _MarketModeEntryAnimation(
                              key: ValueKey('market_entry_${item.id}'),
                              delay: Duration(
                                milliseconds: min(140, index * 20),
                              ),
                              child: Dismissible(
                                key: ValueKey('market_${item.id}'),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (_) async {
                                  _togglePurchased(item, !item.isPurchased);
                                  return false;
                                },
                                background: _MarketModeSwipeBackground(
                                  icon: item.isPurchased
                                      ? Icons.undo_rounded
                                      : Icons.check_rounded,
                                  label: item.isPurchased
                                      ? 'Marcar pendente'
                                      : 'Marcar comprado',
                                  alignRight: false,
                                ),
                                secondaryBackground: _MarketModeSwipeBackground(
                                  icon: item.isPurchased
                                      ? Icons.undo_rounded
                                      : Icons.check_rounded,
                                  label: item.isPurchased
                                      ? 'Marcar pendente'
                                      : 'Marcar comprado',
                                  alignRight: true,
                                ),
                                child: _MarketModeItemCard(
                                  item: item,
                                  onTogglePurchased: () =>
                                      _togglePurchased(item, !item.isPurchased),
                                  onIncrement: () => _changeQuantity(item, 1),
                                  onDecrement: () => _changeQuantity(item, -1),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketModeSummaryCard extends StatelessWidget {
  const _MarketModeSummaryCard({
    required this.completion,
    required this.pendingProductsCount,
    required this.purchasedProductsCount,
    required this.pendingUnits,
    required this.pendingValue,
  });

  final double completion;
  final int pendingProductsCount;
  final int purchasedProductsCount;
  final int pendingUnits;
  final double pendingValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (completion * 100).clamp(0, 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Color.alphaBlend(
          colorScheme.primaryContainer.withValues(alpha: 0.66),
          colorScheme.surface,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Roteiro do mercado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: completion,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MarketModePillLabel(
                  icon: Icons.pending_actions_rounded,
                  text: '$pendingProductsCount pendentes',
                ),
                _MarketModePillLabel(
                  icon: Icons.check_circle_rounded,
                  text: '$purchasedProductsCount comprados',
                ),
                _MarketModePillLabel(
                  icon: Icons.confirmation_number_rounded,
                  text: '$pendingUnits unidades',
                ),
                _MarketModePillLabel(
                  icon: Icons.payments_rounded,
                  text: 'Falta ${formatCurrency(pendingValue)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketModeItemCard extends StatelessWidget {
  const _MarketModeItemCard({
    required this.item,
    required this.onTogglePurchased,
    required this.onIncrement,
    required this.onDecrement,
  });

  final ShoppingItem item;
  final VoidCallback onTogglePurchased;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _MarketModeContentPanel(
      child: AnimatedOpacity(
        duration: _marketModeAdaptiveMotionDuration(
          context,
          const Duration(milliseconds: 180),
        ),
        opacity: item.isPurchased ? 0.62 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTogglePurchased,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    '${item.quantity}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: item.isPurchased
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category.label} • ${formatCurrency(item.unitPrice)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subtotal: ${formatCurrency(item.subtotal)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton.filledTonal(
                      onPressed: onIncrement,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(height: 6),
                    IconButton.filledTonal(
                      onPressed: item.quantity > 1 ? onDecrement : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onTogglePurchased,
                  icon: Icon(
                    item.isPurchased
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.isPurchased
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMarketModeState extends StatelessWidget {
  const _EmptyMarketModeState({
    required this.showOnlyPending,
    required this.hasQuery,
    required this.onShowAllPressed,
    required this.onClearSearch,
  });

  final bool showOnlyPending;
  final bool hasQuery;
  final VoidCallback onShowAllPressed;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = hasQuery
        ? 'Nenhum item encontrado'
        : showOnlyPending
        ? 'Tudo comprado'
        : 'Sem itens para mostrar';
    final description = hasQuery
        ? 'Ajuste sua busca para localizar produtos.'
        : showOnlyPending
        ? 'Parabéns. Todos os itens estão marcados como comprados.'
        : 'Sua lista está vazia.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_checkout_rounded,
              size: 78,
              color: colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (hasQuery)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar busca'),
              )
            else if (showOnlyPending)
              OutlinedButton.icon(
                onPressed: onShowAllPressed,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Mostrar todos'),
              ),
          ],
        ),
      ),
    );
  }
}

Duration _marketModeAdaptiveMotionDuration(
  BuildContext context,
  Duration fallback,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class _MarketModeContentPanel extends StatelessWidget {
  const _MarketModeContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _MarketModePillLabel extends StatelessWidget {
  const _MarketModePillLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 5),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketModeSwipeBackground extends StatelessWidget {
  const _MarketModeSwipeBackground({
    required this.icon,
    required this.label,
    required this.alignRight,
  });

  final IconData icon;
  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.primaryContainer.withValues(alpha: 0.75),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight) Text(label),
          if (alignRight) const SizedBox(width: 8),
          Icon(icon),
          if (!alignRight) const SizedBox(width: 8),
          if (!alignRight) Text(label),
        ],
      ),
    );
  }
}

class _MarketModeInlineInfoBanner extends StatelessWidget {
  const _MarketModeInlineInfoBanner({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.26),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketModeEntryAnimation extends StatelessWidget {
  const _MarketModeEntryAnimation({
    super.key,
    required this.child,
    required this.delay,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
      return child;
    }
    return child
        .animate(delay: delay)
        .fadeIn(duration: AppTokens.motionMedium, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppTokens.motionMedium,
          curve: Curves.easeOutCubic,
        )
        .scaleXY(
          begin: 0.985,
          end: 1,
          duration: AppTokens.motionMedium,
          curve: Curves.easeOutBack,
        );
  }
}
