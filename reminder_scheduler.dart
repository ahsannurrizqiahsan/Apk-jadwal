import '../data/models/task_model.dart';
import '../data/repositories/task_repository.dart';
import 'notification_service.dart';

/// Mengatur kapan & notifikasi apa yang dijadwalkan untuk tiap task —
/// termasuk fitur paling penting di spek: hourly reminder (section 9-13).
///
/// KEPUTUSAN DESAIN: reminder per-jam dijadwalkan sebagai notifikasi
/// exact-alarm INDIVIDUAL untuk tiap slot jam (lewat NotificationService),
/// BUKAN lewat WorkManager yang membangunkan Dart isolate tiap jam.
/// Alasan: WorkManager tunduk ke battery/task-killer masing-masing OEM
/// (Xiaomi/Samsung/Oppo dkk terkenal agresif mematikan background task),
/// sedangkan AlarmManager asli Android (yang dipakai flutter_local_notifications
/// di balik layar) jauh lebih reliable untuk "tampilkan notifikasi di jam X".
/// `workmanager` di proyek ini hanya dipakai untuk boot-restore (section 28).
class ReminderScheduler {
  ReminderScheduler({
    required TaskRepository repository,
    NotificationService? notificationService,
  })  : _repository = repository,
        _notifications = notificationService ?? NotificationService.instance;

  final TaskRepository _repository;
  final NotificationService _notifications;

  static const _hourlyMessages = [
    'Jangan lupa {title}.',
    'Pengingat: {title} belum selesai.',
    'Kamu masih punya tugas {title}.',
  ];

  /// Skema ID notifikasi: 100 slot per task (00-99), dialokasikan dari hash
  /// judul+id task supaya deterministik & bisa dibatalkan lagi tanpa
  /// menyimpan daftar ID terpisah. Risiko tabrakan antar task sangat kecil
  /// untuk aplikasi single-user seperti ini.
  int _baseId(String taskId) => (taskId.hashCode & 0x7FFFFFF) * 100;
  int _hourlySlotId(String taskId, int hour) => _baseId(taskId) + hour; // 0-23
  int _singleReminderId(String taskId) => _baseId(taskId) + 50;
  int _snoozeId(String taskId) => _baseId(taskId) + 51;

  int _parseHour(String hhmm) => int.parse(hhmm.split(':').first);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Jadwalkan ulang semua slot jam untuk [task] pada tanggal task tersebut,
  /// dalam rentang hourlyStartTime..hourlyEndTime. Idempotent — aman
  /// dipanggil berkali-kali (mis. tiap kali app start / boot restore).
  Future<void> scheduleHourlyForTask(TaskModel task) async {
    await cancelHourlyForTask(task.id);
    if (!task.hourlyReminder || task.status != TaskStatus.pending) return;
    if (!_isSameDay(task.date, DateTime.now()) && task.date.isBefore(DateTime.now())) {
      return; // task hari lalu yang belum ditandai selesai — jangan ingatkan lagi
    }

    final startHour = _parseHour(task.hourlyStartTime);
    final endHour = _parseHour(task.hourlyEndTime);
    final now = DateTime.now();
    var messageIndex = 0;

    for (var h = startHour; h <= endHour; h++) {
      final slot = DateTime(task.date.year, task.date.month, task.date.day, h);
      if (slot.isBefore(now)) continue;
      final template = _hourlyMessages[messageIndex % _hourlyMessages.length];
      messageIndex++;
      await _notifications.scheduleAt(
        id: _hourlySlotId(task.id, h),
        title: 'Pengingat tugas',
        body: template.replaceAll('{title}', task.title),
        scheduledAt: slot,
        taskId: task.id,
        hourly: true,
      );
    }
  }

  Future<void> cancelHourlyForTask(String taskId) async {
    for (var h = 0; h < 24; h++) {
      await _notifications.cancel(_hourlySlotId(taskId, h));
    }
    await _notifications.cancel(_snoozeId(taskId));
  }

  /// Reminder biasa, satu kali (bukan hourly) — mis. "30 menit sebelumnya".
  Future<void> scheduleSingleReminder(TaskModel task) async {
    await _notifications.cancel(_singleReminderId(task.id));
    if (!task.reminderEnabled || task.reminderTime == null) return;
    if (task.status != TaskStatus.pending) return;
    if (task.reminderTime!.isBefore(DateTime.now())) return;

    await _notifications.scheduleAt(
      id: _singleReminderId(task.id),
      title: task.title,
      body: 'Dijadwalkan ${_formatTime(task.occursAt)}',
      scheduledAt: task.reminderTime!,
      taskId: task.id,
      hourly: false,
    );
  }

  /// Tombol "⏰ Ingatkan 1 jam lagi" di notifikasi (section 13).
  Future<void> snoozeOneHour(String taskId) async {
    final task = await _repository.getById(taskId);
    if (task == null) return;
    final next = DateTime.now().add(const Duration(hours: 1));
    await _notifications.scheduleAt(
      id: _snoozeId(taskId),
      title: 'Pengingat tugas',
      body: 'Kamu masih punya tugas ${task.title}.',
      scheduledAt: next,
      taskId: taskId,
      hourly: true,
    );
  }

  /// Dipanggil saat task ditandai selesai (lewat suara, checkbox, atau
  /// tombol notifikasi) — hentikan semua reminder untuk task itu.
  Future<void> onTaskCompleted(String taskId) async {
    await cancelHourlyForTask(taskId);
    await _notifications.cancel(_singleReminderId(taskId));
  }

  /// 🔕 "Hentikan Reminder" — task TETAP tersimpan, hanya reminder yang mati
  /// (section 13, beda dengan "Selesai" yang mengubah status).
  Future<void> stopReminderOnly(String taskId) async {
    await cancelHourlyForTask(taskId);
    await _notifications.cancel(_singleReminderId(taskId));
  }

  /// Dipanggil saat app start (main.dart) dan idealnya juga dari jalur
  /// boot-restore (lihat README & AndroidManifest untuk wiring native-nya,
  /// section 28). Menjadwalkan ulang semua reminder yang masih aktif supaya
  /// tidak hilang setelah app ditutup/HP restart.
  Future<void> rescheduleAllActiveReminders() async {
    final hourlyTasks = await _repository.getActiveHourlyReminders();
    for (final t in hourlyTasks) {
      await scheduleHourlyForTask(t);
    }
    final pending = await _repository.getPending();
    for (final t in pending) {
      if (t.reminderEnabled && t.reminderTime != null) {
        await scheduleSingleReminder(t);
      }
    }
  }

  /// Menangani tap pada action button notifikasi (section 13).
  Future<void> handleNotificationAction(NotificationActionEvent event) async {
    switch (event.action) {
      case NotificationAction.markCompleted:
        await _repository.markCompleted(event.taskId);
        await onTaskCompleted(event.taskId);
        break;
      case NotificationAction.snoozeOneHour:
        await snoozeOneHour(event.taskId);
        break;
      case NotificationAction.stopReminder:
        await stopReminderOnly(event.taskId);
        break;
      case NotificationAction.tapOpen:
        break; // navigasi ditangani di layer UI (main.dart), bukan di sini
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}.${dt.minute.toString().padLeft(2, '0')}';
}
