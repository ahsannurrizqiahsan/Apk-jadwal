# Voice Schedule App — Starting Point

Scaffold Flutter untuk aplikasi asisten jadwal voice-first Bahasa Indonesia,
dibangun berdasarkan master prompt 51-bagian. Dokumen ini menjelaskan apa
yang sudah jadi, keputusan teknis & alasannya, dan cara melanjutkan.

## ⚠️ Keterbatasan environment tempat ini dibuat

Kode ini ditulis di sandbox tanpa Flutter SDK dan tanpa akses internet —
jadi **belum pernah di-`flutter pub get`, di-analyze, atau di-build**.
Sintaks Dart sudah ditulis seteliti mungkin (termasuk riset versi paket
yang dipakai), tapi langkah pertama di mesinmu sendiri (atau di Claude
Code) HARUS:

```bash
flutter pub get
flutter analyze
flutter run
```

dan perbaiki error kecil yang mungkin muncul (biasanya cuma soal versi
paket yang sedikit berbeda dari yang saya asumsikan).

## Status per fase (mengikuti section 47 di spek asli)

| Fase | Status |
|---|---|
| 1. Struktur proyek, local database, navigasi, Home/Kalender/Tugas | ✅ Selesai |
| 2. Speech-to-Text, auto listen, Voice Mode UI, Text-to-Speech | ✅ Kode lengkap, **belum pernah diuji di device sungguhan** |
| 3. Notifikasi, hourly reminder, boot restore | 🟡 Notifikasi & hourly reminder lengkap; boot restore baru menutupi "buka app lagi setelah restart", belum background penuh (lihat di bawah) |
| 4. AI command parsing, voice query, update/delete, follow-up | 🟡 Parser lokal (rule-based) lengkap & fungsional; lapisan LLM sungguhan tinggal di-inject (lihat `ai_command_service.dart`) |
| 5. Android Assistant integration (ROLE_ASSISTANT) | ⬜ Baru riset + placeholder, butuh kode native Kotlin |
| 6. Settings, Dark Mode, polish, testing | 🟡 Settings & Dark Mode jadi; testing/polish belum |

## Cara dapat file .apk (paling gampang — otomatis, tanpa install Flutter)

Project ini sudah dilengkapi `.github/workflows/build-apk.yml` yang build
APK otomatis di server GitHub. Kamu TIDAK perlu install Flutter/Android
SDK apa pun di laptop atau HP sendiri.

1. Buat akun GitHub (gratis) di github.com kalau belum punya.
2. Klik **New repository** → beri nama bebas → **jangan** centang "Add a
   README" (biar tidak bentrok saat upload) → Create repository.
3. Di halaman repo kosong itu akan ada opsi upload file lewat browser
   (biasanya linknya tertulis semacam "uploading an existing file").
   Extract zip ini di komputer, lalu upload **ISI** folder
   `voice_schedule_app` (bukan folder itu sendiri) — jadi yang ter-upload
   ke root repo adalah `lib/`, `.github/`, `pubspec.yaml`, `README.md`
   langsung. Commit.
4. Buka tab **Actions** di repo itu. Build akan jalan otomatis begitu kamu
   commit (atau klik "Run workflow" manual kalau belum jalan sendiri).
5. Tunggu ±5-10 menit sampai tanda centang hijau ✅ muncul.
6. Klik run yang sudah selesai → scroll ke bawah ke bagian **Artifacts**
   → download `voice-schedule-app-apk` (isinya .zip berisi
   `app-release.apk`).
7. Extract, pindahkan `app-release.apk` ke HP Android, izinkan "Install
   dari sumber tidak dikenal" kalau diminta, lalu install seperti biasa.

APK ini ditandatangani dengan debug key bawaan Flutter — cukup untuk
pemakaian pribadi (bukan untuk upload ke Play Store, yang butuh keystore
sendiri).

Kalau build gagal (merah ❌), klik run-nya untuk lihat log error persis di
step mana — paling sering gara-gara versi paket yang perlu disesuaikan
sedikit (lihat bagian "Keputusan teknis" di bawah).

## Keputusan teknis & alasannya

