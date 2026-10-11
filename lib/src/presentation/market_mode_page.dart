import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../application/finance_integration.dart';
import '../application/market_shopping_session.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'theme/editorial_workspace_theme.dart';
import 'dialogs_and_sheets.dart';
import 'dialogs/sheets/item_unit_price_sheet.dart';
import 'shopping_list_editor/widgets/market_payment_preview.dart';
import 'market_mode/market_editorial_widgets.dart';
import 'theme/app_tokens.dart';
import 'utils/app_toast.dart';

class ShoppingMarketModePage extends StatefulWidget {
  const ShoppingMarketModePage({
    super.key,
    required this.initialList,
    required this.onSave,
    this.financeRepository,
  });

  final ShoppingListModel initialList;
  final Future<void> Function(ShoppingListModel) onSave;
  final FinanceIntegrationRepository? financeRepository;

  @override
  State<ShoppingMarketModePage> createState() => _ShoppingMarketModePageState();
}

class _ShoppingMarketModePageState extends State<ShoppingMarketModePage> {
  late final MarketShoppingSession _session;
  ShoppingListModel get _list => _session.list;
  bool _leaving = false;
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
    _session = MarketShoppingSession(
      initialList: widget.initialList,
      onSave: widget.onSave,
    )..addListener(_onSessionChanged);
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _togglePurchased(ShoppingItem item, bool isPurchased) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    _session.updateItem(item.copyWith(isPurchased: isPurchased));
    HapticFeedback.selectionClick();
    AppToast.show(
      context,
      message: isPurchased ? 'Item pego.' : 'Item pendente.',
      type: AppToastType.success,
      duration: const Duration(milliseconds: 900),
    );
  }

  void _changeQuantity(ShoppingItem item, int delta) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final nextQuantity = max(1, item.quantity + delta);
    _session.updateItem(item.copyWith(quantity: nextQuantity));
  }

  Future<void> _editPrice(ShoppingItem item) async {
    final price = await showItemUnitPriceSheet(
      context,
      name: item.name,
      unitPrice: item.unitPrice,
    );
    if (!mounted || price == null) return;
    final current = _list.items
        .where((entry) => entry.id == item.id)
        .firstOrNull;
    if (current != null) {
      _session.updateItem(current.copyWith(unitPrice: price));
    }
  }

  Future<void> _editBalances() async {
    final result = await showPaymentBalancesEditorDialog(
      context,
      initialValues: _list.paymentBalances,
      financeRepository: widget.financeRepository,
    );
    if (!mounted || result == null) return;
    _session.updateBalances(result.clear ? [] : result.value ?? []);
  }

  Future<void> _finishAndReturn() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final saved = await _session.flush();
    if (!mounted) return;
    if (!saved) {
      setState(() => _leaving = false);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _list);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => PopScope(
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
                tooltip: 'Voltar',
                onPressed: _leaving ? null : _finishAndReturn,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modo compra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
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
              ],
            ),
            body: AbsorbPointer(
              absorbing: _leaving,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SafeArea(
                    child: CustomScrollView(
                      key: const Key('market_scroll'),
                      slivers: [
                        ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                            child: MarketEditorialSummary(
                              list: _list,
                              completion: _completion,
                              pendingProductsCount: _pendingProductsCount,
                              purchasedProductsCount: _purchasedProductsCount,
                              pendingUnits: _pendingUnits,
                              pendingValue: _pendingValue,
                            ),
                          ),
                          if (_list.hasPaymentBalances)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: MarketPaymentPreview(
                                list: _list,
                                onEditBalances: _editBalances,
                                repository: widget.financeRepository,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar item na compra',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                    suffixIcon: _searchController.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: _searchController.clear,
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    ChoiceChip(
                                      label: Text(
                                        'Apenas pendentes ($_pendingProductsCount)',
                                      ),
                                      selected: _showOnlyPending,
                                      showCheckmark: false,
                                      onSelected: (_) => setState(
                                        () => _showOnlyPending = true,
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: Text(
                                        'Todos (${_list.items.length})',
                                      ),
                                      selected: !_showOnlyPending,
                                      showCheckmark: false,
                                      onSelected: (_) => setState(
                                        () => _showOnlyPending = false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  children: [
                                    Text(
                                      '${_showOnlyPending ? 'PENDENTES' : 'ITENS'} · ${formatItemCount(visibleItems.length)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            letterSpacing: .6,
                                          ),
                                    ),
                                    Text(
                                      'Subtotal: ${formatCurrency(visibleItems.fold<double>(0, (sum, item) => sum + item.subtotal))}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_showOnlyPending && _purchasedProductsCount > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: _MarketModeInlineInfoBanner(
                                icon: Icons.visibility_outlined,
                                message: _purchasedProductsCount == 1
                                    ? '1 item pego está oculto para facilitar a compra.'
                                    : '$_purchasedProductsCount itens pegos estão ocultos para facilitar a compra.',
                                actionLabel: 'Mostrar',
                                onAction: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _showOnlyPending = false;
                                  });
                                },
                              ),
                            ),
                        ].map((child) => SliverToBoxAdapter(child: child)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: visibleItems.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _EmptyMarketModeState(
                                    showOnlyPending: _showOnlyPending,
                                    hasQuery: _searchQuery.isNotEmpty,
                                    onShowAllPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _showOnlyPending = false;
                                      });
                                    },
                                    onClearSearch: _searchController.clear,
                                  ),
                                )
                              : SliverList.separated(
                                  itemCount: visibleItems.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
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
                                          _togglePurchased(
                                            item,
                                            !item.isPurchased,
                                          );
                                          return false;
                                        },
                                        background: _MarketModeSwipeBackground(
                                          icon: item.isPurchased
                                              ? Icons.undo_rounded
                                              : Icons.check_rounded,
                                          label: item.isPurchased
                                              ? 'Marcar pendente'
                                              : 'Marcar como pego',
                                          alignRight: false,
                                        ),
                                        secondaryBackground:
                                            _MarketModeSwipeBackground(
                                              icon: item.isPurchased
                                                  ? Icons.undo_rounded
                                                  : Icons.check_rounded,
                                              label: item.isPurchased
                                                  ? 'Marcar pendente'
                                                  : 'Marcar como pego',
                                              alignRight: true,
                                            ),
                                        child: MarketEditorialItemRow(
                                          item: item,
                                          onTogglePurchased: () =>
                                              _togglePurchased(
                                                item,
                                                !item.isPurchased,
                                              ),
                                          onIncrement: () =>
                                              _changeQuantity(item, 1),
                                          onDecrement: () =>
                                              _changeQuantity(item, -1),
                                          onEditPrice: () => _editPrice(item),
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
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VALOR PEGO',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontSize: 10, letterSpacing: .8),
                              ),
                              Text(
                                formatCurrency(
                                  _list.items
                                      .where((item) => item.isPurchased)
                                      .fold<double>(
                                        0,
                                        (sum, item) => sum + item.subtotal,
                                      ),
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _leaving ? null : _finishAndReturn,
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(_leaving ? 'Salvando…' : 'Concluir'),
                        ),
                      ],
                    ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: _session.saveError != null
                              ? _MarketModeInlineInfoBanner(
                                  icon: Icons.error_outline,
                                  message:
                                      'Não foi possível salvar no aparelho.',
                                  actionLabel: 'Tentar novamente',
                                  onAction: _session.retrySave,
                                )
                              : Text(
                                  _session.isSaving
                                      ? 'Salvando…'
                                      : 'Salvo no aparelho',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                        ),
                        TextButton(
                          onPressed: _leaving ? null : _editBalances,
                          child: Text(
                            'Meios de pagamento',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        ? 'Tudo pego'
        : 'Nenhum item para mostrar';
    final description = hasQuery
        ? 'Ajuste sua busca para localizar produtos.'
        : showOnlyPending
        ? 'Todos os itens foram pegos.'
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
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        color: colorScheme.primaryContainer,
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
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
