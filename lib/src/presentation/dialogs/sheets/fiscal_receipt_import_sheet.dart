import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/fiscal_receipt_import.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/services/fiscal_receipt_parser.dart';
import '../../../data/services/receipt_ocr_text_normalizer.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../../domain/receipt_item_matcher.dart';
import '../widgets/item_editor_support_widgets.dart';

enum _ReceiptImportStep { capture, review }

class FiscalReceiptImportSheet extends StatefulWidget {
  const FiscalReceiptImportSheet({
    super.key,
    this.currentItems = const <ShoppingItem>[],
    this.catalogProducts = const <CatalogProduct>[],
  });

  final List<ShoppingItem> currentItems;
  final List<CatalogProduct> catalogProducts;

  @override
  State<FiscalReceiptImportSheet> createState() =>
      _FiscalReceiptImportSheetState();
}

class _FiscalReceiptImportSheetState extends State<FiscalReceiptImportSheet> {
  final FiscalReceiptParser _parser = const FiscalReceiptParser();
  final ReceiptItemMatcher _matcher = const ReceiptItemMatcher();
  final ReceiptOcrTextNormalizer _ocrTextNormalizer =
      const ReceiptOcrTextNormalizer();
  final TextEditingController _rawTextController = TextEditingController();
  final GlobalKey<FormState> _reviewFormKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  FiscalReceiptParseResult _parseResult = const FiscalReceiptParseResult(
    items: <ShoppingItemDraft>[],
  );
  List<ReceiptItemMatchResult> _matchResults = const <ReceiptItemMatchResult>[];
  List<_EditableReceiptLine> _reviewLines = <_EditableReceiptLine>[];
  _ReceiptImportStep _step = _ReceiptImportStep.capture;
  bool _isExtractingFromImage = false;
  bool _finalizePurchase = true;
  String? _ocrFeedback;
  String? _reviewError;

  @override
  void initState() {
    super.initState();
    _rawTextController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _rawTextController.removeListener(_onTextChanged);
    _rawTextController.dispose();
    for (final line in _reviewLines) {
      line.dispose();
    }
    unawaited(_textRecognizer.close());
    super.dispose();
  }

  int get _selectedCount =>
      _reviewLines.where((line) => line.isSelected).length;

  int get _selectedUnits => _reviewLines
      .where((line) => line.isSelected)
      .fold<int>(0, (sum, line) => sum + line.quantity);

  double get _selectedTotal => _reviewLines
      .where((line) => line.isSelected)
      .fold<double>(0, (sum, line) => sum + line.subtotal);

  double? get _difference {
    final declared = _parseResult.declaredTotal;
    return declared == null ? null : _selectedTotal - declared;
  }

  bool get _hasRelevantDifference {
    final difference = _difference;
    return difference != null && difference.abs() > 0.05;
  }

