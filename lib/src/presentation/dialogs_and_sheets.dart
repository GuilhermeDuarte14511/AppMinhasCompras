import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../application/ports.dart';
import '../core/utils/format_utils.dart';
import '../data/services/fiscal_receipt_parser.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'extensions/classification_ui_extensions.dart';
import 'utils/time_utils.dart';

Future<String?> showListNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: initialValue);

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da lista',
              prefixIcon: Icon(Icons.list_alt_rounded),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Digite um nome para a lista.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() != true) {
                return;
              }
              Navigator.pop(context, controller.text.trim());
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
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result;
}

Future<BudgetEditorResult?> showBudgetEditorDialog(
  BuildContext context, {
  double? initialValue,
}) async {
  final formKey = GlobalKey<FormState>();
  final formatter = BrlCurrencyInputFormatter();
  final controller = TextEditingController(
    text: initialValue == null ? '' : formatter.formatValue(initialValue),
  );

  final result = await showDialog<BudgetEditorResult>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Definir orçamento'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              formatter,
            ],
            decoration: const InputDecoration(
              labelText: 'Orçamento da lista',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              hintText: 'R\$ 0,00',
            ),
            validator: (value) {
              final parsed = BrlCurrencyInputFormatter.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Informe um valor válido.';
              }
              return null;
            },
          ),
        ),
        actions: [
          if (initialValue != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, const BudgetEditorResult(clear: true));
              },
              child: const Text('Remover limite'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) {
                return;
              }
              Navigator.pop(
                context,
                BudgetEditorResult(
                  value: BrlCurrencyInputFormatter.tryParse(controller.text),
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );

  return result;
}

