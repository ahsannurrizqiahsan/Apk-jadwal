import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/task_model.dart';

/// Sumber data tunggal untuk semua operasi terhadap tasks/jadwal/catatan.
/// Dibuat sebagai ChangeNotifier supaya Home/Calendar/Tasks screen otomatis
/// refresh begitu ada perubahan dari voice command maupun dari UI manual.
class TaskRepository extends ChangeNotifier {
  TaskRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<TaskModel> create({
    required String title,
    String? description,
    required DateTime date,
    DateTime? time,
    TaskType type = TaskType.task,
    bool reminderEnabled = false,
    DateTime? reminderTime,
    bool hourlyReminder = false,
    String hourlyStartTime = '07:00',
    String hourlyEndTime = '22:00',
    RecurrenceFrequency recurrence = RecurrenceFrequency.none,
    List<int>? recurrenceDaysOfWeek,
    int? recurrenceDayOfMonth,
  }) async {
    final task = TaskModel(
      id: _uuid.v4(),
      title: title,
      description: description,
      date: date,
      time: time,
      type: type,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      hourlyReminder: hourlyReminder,
      hourlyStartTime: hourlyStartTime,
      hourlyEndTime: hourlyEndTime,
      recurrence: recurrence,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek,
      recurrenceDayOfMonth: recurrenceDayOfMonth,
      createdAt: DateTime.now(),
    );
    final db = await _database.database;
    await db.insert('tasks', task.toMap());
    notifyListeners();
    return task;
  }

  Future<void> update(TaskModel task) async {
    final db = await _database.database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Tandai selesai. NotificationService/ReminderScheduler yang memanggil
  /// repository ini bertanggung jawab membatalkan reminder terkait
  /// (lihat voice_screen.dart & reminder_scheduler.dart untuk orkestrasinya).
  Future<TaskModel?> markCompleted(String id) async {
    final task = await getById(id);
    if (task == null) return null;
    final updated = task.copyWith(status: TaskStatus.completed, completedAt: DateTime.now());
    await update(updated);
    return updated;
  }

  Future<TaskModel?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TaskModel.fromMap(rows.first);
  }

  /// Semua item (jadwal/tugas/catatan/reminder) pada satu tanggal kalender.
  Future<List<TaskModel>> getForDate(DateTime date) async {
    final db = await _database.database;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'tasks',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'time ASC, createdAt ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  /// Dipakai kalender bulanan untuk menandai tanggal yang punya kegiatan.
  Future<Map<DateTime, List<TaskModel>>> getForMonth(DateTime anyDayInMonth) async {
    final db = await _database.database;
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final end = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final rows = await db.query(
      'tasks',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );
    final tasks = rows.map(TaskModel.fromMap).toList();
    final grouped = <DateTime, List<TaskModel>>{};
    for (final t in tasks) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  }

  Future<List<TaskModel>> getPending() async {
    final db = await _database.database;
    final rows = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [TaskStatus.pending.dbValue],
      orderBy: 'date ASC, time ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  /// Semua task dengan hourlyReminder aktif & masih pending — dipakai
  /// ReminderScheduler untuk reschedule massal (mis. setelah boot restore).
  Future<List<TaskModel>> getActiveHourlyReminders() async {
    final db = await _database.database;
    final rows = await db.query(
      'tasks',
      where: 'hourlyReminder = 1 AND status = ?',
      whereArgs: [TaskStatus.pending.dbValue],
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  /// Pencarian judul sederhana (contains, case-insensitive) — dipakai voice
  /// command edit/complete seperti "Tandai laporan sudah selesai" (section 14).
  Future<List<TaskModel>> searchByTitle(String keyword) async {
    final db = await _database.database;
    final rows = await db.query(
      'tasks',
      where: 'LOWER(title) LIKE ? AND status = ?',
      whereArgs: ['%${keyword.toLowerCase()}%', TaskStatus.pending.dbValue],
      orderBy: 'date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }
}