Beberapa keputusan di spek sengaja diserahkan ke saya ("pilih yang paling
sesuai"). Berikut yang saya pilih dan kenapa:

**Database lokal: sqflite, bukan Isar/Drift.**
Isar & Drift butuh `build_runner` untuk generate file `.g.dart`/schema
sebelum project bisa jalan. Saya tidak bisa menjalankan `build_runner` di
sini (tanpa Flutter SDK/internet) untuk memverifikasinya, dan generated
code yang salah tebak akan membuat project tidak bisa di-build sama sekali.
sqflite murni SQL, langsung jalan setelah `pub get`. Kalau nanti kamu mau
pindah ke Drift (type-safe query, reactive streams), `task_repository.dart`
adalah satu-satunya tempat yang perlu diubah — UI tidak menyentuh SQL
langsung.

**Hourly reminder: notifikasi exact-alarm individual, bukan WorkManager
periodik.** Saya riset dan banyak HP (Xiaomi/Samsung/Oppo/Vivo/Huawei)
punya task-killer masing-masing yang bikin WorkManager molor berjam-jam
meski laporan statusnya "OK". AlarmManager asli Android (yang dipakai
`flutter_local_notifications` di balik layar) jauh lebih reliable untuk
"tampilkan notifikasi tepat di jam X". Jadi tiap task dengan hourly
reminder aktif langsung dijadwalkan semua slot jamnya (lihat
`reminder_scheduler.dart`). `workmanager` tetap ada di `pubspec.yaml`
untuk keperluan boot-restore (lihat bagian "Fase berikutnya" di bawah),
bukan untuk reminder itu sendiri.

**`flutter_local_notifications` dipin di `^18.0.1`, bukan versi terbaru.**
Per Oktober 2026 versi v22 mengubah `show()`/`zonedSchedule()`/`initialize()`
jadi named-parameter penuh (breaking) dan mewajibkan core library
desugaring + Java 17. Saya tidak bisa compile-test perubahan itu di sini,
jadi saya pin ke versi yang signature-nya saya yakin benar. Upgrade kapan
pun kamu siap menyesuaikan pemanggilannya.

**Android Assistant Role (section 5, 42): baru riset + placeholder.**
Ini fitur nyata dan bisa dipakai third-party app (dikonfirmasi regulasi EU
soal Android assistant app pihak ketiga, Juli 2026), tapi:
- Butuh kode native Kotlin (`VoiceInteractionService` +
  `VoiceInteractionSessionService` + Activity dengan intent-filter
  `ACTION_ASSIST`) yang berisiko saya tulis tanpa bisa compile & test di
  device sungguhan.
- **Catatan penting untuk development**: setting assistant di Android bisa
  **ter-reset tiap reinstall APK** (dialami juga oleh aplikasi resmi
  sekalipun) — ini normal terjadi berulang kali selama kamu `flutter run`,
  bukan tanda ada yang rusak. Workaround lewat ADB:
  ```
  adb shell settings put secure assistant <package>/.AssistActivity
  adb shell settings put secure voice_interaction_service <package>/.VoiceInteractionService
  ```
- Detail & rencana wiring lengkap ada di komentar
  `lib/services/assistant_service.dart`.

## Cara menjalankan

1. **Generate folder platform** (android/ios) dengan Flutter SDK versi
   kamu sendiri, supaya cocok dengan Gradle/AGP yang terpasang:
   ```bash
   flutter create --org com.namamu --project-name voice_schedule_app .
   ```
   (Jalankan ini di folder KOSONG baru, lalu copy isi `lib/` dan
   `pubspec.yaml` dari scaffold ini ke dalamnya — supaya `android/`, `ios/`
   dkk dibuatkan otomatis oleh `flutter create` sesuai versi SDK-mu,
   bukan saya tebak manual.)

2. **Tambahkan permission** ke `android/app/src/main/AndroidManifest.xml`,
   di dalam tag `<manifest>` (sejajar dengan `<application>`, bukan di
   dalamnya):
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   <uses-permission android:name="android.permission.INTERNET" />
   ```

3. **Set `minSdkVersion`** di `android/app/build.gradle` ke minimal 23
   (disarankan untuk kompatibilitas exact-alarm & speech_to_text terbaru).

4. ```bash
   flutter pub get
   flutter analyze        # perbaiki error kecil yang mungkin muncul
   flutter run
   ```

## Fase berikutnya (belum dikerjakan di scaffold ini)

- **Boot restore penuh (section 28, Test 7 di section 50)**: saat ini
  reminder dijadwalkan ulang setiap app dibuka (`main.dart`), tapi BELUM
  otomatis tanpa membuka app setelah restart. Pola yang umum dipakai:
  ```dart
  // top-level function, bukan di dalam class
  @pragma('vm:entry-point')
  void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.instance.init();
      final repo = TaskRepository();
      await ReminderScheduler(repository: repo).rescheduleAllActiveReminders();
      return true;
    });
  }
  // di main(): Workmanager().initialize(callbackDispatcher);
  //            Workmanager().registerPeriodicTask('reschedule', 'reschedule-task',
  //                frequency: const Duration(hours: 6));
  ```
  Android WorkManager mem-persist periodic task lintas reboot secara
  otomatis (tidak perlu BroadcastReceiver native terpisah) — tapi **cek
  nama parameter persis** terhadap versi `workmanager` yang ter-install,
  karena saya tidak bisa compile-verify ini di sini.
- **Disambiguasi hasil ganda**: `_handleComplete`/`_handleDelete`/
  `_handleUpdate` di `voice_screen.dart` saat ini ambil match pertama dari
  `searchByTitle`. Section 18 minta konfirmasi singkat kalau ambigu —
  tinggal tambahkan dialog/voice prompt kalau `matches.length > 1`.
- **Lapisan AI sungguhan** (section 32): injeksikan `remoteParser` ke
  `AiCommandService` (lihat komentar di `main.dart`) yang memanggil LLM
  pilihanmu. Parser lokal yang ada sekarang (`indo_datetime_parser.dart`)
  tetap jalan sebagai fallback otomatis kalau API gagal/offline (section 33).
- **VoiceInteractionService native** untuk Assistant Role (section 5, 42) —
  lihat `assistant_service.dart`.
- Widget test & integration test (section 50 — 8 testing scenarios resmi
  dari spek bisa langsung dipakai sebagai acuan).

## Catatan soal `indo_datetime_parser.dart`

Ini parser rule-based murni (regex + tabel kata), sengaja tanpa dependensi
AI/jaringan, supaya app tetap fungsional tanpa API key (section 33). Dia
menangani pola di section 8 (besok, lusa, nama hari + "depan", "tanggal N",
"X jam/menit lagi", "jam tujuh malam", "jam setengah delapan", dst), tapi
bahasa natural punya ekor panjang kasus yang tidak tercakup regex. Untuk
akurasi penuh, lapisan AI (section 32) yang idealnya jadi jalur utama;
parser ini adalah jaring pengaman, bukan pengganti.
