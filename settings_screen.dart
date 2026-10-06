import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/settings_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          _SectionLabel('Voice'),
          _SettingsCard(children: [
            SwitchListTile(
              title: const Text('Auto Listen on Launch'),
              subtitle: const Text('Langsung mendengarkan begitu app dibuka dari Home Screen'),
              value: settings.autoListenOnLaunch,
              onChanged: settings.setAutoListenOnLaunch,
            ),
            SwitchListTile(
              title: const Text('Voice confirmation'),
              subtitle: const Text('Konfirmasi hasil perintah lewat suara (Text-to-Speech)'),
              value: settings.voiceConfirmation,
              onChanged: settings.setVoiceConfirmation,
            ),
          ]),

          const SizedBox(height: 20),
          _SectionLabel('Reminder'),
          _SettingsCard(children: [
            SwitchListTile(
              title: const Text('Hourly reminder default'),
              subtitle: const Text('Aktifkan reminder tiap jam otomatis untuk tugas baru'),
              value: settings.hourlyReminderDefault,
              onChanged: settings.setHourlyReminderDefault,
            ),
            ListTile(
              title: const Text('Jam aktif reminder'),
              subtitle: Text('${settings.activeHoursStart} – ${settings.activeHoursEnd}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editActiveHours(context, settings),
            ),
          ]),

          const SizedBox(height: 20),
          _SectionLabel('Notification'),
          _SettingsCard(children: [
            SwitchListTile(
              title: const Text('Sound'),
              value: settings.notificationSound,
              onChanged: settings.setNotificationSound,
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              value: settings.notificationVibration,
              onChanged: settings.setNotificationVibration,
            ),
          ]),

          const SizedBox(height: 20),
          _SectionLabel('Assistant Integration'),
          _SettingsCard(children: [
            ListTile(
              title: const Text('Jadikan sebagai Assistant Default'),
              subtitle: const Text('Buka pengaturan Android untuk memilih aplikasi ini sebagai digital assistant'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAssistantInfo(context),
            ),
          ]),
        ],
      ),
    );
  }

  void _editActiveHours(BuildContext context, SettingsRepository settings) async {
    final start = await showTimePicker(
      context: context,
      helpText: 'Mulai jam aktif',
      initialTime: _parse(settings.activeHoursStart),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'Selesai jam aktif',
      initialTime: _parse(settings.activeHoursEnd),
    );
    if (end == null) return;
    await settings.setActiveHours(_format(start), _format(end));
  }

  TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showAssistantInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assistant Default'),
        content: const Text(
          'Fitur ini butuh dukungan native Android (VoiceInteractionService) '
          'yang belum terpasang di versi awal ini — lihat assistant_service.dart.\n\n'
          'Untuk sementara, kamu bisa coba atur manual lewat:\n'
          'Settings HP > Apps > Default apps > Digital assistant app\n\n'
          '(Lokasi menu ini bisa berbeda tergantung merek HP.)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti')),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
