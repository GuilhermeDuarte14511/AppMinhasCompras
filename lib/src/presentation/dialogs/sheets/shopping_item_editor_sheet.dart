import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/ports.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../../domain/product_price_analysis.dart';
import '../../extensions/classification_ui_extensions.dart';
import '../../utils/app_modal.dart';
import '../../utils/item_price_insight.dart';
import '../widgets/brl_currency_input_formatter.dart';
import '../widgets/item_editor_support_widgets.dart';
import 'barcode_scanner_sheet.dart';

enum ShoppingItemEditorMode { listItem, catalogProduct }

Future<ShoppingItemDraft?> showShoppingItemEditorSheet(
  BuildContext context, {
  ShoppingItem? existingItem,
  Set<String> blockedNormalizedNames = const <String>{},
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
  Future<ProductLookupResult> Function(String barcode)? onLookupBarcode,
  Future<CatalogProduct?> Function(String name)? onLookupCatalogByName,
  ShoppingItemEditorMode mode = ShoppingItemEditorMode.listItem,
}) {
  return showAppModalBottomSheet<ShoppingItemDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return _ShoppingItemEditorSheet(
        existingItem: existingItem,
        blockedNormalizedNames: blockedNormalizedNames,
        catalogProducts: catalogProducts,
        onLookupBarcode: onLookupBarcode,
        onLookupCatalogByName: onLookupCatalogByName,
        mode: mode,
        allowMultiple: false,
      );
    },
  );
}

Future<List<ShoppingItemDraft>?> showShoppingItemsEditorSheet(
  BuildContext context, {
  Set<String> blockedNormalizedNames = const <String>{},
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
  Future<ProductLookupResult> Function(String barcode)? onLookupBarcode,
  Future<CatalogProduct?> Function(String name)? onLookupCatalogByName,
}) {
  return showAppModalBottomSheet<List<ShoppingItemDraft>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return _ShoppingItemEditorSheet(
        existingItem: null,
        blockedNormalizedNames: blockedNormalizedNames,
        catalogProducts: catalogProducts,
        onLookupBarcode: onLookupBarcode,
        onLookupCatalogByName: onLookupCatalogByName,
        mode: ShoppingItemEditorMode.listItem,
        allowMultiple: true,
      );
    },
  );
}

class _ShoppingItemEditorSheet extends StatefulWidget {
  const _ShoppingItemEditorSheet({
    required this.existingItem,
    required this.blockedNormalizedNames,
    required this.catalogProducts,
    required this.onLookupBarcode,
    required this.onLookupCatalogByName,
    required this.mode,
    required this.allowMultiple,
  });

  final ShoppingItem? existingItem;
  final Set<String> blockedNormalizedNames;
  final List<CatalogProduct> catalogProducts;
  final Future<ProductLookupResult> Function(String barcode)? onLookupBarcode;
  final Future<CatalogProduct?> Function(String name)? onLookupCatalogByName;
  final ShoppingItemEditorMode mode;
  final bool allowMultiple;

  @override
  State<_ShoppingItemEditorSheet> createState() =>
      _ShoppingItemEditorSheetState();
}

