import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan aplikasi (section 34). Dibaca di main.dart SEBELUM UI pertama
/// tampil (untuk cek autoListenOnLaunch), jadi dipisah dari SettingsScreen.
class SettingsRepository extends ChangeNotifier {
  static const _kAutoListen = 'auto_listen_on_launch';
  static const _kVoiceConfirmation = 'voice_confirmation';
  static const _kHourlyReminderDefault = 'hourly_reminder_default';
  static const _kActiveHoursStart = 'active_hours_start';
  static const _kActiveHoursEnd = 'active_hours_end';
  static const _kNotificationSound = 'notification_sound';
  static const _kNotificationVibration = 'notification_vibration';

  bool autoListenOnLaunch = true;
  bool voiceConfirmation = true;
  bool hourlyReminderDefault = false;
  String activeHoursStart = '07:00';
  String activeHoursEnd = '22:00';
  bool notificationSound = true;
  bool notificationVibration = true;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoListenOnLaunch = prefs.getBool(_kAutoListen) ?? true;
    voiceConfirmation = prefs.getBool(_kVoiceConfirmation) ?? true;
    hourlyReminderDefault = prefs.getBool(_kHourlyReminderDefault) ?? false;
    activeHoursStart = prefs.getString(_kActiveHoursStart) ?? '07:00';
    activeHoursEnd = prefs.getString(_kActiveHoursEnd) ?? '22:00';
    notificationSound = prefs.getBool(_kNotificationSound) ?? true;
    notificationVibration = prefs.getBool(_kNotificationVibration) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoListenOnLaunch(bool value) async {
    autoListenOnLaunch = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoListen, value);
  }

  Future<void> setVoiceConfirmation(bool value) async {
    voiceConfirmation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceConfirmation, value);
  }

  Future<void> setHourlyReminderDefault(bool value) async {
    hourlyReminderDefault = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHourlyReminderDefault, value);
  }

  Future<void> setActiveHours(String start, String end) async {
    activeHoursStart = start;
    activeHoursEnd = end;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveHoursStart, start);
    await prefs.setString(_kActiveHoursEnd, end);
  }

  Future<void> setNotificationSound(bool value) async {
    notificationSound = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationSound, value);
  }

  Future<void> setNotificationVibration(bool value) async {
    notificationVibration = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationVibration, value);
  }
}
