import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Jenis aksi yang bisa ditekan dari notification action button
/// (section 13: ✅ Selesai / ⏰ Ingatkan 1 jam lagi / 🔕 Hentikan Reminder).
enum NotificationAction { markCompleted, snoozeOneHour, stopReminder, tapOpen }

class NotificationActionEvent {
  final NotificationAction action;
  final String taskId;
  const NotificationActionEvent(this.action, this.taskId);
}

/// Wrapper flutter_local_notifications: init, channel, permission, jadwal
/// exact-alarm, dan action buttons. Tidak menyimpan state task apa pun di
/// sini — murni lapisan notifikasi, orkestrasi ada di ReminderScheduler.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _actionController = StreamController<NotificationActionEvent>.broadcast();

  /// Didengarkan main.dart untuk meneruskan aksi ke TaskRepository/ReminderScheduler.
  Stream<NotificationActionEvent> get actionStream => _actionController.stream;

  static const _channelReminder = AndroidNotificationChannel(
    'reminder_channel',
    'Pengingat Jadwal',
    description: 'Notifikasi pengingat untuk jadwal & tugas.',
    importance: Importance.high,
  );

  static const _channelHourly = AndroidNotificationChannel(
    'hourly_channel',
    'Pengingat Tiap Jam',
    description: 'Notifikasi berulang tiap jam untuk tugas yang belum selesai.',
    importance: Importance.max,
  );

  Future<void> init() async {
    // Zona waktu dipaksa Asia/Jakarta (WIB) sesuai section 8 — aplikasi ini
    // memang didesain untuk satu zona waktu, jadi tidak perlu deteksi
    // timezone perangkat.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelReminder);
    await androidPlugin?.createNotificationChannel(_channelHourly);
  }

  void _onResponse(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty) return;
    final action = switch (response.actionId) {
      'mark_completed' => NotificationAction.markCompleted,
      'snooze_one_hour' => NotificationAction.snoozeOneHour,
      'stop_reminder' => NotificationAction.stopReminder,
      _ => NotificationAction.tapOpen,
    };
    _actionController.add(NotificationActionEvent(action, taskId));
  }

  /// Minta izin notifikasi (Android 13+) & exact alarm (Android 12+).
  /// Dipanggil sekali saat onboarding/pertama kali butuh reminder, BUKAN
  /// langsung saat app start (section 44: minta permission sesuai kebutuhan).
  Future<bool> requestPermissions() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted = await androidPlugin?.requestNotificationsPermission() ?? false;
    final exactGranted = await androidPlugin?.requestExactAlarmsPermission() ?? true;
    return notifGranted && exactGranted;
  }

  List<AndroidNotificationAction> _taskActions() => const [
        AndroidNotificationAction('mark_completed', '✅ Selesai'),
        AndroidNotificationAction('snooze_one_hour', '⏰ Ingatkan 1 jam lagi'),
        AndroidNotificationAction('stop_reminder', '🔕 Hentikan Reminder'),
      ];

  /// Jadwalkan satu notifikasi exact di [scheduledAt]. [id] harus unik &
  /// deterministik supaya bisa di-cancel lagi nanti (lihat ReminderScheduler
  /// untuk skema id per task per jam).
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String taskId,
    bool hourly = false,
    bool withTaskActions = true,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        hourly ? _channelHourly.id : _channelReminder.id,
        hourly ? _channelHourly.name : _channelReminder.name,
        channelDescription: hourly ? _channelHourly.description : _channelReminder.description,
        importance: hourly ? Importance.max : Importance.high,
        priority: Priority.high,
        actions: withTaskActions ? _taskActions() : null,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> pending() => _plugin.pendingNotificationRequests();

  void dispose() {
    _actionController.close();
  }
}
