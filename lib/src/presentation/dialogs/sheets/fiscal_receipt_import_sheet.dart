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
import '../widgets/item_editor_theme.dart';

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
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text;
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        setState(
          () => _ocrFeedback =
              'Nenhum texto para colar. Copie o texto do cupom e tente novamente.',
        );
        return;
      }
      _rawTextController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _ocrFeedback =
            'Não foi possível colar. Digite o texto ou escolha uma foto.',
      );
    }
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
        for (final line in _reviewLines) {
          if (line.isSelected &&
              (line.nameController.text.trim().isEmpty ||
                  line.quantity <= 0 ||
                  line.unitPrice <= 0)) {
            line.isEditing = true;
          }
        }
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
  Widget build(BuildContext context) => Theme(
    data: itemEditorTheme(Theme.of(context)),
    child: Builder(builder: _buildSheet),
  );

  Widget _buildSheet(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight = max(
      0.0,
      media.size.height - keyboardInset - media.padding.top,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: min(
          availableHeight * .96,
          _step == _ReceiptImportStep.capture
              ? 550 * media.textScaler.scale(1).clamp(1, 1.4)
              : 900,
        ),
        child: Material(
          color: colors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == _ReceiptImportStep.review)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                if (_step == _ReceiptImportStep.capture)
                  _buildCaptureHeader(context)
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                        Expanded(
                          child: Text(
                            _step == _ReceiptImportStep.capture
                                ? 'Importar cupom fiscal'
                                : 'Revisar compra',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 22),
                          ),
                        ),
                        TextButton(
                          onPressed: _selectedCount == 0
                              ? null
                              : () {
                                  final selected = _reviewLines.where(
                                    (line) => line.isSelected,
                                  );
                                  final edit = selected.any(
                                    (line) => !line.isEditing,
                                  );
                                  setState(() {
                                    for (final line in selected) {
                                      line.isEditing = edit;
                                    }
                                  });
                                },
                          child: Tooltip(
                            message: 'Editar itens selecionados',
                            child: Text(
                              _reviewLines
                                      .where((line) => line.isSelected)
                                      .any((line) => !line.isEditing)
                                  ? 'Editar'
                                  : 'Concluir',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _step == _ReceiptImportStep.capture
                      ? _buildCaptureStep(context)
                      : _buildReviewStep(context),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ler cupom fiscal',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          Text(
            'Fotografe ou cole o texto. Você poderá revisar tudo antes de aplicar.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureStep(BuildContext context) {
    final theme = Theme.of(context);
    final hasInput = _rawTextController.text.trim().isNotEmpty;
    final rawLines = _rawTextController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = <Widget>[
                _captureAction(
                  context,
                  'Colar texto',
                  Icons.content_paste,
                  _pasteFromClipboard,
                ),
                _captureAction(
                  context,
                  'Escolher foto',
                  Icons.photo_library_outlined,
                  () => _importFromImage(ImageSource.gallery),
                ),
                _captureAction(
                  context,
                  'Fotografar',
                  Icons.photo_camera_outlined,
                  () => _importFromImage(ImageSource.camera),
                ),
                if (hasInput)
                  _captureAction(
                    context,
                    'Limpar texto',
                    Icons.delete_outline,
                    _rawTextController.clear,
                    destructive: true,
                  ),
              ];
              final columns =
                  constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2
                  ? 2
                  : actions.length;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    SizedBox(width: width, child: action),
                ],
              );
            },
          ),
          if (_isExtractingFromImage) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_ocrFeedback != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_ocrFeedback!, style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Texto do cupom',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasInput)
                Text(
                  formatCountLabel(
                    rawLines,
                    'linha de texto',
                    'linhas de texto',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _rawTextController,
            minLines: 4,
            maxLines: 7,
            enabled: !_isExtractingFromImage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              labelText: 'Texto do cupom',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              hintText: 'Cole ou edite as linhas do cupom...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _CaptureSummary(parseResult: _parseResult, hasInput: hasInput),
        ],
      ),
    );
  }

  Widget _captureAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback action, {
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: _isExtractingFromImage ? null : action,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 80),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: destructive ? colors.error : colors.onSurface,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: destructive ? colors.error : colors.primary,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) => Form(
    key: _reviewFormKey,
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selecione os itens, corrija os valores e relacione-os à sua lista.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCountLabel(
                    _selectedCount,
                    'item selecionado',
                    'itens selecionados',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
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
          for (var index = 0; index < _reviewLines.length; index++)
            _ReceiptReviewCard(
              index: index,
              line: _reviewLines[index],
              plannedItems: widget.currentItems,
              onSelectedChanged: (selected) =>
                  _toggleLine(_reviewLines[index], selected),
              onPlannedItemChanged: (value) =>
                  _linkPlannedItem(_reviewLines[index], value),
              onValueChanged: () => setState(() => _reviewError = null),
            ),
          const SizedBox(height: 20),
          _ReceiptTotalsPanel(
            selectedCount: _selectedCount,
            selectedUnits: _selectedUnits,
            selectedTotal: _selectedTotal,
            declaredTotal: _parseResult.declaredTotal,
            difference: _difference,
            hasRelevantDifference: _hasRelevantDifference,
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              value: _finalizePurchase,
              onChanged: (value) => setState(() => _finalizePurchase = value),
              title: Text(
                'Fechar lista e salvar no histórico',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Os itens selecionados serão marcados como comprados e atualizarão seus preços.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_reviewError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _reviewError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildFooter(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final review = _step == _ReceiptImportStep.review;
    if (review) {
      final edit = OutlinedButton(
        onPressed: _backToCapture,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Editar texto'),
      );
      final confirm = FilledButton.icon(
        onPressed: _selectedCount == 0 ? null : _submitReview,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.arrow_forward, size: 18),
        iconAlignment: IconAlignment.end,
        label: Text(_finalizePurchase ? 'Confirmar compra' : 'Aplicar à lista'),
      );
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [edit, const SizedBox(height: 8), confirm],
              );
            }
            return Row(
              children: [
                Expanded(child: edit),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: confirm),
              ],
            );
          },
        ),
      );
    }
    final cancel = OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Cancelar'),
    );
    final reviewButton = FilledButton(
      onPressed: _parseResult.items.isEmpty || _isExtractingFromImage
          ? null
          : _startReview,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _parseResult.items.isEmpty
                  ? 'Revisar itens'
                  : 'Revisar ${formatItemCount(_parseResult.items.length)}',
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.2) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cancel, const SizedBox(height: 8), reviewButton],
            );
          }
          return Row(
            children: [
              Expanded(child: cancel),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: reviewButton),
            ],
          );
        },
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
  bool isEditing = false;

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

