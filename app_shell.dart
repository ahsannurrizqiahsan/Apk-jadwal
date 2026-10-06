import 'package:flutter/material.dart';

import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import '../voice/voice_screen.dart';

/// Shell utama: bottom navigation (Home/Kalender/Tugas/Settings) + FAB
/// microphone untuk memulai ulang Voice Mode kapan saja (section 21, 37).
class AppShell extends StatefulWidget {
  /// [autoOpenVoice]: dipakai main.dart ketika app dibuka dari launcher
  /// dengan auto-listen aktif (section 20) — AppShell tetap jadi "home"
  /// dasar, Voice Mode di-push di atasnya lewat jalur _openVoiceMode yang
  /// sama seperti FAB, supaya tombol tutup/"Selesai" di VoiceScreen otomatis
  /// kembali ke sini tanpa perlu Navigator kustom.
  const AppShell({super.key, this.autoOpenVoice = false});

  final bool autoOpenVoice;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openVoiceMode());
    }
  }

  static const _screens = [
    HomeScreen(),
    CalendarScreen(),
    TasksScreen(),
    SettingsScreen(),
  ];

  Future<void> _openVoiceMode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VoiceScreen(), fullscreenDialog: true),
    );
    // Screen aktif otomatis refresh karena semua repository adalah
    // ChangeNotifier yang didengarkan lewat Provider.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openVoiceMode,
        tooltip: 'Mulai Voice Mode',
        child: const Icon(Icons.mic, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavButton(
              icon: Icons.calendar_month_rounded,
              label: 'Kalender',
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            const SizedBox(width: 48), // ruang untuk notch FAB
            _NavButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Tugas',
              selected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
            _NavButton(
              icon: Icons.settings_rounded,
              label: 'Settings',
              selected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
