import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../application/ports.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';

class NoopShoppingReminderService implements ShoppingReminderService {
  const NoopShoppingReminderService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleForList(ShoppingListModel list) async {}

  @override
  Future<void> cancelForList(String listId) async {}

  @override
  Future<void> notifyBudgetNearLimit(
    ShoppingListModel list, {
    required double budgetUsageRatio,
  }) async {}

  @override
  Future<void> notifySyncPending({
    required int pendingRecords,
    required bool hasNetworkConnection,
  }) async {}

  @override
  Future<void> syncFromLists(
    List<ShoppingListModel> lists, {
    bool reset = false,
  }) async {}
}

class LocalNotificationsReminderService implements ShoppingReminderService {
  LocalNotificationsReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'shopping_reminders_channel',
    'Lembretes de compras',
    description: 'Avisos locais para lembrar das listas de compras.',
    importance: Importance.max,
  );

  static final DateFormat _timeFormatter = DateFormat('HH:mm');
  static final DateFormat _dateFormatter = DateFormat('dd/MM');

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _canScheduleExactNotifications = false;
  bool _notificationsEnabled = true;
  final Map<String, DateTime> _notificationThrottle = <String, DateTime>{};

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    await _refreshAndroidCapabilities(requestIfNeeded: true);
    _initialized = true;
  }

  Future<void> _refreshAndroidCapabilities({
    required bool requestIfNeeded,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return;
    }

    if (requestIfNeeded) {
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (error, stackTrace) {
        _log('Falha ao solicitar permissão de notificações', error, stackTrace);
      }
    }

    try {
      final enabled = await androidPlugin.areNotificationsEnabled();
      if (enabled != null) {
        _notificationsEnabled = enabled;
      }
    } catch (error, stackTrace) {
      _log(
        'Falha ao verificar se notificações estão ativas',
        error,
        stackTrace,
      );
    }

    try {
      var canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact && requestIfNeeded) {
        await androidPlugin.requestExactAlarmsPermission();
        canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }
      _canScheduleExactNotifications = canScheduleExact;
    } catch (error, stackTrace) {
      _canScheduleExactNotifications = false;
      _log('Falha ao verificar permissão de alarme exato', error, stackTrace);
    }

    try {
      await androidPlugin.createNotificationChannel(_channel);
    } catch (error, stackTrace) {
      _log('Falha ao criar canal de notificacao', error, stackTrace);
    }
  }

  Future<void> _configureLocalTimezone() async {
    final candidates = <String>[];
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final identifier = timezoneInfo.identifier.trim();
      if (identifier.isNotEmpty) {
        candidates.add(identifier);
        candidates.add(identifier.replaceAll(' ', '_'));
      }
    } catch (_) {}

    candidates.addAll(const <String>[
      'America/Sao_Paulo',
      'Brazil/East',
      'Etc/GMT+3',
      'UTC',
    ]);

    final tried = <String>{};
    for (final timezoneId in candidates) {
      if (!tried.add(timezoneId)) {
        continue;
      }
      try {
        final location = tz.getLocation(timezoneId);
        tz.setLocalLocation(location);
        return;
      } catch (_) {
        continue;
      }
    }

    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  @override
  Future<void> scheduleForList(ShoppingListModel list) async {
    if (list.isClosed || list.reminder == null) {
      await cancelForList(list.id);
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _refreshAndroidCapabilities(requestIfNeeded: false);
    if (!_notificationsEnabled) {
      await _refreshAndroidCapabilities(requestIfNeeded: true);
      if (!_notificationsEnabled) {
        _log(
          'Notificações desativadas no sistema. Lembrete não será agendado.',
          null,
          null,
        );
        return;
      }
    }

    final reminderDate = list.reminder!.nextOccurrence();
    if (!reminderDate.isAfter(DateTime.now())) {
      await cancelForList(list.id);
      _log(
        'Lembrete descartado por estar no passado: ${list.name}',
        null,
        null,
      );
      return;
    }

    final scheduleDate = tz.TZDateTime.from(reminderDate, tz.local);
    final notificationId = _notificationIdForList(list.id);
    final preNotificationId = _preNotificationIdForList(list.id);
    final title = _buildNotificationTitle(list, reminderDate);
    final body = _buildNotificationBody(list, reminderDate);

    await _plugin.cancel(id: notificationId);
    await _plugin.cancel(id: preNotificationId);

    await _scheduleNotification(
      id: notificationId,
      scheduledDate: scheduleDate,
      title: title,
      body: body,
      payload: list.id,
    );

    final preReminderDate = reminderDate.subtract(const Duration(hours: 2));
    if (preReminderDate.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      await _scheduleNotification(
        id: preNotificationId,
        scheduledDate: tz.TZDateTime.from(preReminderDate, tz.local),
        title: 'Hora de comprar em breve',
        body:
            'Faltam cerca de 2h para a lista "${list.name}". Ja deixe tudo preparado.',
        payload: '${list.id}:pre',
      );
    }

    _log(
      'Lembrete agendado para ${list.name} em ${scheduleDate.toString()} (exact=$_canScheduleExactNotifications)',
      null,
      null,
    );
  }

  @override
  Future<void> cancelForList(String listId) async {
    if (!_initialized) {
      await initialize();
    }

    await _plugin.cancel(id: _notificationIdForList(listId));
    await _plugin.cancel(id: _preNotificationIdForList(listId));
  }

  @override
  Future<void> notifyBudgetNearLimit(
    ShoppingListModel list, {
    required double budgetUsageRatio,
  }) async {
    if (!list.hasBudget || budgetUsageRatio < 0.85 || budgetUsageRatio >= 1.0) {
      return;
    }
    if (!_shouldNotify(
      'budget_${list.id}',
      cooldown: const Duration(hours: 4),
    )) {
      return;
    }
    final budget = list.budget ?? 0;
    final usedPercent = (budgetUsageRatio * 100).clamp(0, 999).round();
    final remaining = max<double>(0, budget - list.totalValue);
    await _showImmediateNotification(
      id: 910000000 + (_notificationIdForList(list.id) % 99999),
      title: 'Orcamento quase no limite',
      body:
          'Lista "${list.name}" ja consumiu $usedPercent% do orcamento. Restante: ${formatCurrency(remaining)}.',
      payload: '${list.id}:budget',
    );
  }

  @override
  Future<void> notifySyncPending({
    required int pendingRecords,
    required bool hasNetworkConnection,
  }) async {
    if (pendingRecords <= 0 || hasNetworkConnection) {
      return;
    }
    if (
        !_shouldNotify('sync_pending', cooldown: const Duration(minutes: 45))) {
      return;
    }
    await _showImmediateNotification(
      id: 920000001,
      title: 'Lista sem sync',
      body:
          '$pendingRecords registro(s) aguardando internet para sincronizar.',
      payload: 'sync-pending',
    );
  }

  @override
  Future<void> syncFromLists(
    List<ShoppingListModel> lists, {
    bool reset = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (reset) {
      try {
        await _plugin.cancelAllPendingNotifications();
      } catch (_) {
        await _plugin.cancelAll();
      }
    }

    for (final list in lists) {
      if (list.reminder == null || list.isClosed) {
        await cancelForList(list.id);
      } else {
        await scheduleForList(list);
      }
    }
  }

  int _notificationIdForList(String listId) {
    final hash = listId.hashCode & 0x7fffffff;
    return 100000 + (hash % 400000000);
  }

  int _preNotificationIdForList(String listId) {
    return _notificationIdForList(listId) + 400000000;
  }

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(const <int>[
            0,
            220,
            140,
            220,
            140,
            320,
          ]),
          ticker: 'Lembrete Minhas Compras',
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'Minhas Compras',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: 'Minhas Compras',
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: 'Minhas Compras',
        ),
      ),
      androidScheduleMode: _canScheduleExactNotifications
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    await _refreshAndroidCapabilities(requestIfNeeded: false);
    if (!_notificationsEnabled) {
      return;
    }
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'Minhas Compras',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: 'Minhas Compras',
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: 'Minhas Compras',
        ),
      ),
      payload: payload,
    );
  }

  bool _shouldNotify(String key, {required Duration cooldown}) {
    final now = DateTime.now();
    final last = _notificationThrottle[key];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _notificationThrottle[key] = now;
    return true;
  }

  String _buildNotificationTitle(ShoppingListModel list, DateTime when) {
    final now = DateTime.now();
    if (_sameDate(now, when)) {
      return 'Sua compra acontece hoje';
    }
    if (_sameDate(now.add(const Duration(days: 1)), when)) {
      return 'Sua compra é amanhã';
    }
    return 'Lembrete de compras';
  }

  String _buildNotificationBody(ShoppingListModel list, DateTime when) {
    final timeText = _timeFormatter.format(when);
    final dateText = _dateFormatter.format(when);
    final totalText = formatCurrency(list.totalValue);
    final itemsText =
        '${list.totalItems} item${list.totalItems == 1 ? '' : 's'}';

    final now = DateTime.now();
    if (_sameDate(now, when)) {
      return 'Não se esqueça da lista "${list.name}" às $timeText. $itemsText • Total $totalText.';
    }
    return 'Lista "${list.name}" marcada para $dateText às $timeText. $itemsText • Total $totalText.';
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _log(String message, Object? error, StackTrace? stackTrace) {
    if (!kDebugMode) {
      return;
    }
    if (error == null) {
      debugPrint('[Reminder] $message');
      return;
    }
    debugPrint('[Reminder] $message: $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
}