  void _onTextChanged() {
    final result = _parser.parseReceipt(_rawTextController.text);
    final matches = _matcher.matchAll(
      result.items,
      currentItems: widget.currentItems,
      catalogProducts: widget.catalogProducts,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _parseResult = result;
      _matchResults = matches;
      _ocrFeedback = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (!mounted || text == null || text.trim().isEmpty) {
      return;
    }
    _rawTextController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _importFromImage(ImageSource source) async {
    if (_isExtractingFromImage) {
      return;
    }
    setState(() {
      _isExtractingFromImage = true;
      _ocrFeedback = null;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() {
          _isExtractingFromImage = false;
          _ocrFeedback = 'Nenhuma imagem selecionada.';
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted) {
        return;
      }
      final extractedText = _ocrTextNormalizer.normalize(recognizedText);
      if (extractedText.isEmpty) {
        setState(() {
          _isExtractingFromImage = false;
          _ocrFeedback =
              'Não encontramos texto suficiente. Fotografe o cupom inteiro e tente novamente.';
        });
        return;
      }

      final currentText = _rawTextController.text.trim();
      final merged = currentText.isEmpty
          ? extractedText
          : '$currentText\n$extractedText';
      _rawTextController
        ..text = merged
        ..selection = TextSelection.collapsed(offset: merged.length);
      setState(() {
        _isExtractingFromImage = false;
        _ocrFeedback = 'Texto extraído. Revise os itens antes de confirmar.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExtractingFromImage = false;
        _ocrFeedback =
            'Não foi possível ler a imagem. Escolha outra foto e tente novamente.';
      });
    }
  }

  void _startReview() {
    if (_parseResult.items.isEmpty) {
      return;
    }
    for (final line in _reviewLines) {
      line.dispose();
    }
    _reviewLines = <_EditableReceiptLine>[
      for (var index = 0; index < _parseResult.items.length; index++)
        _EditableReceiptLine.fromMatch(_matchResults[index]),
    ];
    setState(() {
      _step = _ReceiptImportStep.review;
      _reviewError = null;
    });
  }

  void _backToCapture() {
    setState(() {
      _step = _ReceiptImportStep.capture;
      _reviewError = null;
    });
  }

  void _setAllSelected(bool selected) {
    setState(() {
      for (final line in _reviewLines) {
        line.isSelected = selected;
      }
      _reviewError = null;
    });
  }

  void _toggleLine(_EditableReceiptLine line, bool selected) {
    setState(() {
      line.isSelected = selected;
      _reviewError = null;
    });
  }

  void _linkPlannedItem(_EditableReceiptLine line, String value) {
    final plannedId = value.trim();
    ShoppingItem? planned;
    if (plannedId.isNotEmpty) {
      for (final item in widget.currentItems) {
        if (item.id == plannedId) {
          planned = item;
          break;
        }
      }
    }
    setState(() {
      line.plannedItemId = planned?.id;
      if (planned != null) {
        line.nameController.text = planned.name;
        line.category = planned.category;
        line.barcode = planned.barcode ?? line.barcode;
      }
      _reviewError = null;
    });
  }

  void _submitReview() {
    setState(() {
      _reviewError = null;
    });
    if (!_reviewFormKey.currentState!.validate()) {
      setState(() {
        _reviewError = 'Revise os campos destacados antes de continuar.';
      });
      return;
    }

    final selected = _reviewLines
        .where((line) => line.isSelected)
        .toList(growable: false);
    if (selected.isEmpty) {
      setState(() {
        _reviewError = 'Selecione pelo menos um item do cupom.';
      });
      return;
    }

    final linkedIds = <String>{};
    for (final line in selected) {
      final plannedId = line.plannedItemId;
      if (plannedId != null && !linkedIds.add(plannedId)) {
        setState(() {
          _reviewError =
              'Cada item planejado pode ser relacionado a apenas uma linha.';
        });
        return;
      }
    }

    Navigator.pop(
      context,
      FiscalReceiptReviewSubmission(
        items: List<FiscalReceiptReviewedItem>.unmodifiable(
          selected.map(
            (line) => FiscalReceiptReviewedItem(
              draft: line.toDraft(),
              plannedItemId: line.plannedItemId,
            ),
          ),
        ),
        finalizePurchase: _finalizePurchase,
        declaredTotal: _parseResult.declaredTotal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final availableHeight = max(420.0, mediaQuery.size.height - keyboardInset);
    final sheetHeight = min(availableHeight * 0.96, 840.0);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16 + mediaQuery.viewPadding.bottom,
          ),
          child: _step == _ReceiptImportStep.capture
              ? _buildCaptureStep(context)
              : _buildReviewStep(context),
        ),
      ),
    );
  }

  Widget _buildCaptureStep(BuildContext context) {
    final hasInput = _rawTextController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
          title: 'Ler cupom fiscal',
          description:
              'Fotografe ou cole o texto. Você poderá revisar tudo antes de aplicar.',
          icon: Icons.document_scanner_rounded,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isExtractingFromImage ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Colar texto'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isExtractingFromImage
                  ? null
                  : () => _importFromImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Escolher foto'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isExtractingFromImage
                  ? null
                  : () => _importFromImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Fotografar cupom'),
            ),
            if (hasInput)
              OutlinedButton.icon(
                onPressed: _isExtractingFromImage
                    ? null
                    : _rawTextController.clear,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Limpar texto'),
              ),
          ],
        ),
        if (_isExtractingFromImage) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (_ocrFeedback != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _ocrFeedback!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _rawTextController,
            minLines: null,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Texto do cupom',
              helperText: 'O texto permanece editável antes da revisão.',
              hintText:
                  'Exemplo:\nLEITE INTEGRAL 2 X 5,49 10,98\nARROZ T1 1 X 24,90 24,90',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CaptureSummary(parseResult: _parseResult, hasInput: hasInput),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _parseResult.items.isEmpty ? null : _startReview,
                icon: const Icon(Icons.fact_check_rounded),
                label: Text(
                  _parseResult.items.isEmpty
                      ? 'Revisar itens'
                      : 'Revisar ${_parseResult.items.length} itens',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return Form(
      key: _reviewFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: 'Revisar compra',
            description:
                'Selecione os itens, corrija os valores e relacione-os à sua lista.',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCountLabel(
                    _selectedCount,
                    'item selecionado',
                    'itens selecionados',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _setAllSelected(_selectedCount != _reviewLines.length),
                child: Text(
                  _selectedCount == _reviewLines.length
                      ? 'Desmarcar todos'
                      : 'Selecionar todos',
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _reviewLines.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = _reviewLines[index];
                return _ReceiptReviewCard(
                  index: index,
                  line: line,
                  plannedItems: widget.currentItems,
                  onSelectedChanged: (selected) => _toggleLine(line, selected),
                  onPlannedItemChanged: (value) =>
                      _linkPlannedItem(line, value),
                  onValueChanged: () => setState(() {
                    _reviewError = null;
                  }),
                );
              },
            ),
          ),
          _ReceiptTotalsPanel(
            selectedCount: _selectedCount,
            selectedUnits: _selectedUnits,
            selectedTotal: _selectedTotal,
            declaredTotal: _parseResult.declaredTotal,
            difference: _difference,
            hasRelevantDifference: _hasRelevantDifference,
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _finalizePurchase,
            onChanged: (value) => setState(() {
              _finalizePurchase = value;
            }),
            title: const Text('Fechar lista e salvar no histórico'),
            subtitle: const Text(
              'Os itens selecionados serão marcados como comprados e atualizarão seus preços.',
            ),
          ),
          if (_reviewError != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _reviewError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backToCapture,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Editar texto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _selectedCount == 0 ? null : _submitReview,
                  icon: Icon(
                    _finalizePurchase
                        ? Icons.task_alt_rounded
                        : Icons.playlist_add_check_rounded,
                  ),
                  label: Text(
                    _finalizePurchase ? 'Confirmar compra' : 'Aplicar à lista',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableReceiptLine {
  _EditableReceiptLine({
    required this.match,
    required this.nameController,
    required this.quantityController,
    required this.priceController,
    required this.category,
    required this.barcode,
    required this.plannedItemId,
  });

  factory _EditableReceiptLine.fromMatch(ReceiptItemMatchResult match) {
    final draft = match.resolvedDraft;
    final candidate = match.candidate;
    final plannedId =
        match.hasAppliedMatch &&
            candidate?.source == ReceiptItemMatchSource.currentList
        ? candidate!.id
        : null;
    return _EditableReceiptLine(
      match: match,
      nameController: TextEditingController(text: draft.name),
      quantityController: TextEditingController(
        text: draft.quantity.toString(),
      ),
      priceController: TextEditingController(
        text: draft.unitPrice.toStringAsFixed(2).replaceAll('.', ','),
      ),
      category: draft.category,
      barcode: draft.barcode,
      plannedItemId: plannedId,
    );
  }

  final ReceiptItemMatchResult match;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  ShoppingCategory category;
  String? barcode;
  String? plannedItemId;
  bool isSelected = true;

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;
  double get unitPrice => _parseCurrency(priceController.text) ?? 0;
  double get subtotal => quantity * unitPrice;

  ShoppingItemDraft toDraft() {
    return ShoppingItemDraft(
      name: nameController.text.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      category: category,
      barcode: barcode,
      isPurchased: true,
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaptureSummary extends StatelessWidget {
  const _CaptureSummary({required this.parseResult, required this.hasInput});

  final FiscalReceiptParseResult parseResult;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    if (parseResult.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        ),
        child: Text(
          hasInput
              ? 'Nenhum item reconhecido. Confira o texto ou tente outra foto.'
              : 'Adicione o cupom para começar a revisão.',
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ReceiptStatChip(
            icon: Icons.receipt_long_rounded,
            text: formatItemCount(parseResult.items.length),
          ),
          ReceiptStatChip(
            icon: Icons.attach_money_rounded,
            text: formatCurrency(parseResult.recognizedTotal),
          ),
          if (parseResult.declaredTotal != null)
            ReceiptStatChip(
              icon: Icons.request_quote_rounded,
              text: 'Cupom ${formatCurrency(parseResult.declaredTotal!)}',
            ),
        ],
      ),
    );
  }
}

class _ReceiptReviewCard extends StatelessWidget {
  const _ReceiptReviewCard({
    required this.index,
    required this.line,
    required this.plannedItems,
    required this.onSelectedChanged,
    required this.onPlannedItemChanged,
    required this.onValueChanged,
  });

  final int index;
  final _EditableReceiptLine line;
  final List<ShoppingItem> plannedItems;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<String> onPlannedItemChanged;
  final VoidCallback onValueChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: line.isSelected ? 1 : 0.62,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: line.isSelected
                ? colorScheme.primary.withValues(alpha: 0.35)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    label: line.isSelected
                        ? 'Remover item ${index + 1} da importação'
                        : 'Selecionar item ${index + 1} para importar',
                    child: Checkbox.adaptive(
                      value: line.isSelected,
                      onChanged: (value) => onSelectedChanged(value ?? false),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Item ${index + 1}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _ConfidenceBadge(match: line.match),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: line.nameController,
                enabled: line.isSelected,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Produto',
                  prefixIcon: Icon(Icons.shopping_basket_outlined),
                ),
                validator: (value) {
                  if (!line.isSelected) {
                    return null;
                  }
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o produto.';
                  }
                  return null;
                },
                onChanged: (_) => onValueChanged(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: line.plannedItemId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relacionar à lista',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Não relacionar'),
                  ),
                  for (final item in plannedItems)
                    DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: line.isSelected
                    ? (value) => onPlannedItemChanged(value ?? '')
                    : null,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final quantityField = TextFormField(
                    controller: line.quantityController,
                    enabled: line.isSelected,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: (value) {
                      if (!line.isSelected) {
                        return null;
                      }
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Use 1 ou mais.';
                      }
                      return null;
                    },
                    onChanged: (_) => onValueChanged(),
                  );
                  final priceField = TextFormField(
                    controller: line.priceController,
                    enabled: line.isSelected,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Preço unitário',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (value) {
                      if (!line.isSelected) {
                        return null;
                      }
                      final parsed = _parseCurrency(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Informe um preço válido.';
                      }
                      return null;
                    },
                    onChanged: (_) => onValueChanged(),
                  );

                  if (constraints.maxWidth < 480) {
                    return Column(
                      children: [
                        quantityField,
                        const SizedBox(height: 10),
                        priceField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 10),
                      Expanded(child: priceField),
                    ],
                  );
                },
              ),
              if (line.isSelected) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Subtotal ${formatCurrency(line.subtotal)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.match});

  final ReceiptItemMatchResult match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (match.confidence) {
      ReceiptItemMatchConfidence.exact => (
        'Exata ${match.matchPercent}%',
        Icons.verified_rounded,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      ReceiptItemMatchConfidence.high => (
        'Alta ${match.matchPercent}%',
        Icons.check_circle_rounded,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      ReceiptItemMatchConfidence.medium => (
        'Média ${match.matchPercent}%',
        Icons.rule_rounded,
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      ReceiptItemMatchConfidence.low => (
        'Baixa ${match.matchPercent}%',
        Icons.warning_amber_rounded,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      ReceiptItemMatchConfidence.none => (
        'Sem vínculo',
        Icons.link_off_rounded,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Confiança da correspondência: $label',
      child: Tooltip(
        message: 'Compara o texto do cupom com sua lista e seu catálogo.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptTotalsPanel extends StatelessWidget {
  const _ReceiptTotalsPanel({
    required this.selectedCount,
    required this.selectedUnits,
    required this.selectedTotal,
    required this.declaredTotal,
    required this.difference,
    required this.hasRelevantDifference,
  });

  final int selectedCount;
  final int selectedUnits;
  final double selectedTotal;
  final double? declaredTotal;
  final double? difference;
  final bool hasRelevantDifference;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDeclaredTotal = declaredTotal != null;
    final background = hasRelevantDifference
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = hasRelevantDifference
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    final message = !hasDeclaredTotal
        ? 'O total do cupom não foi identificado. Confira os valores.'
        : hasRelevantDifference
        ? 'A soma difere do cupom em ${formatCurrency(difference!.abs())}. Revise itens, quantidades e preços.'
        : 'A soma dos itens confere com o total do cupom.';

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ReceiptStatChip(
                  icon: Icons.checklist_rounded,
                  text: formatItemCount(selectedCount),
                ),
                ReceiptStatChip(
                  icon: Icons.confirmation_number_outlined,
                  text: formatUnitCount(selectedUnits),
                ),
                ReceiptStatChip(
                  icon: Icons.calculate_outlined,
                  text: formatCurrency(selectedTotal),
                ),
                if (hasDeclaredTotal)
                  ReceiptStatChip(
                    icon: Icons.receipt_long_rounded,
                    text: 'Cupom ${formatCurrency(declaredTotal!)}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasRelevantDifference
                      ? Icons.error_outline_rounded
                      : hasDeclaredTotal
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: foreground,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

double? _parseCurrency(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[^0-9,.]'), '');
  if (value.isEmpty) {
    return null;
  }
  final lastComma = value.lastIndexOf(',');
  final lastDot = value.lastIndexOf('.');
  final decimalIndex = max(lastComma, lastDot);
  if (decimalIndex >= 0) {
    final integer = value
        .substring(0, decimalIndex)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final decimals = value
        .substring(decimalIndex + 1)
        .replaceAll(RegExp(r'[^0-9]'), '');
    value = '$integer.$decimals';
  } else {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
  }
  return double.tryParse(value);
}
