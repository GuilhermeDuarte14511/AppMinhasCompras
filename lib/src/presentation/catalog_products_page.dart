import 'package:flutter/material.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'extensions/classification_ui_extensions.dart';
import 'launch.dart';
import 'product_details_page.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

enum _CatalogSortOption { updatedAt, name, usage, price }

enum _CatalogPriceFilter { all, withoutPrice }

enum _CatalogProductAction { edit, updatePrice, delete }

class CatalogProductsPage extends StatefulWidget {
  const CatalogProductsPage({super.key, required this.store});

  final ShoppingListsStore store;

  @override
  State<CatalogProductsPage> createState() => _CatalogProductsPageState();
}

class _CatalogProductsPageState extends State<CatalogProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  _CatalogSortOption _sortOption = _CatalogSortOption.updatedAt;
  _CatalogPriceFilter _priceFilter = _CatalogPriceFilter.all;
  ShoppingCategory? _categoryFilter;
  bool _onlyWithBarcode = false;
  bool _batchMode = false;
  final Set<String> _selectedProductIds = <String>{};

  String get _searchQuery => _searchController.text.trim();
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _categoryFilter != null ||
      _onlyWithBarcode ||
      _priceFilter != _CatalogPriceFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
  }

  String _sortLabel(_CatalogSortOption option) {
    switch (option) {
      case _CatalogSortOption.updatedAt:
        return 'Atualização';
      case _CatalogSortOption.name:
        return 'Nome';
      case _CatalogSortOption.usage:
        return 'Uso';
      case _CatalogSortOption.price:
        return 'preço';
    }
  }

  IconData _sortIcon(_CatalogSortOption option) {
    switch (option) {
      case _CatalogSortOption.updatedAt:
        return Icons.update_rounded;
      case _CatalogSortOption.name:
        return Icons.sort_by_alpha_rounded;
      case _CatalogSortOption.usage:
        return Icons.bar_chart_rounded;
      case _CatalogSortOption.price:
        return Icons.attach_money_rounded;
    }
  }

  void _toggleBatchMode([bool? enabled]) {
    final next = enabled ?? !_batchMode;
    setState(() {
      _batchMode = next;
      if (!next) {
        _selectedProductIds.clear();
      }
    });
  }

  void _toggleSelection(String productId, {bool forceSelect = false}) {
    setState(() {
      if (!_batchMode) {
        _batchMode = true;
      }
      if (forceSelect) {
        _selectedProductIds.add(productId);
      } else if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
      if (_batchMode && _selectedProductIds.isEmpty) {
        _batchMode = false;
      }
    });
  }

  void _toggleSelectAllVisible(List<CatalogProduct> visibleProducts) {
    if (visibleProducts.isEmpty) {
      return;
    }
    final visibleIds = visibleProducts.map((entry) => entry.id).toSet();
    final allSelected = visibleIds.every(_selectedProductIds.contains);
    setState(() {
      _batchMode = true;
      if (allSelected) {
        _selectedProductIds.removeAll(visibleIds);
      } else {
        _selectedProductIds.addAll(visibleIds);
      }
      if (_selectedProductIds.isEmpty) {
        _batchMode = false;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _categoryFilter = null;
      _onlyWithBarcode = false;
      _priceFilter = _CatalogPriceFilter.all;
    });
  }

  Future<void> _deleteSelectedProducts() async {
    final count = _selectedProductIds.length;
    if (count == 0) {
      return;
    }
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir selecionados?'),
        content: Text(
          'Deseja excluir ${formatCountLabel(count, 'produto', 'produtos')} do catálogo?',
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

    if (!mounted || shouldDelete != true) {
      return;
    }
    final updated = widget.store.catalogProducts
        .where((entry) => !_selectedProductIds.contains(entry.id))
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(updated);
    if (!mounted) {
      return;
    }
    _toggleBatchMode(false);
    _showSnack(
      count == 1 ? '1 produto removido.' : '$count produtos removidos.',
      type: AppToastType.success,
    );
  }

  Future<void> _updateCategoryForSelectedProducts() async {
    final selected = widget.store.catalogProducts
        .where((entry) => _selectedProductIds.contains(entry.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return;
    }

    ShoppingCategory selectedCategory = selected.first.category;
    final result = await showAppDialog<ShoppingCategory>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Categoria em lote'),
          content: DropdownButtonFormField<ShoppingCategory>(
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: ShoppingCategory.values
                .map(
                  (entry) => DropdownMenuItem<ShoppingCategory>(
                    value: entry,
                    child: Text(entry.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setDialogState(() {
                selectedCategory = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedCategory),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    final now = DateTime.now();
    final updated = widget.store.catalogProducts
        .map(
          (entry) => _selectedProductIds.contains(entry.id)
              ? entry.copyWith(category: result, updatedAt: now)
              : entry,
        )
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(updated);
    if (!mounted) {
      return;
    }
    _showSnack(
      'Categoria aplicada em ${formatCountLabel(_selectedProductIds.length, 'produto', 'produtos')}.',
      type: AppToastType.success,
    );
  }

  List<CatalogProduct> _visibleProducts(List<CatalogProduct> source) {
    final normalizedQuery = normalizeQuery(_searchQuery);
    final filtered = source
        .where((product) {
          if (_categoryFilter != null && product.category != _categoryFilter) {
            return false;
          }
          if (_onlyWithBarcode &&
              (product.barcode == null || product.barcode!.trim().isEmpty)) {
            return false;
          }
          if (_priceFilter == _CatalogPriceFilter.withoutPrice &&
              product.unitPrice != null &&
              product.unitPrice! > 0) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final searchable = normalizeQuery(
            [
              product.name,
              product.barcode ?? '',
              product.category.label,
            ].join(' '),
          );
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      switch (_sortOption) {
        case _CatalogSortOption.updatedAt:
          return b.updatedAt.compareTo(a.updatedAt);
        case _CatalogSortOption.name:
          return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
        case _CatalogSortOption.usage:
          return b.usageCount.compareTo(a.usageCount);
        case _CatalogSortOption.price:
          final aPrice = a.unitPrice ?? 0;
          final bPrice = b.unitPrice ?? 0;
          return bPrice.compareTo(aPrice);
      }
    });

    return filtered;
  }

  ShoppingItem _editableItemFromCatalog(CatalogProduct product) {
    return ShoppingItem(
      id: product.id,
      name: product.name,
      quantity: 1,
      unitPrice: product.unitPrice ?? 0,
      barcode: product.barcode,
      category: product.category,
      priceHistory: product.priceHistory,
    );
  }

  List<PriceHistoryEntry> _buildUpdatedPriceHistory({
    required CatalogProduct original,
    required double newPrice,
    required DateTime recordedAt,
  }) {
    final history = [...original.priceHistory];
    final currentPrice = original.unitPrice ?? 0;
    if (history.isEmpty && currentPrice > 0) {
      history.add(
        PriceHistoryEntry(price: currentPrice, recordedAt: original.updatedAt),
      );
    }
    final shouldAppend =
        history.isEmpty || (history.last.price - newPrice).abs() > 0.0001;
    if (shouldAppend) {
      history.add(PriceHistoryEntry(price: newPrice, recordedAt: recordedAt));
    }
    return history;
  }

  Future<void> _createCatalogProduct() async {
    final blockedNames = widget.store.catalogProducts
        .map((product) => normalizeQuery(product.name))
        .toSet();
    final draft = await showShoppingItemEditorSheet(
      context,
      blockedNormalizedNames: blockedNames,
      catalogProducts: widget.store.catalogProducts,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );
    if (!mounted || draft == null) {
      return;
    }
    await widget.store.saveDraftToCatalog(draft);
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('Produto adicionado ao catálogo.', type: AppToastType.success);
  }

  Future<void> _openProductDetails(CatalogProduct product) async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) =>
            ProductDetailsPage(store: widget.store, productId: product.id),
      ),
    );
  }

  Future<void> _editCatalogProduct(CatalogProduct product) async {
    final blockedNames = widget.store.catalogProducts
        .where((entry) => entry.id != product.id)
        .map((entry) => normalizeQuery(entry.name))
        .toSet();
    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: _editableItemFromCatalog(product),
      blockedNormalizedNames: blockedNames,
      catalogProducts: widget.store.catalogProducts,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );
    if (!mounted || draft == null) {
      return;
    }

    final now = DateTime.now();
    final updated = product.copyWith(
      name: draft.name,
      category: draft.category,
      unitPrice: draft.unitPrice,
      barcode: draft.barcode,
      clearBarcode: draft.barcode == null || draft.barcode!.trim().isEmpty,
      updatedAt: now,
      priceHistory: _buildUpdatedPriceHistory(
        original: product,
        newPrice: draft.unitPrice,
        recordedAt: now,
      ),
    );
    final products = widget.store.catalogProducts
        .map((entry) => entry.id == product.id ? updated : entry)
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(products);
    if (!mounted) {
      return;
    }
    _showSnack('Produto atualizado.', type: AppToastType.success);
  }

  Future<void> _updateCatalogPrice(CatalogProduct product) async {
    final formatter = BrlCurrencyInputFormatter();
    final initialPrice = product.unitPrice ?? 0;
    final controller = TextEditingController(
      text: formatter.formatValue(initialPrice > 0 ? initialPrice : 0),
    );
    final formKey = GlobalKey<FormState>();

    final price = await showAppDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Atualizar preço'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [formatter],
              decoration: const InputDecoration(
                labelText: 'Novo preço',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (value) {
                final parsed = BrlCurrencyInputFormatter.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Informe um preço válido.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                final parsed = BrlCurrencyInputFormatter.tryParse(
                  controller.text,
                );
                Navigator.pop(context, parsed);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (!mounted || price == null || price <= 0) {
      return;
    }

    final now = DateTime.now();
    final updated = product.copyWith(
      unitPrice: price,
      updatedAt: now,
      priceHistory: _buildUpdatedPriceHistory(
        original: product,
        newPrice: price,
        recordedAt: now,
      ),
    );
    final products = widget.store.catalogProducts
        .map((entry) => entry.id == product.id ? updated : entry)
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(products);
    if (!mounted) {
      return;
    }
    _showSnack('preço atualizado.', type: AppToastType.success);
  }

  Future<void> _deleteCatalogProduct(CatalogProduct product) async {
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('Deseja excluir "${product.name}" do catálogo?'),
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

    if (!mounted || shouldDelete != true) {
      return;
    }

    final products = widget.store.catalogProducts
        .where((entry) => entry.id != product.id)
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(products);
    if (!mounted) {
      return;
    }
    _showSnack('Produto removido do catálogo.', type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _batchMode
              ? 'Catálogo (${_selectedProductIds.length})'
              : 'Catálogo de produtos',
        ),
        actions: [
          if (_batchMode)
            IconButton(
              tooltip: 'Selecionar visíveis',
              onPressed: () => _toggleSelectAllVisible(
                _visibleProducts(widget.store.catalogProducts),
              ),
              icon: const Icon(Icons.select_all_rounded),
            ),
          IconButton(
            tooltip: _batchMode ? 'Sair da seleção' : 'Seleção em lote',
            onPressed: () => _toggleBatchMode(),
            icon: Icon(
              _batchMode
                  ? Icons.checklist_rtl_rounded
                  : Icons.checklist_rounded,
            ),
          ),
          if (_batchMode)
            IconButton(
              tooltip: 'Categoria em lote',
              onPressed: _selectedProductIds.isEmpty
                  ? null
                  : _updateCategoryForSelectedProducts,
              icon: const Icon(Icons.category_rounded),
            ),
          if (_batchMode)
            IconButton(
              tooltip: 'Excluir selecionados',
              onPressed: _selectedProductIds.isEmpty
                  ? null
                  : _deleteSelectedProducts,
              icon: const Icon(Icons.delete_rounded),
            ),
        ],
      ),
      floatingActionButton: _batchMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _createCatalogProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar produto'),
            ),
      body: AppGradientScene(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final allProducts = widget.store.catalogProducts;
              final visibleProducts = _visibleProducts(allProducts);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: _CatalogContentPanel(
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'Buscar no catálogo por nome ou código',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${visibleProducts.length} de ${formatCountLabel(allProducts.length, 'produto', 'produtos')}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_batchMode) ...[
                                const SizedBox(width: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _selectedProductIds.length == 1
                                          ? '1 selecionado'
                                          : '${_selectedProductIds.length} selecionados',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              PopupMenuButton<_CatalogSortOption>(
                                onSelected: (value) {
                                  setState(() {
                                    _sortOption = value;
                                  });
                                },
                                itemBuilder: (context) => _CatalogSortOption
                                    .values
                                    .map(
                                      (value) =>
                                          PopupMenuItem<_CatalogSortOption>(
                                            value: value,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _sortIcon(value),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(_sortLabel(value)),
                                              ],
                                            ),
                                          ),
                                    )
                                    .toList(growable: false),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_sortIcon(_sortOption), size: 18),
                                        const SizedBox(width: 6),
                                        Text(_sortLabel(_sortOption)),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child:
                                    DropdownButtonFormField<ShoppingCategory?>(
                                      isExpanded: true,
                                      initialValue: _categoryFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Categoria',
                                        prefixIcon: Icon(
                                          Icons.category_rounded,
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<
                                          ShoppingCategory?
                                        >(
                                          value: null,
                                          child: Text('Todas as categorias'),
                                        ),
                                        ...ShoppingCategory.values.map(
                                          (entry) =>
                                              DropdownMenuItem<
                                                ShoppingCategory?
                                              >(
                                                value: entry,
                                                child: Text(entry.label),
                                              ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _categoryFilter = value;
                                        });
                                      },
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                      _CatalogPriceFilter
                                    >(
                                      isExpanded: true,
                                      initialValue: _priceFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Preço',
                                        prefixIcon: Icon(
                                          Icons.attach_money_rounded,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: _CatalogPriceFilter.all,
                                          child: Text('Todos'),
                                        ),
                                        DropdownMenuItem(
                                          value:
                                              _CatalogPriceFilter.withoutPrice,
                                          child: Text('Sem preço'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _priceFilter = value;
                                        });
                                      },
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                selected: _onlyWithBarcode,
                                onSelected: (value) {
                                  setState(() {
                                    _onlyWithBarcode = value;
                                  });
                                },
                                avatar: const Icon(Icons.qr_code_2_rounded),
                                label: const Text('Com código de barras'),
                              ),
                              if (_hasActiveFilters)
                                ActionChip(
                                  avatar: const Icon(Icons.clear_all_rounded),
                                  label: const Text('Limpar filtros'),
                                  onPressed: _clearFilters,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? _CatalogEmptyState(
                            hasQuery: _hasActiveFilters,
                            onCreateProduct: _createCatalogProduct,
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              _batchMode ? 120 : 100,
                            ),
                            itemCount: visibleProducts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final product = visibleProducts[index];
                              final isSelected = _selectedProductIds.contains(
                                product.id,
                              );
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : null,
                                child: InkWell(
                                  onLongPress: () => _toggleSelection(
                                    product.id,
                                    forceSelect: true,
                                  ),
                                  onTap: _batchMode
                                      ? () => _toggleSelection(product.id)
                                      : () => _openProductDetails(product),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      8,
                                      10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_batchMode)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                  top: 2,
                                                ),
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (_) =>
                                                      _toggleSelection(
                                                        product.id,
                                                      ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    product.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textTheme.titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      _CatalogSummaryPill(
                                                        icon: product
                                                            .category
                                                            .icon,
                                                        label: 'Categoria',
                                                        value: product
                                                            .category
                                                            .label,
                                                      ),
                                                      _CatalogSummaryPill(
                                                        icon: Icons
                                                            .history_toggle_off_rounded,
                                                        label: 'Uso',
                                                        value:
                                                            '${product.usageCount}',
                                                      ),
                                                      if (product.barcode !=
                                                              null &&
                                                          product
                                                              .barcode!
                                                              .isNotEmpty)
                                                        _CatalogSummaryPill(
                                                          icon: Icons
                                                              .qr_code_2_rounded,
                                                          label: 'Código',
                                                          value:
                                                              product.barcode!,
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!_batchMode)
                                              PopupMenuButton<
                                                _CatalogProductAction
                                              >(
                                                onSelected: (action) {
                                                  switch (action) {
                                                    case _CatalogProductAction
                                                        .edit:
                                                      _editCatalogProduct(
                                                        product,
                                                      );
                                                      return;
                                                    case _CatalogProductAction
                                                        .updatePrice:
                                                      _updateCatalogPrice(
                                                        product,
                                                      );
                                                      return;
                                                    case _CatalogProductAction
                                                        .delete:
                                                      _deleteCatalogProduct(
                                                        product,
                                                      );
                                                      return;
                                                  }
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(
                                                    value: _CatalogProductAction
                                                        .edit,
                                                    child: Text(
                                                      'Editar produto',
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: _CatalogProductAction
                                                        .updatePrice,
                                                    child: Text(
                                                      'Atualizar preço',
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: _CatalogProductAction
                                                        .delete,
                                                    child: Text(
                                                      'Excluir produto',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              product.unitPrice == null
                                                  ? 'Sem preço'
                                                  : formatCurrency(
                                                      product.unitPrice!,
                                                    ),
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'Atualizado em ${formatShortDate(product.updatedAt)}',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState({
    required this.hasQuery,
    required this.onCreateProduct,
  });

  final bool hasQuery;
  final VoidCallback onCreateProduct;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.local_offer_outlined,
              size: 52,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'Nenhum produto encontrado.'
                  : 'Adicione produtos frequentes',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Tente outro termo de busca.'
                  : 'Salve produtos que você compra sempre para reaproveitar nomes, preços e códigos.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar produto frequente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Duration _catalogAdaptiveMotionDuration(
  BuildContext context,
  Duration fallback,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class _CatalogSummaryPill extends StatelessWidget {
  const _CatalogSummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: _catalogAdaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Text(
                  value,
                  key: ValueKey('$label|$value'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogContentPanel extends StatelessWidget {
  const _CatalogContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}
