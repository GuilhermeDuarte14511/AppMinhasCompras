import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/finance_integration.dart';
import '../application/finance_purchase_bridge.dart';
import '../data/finance_integration_dependencies.dart';
import 'finance_purchase_sync_panel.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'theme/editorial_workspace_theme.dart';
import 'purchase_history/history_ledger_widgets.dart';
import 'purchase_history/completed_purchase_details_sheet.dart';
import 'shopping_list_editor_page.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({
    super.key,
    required this.store,
    this.voiceRecognitionService,
    this.financeRepository,
  });

  final ShoppingListsStore store;
  final FinanceIntegrationRepository? financeRepository;
  final ShoppingVoiceRecognitionService? voiceRecognitionService;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  late final TextEditingController _searchController;
  late final FinanceIntegrationRepository _financeRepository;
  List<FinancePurchaseSync> _financeRecords = [];
  bool _financeLoading = true;
  String? _financeError;
  final _retrying = <String>{};

  Future<void> _loadFinanceHistory() async {
    try {
      final records = await _financeRepository.purchaseSyncHistory();
      if (mounted) {
        setState(() {
          _financeRecords = records;
          _financeError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _financeError = 'Consulta indisponível.');
    } finally {
      if (mounted) setState(() => _financeLoading = false);
    }
  }

  Future<void> _retryFinance(String purchaseId) async {
    if (_retrying.contains(purchaseId)) return;
    if (_financeError != null) {
      await _loadFinanceHistory();
      return;
    }
    setState(() => _retrying.add(purchaseId));
    try {
      final purchase = widget.store.purchaseHistory
          .where((p) => p.id == purchaseId)
          .firstOrNull;
      final intent = purchase?.financeIntent;
      if (!_financeRecords.any((r) => r.purchaseId == purchaseId) &&
          purchase != null &&
          intent != null) {
        await _financeRepository.submitPurchasePlan(
          buildFinancePurchasePlan(
            purchase: purchase,
            allocations: intent.allocations,
            categoryId: intent.categoryId,
          ),
        );
      } else {
        await _financeRepository.retryPurchase(purchaseId);
      }
      await _loadFinanceHistory();
    } on FinanceIntegrationException catch (error) {
      if (mounted) AppToast.show(context, message: error.message);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message:
              'Não foi possível reenviar. Seus pagamentos continuam salvos.',
        );
      }
    } finally {
      if (mounted) setState(() => _retrying.remove(purchaseId));
    }
  }

  String get _searchQuery => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _financeRepository =
        widget.financeRepository ?? createFinanceIntegrationRepository();
    unawaited(_loadFinanceHistory());
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

  Map<DateTime, List<CompletedPurchase>> _filteredHistoryByMonth() {
    final grouped = widget.store.historyGroupedByMonth();
    final normalizedQuery = normalizeQuery(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return grouped;
    }

    final filtered = <DateTime, List<CompletedPurchase>>{};
    for (final entry in grouped.entries) {
      final matches = entry.value
          .where((purchase) {
            if (normalizeQuery(purchase.listName).contains(normalizedQuery)) {
              return true;
            }
            for (final item in purchase.items) {
              if (normalizeQuery(item.name).contains(normalizedQuery)) {
                return true;
              }
            }
            return false;
          })
          .toList(growable: false);
      if (matches.isNotEmpty) {
        filtered[entry.key] = matches;
      }
    }
    return filtered;
  }

  String _monthLabel(DateTime month) {
    final raw = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    if (raw.isEmpty) {
      return '';
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  Future<void> _showPurchaseDetails(CompletedPurchase purchase) async {
    await showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompletedPurchaseDetailsSheet(purchase: purchase),
    );
  }

  Future<void> _deletePurchase(CompletedPurchase purchase) async {
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir fechamento?'),
        content: Text(
          'Deseja remover o fechamento da lista "${purchase.listName}" em ${formatDateTime(purchase.closedAt)}? Isso não cancela lançamentos nem envios pendentes no Finanças.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.deleteCompletedPurchase(purchase.id);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: 'Fechamento removido do histórico.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _clearHistory() async {
    if (widget.store.purchaseHistory.isEmpty) {
      return;
    }
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico mensal?'),
        content: const Text(
          'Essa ação remove todos os fechamentos salvos no histórico. Não cancela lançamentos nem envios pendentes no Finanças.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.clearPurchaseHistory();
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: 'Histórico mensal limpo com sucesso.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _createListFromEmptyState() async {
    final setup = await showListSetupDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
    );
    if (!mounted || setup == null) {
      return;
    }

    final created = await widget.store.createList(
      name: setup.name,
      budget: setup.budget,
      paymentBalances: setup.paymentBalances,
    );
    if (!mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    AppToast.show(
      context,
      message: 'Lista criada.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: created.id,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final grouped = _filteredHistoryByMonth();
          final count = grouped.values.fold<int>(
            0,
            (sum, entries) => sum + entries.length,
          );
          Widget columnWidth(Widget child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          );
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Histórico de compras',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              actions: [
                TextButton.icon(
                  onPressed: widget.store.purchaseHistory.isEmpty
                      ? null
                      : _clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Limpar'),
                ),
              ],
            ),
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: columnWidth(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchController,
                              style: Theme.of(context).textTheme.bodySmall,
                              decoration: InputDecoration(
                                hintText: 'Buscar por lista ou produto',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpar busca',
                                        onPressed: _searchController.clear,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${formatCountLabel(count, 'fechamento', 'fechamentos')} · ${formatCountLabel(grouped.length, 'mês', 'meses')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (grouped.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyPurchaseHistoryState(
                        hasQuery: _searchQuery.isNotEmpty,
                        onClearSearch: _searchController.clear,
                        onCreateList: _createListFromEmptyState,
                      ),
                    )
                  else ...[
                    for (final group in grouped.entries) ...[
                      SliverToBoxAdapter(
                        child: columnWidth(
                          HistoryMonthHeader(
                            label: _monthLabel(group.key),
                            purchases: group.value,
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: group.value.length,
                        itemBuilder: (context, index) {
                          final purchase = group.value[index];
                          final financeRecords = _financeRecords
                              .where(
                                (record) => record.purchaseId == purchase.id,
                              )
                              .toList();
                          final hasFinanceActivity =
                              purchase.financeIntent != null ||
                              financeRecords.isNotEmpty;
                          return columnWidth(
                            PurchaseHistoryRow(
                              key: ValueKey('history_purchase_${purchase.id}'),
                              purchase: purchase,
                              onDetails: () => _showPurchaseDetails(purchase),
                              onDelete: () => _deletePurchase(purchase),
                              financePanel: hasFinanceActivity
                                  ? FinancePurchaseSyncPanel(
                                      records: financeRecords,
                                      hasIntent: purchase.financeIntent != null,
                                      loading: _financeLoading,
                                      error: _financeError,
                                      busy: _retrying.contains(purchase.id),
                                      onRetry: () => _retryFinance(purchase.id),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        child: Text(
                          'Fechamentos salvos no histórico',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontFamily: 'MercadoNewsreader',
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _EmptyPurchaseHistoryState extends StatelessWidget {
  const _EmptyPurchaseHistoryState({
    required this.hasQuery,
    required this.onClearSearch,
    required this.onCreateList,
  });

  final bool hasQuery;
  final VoidCallback onClearSearch;
  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'Nenhum fechamento encontrado'
        : 'Sem histórico de compras';
    final description = hasQuery
        ? 'Tente outro termo para lista ou produto.'
        : 'Feche uma compra para ver gastos por mês.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 82,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.72),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar busca'),
              ),
            ] else ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreateList,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar lista'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
