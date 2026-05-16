import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/format_utils.dart';
import '../domain/models_and_utils.dart';
import 'dialogs/sheets/fiscal_receipt_import_sheet.dart';
import 'dialogs/sheets/replenishment_suggestions_sheet.dart';
import 'dialogs/widgets/brl_currency_input_formatter.dart';
import 'utils/app_modal.dart';
import 'utils/time_utils.dart';

export 'dialogs/sheets/barcode_scanner_sheet.dart' show showBarcodeScannerSheet;
export 'dialogs/sheets/shopping_item_editor_sheet.dart';
export 'dialogs/widgets/brl_currency_input_formatter.dart';

Future<String?> showListNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: initialValue);

  final result = await showAppDialog<String>(
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

  final result = await showAppDialog<BudgetEditorResult>(
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

  return showAppDialog<PaymentBalancesEditorResult>(
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
    return await showAppDialog<PaymentBalance>(
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
                        labelText: 'Saldo disponível',
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

  return showAppDialog<ReminderEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate() async {
            final selected = await showAppDatePicker(
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
            final selected = await showAppTimePicker(
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

  return showAppDialog<PurchaseCheckoutResult>(
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
                    subtitle: Text(
                      pendingCount == 1
                          ? '1 item pendente.'
                          : '$pendingCount itens pendentes.',
                    ),
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
  return showAppModalBottomSheet<ShoppingListModel>(
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

Future<List<ReplenishmentSuggestion>?> showReplenishmentSuggestionsSheet(
  BuildContext context, {
  required List<ReplenishmentSuggestion> suggestions,
}) {
  return showAppModalBottomSheet<List<ReplenishmentSuggestion>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        ReplenishmentSuggestionsSheet(suggestions: suggestions),
  );
}

Future<List<ShoppingItemDraft>?> showFiscalReceiptImportSheet(
  BuildContext context, {
  List<ShoppingItem> currentItems = const <ShoppingItem>[],
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
}) {
  return showAppModalBottomSheet<List<ShoppingItemDraft>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FiscalReceiptImportSheet(
      currentItems: currentItems,
      catalogProducts: catalogProducts,
    ),
  );
}
