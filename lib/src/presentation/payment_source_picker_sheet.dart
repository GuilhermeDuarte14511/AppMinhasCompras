import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/finance_integration.dart';
import '../core/utils/format_utils.dart';
import '../domain/models_and_utils.dart';
import 'dialogs/widgets/brl_currency_input_formatter.dart';
import 'theme/app_tokens.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';

final _pickerButtonStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

class PaymentSourcePickerResult {
  const PaymentSourcePickerResult.balance(this.balance) : addManually = false;
  const PaymentSourcePickerResult.manual() : balance = null, addManually = true;
  final PaymentBalance? balance;
  final bool addManually;
}

Future<PaymentSourcePickerResult?> showPaymentSourcePickerSheet(
  BuildContext context, {
  required FinanceIntegrationRepository repository,
}) {
  return showAppModalBottomSheet<PaymentSourcePickerResult>(
    context: context,
    backgroundColor: editorialWorkspaceTheme(
      Theme.of(context),
    ).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _PaymentSourcePicker(repository: repository),
  );
}

class _PaymentSourcePicker extends StatefulWidget {
  const _PaymentSourcePicker({required this.repository});
  final FinanceIntegrationRepository repository;
  @override
  State<_PaymentSourcePicker> createState() => _PaymentSourcePickerState();
}

