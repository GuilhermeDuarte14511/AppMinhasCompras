import 'package:flutter/material.dart';

import '../application/store_and_services.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'theme/editorial_workspace_theme.dart';
import 'catalog/catalog_controls.dart';
import 'catalog/catalog_product_row.dart';
import 'product_details_page.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class CatalogProductsPage extends StatefulWidget {
  const CatalogProductsPage({super.key, required this.store});

  final ShoppingListsStore store;

  @override
  State<CatalogProductsPage> createState() => _CatalogProductsPageState();
}

class _CatalogProductsPageState extends State<CatalogProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  CatalogSortOption _sortOption = CatalogSortOption.updatedAt;
  CatalogPriceFilter _priceFilter = CatalogPriceFilter.all;
  ShoppingCategory? _categoryFilter;
  bool _onlyWithBarcode = false;
  bool _batchMode = false;
  final Set<String> _selectedProductIds = <String>{};

  String get _searchQuery => _searchController.text.trim();
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _categoryFilter != null ||
      _onlyWithBarcode ||
      _priceFilter != CatalogPriceFilter.all;

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

  Future<void> _addToPantry(CatalogProduct product) async {
    await widget.store.addCatalogProductToPantry(product);
    if (!mounted) {
      return;
    }
    _showSnack(
      '${product.name} foi adicionado à despensa.',
      type: AppToastType.success,
    );
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
      _priceFilter = CatalogPriceFilter.all;
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
          if (_priceFilter == CatalogPriceFilter.withoutPrice &&
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
        case CatalogSortOption.updatedAt:
          return b.updatedAt.compareTo(a.updatedAt);
        case CatalogSortOption.name:
          return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
        case CatalogSortOption.usage:
          return b.usageCount.compareTo(a.usageCount);
        case CatalogSortOption.price:
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

  Future<void> _createCatalogProduct({bool scanBarcode = false}) async {
    final blockedNames = widget.store.catalogProducts
        .map((product) => normalizeQuery(product.name))
        .toSet();
    final draft = await showShoppingItemEditorSheet(
      context,
      startBarcodeScan: scanBarcode,
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
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final allProducts = widget.store.catalogProducts;
          final visibleProducts = _visibleProducts(allProducts);
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
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    key: const ValueKey('catalog_scroll'),
                    slivers: [
                      SliverToBoxAdapter(
                        child: CatalogControls(
                          controller: _searchController,
                          products: allProducts,
                          category: _categoryFilter,
                          sort: _sortOption,
                          priceFilter: _priceFilter,
                          onlyWithBarcode: _onlyWithBarcode,
                          hasFilters: _hasActiveFilters,
                          visibleCount: visibleProducts.length,
                          batchMode: _batchMode,
                          onCategory: (value) =>
                              setState(() => _categoryFilter = value),
                          onSort: (value) =>
                              setState(() => _sortOption = value),
                          onPrice: (value) =>
                              setState(() => _priceFilter = value),
                          onBarcode: (value) =>
                              setState(() => _onlyWithBarcode = value),
                          onClear: _clearFilters,
                          onCreate: _createCatalogProduct,
                          onScan: () =>
                              _createCatalogProduct(scanBarcode: true),
                        ),
                      ),
                      if (visibleProducts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _CatalogEmptyState(
                            hasQuery: _hasActiveFilters,
                            onCreateProduct: _createCatalogProduct,
                          ),
                        )
                      else
                        SliverList.separated(
                          itemCount: visibleProducts.length,
                          separatorBuilder: (_, index) => Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: .5),
                          ),
                          itemBuilder: (context, index) {
                            final product = visibleProducts[index];
                            return CatalogProductRow(
                              key: ValueKey('catalog_product_${product.id}'),
                              product: product,
                              batchMode: _batchMode,
                              selected: _selectedProductIds.contains(
                                product.id,
                              ),
                              onLongPress: () => _toggleSelection(
                                product.id,
                                forceSelect: true,
                              ),
                              onTap: _batchMode
                                  ? () => _toggleSelection(product.id)
                                  : () => _openProductDetails(product),
                              onAction: (action) {
                                switch (action) {
                                  case CatalogProductAction.addToPantry:
                                    _addToPantry(product);
                                  case CatalogProductAction.edit:
                                    _editCatalogProduct(product);
                                  case CatalogProductAction.updatePrice:
                                    _updateCatalogPrice(product);
                                  case CatalogProductAction.delete:
                                    _deleteCatalogProduct(product);
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  '${visibleProducts.length} de ${allProducts.length} produtos exibidos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
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
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'Nenhum produto encontrado.'
                  : 'Adicione produtos frequentes',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
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
