/// Parser tanggal & waktu berbahasa Indonesia, rule-based, tanpa dependensi
/// jaringan/AI. Ini adalah lapisan fallback (section 33 di spek): dipakai
/// ketika AiCommandService tidak bisa memanggil API (offline, API error),
/// dan juga sebagai validator/pre-processor sebelum hasil AI diterapkan.
///
/// Parser ini sengaja best-effort — bahasa natural punya ekor panjang kasus
/// yang sulit dicakup regex. Untuk kasus ambigu, AiCommandService yang punya
/// akses ke model bahasa adalah jalur utama; parser ini menjamin perintah
/// paling umum (lihat contoh di section 8) tetap berfungsi tanpa API key.
library;

class ParsedDateTime {
  /// Tanggal+jam hasil parsing. Null jika tidak ada informasi tanggal sama
  /// sekali yang terdeteksi di teks.
  final DateTime? dateTime;

  /// True jika teks menyebutkan jam secara eksplisit (bukan cuma tanggal).
  final bool hasExplicitTime;

  const ParsedDateTime({this.dateTime, this.hasExplicitTime = false});

  @override
  String toString() => 'ParsedDateTime(dateTime: $dateTime, hasExplicitTime: $hasExplicitTime)';
}

class IndoDateTimeParser {
  const IndoDateTimeParser();

  static const List<String> _hariNama = [
    'minggu', 'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu',
  ];

  static const Map<String, int> _angkaKata = {
    'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5,
    'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10,
    'sebelas': 11, 'duabelas': 12,
  };

  /// Parse [rawText] relatif terhadap waktu sekarang [now].
  /// PENTING: [now] harus sudah dalam waktu lokal Asia/Jakarta (WIB) —
  /// konversi timezone dilakukan oleh pemanggil, bukan di sini, supaya
  /// fungsi ini murni & mudah di-unit-test.
  ParsedDateTime parse(String rawText, DateTime now) {
    final text = ' ${rawText.toLowerCase().trim()} ';

    DateTime datePart = DateTime(now.year, now.month, now.day);
    bool dateFound = false;
    int? hour;
    int? minute;

    // --- 1. Tanggal relatif sederhana ---
    if (text.contains(' lusa ')) {
      datePart = datePart.add(const Duration(days: 2));
      dateFound = true;
    } else if (text.contains(' besok ')) {
      datePart = datePart.add(const Duration(days: 1));
      dateFound = true;
    } else if (text.contains('hari ini') ||
        text.contains('nanti malam') ||
        text.contains('sore ini') ||
        text.contains('pagi ini') ||
        text.contains('siang ini') ||
        text.contains('malam ini')) {
      dateFound = true;
    }

    // --- 2. Nama hari ("Senin", "Jumat depan", dst) ---
    for (var i = 0; i < _hariNama.length; i++) {
      final nama = _hariNama[i];
      if (text.contains(nama)) {
        // Dart: DateTime.monday == 1 ... DateTime.sunday == 7
        final targetWeekday = i == 0 ? DateTime.sunday : i;
        final isDepan = text.contains('$nama depan');
        var diff = (targetWeekday - now.weekday) % 7;
        if (diff == 0 && isDepan) {
          // "Senin depan" diucapkan pas hari Senin -> minggu depan, bukan hari ini.
          diff = 7;
        }
        datePart = DateTime(now.year, now.month, now.day).add(Duration(days: diff));
        dateFound = true;
        break;
      }
    }

    // --- 3. "minggu depan" generik (tanpa nama hari spesifik) ---
    if (!dateFound && text.contains('minggu depan')) {
      datePart = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
      dateFound = true;
    }

    // --- 4. "tanggal N" ---
    final tglMatch = RegExp(r'tanggal (\d{1,2})').firstMatch(text);
    if (tglMatch != null) {
      final day = int.parse(tglMatch.group(1)!);
      var month = now.month;
      var year = now.year;
      var candidate = DateTime(year, month, day);
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        month += 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
        candidate = DateTime(year, month, day);
      }
      datePart = candidate;
      dateFound = true;
    }

