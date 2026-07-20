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
    showDragHandle: true,
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
    _transcriptController.dispose();
    super.dispose();
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
  }

  Future<void> _stopListening() async {
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
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + safeBottom),
          child: _isReviewing ? _buildReview(context) : _buildCapture(context),
        ),
      ),
    );
  }

  Widget _buildCapture(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Adicionar por voz',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Exemplo: “dois detergentes Minuano, um arroz e três sabonetes”.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Semantics(
              button: true,
              label: _isListening ? 'Parar de ouvir' : 'Começar a ouvir',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isInitializing
                    ? null
                    : (_isListening ? _stopListening : _startListening),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                  ),
                  child: _isInitializing
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 42,
                          color: _isListening
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? 'Ouvindo… toque para parar'
                : (_recognitionAvailable
                      ? 'Toque no microfone para falar'
                      : 'Digite os itens abaixo'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _transcriptController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Itens reconhecidos',
              alignLabelWithHint: true,
              hintText: 'Digite os produtos separados por vírgulas.',
              prefixIcon: Icon(Icons.format_list_bulleted_rounded),
            ),
            onChanged: (_) {
              if (_feedback != null) {
                setState(() {
                  _feedback = null;
                });
              }
            },
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 10),
            _VoiceFeedbackBanner(message: _feedback!),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isListening ? null : _analyzeTranscript,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Analisar itens'),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final selectedCount = _selectedIndexes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revise os produtos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$selectedCount de ${_resolvedItems.length} selecionados',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _returnToCapture,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Ouvir novamente'),
            ),
          ],
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 10),
          _VoiceFeedbackBanner(message: _feedback!),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _resolvedItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _resolvedItems[index];
              return _VoiceReviewCard(
                item: item,
                isSelected: _selectedIndexes.contains(index),
                isAlreadyInList: _matchesCurrentList(item.draft),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedIndexes.add(index);
                    } else {
                      _selectedIndexes.remove(index);
                    }
                  });
                },
                onEdit: () => _editItem(index),
                onSelectProduct: (product) =>
                    _selectCatalogProduct(index, product),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: Text(
            selectedCount == 1
                ? 'Adicionar 1 produto'
                : 'Adicionar $selectedCount produtos',
          ),
        ),
      ],
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
    return Card(
      elevation: 0,
      color: needsAttention
          ? colorScheme.errorContainer.withValues(alpha: 0.34)
          : colorScheme.surfaceContainerLow,
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
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.draft.quantity} un. • '
                        '${item.hasPrice ? formatCurrency(item.draft.unitPrice) : 'valor pendente'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: needsAttention
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
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
                  Chip(
                    avatar: Icon(item.draft.category.icon, size: 16),
                    label: Text(item.draft.category.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (item.draft.barcode != null)
                    const Chip(
                      avatar: Icon(Icons.qr_code_rounded, size: 16),
                      label: Text('Código associado'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isAlreadyInList)
                    const Chip(
                      avatar: Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text('Quantidade será somada'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            if (item.confidence == VoiceCatalogMatchConfidence.ambiguous &&
                item.alternatives.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  'Qual produto você quis adicionar?',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final alternative in item.alternatives)
                      ActionChip(
                        avatar: const Icon(Icons.local_offer_rounded, size: 16),
                        label: Text(alternative.product.name),
                        onPressed: () => onSelectProduct(alternative.product),
                      ),
                  ],
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
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
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
        borderRadius: BorderRadius.circular(12),
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
