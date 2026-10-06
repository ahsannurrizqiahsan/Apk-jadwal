import '../core/utils/indo_datetime_parser.dart';

/// Intent minimal sesuai section 32.
enum CommandIntent {
  createEvent,
  createTask,
  createNote,
  updateEvent,
  deleteEvent,
  completeTask,
  getTodaySchedule,
  getTomorrowSchedule,
  getWeekSchedule,
  enableReminder,
  disableReminder,
}

/// Output terstruktur dari lapisan AI, dipakai voice_screen.dart untuk
/// memanggil TaskRepository/ReminderScheduler. Field mengikuti JSON di
/// section 8 & 32.
class ParsedCommand {
  final CommandIntent intent;
  final String? title;
  final DateTime? dateTime;
  final bool hasExplicitTime;
  final Duration? reminderOffset;
  final bool hourlyReminder;
  final String rawText;

  const ParsedCommand({
    required this.intent,
    this.title,
    this.dateTime,
    this.hasExplicitTime = false,
    this.reminderOffset,
    this.hourlyReminder = false,
    required this.rawText,
  });
}

/// Titik ekstensi untuk AI layer "sungguhan" lewat LLM API. Dibuat sebagai
/// typedef yang di-inject, BUKAN dipanggil langsung di dalam service ini,
/// supaya:
///   1. API key tidak pernah hardcoded di source (section 45) — pemanggil
///      yang menyuntikkan fungsi ini dari konfigurasi/env var.
///   2. Service ini tetap bisa di-unit-test tanpa jaringan.
/// Kembalikan null kalau request gagal/tidak yakin -> otomatis fallback
/// ke parser lokal di bawah.
typedef RemoteCommandParser = Future<ParsedCommand?> Function(String text, DateTime now);

/// Lapisan AI command (section 32). Tanpa [remoteParser], service ini
/// berjalan sepenuhnya dengan parser lokal rule-based (section 33) — jadi
/// app tetap fungsional tanpa API key/internet, sesuai requirement spek.
class AiCommandService {
  AiCommandService({RemoteCommandParser? remoteParser, IndoDateTimeParser? dateTimeParser})
      : _remoteParser = remoteParser,
        _dateTimeParser = dateTimeParser ?? const IndoDateTimeParser();

  final RemoteCommandParser? _remoteParser;
  final IndoDateTimeParser _dateTimeParser;

  Future<ParsedCommand> parse(String text, {DateTime? now}) async {
    final referenceTime = now ?? DateTime.now();

    if (_remoteParser != null) {
      try {
        final remoteResult = await _remoteParser(text, referenceTime);
        if (remoteResult != null) return remoteResult;
      } catch (_) {
        // AI API error / offline -> diam-diam fallback ke parser lokal,
        // sesuai section 33 ("Jika AI API sedang tidak tersedia, aplikasi
        // masih dapat menangani command sederhana").
      }
    }
    return _parseLocally(text, referenceTime);
  }

  ParsedCommand _parseLocally(String text, DateTime now) {
    final lower = text.toLowerCase();
    final intent = _classifyIntent(lower);
    final dt = _dateTimeParser.parse(text, now);
    final offset = _dateTimeParser.parseReminderOffset(text);
    final hourly = lower.contains('tiap jam') || lower.contains('setiap jam');

    return ParsedCommand(
      intent: intent,
      title: _extractTitle(text),
      dateTime: dt.dateTime,
      hasExplicitTime: dt.hasExplicitTime,
      reminderOffset: offset,
      hourlyReminder: hourly,
      rawText: text,
    );
  }

  CommandIntent _classifyIntent(String lower) {
    if (_any(lower, ['jadwal hari ini', 'kegiatan hari ini', 'jadwalku hari ini'])) {
      return CommandIntent.getTodaySchedule;
    }
    if (_any(lower, ['jadwalku besok', 'besok ada kegiatan', 'jadwal besok', 'besok aku ada'])) {
      return CommandIntent.getTomorrowSchedule;
    }
    if (_any(lower, ['minggu ini tugas', 'jadwal minggu ini'])) {
      return CommandIntent.getWeekSchedule;
    }
    if (_any(lower, ['sudah selesai', 'tandai', 'selesaikan tugas'])) {
      return CommandIntent.completeTask;
    }
    if (_any(lower, ['hapus', 'batalkan jadwal'])) {
      return CommandIntent.deleteEvent;
    }
    if (_any(lower, ['pindahkan', 'ubah deadline', 'ubah jadwal', 'ganti jadwal'])) {
      return CommandIntent.updateEvent;
    }
    if (_any(lower, ['matikan reminder', 'hentikan reminder', 'nonaktifkan pengingat'])) {
      return CommandIntent.disableReminder;
    }
    if (_any(lower, ['ingatkan setiap jam', 'ingatkan tiap jam']) &&
        !_any(lower, ['tugas', 'harus'])) {
      return CommandIntent.enableReminder;
    }
    if (_any(lower, ['catat', 'catatan'])) {
      return CommandIntent.createNote;
    }
    if (_any(lower, ['tugas', 'harus menyelesaikan', 'harus mengerjakan', 'pekerjaan', 'proposal', 'laporan'])) {
      return CommandIntent.createTask;
    }
    // Default: kegiatan/jadwal biasa — kasus paling umum di contoh spek.
    return CommandIntent.createEvent;
  }

  bool _any(String text, List<String> needles) => needles.any(text.contains);

  /// Ekstraksi judul heuristik kasar (buang token tanggal/waktu & kata
  /// kunci umum). Lapisan AI sungguhan jauh lebih baik di sini — ini murni
  /// fallback supaya app tidak buntu tanpa API.
  String _extractTitle(String text) {
    var t = text;
    const stripPhrases = [
      'besok', 'lusa', 'hari ini', 'nanti malam', 'sore ini', 'pagi ini',
      'minggu depan', 'minggu ini', 'ingatkan setiap jam', 'ingatkan tiap jam',
      'tolong', 'catat hari ini', 'catat', 'tambahkan tugas', 'buat tugas', 'buat jadwal',
    ];
    for (final p in stripPhrases) {
      t = t.replaceAll(RegExp(RegExp.escape(p), caseSensitive: false), ' ');
    }
    t = t.replaceAll(RegExp(r'jam \S+'), ' ');
    t = t.replaceAll(RegExp(r'tanggal \d+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return text.trim();
    return t[0].toUpperCase() + t.substring(1);
  }
}