    // --- 5. "X jam lagi" / "X menit lagi" (relatif ke 'now', termasuk jam) ---
    final jamLagiMatch =
        RegExp(r'([\d]+|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh) jam lagi')
            .firstMatch(text);
    if (jamLagiMatch != null) {
      final n = _toNumber(jamLagiMatch.group(1)!);
      if (n != null) {
        final target = now.add(Duration(hours: n));
        datePart = DateTime(target.year, target.month, target.day);
        hour = target.hour;
        minute = target.minute;
        dateFound = true;
      }
    }
    final menitLagiMatch =
        RegExp(r'([\d]+|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh|lima belas|lima belas menit|setengah jam) menit lagi')
            .firstMatch(text);
    if (menitLagiMatch != null) {
      final n = _toNumber(menitLagiMatch.group(1)!);
      if (n != null) {
        final target = now.add(Duration(minutes: n));
        datePart = DateTime(target.year, target.month, target.day);
        hour = target.hour;
        minute = target.minute;
        dateFound = true;
      }
    }

    // --- 6. Jam eksplisit: "jam tujuh malam", "jam 7", "jam setengah delapan" ---
    final setengahMatch = RegExp(r'jam setengah (\w+)').firstMatch(text);
    if (setengahMatch != null) {
      final baseNum = _toNumber(setengahMatch.group(1)!);
      if (baseNum != null) {
        // "setengah delapan" = 07.30 (setengah MENUJU jam delapan)
        hour = _applyPeriod(baseNum - 1, text);
        minute = 30;
      }
    } else {
      final jamMatch = RegExp(
        r'jam (\d{1,2}|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh|sebelas|duabelas)(?:[:.](\d{2}))?',
      ).firstMatch(text);
      if (jamMatch != null) {
        final h = _toNumber(jamMatch.group(1)!);
        if (h != null) {
          hour = _applyPeriod(h, text);
          minute = jamMatch.group(2) != null ? int.parse(jamMatch.group(2)!) : 0;
        }
      }
    }

    if (hour != null) {
      datePart = DateTime(datePart.year, datePart.month, datePart.day, hour, minute ?? 0);
      dateFound = true;
    }

    return ParsedDateTime(
      dateTime: dateFound ? datePart : null,
      hasExplicitTime: hour != null,
    );
  }

  /// Parse offset reminder relatif, mis. "30 menit sebelumnya", "H-1",
  /// "satu jam sebelumnya". Dipakai terpisah dari [parse] karena offset
  /// reminder & waktu kejadian sering muncul di klausa berbeda.
  Duration? parseReminderOffset(String rawText) {
    final text = rawText.toLowerCase();
    final menitMatch = RegExp(r'(\d+) menit sebelumnya').firstMatch(text);
    if (menitMatch != null) return Duration(minutes: int.parse(menitMatch.group(1)!));

    final jamMatch = RegExp(r'(\d+) jam sebelumnya').firstMatch(text);
    if (jamMatch != null) return Duration(hours: int.parse(jamMatch.group(1)!));

    if (text.contains('h-1')) return const Duration(days: 1);
    if (text.contains('h-2')) return const Duration(days: 2);

    return null;
  }

  int? _toNumber(String word) {
    final asInt = int.tryParse(word);
    if (asInt != null) return asInt;
    return _angkaKata[word];
  }

  /// Terapkan penanda waktu (pagi/siang/sore/malam) ke jam 1-12 supaya jadi
  /// format 24 jam. Heuristik umum Bahasa Indonesia sehari-hari:
  /// pagi 00-11, siang ~11-15, sore ~15-18, malam 18-23 (+00 untuk 'jam 12 malam').
  int _applyPeriod(int hour, String text) {
    if (text.contains('malam')) {
      if (hour == 12) return 0;
      return hour < 12 ? hour + 12 : hour;
    }
    if (text.contains('sore')) {
      return hour < 12 ? hour + 12 : hour;
    }
    if (text.contains('siang')) {
      if (hour == 12) return 12;
      return hour <= 4 ? hour + 12 : hour;
    }
    if (text.contains('pagi')) {
      return hour == 12 ? 0 : hour;
    }
    // Tanpa penanda waktu: biarkan apa adanya (anggap sudah format 24 jam
    // jika > 12, atau biarkan AI layer yang konfirmasi jika ambigu).
    return hour;
  }
}
