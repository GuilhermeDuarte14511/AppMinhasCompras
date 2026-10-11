import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/ports.dart';
import '../../../application/voice_shopping.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../extensions/classification_ui_extensions.dart';
import '../../utils/app_modal.dart';
import '../../theme/editorial_workspace_theme.dart';
import 'shopping_item_editor_sheet.dart';

Future<List<ShoppingItemDraft>?> showVoiceQuickAddSheet(
  BuildContext context, {
  required ShoppingVoiceRecognitionService voiceRecognitionService,
  required List<CatalogProduct> catalogProducts,
  required List<ShoppingItem> currentItems,
  String initialTranscript = '',
  bool autoStart = true,
}) {
  return showAppModalBottomSheet<List<ShoppingItemDraft>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: editorialWorkspaceTheme(
      Theme.of(context),
    ).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    useSafeArea: true,
    builder: (context) => _VoiceQuickAddSheet(
      voiceRecognitionService: voiceRecognitionService,
      catalogProducts: catalogProducts,
      currentItems: currentItems,
      initialTranscript: initialTranscript,
      autoStart: autoStart,
    ),
  );
}

class _VoiceQuickAddSheet extends StatefulWidget {
  const _VoiceQuickAddSheet({
    required this.voiceRecognitionService,
    required this.catalogProducts,
    required this.currentItems,
    required this.initialTranscript,
    required this.autoStart,
  });

  final ShoppingVoiceRecognitionService voiceRecognitionService;
  final List<CatalogProduct> catalogProducts;
  final List<ShoppingItem> currentItems;
  final String initialTranscript;
  final bool autoStart;

  @override
  State<_VoiceQuickAddSheet> createState() => _VoiceQuickAddSheetState();
}

class _VoiceQuickAddSheetState extends State<_VoiceQuickAddSheet> {
  static const VoiceShoppingParser _parser = VoiceShoppingParser();
  static const VoiceCatalogMatcher _matcher = VoiceCatalogMatcher();

  late final TextEditingController _transcriptController;
  final FocusNode _transcriptFocus = FocusNode();
  List<VoiceResolvedShoppingItem> _resolvedItems =
      const <VoiceResolvedShoppingItem>[];
  final Set<int> _selectedIndexes = <int>{};
  bool _isInitializing = false;
  bool _isListening = false;
  bool _recognitionAvailable = true;
  String? _feedback;

