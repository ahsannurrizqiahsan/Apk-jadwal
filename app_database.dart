import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Wrapper singleton untuk database SQLite lokal. Dipilih sqflite murni
/// (tanpa Isar/Drift) supaya project tidak butuh langkah `build_runner`
/// sebelum pertama kali di-run — lihat README bagian "Keputusan Teknis".
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static const _dbName = 'voice_schedule.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      // onUpgrade: tambahkan migrasi di sini saat skema berubah di versi berikutnya.
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        time TEXT,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        reminderTime TEXT,
        hourlyReminder INTEGER NOT NULL DEFAULT 0,
        hourlyStartTime TEXT NOT NULL DEFAULT '07:00',
        hourlyEndTime TEXT NOT NULL DEFAULT '22:00',
        recurrence TEXT NOT NULL DEFAULT 'none',
        recurrenceDaysOfWeek TEXT,
        recurrenceDayOfMonth INTEGER,
        createdAt TEXT NOT NULL,
        completedAt TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_date ON tasks(date)');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
