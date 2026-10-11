import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';
import '../theme/editorial_workspace_theme.dart';
import '../utils/app_modal.dart';
import '../utils/time_utils.dart';

Future<ReminderEditorResult?> showReminderEditorDialog(
  BuildContext context, {
  ShoppingReminderConfig? initialValue,
  DateTime Function()? nowProvider,
}) => showAppDialog<ReminderEditorResult>(
  context: context,
  builder: (context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: _ReminderEditorDialog(
      initialValue: initialValue,
      nowProvider: nowProvider ?? DateTime.now,
    ),
  ),
);

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({this.initialValue, required this.nowProvider});
  final ShoppingReminderConfig? initialValue;
  final DateTime Function() nowProvider;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  late bool _enabled;
  late DateTime _date;
  late TimeOfDay _time;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialValue?.scheduledAt ??
        widget.nowProvider().add(const Duration(hours: 1));
    _enabled = widget.initialValue != null;
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay.fromDateTime(initial);
  }

  DateTime get _scheduledAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = widget.nowProvider();
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 15);
    // Expired reminders remain unchanged until the user confirms a new date.
    final initial = _date.isBefore(first)
        ? first
        : _date.isAfter(last)
        ? last
        : _date;
    final result = await showAppDatePicker(
      context: context,
      initialDate: initial,
      currentDate: now,
      firstDate: first,
      lastDate: last,
      helpText: 'Data do lembrete',
    );
    if (!mounted || result == null) return;
    setState(() {
      _date = result;
      _showError = false;
    });
  }

  Future<void> _pickTime() async {
    final result = await showAppTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Horário do lembrete',
    );
    if (!mounted || result == null) return;
    setState(() {
      _time = result;
      _showError = false;
    });
  }

  void _save() {
    if (!_enabled) {
      Navigator.pop(context, const ReminderEditorResult(clear: true));
    } else if (!_scheduledAt.isAfter(widget.nowProvider())) {
      setState(() => _showError = true);
    } else {
      Navigator.pop(
        context,
        ReminderEditorResult(
          value: ShoppingReminderConfig(scheduledAt: _scheduledAt),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lembrete da lista',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 48,
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 22),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Receba um aviso local para revisar sua lista.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 20),
                          Material(
                            color: colors.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: colors.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SwitchListTile(
                              value: _enabled,
                              onChanged: (value) => setState(() {
                                _enabled = value;
                                _showError = false;
                              }),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              title: Text(
                                'Ativar lembrete',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ScheduleField(
                            label: 'Data planejada',
                            value: formatShortDate(_date),
                            icon: Icons.calendar_today_outlined,
                            onPressed: _enabled ? _pickDate : null,
                          ),
                          const SizedBox(height: 16),
                          _ScheduleField(
                            label: 'Horário do alerta',
                            value: formatTimeOfDay(_time),
                            icon: Icons.schedule,
                            onPressed: _enabled ? _pickTime : null,
                          ),
                          if (_enabled && _showError) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'Escolha uma data e horário no futuro.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: shape,
                    ),
                    onPressed: _save,
                    child: const Text('Salvar lembrete'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: shape,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  if (widget.initialValue != null) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: colors.error,
                        shape: shape,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        const ReminderEditorResult(clear: true),
                      ),
                      icon: const Icon(
                        Icons.notifications_off_outlined,
                        size: 18,
                      ),
                      label: const Text('Remover lembrete'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.value,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: onPressed == null ? null : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}