  bool get _isReviewing => _resolvedItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(
      text: widget.initialTranscript,
    );
    _transcriptFocus.addListener(_refreshTranscriptFocus);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startListening());
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(widget.voiceRecognitionService.cancelListening());
    _transcriptFocus.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _refreshTranscriptFocus() {
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (_isInitializing || _isListening) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isInitializing = true;
      _feedback = null;
    });

    try {
      final available = await widget.voiceRecognitionService.initialize(
        onError: _handleRecognitionError,
        onStatus: _handleRecognitionStatus,
      );
      if (!mounted) {
        return;
      }
      if (!available) {
        setState(() {
          _isInitializing = false;
          _recognitionAvailable = false;
          _feedback =
              'O reconhecimento de voz não está disponível. Digite os itens abaixo.';
        });
        return;
      }

      setState(() {
        _isInitializing = false;
        _recognitionAvailable = true;
        _isListening = true;
        _feedback = 'Estou ouvindo. Fale os produtos naturalmente.';
      });
      await widget.voiceRecognitionService.startListening(
        onResult: _handleRecognitionResult,
      );
    } catch (error) {
      _handleRecognitionError(error.toString());
    }
  }

  Future<void> _stopListening() async {
    try {
      await widget.voiceRecognitionService.stopListening();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _feedback = _transcriptController.text.trim().isEmpty
            ? 'Não reconheci nenhum item. Tente novamente ou digite.'
            : 'Revise a frase e toque em “Analisar itens”.';
      });
    } catch (error) {
      _handleRecognitionError(error.toString());
    }
  }

  void _handleRecognitionResult(ShoppingVoiceRecognitionUpdate update) {
    if (!mounted) {
      return;
    }
    setState(() {
      _transcriptController.text = update.words;
      _transcriptController.selection = TextSelection.collapsed(
        offset: update.words.length,
      );
      if (update.isFinal) {
        _isListening = false;
        _feedback = 'Revise a frase e toque em “Analisar itens”.';
      }
    });
  }

  void _handleRecognitionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializing = false;
      _isListening = false;
      _feedback = _friendlyRecognitionError(message);
    });
  }

  void _handleRecognitionStatus(String status) {
    if (!mounted) {
      return;
    }
    final normalized = status.trim().toLowerCase();
    if (normalized != 'done' && normalized != 'notlistening') {
      return;
    }
    setState(() {
      _isListening = false;
    });
  }

  String _friendlyRecognitionError(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('notallowed')) {
      return 'Permita o acesso ao microfone nas configurações do aparelho.';
    }
    if (normalized.contains('network')) {
      return 'O reconhecimento de voz está sem conexão. Você pode digitar os itens.';
    }
    if (normalized.contains('no_match')) {
      return 'Não consegui entender. Fale novamente ou digite os itens.';
    }
    return 'Não foi possível ouvir agora. Tente novamente ou digite os itens.';
  }

  void _analyzeTranscript() {
    final intents = _parser.parse(_transcriptController.text);
    if (intents.isEmpty) {
      setState(() {
        _feedback = 'Diga ou escreva ao menos um produto para continuar.';
      });
      return;
    }

    final resolved = _matcher.resolveAll(
      intents,
      catalogProducts: widget.catalogProducts,
    );
    setState(() {
      _resolvedItems = resolved;
      _selectedIndexes
        ..clear()
        ..addAll(List<int>.generate(resolved.length, (index) => index));
      _feedback = null;
    });
  }

  void _returnToCapture() {
    setState(() {
      _resolvedItems = const <VoiceResolvedShoppingItem>[];
      _selectedIndexes.clear();
      _feedback = null;
    });
  }

  Future<void> _editItem(int index) async {
    final current = _resolvedItems[index];
    final draft = current.draft;
    final edited = await showShoppingItemEditorSheet(
      context,
      existingItem: ShoppingItem(
        id: 'voice-$index',
        name: draft.name,
        quantity: draft.quantity,
        unitPrice: draft.unitPrice,
        barcode: draft.barcode,
        category: draft.category,
      ),
      catalogProducts: widget.catalogProducts,
    );
    if (!mounted || edited == null) {
      return;
    }
    setState(() {
      final updated = [..._resolvedItems];
      updated[index] = current.applyEditedDraft(edited);
      _resolvedItems = List.unmodifiable(updated);
    });
  }

  void _selectCatalogProduct(int index, CatalogProduct product) {
    HapticFeedback.selectionClick();
    setState(() {
      final updated = [..._resolvedItems];
      updated[index] = updated[index].selectProduct(product);
      _resolvedItems = List.unmodifiable(updated);
    });
  }

  void _submit() {
    final selected = _selectedIndexes.toList()..sort();
    if (selected.isEmpty) {
      setState(() {
        _feedback = 'Selecione ao menos um produto.';
      });
      return;
    }
    final missingPrice = selected
        .where((index) => _resolvedItems[index].draft.unitPrice <= 0)
        .toList(growable: false);
    if (missingPrice.isNotEmpty) {
      setState(() {
        _feedback =
            'Informe o valor dos produtos destacados antes de adicionar.';
      });
      return;
    }

    Navigator.pop(
      context,
      selected
          .map((index) => _resolvedItems[index].draft)
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * .85;
    final height = _isReviewing
        ? maxHeight
        : MediaQuery.textScalerOf(context).scale(560).clamp(0.0, maxHeight);
    final editorial = editorialWorkspaceTheme(Theme.of(context));
    return Theme(
      data: editorial.copyWith(
        inputDecorationTheme: editorial.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: editorial.colorScheme.surfaceContainerLowest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: editorial.colorScheme.outlineVariant),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      child: Builder(
        builder: (context) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SizedBox(
            height: (height - keyboardInset).clamp(140.0, height),
            child: Material(
              color: editorial.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      decoration: BoxDecoration(
                        color: editorial.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Fechar voz',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                        Expanded(
                          child: Text(
                            _isReviewing
                                ? 'Revise os produtos'
                                : 'Adicionar por voz',
                            textAlign: TextAlign.center,
                            style:
                                _isReviewing &&
                                    MediaQuery.sizeOf(context).width < 360
                                ? editorial.textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                  )
                                : editorial.textTheme.titleLarge,
                          ),
                        ),
                        if (_isReviewing &&
                            (MediaQuery.sizeOf(context).width < 360 ||
                                MediaQuery.textScalerOf(context).scale(12) >
                                    15))
                          IconButton(
                            tooltip: 'Ouvir novamente',
                            onPressed: _returnToCapture,
                            icon: const Icon(Icons.replay, size: 22),
                          )
                        else if (_isReviewing)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: _returnToCapture,
                            icon: const Icon(Icons.replay, size: 18),
                            label: const SizedBox(
                              width: 76,
                              child: Text(
                                'Ouvir novamente',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: editorial.colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: _isReviewing
                        ? _buildReview(context)
                        : _buildCapture(context),
                  ),
                  if (_isReviewing)
                    _buildReviewFooter(context)
                  else
                    _buildCaptureFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapture(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = _isListening;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: colors.primary.withValues(alpha: .35))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filled(
                    tooltip: active ? 'Parar de ouvir' : 'Começar a ouvir',
                    onPressed: _isInitializing
                        ? null
                        : (active ? _stopListening : _startListening),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.brightness == Brightness.dark
                          ? colors.surface
                          : Colors.white,
                      shape: const CircleBorder(),
                    ),
                    icon: _isInitializing
                        ? SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.brightness == Brightness.dark
                                  ? colors.surface
                                  : Colors.white,
                            ),
                          )
                        : const Icon(Icons.mic, size: 36),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _isInitializing
                  ? 'Preparando microfone…'
                  : active
                  ? 'Ouvindo… toque para parar'
                  : _recognitionAvailable
                  ? 'Toque no microfone para falar'
                  : 'Digite os itens abaixo',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Itens reconhecidos',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(
                color: _transcriptFocus.hasFocus
                    ? colors.primary
                    : colors.brightness == Brightness.dark
                    ? colors.outlineVariant
                    : const Color(0xFF727972),
                width: _transcriptFocus.hasFocus ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    focusNode: _transcriptFocus,
                    controller: _transcriptController,
                    minLines: 2,
                    maxLines: 5,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Diga ou digite os itens e quantidades…',
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 28,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) {
                      if (_feedback != null) setState(() => _feedback = null);
                    },
                  ),
                  Divider(height: 22, color: colors.outlineVariant),
                  Text(
                    'Fale naturalmente nomes e quantidades',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (_feedback != null &&
              _feedback != 'Estou ouvindo. Fale os produtos naturalmente.') ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: _VoiceFeedbackBanner(message: _feedback!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptureFooter(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: colors.primary,
          foregroundColor: colors.brightness == Brightness.dark
              ? colors.surface
              : Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: .40),
          disabledForegroundColor: colors.brightness == Brightness.dark
              ? colors.surface
              : Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isListening || _isInitializing ? null : _analyzeTranscript,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text('Analisar itens')),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selectedIndexes.length == _resolvedItems.length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  '${_selectedIndexes.length} de ${_resolvedItems.length} selecionados',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => setState(() {
                  _selectedIndexes.clear();
                  if (!allSelected) {
                    _selectedIndexes.addAll(
                      List.generate(_resolvedItems.length, (index) => index),
                    );
                  }
                  _feedback = null;
                }),
                child: Text(
                  allSelected ? 'Desmarcar todos' : 'Selecionar todos',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_feedback != null) ...[
                Semantics(
                  liveRegion: true,
                  child: _VoiceFeedbackBanner(message: _feedback!),
                ),
                const SizedBox(height: 12),
              ],
              for (var index = 0; index < _resolvedItems.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _VoiceReviewCard(
                  item: _resolvedItems[index],
                  isSelected: _selectedIndexes.contains(index),
                  isAlreadyInList: _matchesCurrentList(
                    _resolvedItems[index].draft,
                  ),
                  onSelected: (selected) => setState(() {
                    selected
                        ? _selectedIndexes.add(index)
                        : _selectedIndexes.remove(index);
                    _feedback = null;
                  }),
                  onEdit: () => _editItem(index),
                  onSelectProduct: (product) =>
                      _selectCatalogProduct(index, product),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewFooter(BuildContext context) {
    final count = _selectedIndexes.length;
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: colors.primary,
            foregroundColor: colors.brightness == Brightness.dark
                ? colors.surface
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: count == 0 ? null : _submit,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  count == 0
                      ? 'Nenhum produto selecionado'
                      : count == 1
                      ? 'Adicionar 1 produto'
                      : 'Adicionar $count produtos',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesCurrentList(ShoppingItemDraft draft) {
    final barcode = sanitizeBarcode(draft.barcode);
    final normalizedName = normalizeQuery(draft.name);
    return widget.currentItems.any((item) {
      final itemBarcode = sanitizeBarcode(item.barcode);
      return (barcode != null && itemBarcode == barcode) ||
          normalizeQuery(item.name) == normalizedName;
    });
  }
}

class _VoiceReviewCard extends StatelessWidget {
  const _VoiceReviewCard({
    required this.item,
    required this.isSelected,
    required this.isAlreadyInList,
    required this.onSelected,
    required this.onEdit,
    required this.onSelectProduct,
  });

  final VoiceResolvedShoppingItem item;
  final bool isSelected;
  final bool isAlreadyInList;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;
  final ValueChanged<CatalogProduct> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final needsAttention = item.needsAttention;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelected(value ?? false),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.draft.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontFamily: 'MercadoPublicSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.draft.quantity} un. · '
                        '${item.hasPrice ? formatCurrency(item.draft.quantity * item.draft.unitPrice) : 'Preço a definir'}'
                        '${item.hasPrice && item.draft.quantity > 1 ? ' (${formatCurrency(item.draft.unitPrice)}/un)' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: needsAttention
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar produto',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _MatchBadge(item: item),
                  _VoiceMetadata(
                    icon: item.draft.category.icon,
                    label: item.draft.category.label,
                  ),
                  if (item.draft.barcode != null)
                    const _VoiceMetadata(
                      icon: Icons.qr_code_rounded,
                      label: 'Código associado',
                    ),
                  if (isAlreadyInList)
                    const _VoiceMetadata(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Quantidade será somada',
                    ),
                ],
              ),
            ),
            if (item.alternatives.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  item.matchedProduct == null
                      ? 'Qual produto você quis adicionar?'
                      : 'Produto encontrado no catálogo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'MercadoPublicSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: DropdownButtonFormField<CatalogProduct>(
                  key: ValueKey(item.matchedProduct?.id),
                  initialValue:
                      item.alternatives.any(
                        (candidate) => candidate.product == item.matchedProduct,
                      )
                      ? item.matchedProduct
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Correspondência no catálogo',
                  ),
                  hint: const Text('Escolher produto'),
                  items: [
                    for (final alternative in item.alternatives)
                      DropdownMenuItem(
                        value: alternative.product,
                        child: Text(
                          alternative.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (product) {
                    if (product != null) onSelectProduct(product);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.item});

  final VoiceResolvedShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (item.confidence) {
      VoiceCatalogMatchConfidence.exact => (
        Icons.verified_rounded,
        'Catálogo confirmado',
      ),
      VoiceCatalogMatchConfidence.high => (Icons.link_rounded, 'Match seguro'),
      VoiceCatalogMatchConfidence.ambiguous => (
        Icons.help_outline_rounded,
        'Escolha necessária',
      ),
      VoiceCatalogMatchConfidence.none => (
        Icons.add_box_outlined,
        'Produto novo',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _VoiceMetadata(icon: icon, label: label),
    );
  }
}

class _VoiceMetadata extends StatelessWidget {
  const _VoiceMetadata({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _VoiceFeedbackBanner extends StatelessWidget {
  const _VoiceFeedbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colorScheme.onSecondaryContainer,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
