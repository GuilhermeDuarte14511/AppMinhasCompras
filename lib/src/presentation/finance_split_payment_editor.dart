import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/finance_integration.dart';
import '../core/utils/format_utils.dart';
import '../domain/models_and_utils.dart';
import 'dialogs/widgets/brl_currency_input_formatter.dart';
import 'theme/editorial_workspace_theme.dart';

class FinanceSplitPaymentEditor extends StatefulWidget {
  const FinanceSplitPaymentEditor({
    super.key,
    required this.sources,
    required this.totalCents,
    required this.onChanged,
    this.preferredSourceId,
  });

  final List<FinancePaymentSource> sources;
  final int totalCents;
  final String? preferredSourceId;
  final ValueChanged<List<FinancePaymentAllocation>?> onChanged;

  @override
  State<FinanceSplitPaymentEditor> createState() =>
      _FinanceSplitPaymentEditorState();
}

class _FinanceSplitPaymentEditorState extends State<FinanceSplitPaymentEditor> {
  final _rows = <_PaymentRow>[];
  final _formatter = BrlCurrencyInputFormatter();

  @override
  void initState() {
    super.initState();
    final source =
        widget.sources
            .where((s) => s.id == widget.preferredSourceId)
            .firstOrNull ??
        widget.sources.first;
    _rows.add(_row(source, widget.totalCents));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
  }

  _PaymentRow _row(FinancePaymentSource source, int cents) => _PaymentRow(
    source,
    TextEditingController(text: _formatter.formatValue(cents / 100)),
  );

  int _cents(_PaymentRow row) =>
      int.tryParse(row.controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get _allocated => _rows.fold(0, (sum, row) => sum + _cents(row));
  bool get _valid =>
      widget.totalCents > 0 &&
      _allocated == widget.totalCents &&
      _rows.every(
        (row) => _cents(row) > 0 && _cents(row) <= row.source.availableCents,
      );

  void _notify() => widget.onChanged(
    _valid
        ? _rows
              .map(
                (row) => FinancePaymentAllocation(
                  sourceId: row.source.id,
                  sourceKind: row.source.kind.wireValue,
                  sourceName: row.source.name,
                  amountCents: _cents(row),
                ),
              )
              .toList(growable: false)
        : null,
  );

  @override
  void didUpdateWidget(covariant FinanceSplitPaymentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalCents != widget.totalCents) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notify();
      });
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _useRemaining(_PaymentRow row) {
    final otherCents = _allocated - _cents(row);
    final remaining = widget.totalCents - otherCents;
    setState(() {
      row.controller.text = _formatter.formatValue(
        (remaining > 0 ? remaining : 0) / 100,
      );
    });
    _notify();
  }

  void _remove(int index) {
    final removed = _rows[index];
    setState(() => _rows.removeAt(index));
    _notify();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => removed.controller.dispose(),
    );
  }

  void _add() {
    final next = widget.sources.firstWhere(
      (source) => !_rows.any((r) => r.source.id == source.id),
    );
    final remaining = widget.totalCents - _allocated;
    setState(() => _rows.add(_row(next, remaining > 0 ? remaining : 0)));
    _notify();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _editorTheme(Theme.of(context)),
    child: Builder(builder: _buildEditor),
  );

  ThemeData _editorTheme(ThemeData base) {
    final theme = editorialWorkspaceTheme(base);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color),
    );
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: border(theme.colorScheme.outlineVariant),
        enabledBorder: border(theme.colorScheme.outlineVariant),
        focusedBorder: border(theme.colorScheme.primary),
        errorBorder: border(theme.colorScheme.error),
        focusedErrorBorder: border(theme.colorScheme.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final difference = widget.totalCents - _allocated;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Distribua o total da compra entre os meios de pagamento.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _PaymentLedger(total: widget.totalCents, allocated: _allocated),
        const SizedBox(height: 24),
        Text('Valores definidos', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${_rows.length} ${_rows.length == 1 ? 'pagamento' : 'pagamentos'}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _rows.length; index++) ...[
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _buildRow(context, index),
          ),
        ],
        Divider(height: 1, color: scheme.outlineVariant),
        if (_rows.length < widget.sources.length && _rows.length < 5)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Adicionar pagamento'),
            ),
          ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            difference > 0
                ? 'Falta distribuir ${formatCurrency(difference / 100)}'
                : difference < 0
                ? 'Acima do total em ${formatCurrency(-difference / 100)}'
                : 'Total distribuído: ${formatCurrency(_allocated / 100)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: difference == 0 ? scheme.primary : scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final row = _rows[index];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pagamento ${index + 1}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (_rows.length > 1)
              IconButton(
                tooltip: 'Remover pagamento ${index + 1}',
                onPressed: () => _remove(index),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ObjectKey(row),
          initialValue: row.source.id,
          isExpanded: true,
          style: theme.textTheme.bodyMedium,
          decoration: const InputDecoration(labelText: 'Meio de pagamento'),
          items: widget.sources
              .where(
                (source) =>
                    source.id == row.source.id ||
                    !_rows.any((r) => r.source.id == source.id),
              )
              .map(
                (source) => DropdownMenuItem(
                  value: source.id,
                  child: Text(
                    '${source.kind.label} · ${source.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(
              () => row.source = widget.sources.firstWhere((s) => s.id == id),
            );
            _notify();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('split-amount-$index'),
          controller: row.controller,
          keyboardType: TextInputType.number,
          inputFormatters: [LengthLimitingTextInputFormatter(18), _formatter],
          decoration: InputDecoration(
            labelText: 'Valor do pagamento ${index + 1}',
            helperText:
                '${formatCurrency(row.source.availableCents / 100)} disponível',
            helperMaxLines: 2,
            errorMaxLines: 2,
            errorText: _cents(row) > row.source.availableCents
                ? 'Valor acima do saldo ou limite disponível.'
                : null,
          ),
          onChanged: (_) {
            setState(() {});
            _notify();
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: ValueKey('split-remaining-$index'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _useRemaining(row),
            child: const Text('Usar restante'),
          ),
        ),
      ],
    );
  }
}

class _PaymentRow {
  _PaymentRow(this.source, this.controller);
  FinancePaymentSource source;
  final TextEditingController controller;
}

class _PaymentLedger extends StatelessWidget {
  const _PaymentLedger({required this.total, required this.allocated});
  final int total;
  final int allocated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final difference = total - allocated;
    final values = [
      ('Total compra', total, scheme.onSurface),
      ('Alocado', allocated, scheme.primary),
      (
        difference < 0 ? 'Excedente' : 'Restante',
        difference.abs(),
        difference == 0 ? scheme.primary : scheme.error,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(12) > 15;
            Widget value((String, int, Color) item) => Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 4 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(item.$2 / 100),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.$3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact)
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: values.map(value).toList(),
                  )
                else
                  Row(
                    children: [
                      for (final item in values) Expanded(child: value(item)),
                    ],
                  ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total > 0 ? (allocated / total).clamp(0.0, 1.0) : 0,
                  minHeight: 3,
                  color: allocated > total ? scheme.error : scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
