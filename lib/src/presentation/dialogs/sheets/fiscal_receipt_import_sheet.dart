import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/services/fiscal_receipt_parser.dart';
import '../../../data/services/receipt_ocr_text_normalizer.dart';
import '../../../domain/models_and_utils.dart';
import '../../../domain/receipt_item_matcher.dart';
import '../widgets/item_editor_support_widgets.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  List<ShoppingItemDraft> _parsedItems = const <ShoppingItemDraft>[];
  List<ReceiptItemMatchResult> _matchResults = const <ReceiptItemMatchResult>[];
  bool _isExtractingFromImage = false;
  String? _ocrFeedback;

  @override
  void initState() {
    super.initState();
    _rawTextController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _rawTextController.removeListener(_onTextChanged);
    _rawTextController.dispose();
    unawaited(_textRecognizer.close());
    super.dispose();
  }

  void _onTextChanged() {
    final parsed = _parser.parse(_rawTextController.text);
    final matches = _matcher.matchAll(
      parsed,
      currentItems: widget.currentItems,
      catalogProducts: widget.catalogProducts,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _matchResults = matches;
      _parsedItems = matches
          .map((result) => result.resolvedDraft)
          .toList(growable: false);
    });
  }

  String _matchLabel(ReceiptItemMatchResult result) {
    final candidate = result.candidate;
    if (candidate == null) {
      return 'Sem de/para confiável';
    }
    final source = candidate.source == ReceiptItemMatchSource.currentList
        ? 'Lista atual'
        : 'Catálogo';
    return '$source - ${result.matchPercent}%';
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
              'Não foi possível identificar texto suficiente no cupom.';
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
        _ocrFeedback = 'Texto extraído com sucesso pela imagem.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExtractingFromImage = false;
        _ocrFeedback = 'Não foi possível ler a imagem. Tente outra foto.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final totalUnits = _parsedItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalValue = _parsedItems.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
    final hasInput = _rawTextController.text.trim().isNotEmpty;

    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.92, 760),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar cupom fiscal',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Cole o texto do cupom (PDF/OCR) para extrair itens automaticamente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isExtractingFromImage
                      ? null
                      : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Colar texto'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isExtractingFromImage
                      ? null
                      : () => _importFromImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('OCR Galeria'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isExtractingFromImage
                      ? null
                      : () => _importFromImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('OCR Câmera'),
                ),
                if (hasInput)
                  OutlinedButton.icon(
                    onPressed: _isExtractingFromImage
                        ? null
                        : _rawTextController.clear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Limpar'),
                  ),
              ],
            ),
            if (_isExtractingFromImage) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (_ocrFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                _ocrFeedback!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
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
                  labelText: 'Texto bruto do cupom',
                  hintText:
                      'Exemplo:\nLEITE INTEGRAL 2 X 5,49 10,98\nARROZ T1 1 X 24,90 24,90',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _parsedItems.isEmpty
                  ? Container(
                      key: const ValueKey('empty'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                      ),
                      child: Text(
                        hasInput
                            ? 'Nenhum item reconhecido ainda. Tente colar mais linhas do cupom.'
                            : 'Cole o texto para gerar o preview de itens.',
                      ),
                    )
                  : Container(
                      key: const ValueKey('preview'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ReceiptStatChip(
                                icon: Icons.receipt_long_rounded,
                                text: formatItemCount(_parsedItems.length),
                              ),
                              ReceiptStatChip(
                                icon: Icons.confirmation_number_rounded,
                                text: formatUnitCount(totalUnits),
                              ),
                              ReceiptStatChip(
                                icon: Icons.attach_money_rounded,
                                text: formatCurrency(totalValue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 130,
                            child: ListView.separated(
                              itemCount: _parsedItems.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final match = _matchResults[index];
                                final item = match.resolvedDraft;
                                final hasDePara =
                                    match.hasAppliedMatch &&
                                    match.originalDraft.name != item.name;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.name} - ${item.quantity} x ${formatCurrency(item.unitPrice)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (hasDePara)
                                      Text(
                                        '${match.originalDraft.name} -> ${_matchLabel(match)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.78),
                                            ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
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
                    onPressed: _parsedItems.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            List<ShoppingItemDraft>.unmodifiable(_parsedItems),
                          ),
                    icon: const Icon(Icons.download_done_rounded),
                    label: const Text('Importar itens'),
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