class _CaptureSummary extends StatelessWidget {
  const _CaptureSummary({required this.parseResult, required this.hasInput});
  final FiscalReceiptParseResult parseResult;
  final bool hasInput;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          parseResult.items.isEmpty
              ? hasInput
                    ? 'Nenhum item reconhecido. Confira o texto ou tente outra foto.'
                    : 'Adicione o cupom para começar a revisão.'
              : formatItemCount(parseResult.items.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (parseResult.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _totalRow(
            context,
            'Soma reconhecida',
            formatCurrency(parseResult.recognizedTotal),
          ),
          if (parseResult.declaredTotal != null) ...[
            const SizedBox(height: 8),
            _totalRow(
              context,
              'Total declarado',
              'Cupom ${formatCurrency(parseResult.declaredTotal!)}',
            ),
          ],
        ],
      ],
    ),
  );
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
    return Padding(
      padding: EdgeInsets.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1,
        child: Material(
          color: colorScheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
                        line.nameController.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (line.isSelected)
                      Flexible(
                        child: Text(
                          'Subtotal ${formatCurrency(line.subtotal)}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${line.quantity} × ${formatCurrency(line.unitPrice)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      line.category.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    _ConfidenceBadge(match: line.match),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_outlined,
                            size: 15,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              line.plannedItemId == null
                                  ? 'Não relacionado à lista'
                                  : 'Relacionado a: ${plannedItems.where((item) => item.id == line.plannedItemId).map((item) => item.name).firstOrNull ?? "Item da lista"}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: line.isSelected
                          ? () {
                              line.isEditing = !line.isEditing;
                              onValueChanged();
                            }
                          : null,
                      icon: Icon(
                        line.isEditing
                            ? Icons.expand_less
                            : Icons.edit_outlined,
                        size: 15,
                      ),
                      label: Text(
                        line.isEditing ? 'Concluir edição' : 'Editar',
                      ),
                    ),
                  ],
                ),
                Offstage(
                  offstage: !line.isEditing,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final quantityField = TextFormField(
                            controller: line.quantityController,
                            enabled: line.isSelected,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
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

                          if (constraints.maxWidth < 260 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.2) {
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
                    ],
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
        colorScheme.surfaceContainerLow,
        colorScheme.onSurface,
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
        colorScheme.surfaceContainerLow,
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
            borderRadius: BorderRadius.circular(4),
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
                  fontWeight: FontWeight.w500,
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
    final message = !hasDeclaredTotal
        ? 'O total do cupom não foi identificado. Confira os valores.'
        : hasRelevantDifference
        ? 'A soma difere do cupom em ${formatCurrency(difference!.abs())}. Revise itens, quantidades e preços.'
        : 'A soma dos itens confere com o total do cupom.';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _totalRow(
              context,
              'Selecionados',
              '${formatItemCount(selectedCount)} · ${formatUnitCount(selectedUnits)}',
            ),
            const SizedBox(height: 8),
            _totalRow(
              context,
              'Soma reconhecida',
              formatCurrency(selectedTotal),
            ),
            if (hasDeclaredTotal) ...[
              const SizedBox(height: 8),
              _totalRow(
                context,
                'Total declarado',
                formatCurrency(declaredTotal!),
              ),
              Divider(height: 24, color: colorScheme.outlineVariant),
              _totalRow(context, 'Diferença', formatCurrency(difference!)),
            ],
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasRelevantDifference
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _totalRow(BuildContext context, String label, String value) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
    const SizedBox(width: 12),
    Flexible(
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  ],
);

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
