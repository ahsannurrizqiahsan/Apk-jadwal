/// Tipe item: jadwal, tugas, catatan, atau pengingat berdiri sendiri.
enum TaskType { schedule, task, note, reminder }

enum TaskStatus { pending, completed, cancelled }

/// Frekuensi perulangan (section 19). Disimpan simpel, bukan full RRULE,
/// supaya cukup untuk kasus yang disebut di spek (tiap Senin, tiap tanggal 1,
/// tiap malam jam 10).
enum RecurrenceFrequency { none, daily, weekly, monthly, yearly }

extension TaskTypeX on TaskType {
  String get dbValue => name;
  static TaskType fromDb(String v) => TaskType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TaskType.task,
      );
}

extension TaskStatusX on TaskStatus {
  String get dbValue => name;
  static TaskStatus fromDb(String v) => TaskStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TaskStatus.pending,
      );
}

extension RecurrenceFrequencyX on RecurrenceFrequency {
  String get dbValue => name;
  static RecurrenceFrequency fromDb(String? v) => RecurrenceFrequency.values.firstWhere(
        (e) => e.name == v,
        orElse: () => RecurrenceFrequency.none,
      );
}

/// Representasi satu item (jadwal/tugas/catatan/reminder) di database lokal.
/// Field mengikuti daftar di section 25 spek.
class TaskModel {
  final String id; // uuid v4, dibuat di repository saat insert
  final String title;
  final String? description;

  /// Tanggal kejadian/deadline, disimpan sebagai DateTime (jam di dalamnya
  /// dipakai jika [time] null — lihat [occursAt]).
  final DateTime date;

  /// Jam spesifik, kalau perintah suara menyebutkannya terpisah dari
  /// tanggal. Kalau null, dianggap "sepanjang hari" / tanpa jam pasti.
  final DateTime? time;

  final TaskType type;
  final TaskStatus status;

  final bool reminderEnabled;
  final DateTime? reminderTime; // waktu persis notifikasi reminder biasa akan muncul

  final bool hourlyReminder;
  final String hourlyStartTime; // format "HH:mm", default "07:00"
  final String hourlyEndTime; // format "HH:mm", default "22:00"

  final RecurrenceFrequency recurrence;
  final List<int>? recurrenceDaysOfWeek; // 1=Senin..7=Minggu (DateTime.weekday), untuk weekly
  final int? recurrenceDayOfMonth; // untuk monthly, mis. "tiap tanggal 1"

  final DateTime createdAt;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.time,
    this.type = TaskType.task,
    this.status = TaskStatus.pending,
    this.reminderEnabled = false,
    this.reminderTime,
    this.hourlyReminder = false,
    this.hourlyStartTime = '07:00',
    this.hourlyEndTime = '22:00',
    this.recurrence = RecurrenceFrequency.none,
    this.recurrenceDaysOfWeek,
    this.recurrenceDayOfMonth,
    required this.createdAt,
    this.completedAt,
  });

  /// Tanggal+jam efektif kejadian ini — gabungan [date] dan [time] jika ada.
  DateTime get occursAt {
    if (time != null) return time!;
    return date;
  }

  TaskModel copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? time,
    bool clearTime = false,
    TaskType? type,
    TaskStatus? status,
    bool? reminderEnabled,
    DateTime? reminderTime,
    bool? hourlyReminder,
    String? hourlyStartTime,
    String? hourlyEndTime,
    RecurrenceFrequency? recurrence,
    List<int>? recurrenceDaysOfWeek,
    int? recurrenceDayOfMonth,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: clearTime ? null : (time ?? this.time),
      type: type ?? this.type,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      hourlyReminder: hourlyReminder ?? this.hourlyReminder,
      hourlyStartTime: hourlyStartTime ?? this.hourlyStartTime,
      hourlyEndTime: hourlyEndTime ?? this.hourlyEndTime,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek ?? this.recurrenceDaysOfWeek,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time?.toIso8601String(),
      'type': type.dbValue,
      'status': status.dbValue,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderTime': reminderTime?.toIso8601String(),
      'hourlyReminder': hourlyReminder ? 1 : 0,
      'hourlyStartTime': hourlyStartTime,
      'hourlyEndTime': hourlyEndTime,
      'recurrence': recurrence.dbValue,
      'recurrenceDaysOfWeek': recurrenceDaysOfWeek?.join(','),
      'recurrenceDayOfMonth': recurrenceDayOfMonth,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, Object?> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      time: map['time'] != null ? DateTime.parse(map['time'] as String) : null,
      type: TaskTypeX.fromDb(map['type'] as String),
      status: TaskStatusX.fromDb(map['status'] as String),
      reminderEnabled: (map['reminderEnabled'] as int? ?? 0) == 1,
      reminderTime:
          map['reminderTime'] != null ? DateTime.parse(map['reminderTime'] as String) : null,
      hourlyReminder: (map['hourlyReminder'] as int? ?? 0) == 1,
      hourlyStartTime: map['hourlyStartTime'] as String? ?? '07:00',
      hourlyEndTime: map['hourlyEndTime'] as String? ?? '22:00',
      recurrence: RecurrenceFrequencyX.fromDb(map['recurrence'] as String?),
      recurrenceDaysOfWeek: (map['recurrenceDaysOfWeek'] as String?)
          ?.split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList(),
      recurrenceDayOfMonth: map['recurrenceDayOfMonth'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
    );
  }
}
