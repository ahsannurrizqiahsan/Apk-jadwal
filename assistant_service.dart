/// Integrasi "Default Digital Assistant" Android (section 5, 42).
///
/// STATUS: belum diimplementasikan penuh di scaffold ini — bagian ini perlu
/// kode native Kotlin (VoiceInteractionService, sebuah Activity dengan
/// intent-filter ACTION_ASSIST) yang tidak aman untuk saya tulis "membabi
/// buta" tanpa bisa compile & test di perangkat sungguhan. Catatan riset
/// per Oktober 2026 supaya implementasinya terarah:
///
/// 1. Peran ini NYATA dan BISA dipakai aplikasi pihak ketiga: Android
///    mengekspos `RoleManager.ROLE_ASSISTANT`. App perlu:
///      - Activity dengan intent-filter:
///          <action android:name="android.intent.action.ASSIST" />
///          <category android:name="android.intent.category.DEFAULT" />
///      - Implementasi VoiceInteractionService + VoiceInteractionSessionService
///        (lihat developer.android.com/reference/android/service/voice).
///      - Cek ketersediaan role lewat RoleManager.isRoleAvailable(ROLE_ASSISTANT),
///        lalu minta lewat RoleManager.createRequestRoleIntent(ROLE_ASSISTANT)
///        -- TIDAK ADA dialog permission bawaan yang rapi untuk role ini
///        (beda dengan ROLE_BROWSER), jadi UX permintaannya harus dirancang
///        sendiri di SettingsScreen.
///      - Alternatif/fallback: arahkan user ke
///          Settings > Apps > Default apps > Digital assistant app
///        (lokasi menu ini bisa beda-beda tergantung pabrikan HP).
///
/// 2. ADA ISU YANG SUDAH DIKONFIRMASI: setting `assistant` &
///    `voice_interaction_service` di Android Secure Settings bisa ter-reset
///    setiap kali APK di-reinstall (termasuk dialami aplikasi resmi
///    sekalipun). Ini NORMAL terjadi berulang kali selama development
///    (`flutter run` = reinstall tiap kali) — jangan dikira fitur ini rusak.
///    Workaround saat development:
///      adb shell settings put secure assistant <package>/.AssistActivity
///      adb shell settings put secure voice_interaction_service <package>/.VoiceInteractionService
///
/// 3. Dukungan & tampilan menu berbeda-beda antar OEM/versi Android — WAJIB
///    ada fallback yang baik (section 5: "Jangan mengasumsikan semua
///    perangkat Android mendukung fitur dengan cara yang sama").
///
/// Rencana wiring ke Flutter (Phase 5 di spek):
///   - Buat MethodChannel 'voice_schedule/assistant' di MainActivity.kt.
///   - Dari situ expose: isRoleAvailable(), isRoleHeld(), requestRole(),
///     openDefaultAppsSettings().
///   - VoiceInteractionSession native menampilkan compact overlay (section 6)
///     atau langsung memanggil kembali ke VoiceScreen lewat deep link.
class AssistantService {
  AssistantService._internal();
  static final AssistantService instance = AssistantService._internal();

  // TODO(phase-5): ganti dengan MethodChannel ke kode native di atas.
  Future<bool> isRoleAvailable() async => false;
  Future<bool> isRoleHeld() async => false;
  Future<void> requestAssistantRole() async {
    throw UnimplementedError(
      'Integrasi native Assistant Role belum dipasang. Lihat komentar di '
      'assistant_service.dart dan README bagian Phase 5.',
    );
  }
}