class _PaymentSourcePickerState extends State<_PaymentSourcePicker> {
  final _amountController = TextEditingController();
  final _amountFormatter = BrlCurrencyInputFormatter();
  List<FinancePaymentSource> _sources = const [];
  FinancePaymentSource? _selected;
  bool _loading = true;
  String? _error;
  String? _amountError;
  DateTime? _asOf;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await widget.repository.isConnected()) {
        throw const FinanceIntegrationException(
          'Conecte o Minhas Finanças para usar meios sincronizados.',
          retryable: false,
          code: 'NOT_CONNECTED',
        );
      }
      final workspace = await widget.repository.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _sources = workspace.availablePaymentSources;
        _asOf = workspace.asOf;
        final selectedId = _selected?.id;
        _selected = null;
        for (final source in _sources) {
          if (source.id == selectedId) _selected = source;
        }
        _amountError = null;
      });
    } on FinanceIntegrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar seus meios.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(FinancePaymentSource source) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = source;
      _amountError = null;
      _amountController.text = _amountFormatter.formatValue(
        source.availableCents / 100,
      );
    });
  }

  Future<void> _createSource() async {
    final created = await showCreatePaymentSourceSheet(
      context,
      repository: widget.repository,
    );
    if (!mounted || created == null) return;
    setState(() => _sources = [..._sources, created]);
    _select(created);
  }

  void _confirm() {
    final source = _selected;
    final amount = BrlCurrencyInputFormatter.tryParse(_amountController.text);
    if (_loading || _error != null || source == null) return;
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _amountError = 'Informe um valor maior que zero.');
      return;
    }
    if (amount > source.availableCents / 100) {
      setState(() {
        _amountError =
            'O valor da lista não pode superar o disponível neste meio.';
      });
      return;
    }
    Navigator.pop(
      context,
      PaymentSourcePickerResult.balance(
        PaymentBalance(
          id: uniqueId(),
          name: source.name,
          type: _balanceType(source.kind),
          amount: amount,
          financeSourceId: source.id,
          financeSourceKind: source.kind.wireValue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => _PaymentSheetFrame(
        title: 'Adicionar saldo',
        body: _buildContent(Theme.of(context)),
        actions: [
          FilledButton(
            style: _pickerButtonStyle,
            onPressed: _selected == null || _loading || _error != null
                ? null
                : _confirm,
            child: const Text('Usar nesta lista'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: _pickerButtonStyle,
            onPressed: () => Navigator.pop(
              context,
              const PaymentSourcePickerResult.manual(),
            ),
            child: const Text('Adicionar manualmente'),
          ),
        ],
      ),
    ),
  );
  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      key: const ValueKey('finance_sources_scroll'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FONTES SINCRONIZADAS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: .8,
                ),
              ),
            ),
            IconButton(
              onPressed: _load,
              tooltip: 'Atualizar fontes',
              icon: const Icon(Icons.sync_rounded, size: 18),
            ),
          ],
        ),
        if (_asOf != null) ...[
          Text(
            'Dados de ${_asOf!.day.toString().padLeft(2, '0')}/${_asOf!.month.toString().padLeft(2, '0')}/${_asOf!.year}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          SelectableText(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
        ],
        if (_sources.isEmpty && _error == null)
          const Text('Nenhum meio sincronizado ainda.'),
        for (final source in _sources) ...[
          _PaymentSourceTile(
            source: source,
            selected: source.id == _selected?.id,
            onTap: () => _select(source),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: AppTokens.spaceMd),
        OutlinedButton.icon(
          style: _pickerButtonStyle,
          onPressed: _error == null ? _createSource : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Criar no Finanças'),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppTokens.motionMedium,
          curve: Curves.easeOutCubic,
          child: _selected == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VALOR RESERVADO PARA ESTA LISTA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('finance_source_amount_field'),
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _amountFormatter,
                        ],
                        decoration: InputDecoration(
                          errorText: _amountError,
                          errorMaxLines: 3,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'O valor fica reservado para o orçamento desta lista. Reservar não registra um pagamento no Minhas Finanças.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PaymentSourceTile extends StatelessWidget {
  const _PaymentSourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });
  final FinancePaymentSource source;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${source.kind.label} ${source.name}',
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${source.kind.label}${_digitsLabel(source.lastDigits)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${source.kind == FinancePaymentSourceKind.credit ? 'Disponível' : 'Saldo disponível'}: ${formatCurrency(source.availableCents / 100)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (source.limitCents != null)
                        Text(
                          'Limite: ${formatCurrency(source.limitCents! / 100)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
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

Future<FinancePaymentSource?> showCreatePaymentSourceSheet(
  BuildContext context, {
  required FinanceIntegrationRepository repository,
}) {
  return showAppModalBottomSheet<FinancePaymentSource>(
    context: context,
    backgroundColor: editorialWorkspaceTheme(
      Theme.of(context),
    ).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _CreatePaymentSourceForm(repository: repository),
  );
}

class _CreatePaymentSourceForm extends StatefulWidget {
  const _CreatePaymentSourceForm({required this.repository});
  final FinanceIntegrationRepository repository;
  @override
  State<_CreatePaymentSourceForm> createState() =>
      _CreatePaymentSourceFormState();
}

class _CreatePaymentSourceFormState extends State<_CreatePaymentSourceForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _digits = TextEditingController();
  final _amount = TextEditingController();
  final _formatter = BrlCurrencyInputFormatter();
  FinancePaymentSourceKind _kind = FinancePaymentSourceKind.credit;
  int _closingDay = 5;
  int _dueDay = 10;
  bool _saving = false;
  String? _error;
  FinancePaymentSourceRequest? _lastRequest;

  // JSON numbers must preserve the exact integer number of cents.
  int? _availableCents(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final cents = int.tryParse(digits);
    return cents != null && cents > 0 && cents <= 9007199254740991
        ? cents
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _digits.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_formKey.currentState?.validate() != true) return;
    final cents = _availableCents(_amount.text);
    if (cents == null) return;
    final name = _name.text.trim();
    final digits = _digits.text.trim().isEmpty ? null : _digits.text.trim();
    final closingDay = _kind == FinancePaymentSourceKind.credit
        ? _closingDay
        : null;
    final dueDay = _kind == FinancePaymentSourceKind.credit ? _dueDay : null;
    final previous = _lastRequest;
    final unchanged =
        previous != null &&
        previous.kind == _kind &&
        previous.name == name &&
        previous.availableCents == cents &&
        previous.lastDigits == digits &&
        previous.closingDay == closingDay &&
        previous.dueDay == dueDay;
    final request = unchanged
        ? previous
        : FinancePaymentSourceRequest(
            externalRequestId: uniqueId(),
            kind: _kind,
            name: name,
            availableCents: cents,
            lastDigits: digits,
            closingDay: closingDay,
            dueDay: dueDay,
          );
    _lastRequest = request;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final source = await widget.repository.createPaymentSource(request);
      if (mounted) Navigator.pop(context, source);
    } on FinanceIntegrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível criar no Minhas Finanças.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = editorialWorkspaceTheme(Theme.of(context));
    final colors = workspace.colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return Theme(
      data: workspace.copyWith(
        inputDecorationTheme: workspace.inputDecorationTheme.copyWith(
          filled: false,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          disabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          errorBorder: fieldBorder.copyWith(
            borderSide: BorderSide(color: colors.error),
          ),
          focusedErrorBorder: fieldBorder.copyWith(
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
        ),
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final inset = MediaQuery.viewInsetsOf(context).bottom;
          return PopScope(
            canPop: !_saving,
            child: Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight.clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: const Key('create_payment_source_scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Novo meio de pagamento',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontFamily: 'MercadoNewsreader',
                                        fontSize: 23,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Fechar',
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 22),
                              ),
                            ],
                          ),
                          Text(
                            'Ele também será criado no Minhas Finanças.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(height: 1, color: colors.outlineVariant),
                          const SizedBox(height: 20),
                          Text('TIPO', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final kind
                                  in FinancePaymentSourceKind.values)
                                ChoiceChip(
                                  key: ValueKey(
                                    'payment_source_kind_${kind.wireValue}',
                                  ),
                                  label: Text(kind.label),
                                  selected: kind == _kind,
                                  selectedColor: colors.primary,
                                  labelStyle: theme.textTheme.labelMedium
                                      ?.copyWith(
                                        color: kind == _kind
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                      ),
                                  checkmarkColor: colors.onPrimary,
                                  backgroundColor: colors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(() => _kind = kind),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _field(
                            context,
                            label: 'Nome do cartão ou meio *',
                            child: TextFormField(
                              key: const Key('payment_source_name_field'),
                              controller: _name,
                              style: theme.textTheme.bodyMedium,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                hintText: 'Ex.: Cartão Nubank',
                                counterText: '',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Informe um nome.'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _pairedFields(
                            context,
                            _field(
                              context,
                              label: _kind == FinancePaymentSourceKind.credit
                                  ? 'Final (4 dígitos)'
                                  : 'Final (opcional)',
                              child: TextFormField(
                                key: const Key('payment_source_digits_field'),
                                controller: _digits,
                                style: theme.textTheme.bodyMedium,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'Ex.: 4092',
                                ),
                                validator: (value) {
                                  final digits = value?.trim() ?? '';
                                  if (_kind ==
                                          FinancePaymentSourceKind.credit &&
                                      digits.length != 4) {
                                    return 'Informe os quatro dígitos.';
                                  }
                                  if (digits.isNotEmpty && digits.length != 4) {
                                    return 'Use quatro dígitos ou deixe vazio.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            _field(
                              context,
                              label: _kind == FinancePaymentSourceKind.credit
                                  ? 'Limite disponível'
                                  : 'Saldo disponível',
                              child: TextFormField(
                                key: const Key('payment_source_amount_field'),
                                controller: _amount,
                                style: theme.textTheme.bodyMedium,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  TextInputFormatter.withFunction((
                                    oldValue,
                                    newValue,
                                  ) {
                                    // Do not feed an overflowing number to NumberFormat.
                                    if (newValue.text.isNotEmpty &&
                                        _availableCents(newValue.text) ==
                                            null) {
                                      return newValue;
                                    }
                                    return _formatter.formatEditUpdate(
                                      oldValue,
                                      newValue,
                                    );
                                  }),
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'R\$ 0,00',
                                ),
                                validator: (value) =>
                                    _availableCents(value ?? '') == null
                                    ? 'Informe um valor válido.'
                                    : null,
                              ),
                            ),
                          ),
                          if (_kind == FinancePaymentSourceKind.credit) ...[
                            const SizedBox(height: 20),
                            _pairedFields(
                              context,
                              _field(
                                context,
                                label: 'Dia do fechamento',
                                child: _DaySelector(
                                  fieldKey: const Key(
                                    'payment_source_closing_day',
                                  ),
                                  value: _closingDay,
                                  enabled: !_saving,
                                  onChanged: (value) =>
                                      setState(() => _closingDay = value),
                                ),
                              ),
                              _field(
                                context,
                                label: 'Dia do vencimento',
                                child: _DaySelector(
                                  fieldKey: const Key('payment_source_due_day'),
                                  value: _dueDay,
                                  enabled: !_saving,
                                  onChanged: (value) =>
                                      setState(() => _dueDay = value),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: SelectableText(
                                _error!,
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: _pickerButtonStyle,
                              onPressed: _saving ? null : _submit,
                              child: _saving
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Criando...'),
                                      ],
                                    )
                                  : const Text('Criar e usar'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              style: _pickerButtonStyle.copyWith(
                                foregroundColor: WidgetStatePropertyAll(
                                  colors.onSurfaceVariant,
                                ),
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Semantics(label: label, child: child),
      ],
    );
  }

  Widget _pairedFields(BuildContext context, Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 17;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 20), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.fieldKey,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });
  final Key fieldKey;
  final bool enabled;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: const InputDecoration(),
      items: List.generate(
        31,
        (index) =>
            DropdownMenuItem(value: index + 1, child: Text('Dia ${index + 1}')),
      ),
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    );
  }
}

PaymentBalanceType _balanceType(FinancePaymentSourceKind kind) =>
    switch (kind) {
      FinancePaymentSourceKind.credit => PaymentBalanceType.card,
      FinancePaymentSourceKind.debit => PaymentBalanceType.debit,
      FinancePaymentSourceKind.foodVoucher => PaymentBalanceType.foodVoucher,
      FinancePaymentSourceKind.mealVoucher => PaymentBalanceType.mealVoucher,
    };
String _digitsLabel(String? digits) =>
    digits == null || digits.isEmpty ? '' : ' •••• $digits';

class _PaymentSheetFrame extends StatelessWidget {
  const _PaymentSheetFrame({
    required this.title,
    required this.body,
    required this.actions,
  });
  final String title;
  final Widget body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (MediaQuery.sizeOf(context).height * .78).clamp(
          0.0,
          (constraints.maxHeight - inset).clamp(0.0, double.infinity),
        );
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: SizedBox(
            height: height,
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFamily: 'MercadoNewsreader',
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Meios do Minhas Finanças',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Expanded(child: body),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