Future<PaymentBalancesEditorResult?> showPaymentBalancesEditorDialog(
  BuildContext context, {
  List<PaymentBalance> initialValues = const <PaymentBalance>[],
}) {
  final working = initialValues
      .map((entry) => entry.copyWith())
      .toList(growable: true);

  return showDialog<PaymentBalancesEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> addBalance() async {
            final created = await _showPaymentBalanceEntryDialog(dialogContext);
            if (created == null) {
              return;
            }
            setDialogState(() {
              working.add(created);
            });
          }

          Future<void> editBalance(int index) async {
            final edited = await _showPaymentBalanceEntryDialog(
              dialogContext,
              initialValue: working[index],
            );
            if (edited == null) {
              return;
            }
            setDialogState(() {
              working[index] = edited;
            });
          }

          void moveBalance(int from, int to) {
            if (to < 0 || to >= working.length) {
              return;
            }
            setDialogState(() {
              final entry = working.removeAt(from);
              working.insert(to, entry);
            });
          }

          void removeBalance(int index) {
            setDialogState(() {
              working.removeAt(index);
            });
          }

          return AlertDialog(
            title: const Text('Saldos de pagamento'),
            content: SizedBox(
              width: min(MediaQuery.sizeOf(context).width * 0.9, 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prioridade de desconto: 1 -> 2 -> 3.'),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: working.isEmpty
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Nenhum saldo configurado ainda.\nExemplo: 1) VR Alelo, 2) Debito.',
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: working.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = working[index];
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            child: Text('${index + 1}'),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${entry.type.label} - ${formatCurrency(entry.value)}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            tooltip: 'Mover para cima',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: index == 0
                                                ? null
                                                : () => moveBalance(
                                                    index,
                                                    index - 1,
                                                  ),
                                            icon: const Icon(
                                              Icons.keyboard_arrow_up_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Mover para baixo',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed:
                                                index == working.length - 1
                                                ? null
                                                : () => moveBalance(
                                                    index,
                                                    index + 1,
                                                  ),
                                            icon: const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Editar',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () => editBalance(index),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Remover',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () =>
                                                removeBalance(index),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: addBalance,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Novo saldo'),
                  ),
                ],
              ),
            ),
            actions: [
              if (working.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      const PaymentBalancesEditorResult(clear: true),
                    );
                  },
                  child: const Text('Limpar'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    PaymentBalancesEditorResult(
                      value: List<PaymentBalance>.unmodifiable(working),
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<PaymentBalance?> _showPaymentBalanceEntryDialog(
  BuildContext context, {
  PaymentBalance? initialValue,
}) async {
  final formKey = GlobalKey<FormState>();
  final formatter = BrlCurrencyInputFormatter();
  final nameController = TextEditingController(text: initialValue?.name ?? '');
  final amountController = TextEditingController(
    text: initialValue == null ? '' : formatter.formatValue(initialValue.value),
  );
  var selectedType = initialValue?.type ?? PaymentBalanceType.card;

  try {
    return await showDialog<PaymentBalance>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(initialValue == null ? 'Novo saldo' : 'Editar saldo'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'Ex.: VR Alelo',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe um nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentBalanceType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                      items: PaymentBalanceType.values
                          .map(
                            (type) => DropdownMenuItem<PaymentBalanceType>(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        formatter,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Saldo disponivel',
                        hintText: 'R\$ 0,00',
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                      ),
                      validator: (value) {
                        final parsed = BrlCurrencyInputFormatter.tryParse(
                          value ?? '',
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Informe um saldo válido.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) {
                      return;
                    }
                    final parsedAmount = BrlCurrencyInputFormatter.tryParse(
                      amountController.text,
                    );
                    if (parsedAmount == null || parsedAmount <= 0) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      PaymentBalance(
                        id: initialValue?.id ?? uniqueId(),
                        name: nameController.text.trim(),
                        type: selectedType,
                        amount: parsedAmount,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
    amountController.dispose();
  }
}

Future<ReminderEditorResult?> showReminderEditorDialog(
  BuildContext context, {
  ShoppingReminderConfig? initialValue,
}) {
  final now = DateTime.now();
  final fallbackDateTime = now.add(const Duration(hours: 1));
  final initialDateTime =
      initialValue?.scheduledAt ??
      DateTime(
        fallbackDateTime.year,
        fallbackDateTime.month,
        fallbackDateTime.day,
        fallbackDateTime.hour,
        fallbackDateTime.minute,
      );

  var enabled = initialValue != null;
  var selectedDate = DateTime(
    initialDateTime.year,
    initialDateTime.month,
    initialDateTime.day,
  );
  var selectedTime = TimeOfDay(
    hour: initialDateTime.hour,
    minute: initialDateTime.minute,
  );
  var showValidationError = false;

  DateTime selectedDateTime() {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  return showDialog<ReminderEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate() async {
            final selected = await showDatePicker(
              context: dialogContext,
              initialDate: selectedDate,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 15),
              helpText: 'Data do lembrete',
            );
            if (selected == null) {
              return;
            }
            setDialogState(() {
              selectedDate = selected;
              showValidationError = false;
            });
          }

          Future<void> pickTime() async {
            final selected = await showTimePicker(
              context: dialogContext,
              initialTime: selectedTime,
              helpText: 'Horário do lembrete',
            );
            if (selected == null) {
              return;
            }
            setDialogState(() {
              selectedTime = selected;
              showValidationError = false;
            });
          }

          final scheduledAt = selectedDateTime();
          final isInvalidSchedule = !scheduledAt.isAfter(DateTime.now());

          return AlertDialog(
            title: const Text('Lembrete por data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) {
                    setDialogState(() {
                      enabled = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativar lembrete'),
                  subtitle: const Text(
                    'Receba um aviso local para revisar sua lista.',
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(formatShortDate(selectedDate)),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: pickTime,
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(formatTimeOfDay(selectedTime)),
                  ),
                  if (showValidationError && isInvalidSchedule) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Escolha uma data e horário no futuro.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              if (initialValue != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      const ReminderEditorResult(clear: true),
                    );
                  },
                  child: const Text('Remover lembrete'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (!enabled) {
                    Navigator.pop(
                      dialogContext,
                      const ReminderEditorResult(clear: true),
                    );
                    return;
                  }

                  final schedule = selectedDateTime();
                  if (!schedule.isAfter(DateTime.now())) {
                    setDialogState(() {
                      showValidationError = true;
                    });
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    ReminderEditorResult(
                      value: ShoppingReminderConfig(scheduledAt: schedule),
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<PurchaseCheckoutResult?> showPurchaseCheckoutDialog(
  BuildContext context, {
  required ShoppingListModel list,
}) {
  var markPendingAsPurchased = false;
  final pendingCount = list.items.where((item) => !item.isPurchased).length;
  final purchasedValue = list.items
      .where((item) => item.isPurchased)
      .fold<double>(0, (sum, item) => sum + item.subtotal);

  return showDialog<PurchaseCheckoutResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final effectivePurchasedValue = markPendingAsPurchased
              ? list.totalValue
              : purchasedValue;
          return AlertDialog(
            title: const Text('Fechar compra'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista: ${list.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('Produtos: ${list.items.length}'),
                Text('Unidades: ${list.totalItems}'),
                Text('Total planejado: ${formatCurrency(list.totalValue)}'),
                Text(
                  'Total comprado no fechamento: ${formatCurrency(effectivePurchasedValue)}',
                ),
                if (list.hasBudget)
                  Text('Orçamento: ${formatCurrency(list.budget!)}'),
                if (pendingCount > 0) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: markPendingAsPurchased,
                    onChanged: (value) {
                      setDialogState(() {
                        markPendingAsPurchased = value;
                      });
                    },
                    title: const Text('Marcar pendentes como comprados'),
                    subtitle: Text('$pendingCount item(ns) pendente(s).'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    PurchaseCheckoutResult(
                      markPendingAsPurchased: markPendingAsPurchased,
                    ),
                  );
                },
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Fechar compra'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<ShoppingListModel?> showTemplatePickerSheet(
  BuildContext context, {
  required List<ShoppingListModel> lists,
}) {
  return showModalBottomSheet<ShoppingListModel>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 20 + bottomInset),
        itemCount: lists.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final list = lists[index];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            leading: const Icon(Icons.copy_all_rounded),
            title: Text(list.name),
            subtitle: Text(
              '${list.totalItems} itens - ${formatCurrency(list.totalValue)}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.pop(context, list),
          );
        },
      );
    },
  );
}

Future<String?> showBarcodeScannerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _BarcodeScannerSheet(),
  );
}

Future<List<ShoppingItemDraft>?> showFiscalReceiptImportSheet(
  BuildContext context,
) {
  return showModalBottomSheet<List<ShoppingItemDraft>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _FiscalReceiptImportSheet(),
  );
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      final clean = sanitizeBarcode(raw);
      if (clean == null || clean.isEmpty) {
        continue;
      }
      _handled = true;
      Navigator.pop(context, clean);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.85, 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Aponte para o código de barras',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Escaneamento opcional. Se preferir, feche e digite manualmente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Digitar manualmente'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiscalReceiptImportSheet extends StatefulWidget {
  const _FiscalReceiptImportSheet();

  @override
  State<_FiscalReceiptImportSheet> createState() =>
      _FiscalReceiptImportSheetState();
}

class _FiscalReceiptImportSheetState extends State<_FiscalReceiptImportSheet> {
  final FiscalReceiptParser _parser = const FiscalReceiptParser();
  final TextEditingController _rawTextController = TextEditingController();
  List<ShoppingItemDraft> _parsedItems = const <ShoppingItemDraft>[];

  @override
  void initState() {
    super.initState();
    _rawTextController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _rawTextController.removeListener(_onTextChanged);
    _rawTextController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final parsed = _parser.parse(_rawTextController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _parsedItems = parsed;
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
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Colar texto'),
                ),
                const SizedBox(width: 8),
                if (hasInput)
                  OutlinedButton.icon(
                    onPressed: _rawTextController.clear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Limpar'),
                  ),
              ],
            ),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ReceiptStatChip(
                                icon: Icons.receipt_long_rounded,
                                text: '${_parsedItems.length} item(ns)',
                              ),
                              _ReceiptStatChip(
                                icon: Icons.confirmation_number_rounded,
                                text: '$totalUnits unidade(s)',
                              ),
                              _ReceiptStatChip(
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
                                final item = _parsedItems[index];
                                return Text(
                                  '${item.name} - ${item.quantity} x ${formatCurrency(item.unitPrice)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
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

Future<ShoppingItemDraft?> showShoppingItemEditorSheet(
  BuildContext context, {
  ShoppingItem? existingItem,
  Set<String> blockedNormalizedNames = const <String>{},
  List<String> suggestionCatalog = const <String>[],
  Future<ProductLookupResult> Function(String barcode)? onLookupBarcode,
  Future<CatalogProduct?> Function(String name)? onLookupCatalogByName,
}) {
  return showModalBottomSheet<ShoppingItemDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return _ShoppingItemEditorSheet(
        existingItem: existingItem,
        blockedNormalizedNames: blockedNormalizedNames,
        suggestionCatalog: suggestionCatalog,
        onLookupBarcode: onLookupBarcode,
        onLookupCatalogByName: onLookupCatalogByName,
      );
    },
  );
}

class _ShoppingItemEditorSheet extends StatefulWidget {
  const _ShoppingItemEditorSheet({
    required this.existingItem,
    required this.blockedNormalizedNames,
    required this.suggestionCatalog,
    required this.onLookupBarcode,
    required this.onLookupCatalogByName,
  });

  final ShoppingItem? existingItem;
  final Set<String> blockedNormalizedNames;
  final List<String> suggestionCatalog;
  final Future<ProductLookupResult> Function(String barcode)? onLookupBarcode;
  final Future<CatalogProduct?> Function(String name)? onLookupCatalogByName;

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
  late ShoppingCategory _selectedCategory;
  late final List<String> _normalizedSuggestionCatalog;
  bool _isLookingUpBarcode = false;
  bool _isLookingUpCatalog = false;
  String? _lookupFeedback;
  CatalogProduct? _catalogMatch;

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
    _normalizedSuggestionCatalog = _buildSuggestionCatalog(
      widget.suggestionCatalog,
    );
    _nameController.addListener(_handleNameChanged);
  }

  List<String> _buildSuggestionCatalog(List<String> source) {
    final seen = <String>{};
    final values = <String>[];
    for (final raw in source) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final normalized = normalizeQuery(trimmed);
      if (seen.add(normalized)) {
        values.add(trimmed);
      }
    }
    return values;
  }

  void _handleNameChanged() {
    final currentName = normalizeQuery(_nameController.text);
    final catalogName = _catalogMatch == null
        ? ''
        : normalizeQuery(_catalogMatch!.name);
    if (_catalogMatch != null && currentName != catalogName) {
      _catalogMatch = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  List<String> get _matchingSuggestions {
    final query = normalizeQuery(_nameController.text);
    final suggestions = <String>[];
    for (final value in _normalizedSuggestionCatalog) {
      final normalized = normalizeQuery(value);
      final shouldInclude = query.isEmpty ? true : normalized.contains(query);
      if (!shouldInclude || normalized == query) {
        continue;
      }
      suggestions.add(value);
      if (suggestions.length >= 6) {
        break;
      }
    }
    return suggestions;
  }

  Future<void> _applySuggestion(String value) async {
    _nameController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    await _lookupCatalogByName(value, true);
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
    _catalogMatch = product;
    final productName = product.name.trim();
    if (productName.isNotEmpty &&
        normalizeQuery(_nameController.text) == normalizeQuery(productName)) {
      _nameController
        ..text = productName
        ..selection = TextSelection.collapsed(offset: productName.length);
    }
    _selectedCategory = product.category;
    final barcode = product.barcode;
    if (barcode != null &&
        barcode.isNotEmpty &&
        _barcodeController.text.trim().isEmpty) {
      _barcodeController
        ..text = barcode
        ..selection = TextSelection.collapsed(offset: barcode.length);
    }
    final price = product.unitPrice;
    if (price != null && price > 0) {
      _priceController.text = _currencyFormatter.formatValue(price);
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
        'Codigo lido, mas sem resultado online/local. Complete manualmente.',
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
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    final unitPrice = BrlCurrencyInputFormatter.tryParse(_priceController.text);
    if (quantity == null ||
        quantity < 1 ||
        unitPrice == null ||
        unitPrice <= 0) {
      return;
    }

    Navigator.pop(
      context,
      ShoppingItemDraft(
        name: _nameController.text.trim(),
        quantity: quantity,
        unitPrice: unitPrice,
        category: _selectedCategory,
        barcode: sanitizeBarcode(_barcodeController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final contentBottomPadding = max(20.0, safeBottomInset + 20);
    final isEditing = widget.existingItem != null;

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
                isEditing ? 'Editar produto' : 'Novo produto',
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
                  labelText: 'Codigo de barras (opcional)',
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
                onChanged: (_) => setState(() {}),
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Produto',
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
                    return 'Digite o nome do produto.';
                  }
                  if (widget.blockedNormalizedNames.contains(normalized)) {
                    return 'Esse produto já existe na lista.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _lookupCatalogByName(),
              ),
              if (_matchingSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Sugestões recentes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in _matchingSuggestions)
                      ActionChip(
                        avatar: const Icon(Icons.history_rounded, size: 16),
                        label: Text(suggestion),
                        onPressed: () =>
                            unawaited(_applySuggestion(suggestion)),
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
                          return 'Inválida';
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _currencyFormatter,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor unitario',
                        prefixIcon: Icon(Icons.monetization_on_rounded),
                        hintText: 'R\$ 0,00',
                      ),
                      validator: (value) {
                        final parsed = BrlCurrencyInputFormatter.tryParse(
                          value ?? '',
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_catalogMatch != null) ...[
                const SizedBox(height: 10),
                _CatalogPriceHint(product: _catalogMatch!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(
                    isEditing ? Icons.save_rounded : Icons.add_rounded,
                  ),
                  label: Text(isEditing ? 'Salvar item' : 'Adicionar item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogPriceHint extends StatelessWidget {
  const _CatalogPriceHint({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final history = product.priceHistory;
    final latestPrice =
        product.unitPrice ?? (history.isNotEmpty ? history.last.price : null);
    if (latestPrice == null || latestPrice <= 0) {
      return const SizedBox.shrink();
    }

    final previousPrice = history.length > 1
        ? history[history.length - 2].price
        : null;
    final variation = previousPrice == null || previousPrice <= 0
        ? null
        : ((latestPrice - previousPrice) / previousPrice) * 100;
    final variationText = variation == null
        ? 'Primeiro preço salvo no catálogo.'
        : variation > 0
        ? 'Subiu ${variation.abs().toStringAsFixed(1)}% em relação ao registro anterior.'
        : variation < 0
        ? 'Caiu ${variation.abs().toStringAsFixed(1)}% em relação ao registro anterior.'
        : 'Preco igual ao registro anterior.';

    final latestDate = history.isNotEmpty
        ? formatDateTime(history.last.recordedAt)
        : formatDateTime(product.updatedAt);
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preco sugerido: ${formatCurrency(latestPrice)}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$variationText Histórico local: ${history.length} registro(s). Última atualização: $latestDate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptStatChip extends StatelessWidget {
  const _ReceiptStatChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class BrlCurrencyInputFormatter extends TextInputFormatter {
  BrlCurrencyInputFormatter({NumberFormat? formatter})
    : _formatter =
          formatter ??
          NumberFormat.currency(
            locale: 'pt_BR',
            symbol: 'R\$',
            decimalDigits: 2,
          );

  final NumberFormat _formatter;

  String formatValue(double value) => _formatter.format(value);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final value = double.parse(digits) / 100;
    final formatted = _formatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static double? tryParse(String rawText) {
    final digits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return double.parse(digits) / 100;
  }
}