class _ShoppingItemEditorSheetState extends State<_ShoppingItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormatter = BrlCurrencyInputFormatter();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  final FocusNode _nameFocusNode = FocusNode();
  late ShoppingCategory _selectedCategory;
  bool _isLookingUpBarcode = false;
  bool _isLookingUpCatalog = false;
  bool _isApplyingCatalogProduct = false;
  late bool _isPurchased;
  String? _lookupFeedback;
  CatalogProduct? _catalogMatch;
  final List<ShoppingItemDraft> _pendingDrafts = <ShoppingItemDraft>[];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingItem?.name ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.existingItem?.barcode ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.existingItem?.quantity.toString() ?? '1',
    );
    _priceController = TextEditingController(
      text: widget.existingItem == null
          ? ''
          : _currencyFormatter.formatValue(widget.existingItem!.unitPrice),
    );
    _selectedCategory =
        widget.existingItem?.category ?? ShoppingCategory.grocery;
    _isPurchased = widget.existingItem?.isPurchased ?? false;
    _catalogMatch = _catalogProductFromExistingItem(widget.existingItem);
    _nameController.addListener(_handleCatalogMatchChanged);
    _barcodeController.addListener(_handleCatalogMatchChanged);
  }

  CatalogProduct? _catalogProductFromExistingItem(ShoppingItem? item) {
    if (item == null) {
      return null;
    }

    final barcode = sanitizeBarcode(item.barcode);
    if (barcode == null || barcode.isEmpty) {
      return null;
    }

    for (final product in widget.catalogProducts) {
      if (product.barcode == barcode) {
        return product;
      }
    }
    return null;
  }

  void _handleCatalogMatchChanged() {
    if (_isApplyingCatalogProduct) {
      return;
    }

    final match = _catalogMatch;
    if (match == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final currentName = normalizeQuery(_nameController.text);
    final catalogName = normalizeQuery(match.name);
    final currentBarcode = sanitizeBarcode(_barcodeController.text) ?? '';
    final catalogBarcode = sanitizeBarcode(match.barcode) ?? '';
    if (currentName == catalogName && currentBarcode == catalogBarcode) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    setState(() {
      _catalogMatch = null;
      if (_lookupFeedback?.startsWith('Sugestão local aplicada') == true) {
        _lookupFeedback = null;
      }
    });
  }

  List<CatalogProduct> get _matchingCatalogSuggestions {
    final query = normalizeQuery(_nameController.text);
    final suggestions = <CatalogProduct>[];
    for (final product in widget.catalogProducts) {
      final normalized = normalizeQuery(product.name);
      final shouldInclude = query.isEmpty ? true : normalized.contains(query);
      if (!shouldInclude ||
          normalized == query ||
          _blockedNormalizedNames.contains(normalized)) {
        continue;
      }
      suggestions.add(product);
    }
    suggestions.sort(_compareCatalogSuggestions);
    return suggestions.take(6).toList(growable: false);
  }

  int _compareCatalogSuggestions(CatalogProduct a, CatalogProduct b) {
    final byUsage = b.usageCount.compareTo(a.usageCount);
    if (byUsage != 0) {
      return byUsage;
    }
    final byDate = b.updatedAt.compareTo(a.updatedAt);
    if (byDate != 0) {
      return byDate;
    }
    return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
  }

  ItemPriceInsight? get _currentPriceInsight {
    final product = _catalogMatch;
    final currentPrice = BrlCurrencyInputFormatter.tryParse(
      _priceController.text,
    );
    final referencePrice = product?.unitPrice;
    if (product == null || currentPrice == null || referencePrice == null) {
      return null;
    }
    return buildPriceInsight(
      currentPrice: currentPrice,
      referencePrice: referencePrice,
    );
  }

  ProductPriceAdvice? get _currentPriceAdvice {
    final product = _catalogMatch;
    final currentPrice = BrlCurrencyInputFormatter.tryParse(
      _priceController.text,
    );
    if (product == null || currentPrice == null || currentPrice <= 0) {
      return null;
    }
    final advice = ProductPriceAdvice.forCurrentPrice(
      history: product.priceHistory,
      currentPrice: currentPrice,
    );
    return _shouldShowPriceAdvice(advice) ? advice : null;
  }

  Future<void> _applySuggestion(CatalogProduct product) async {
    final value = product.name;
    _nameController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    _applyCatalogProduct(product);
    setState(() {
      final latestPrice = product.unitPrice;
      _lookupFeedback = latestPrice != null && latestPrice > 0
          ? 'Sugestão local aplicada com último preço salvo (${formatCurrency(latestPrice)}).'
          : 'Sugestão local aplicada a partir do catálogo.';
    });
  }

  Set<String> get _blockedNormalizedNames {
    return <String>{
      ...widget.blockedNormalizedNames,
      for (final draft in _pendingDrafts) normalizeQuery(draft.name),
    };
  }

  Future<void> _scanBarcode() async {
    final code = await showBarcodeScannerSheet(context);
    if (!mounted || code == null) {
      return;
    }
    _barcodeController
      ..text = code
      ..selection = TextSelection.collapsed(offset: code.length);
    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode([String? rawValue]) async {
    if (widget.onLookupBarcode == null) {
      return;
    }
    final barcode = sanitizeBarcode(rawValue ?? _barcodeController.text);
    if (barcode == null || barcode.isEmpty) {
      return;
    }
    setState(() {
      _isLookingUpBarcode = true;
      _lookupFeedback = null;
    });

    try {
      final result = await widget.onLookupBarcode!(barcode);
      if (!mounted) {
        return;
      }
      _applyLookupResult(result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLookingUpBarcode = false;
        _lookupFeedback =
            'Não foi possível consultar online agora. Continue manualmente.';
      });
    }
  }

  Future<void> _lookupCatalogByName([
    String? rawValue,
    bool silentIfMissing = false,
  ]) async {
    if (widget.onLookupCatalogByName == null) {
      return;
    }
    final query = (rawValue ?? _nameController.text).trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isLookingUpCatalog = true;
    });

    try {
      final result = await widget.onLookupCatalogByName!(query);
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() {
          _isLookingUpCatalog = false;
          _catalogMatch = null;
          if (!silentIfMissing) {
            _lookupFeedback =
                'Nenhum cadastro local encontrado para esse nome.';
          }
        });
        return;
      }
      _applyCatalogProduct(result);
      setState(() {
        _isLookingUpCatalog = false;
        final latestPrice = result.unitPrice;
        _lookupFeedback = latestPrice != null && latestPrice > 0
            ? 'Sugestão local aplicada com último preço salvo (${formatCurrency(latestPrice)}).'
            : 'Sugestão local aplicada a partir do catálogo.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLookingUpCatalog = false;
      });
    }
  }

  void _applyCatalogProduct(CatalogProduct product) {
    _isApplyingCatalogProduct = true;
    try {
      final productName = product.name.trim();

      _nameController
        ..text = productName
        ..selection = TextSelection.collapsed(offset: productName.length);

      _selectedCategory = product.category;

      final barcode = product.barcode;
      _barcodeController
        ..text = barcode ?? ''
        ..selection = TextSelection.collapsed(offset: (barcode ?? '').length);

      final price = product.unitPrice;
      if (price != null && price > 0) {
        _priceController.text = _currencyFormatter.formatValue(price);
        _catalogMatch = product;
        return;
      }
      _priceController.clear();
      _catalogMatch = product;
    } finally {
      _isApplyingCatalogProduct = false;
    }
  }

  void _applyLookupResult(ProductLookupResult result) {
    final sourceMessage = switch (result.source) {
      ProductLookupSource.cosmos => 'Produto encontrado no Cosmos API.',
      ProductLookupSource.openFoodFacts =>
        'Produto encontrado no Open Food Facts.',
      ProductLookupSource.openProductsFacts =>
        'Produto encontrado no Open Products Facts.',
      ProductLookupSource.localCatalog =>
        'Produto encontrado no seu catálogo local.',
      ProductLookupSource.notFound =>
        'Código lido, mas sem resultado online/local. Complete manualmente.',
    };
    final latestPriceMessage =
        (result.unitPrice != null && result.unitPrice! > 0)
        ? ' Último preço salvo: ${formatCurrency(result.unitPrice!)}.'
        : '';
    setState(() {
      _isLookingUpBarcode = false;
      _lookupFeedback = '$sourceMessage$latestPriceMessage';
    });

    final name = result.name?.trim();
    if (name != null && name.isNotEmpty) {
      _nameController
        ..text = name
        ..selection = TextSelection.collapsed(offset: name.length);
    }
    if (result.category != null) {
      _selectedCategory = result.category!;
    }
    if (result.unitPrice != null && result.unitPrice! > 0) {
      _priceController.text = _currencyFormatter.formatValue(result.unitPrice!);
    }
    if (result.priceHistory.isNotEmpty &&
        result.name != null &&
        result.category != null) {
      _catalogMatch = CatalogProduct(
        id: uniqueId(),
        name: result.name!,
        category: result.category!,
        unitPrice: result.unitPrice,
        barcode: result.barcode,
        updatedAt: DateTime.now(),
        priceHistory: result.priceHistory,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleCatalogMatchChanged);
    _barcodeController.removeListener(_handleCatalogMatchChanged);
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  ShoppingItemDraft? _buildDraftFromForm() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    final quantity = widget.mode == ShoppingItemEditorMode.catalogProduct
        ? 1
        : int.tryParse(_quantityController.text.trim());
    final unitPrice = BrlCurrencyInputFormatter.tryParse(_priceController.text);
    if (quantity == null ||
        quantity < 1 ||
        unitPrice == null ||
        unitPrice <= 0) {
      return null;
    }

    return ShoppingItemDraft(
      name: _nameController.text.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      category: _selectedCategory,
      barcode: sanitizeBarcode(_barcodeController.text),
      isPurchased: _isPurchased,
    );
  }

  void _resetFormAfterQueuedDraft(String productName) {
    _formKey.currentState?.reset();
    _nameController.clear();
    _barcodeController.clear();
    _quantityController.text = '1';
    _priceController.clear();
    setState(() {
      _selectedCategory = ShoppingCategory.grocery;
      _isPurchased = false;
      _catalogMatch = null;
      _lookupFeedback = '$productName adicionado. Continue com o próximo.';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  void _addAndContinue() {
    final draft = _buildDraftFromForm();
    if (draft == null) {
      return;
    }
    setState(() {
      _pendingDrafts.add(draft);
    });
    _resetFormAfterQueuedDraft(draft.name);
  }

  void _submit() {
    final draft = _buildDraftFromForm();
    if (draft == null) {
      return;
    }

    if (widget.allowMultiple) {
      Navigator.pop(
        context,
        List<ShoppingItemDraft>.unmodifiable([..._pendingDrafts, draft]),
      );
      return;
    }

    Navigator.pop(context, draft);
  }

  void _handleLastFieldSubmitted() {
    if (widget.allowMultiple && widget.existingItem == null) {
      _addAndContinue();
      return;
    }
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final contentBottomPadding = max(20.0, safeBottomInset + 20);
    final isEditing = widget.existingItem != null;
    final isCatalogMode = widget.mode == ShoppingItemEditorMode.catalogProduct;
    final title = isEditing
        ? (isCatalogMode ? 'Editar produto' : 'Editar item')
        : (isCatalogMode ? 'Novo produto' : 'Novo item');
    final submitLabel = isEditing
        ? (isCatalogMode ? 'Salvar produto' : 'Salvar item')
        : (isCatalogMode ? 'Adicionar produto' : 'Adicionar item');
    final nameLabel = isCatalogMode ? 'Produto' : 'Item';
    final priceInsight = _currentPriceInsight;
    final priceAdvice = _currentPriceAdvice;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 6, 20, contentBottomPadding),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scanner opcional: você pode escanear ou preencher tudo na mão.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Busque no catálogo ou preencha manualmente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Ler código de barras'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Buscar código',
                    onPressed: _isLookingUpBarcode ? null : _lookupBarcode,
                    icon: _isLookingUpBarcode
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.1),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Código de barras (opcional)',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  suffixIcon: _barcodeController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _barcodeController.clear();
                            setState(() {
                              _lookupFeedback = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (_) => _handleCatalogMatchChanged(),
                onFieldSubmitted: (_) => _lookupBarcode(),
              ),
              if (_lookupFeedback != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lookupFeedback!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                autofocus: !isEditing,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: nameLabel,
                  prefixIcon: const Icon(Icons.local_grocery_store_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar no catálogo local',
                    onPressed: _isLookingUpCatalog
                        ? null
                        : () => _lookupCatalogByName(),
                    icon: _isLookingUpCatalog
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.1),
                          )
                        : const Icon(Icons.manage_search_rounded),
                  ),
                ),
                validator: (value) {
                  final normalized = normalizeQuery(value ?? '');
                  if (normalized.isEmpty) {
                    return isCatalogMode
                        ? 'Digite o nome do produto.'
                        : 'Digite o nome do item.';
                  }
                  if (_blockedNormalizedNames.contains(normalized)) {
                    return isCatalogMode
                        ? 'Esse produto já existe no catálogo.'
                        : 'Esse item já existe na lista.';
                  }
                  return null;
                },
                onChanged: (_) => _handleCatalogMatchChanged(),
                onFieldSubmitted: (_) => _lookupCatalogByName(),
              ),
              if (_matchingCatalogSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Produtos encontrados',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Column(
                  children: [
                    for (final suggestion in _matchingCatalogSuggestions)
                      CatalogSuggestionTile(
                        product: suggestion,
                        onTap: () => unawaited(_applySuggestion(suggestion)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<ShoppingCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final category in ShoppingCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(category.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (isCatalogMode)
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _currencyFormatter,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixIcon: Icon(Icons.monetization_on_rounded),
                    hintText: 'R\$ 0,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final parsed = BrlCurrencyInputFormatter.tryParse(
                      value ?? '',
                    );
                    if (parsed == null || parsed <= 0) {
                      return 'Informe um valor válido.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleLastFieldSubmitted(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 1) {
                            return 'Informe uma quantidade válida.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _currencyFormatter,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Valor unitário',
                          prefixIcon: Icon(Icons.monetization_on_rounded),
                          hintText: 'R\$ 0,00',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final parsed = BrlCurrencyInputFormatter.tryParse(
                            value ?? '',
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Informe um valor válido.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleLastFieldSubmitted(),
                      ),
                    ),
                  ],
                ),
              if (!isCatalogMode) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _isPurchased,
                  onChanged: (value) {
                    setState(() {
                      _isPurchased = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Já peguei este item'),
                  subtitle: const Text('O item entra como comprado.'),
                ),
              ],
              if (priceInsight != null) ...[
                const SizedBox(height: 10),
                ItemPriceInsightBanner(insight: priceInsight),
              ],
              if (priceAdvice != null) ...[
                const SizedBox(height: 10),
                LocalPriceAdviceBanner(advice: priceAdvice),
              ],
              if (_catalogMatch != null) ...[
                const SizedBox(height: 10),
                CatalogPriceHint(product: _catalogMatch!),
              ],
              const SizedBox(height: 20),
              if (widget.allowMultiple && _pendingDrafts.isNotEmpty) ...[
                PendingDraftsPreview(drafts: _pendingDrafts),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        List<ShoppingItemDraft>.unmodifiable(_pendingDrafts),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Concluir seleção'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.allowMultiple)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addAndContinue,
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Adicionar e continuar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar item'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      isEditing ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    label: Text(submitLabel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _shouldShowPriceAdvice(ProductPriceAdvice advice) {
  return switch (advice.type) {
    ProductPriceAdviceType.bestPrice ||
    ProductPriceAdviceType.goodPrice ||
    ProductPriceAdviceType.highPrice ||
    ProductPriceAdviceType.recordHigh => true,
    ProductPriceAdviceType.noPrice ||
    ProductPriceAdviceType.learning ||
    ProductPriceAdviceType.normalPrice => false,
  };
}
