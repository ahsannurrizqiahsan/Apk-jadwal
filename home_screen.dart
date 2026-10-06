import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../services/reminder_scheduler.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TaskRepository>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Apa yang perlu kamu lakukan hari ini?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<TaskModel>>(
              future: repo.getForDate(DateTime.now()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return _EmptyToday();
                }
                return Column(
                  children: items.map((t) => _TodayCard(task: t)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.spa_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('Belum ada jadwal hari ini.'),
            const SizedBox(height: 4),
            Text(
              'Tekan ikon mic untuk menambahkan lewat suara.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.task});
  final TaskModel task;

  String _timeLabel() {
    if (task.time == null) return '';
    return '${task.time!.hour.toString().padLeft(2, '0')}.${task.time!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isTask = task.type == TaskType.task;
    final done = task.status == TaskStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isTask)
                Checkbox(
                  value: done,
                  onChanged: (v) async {
                    final repo = context.read<TaskRepository>();
                    final scheduler = context.read<ReminderScheduler>();
                    if (v == true) {
                      await repo.markCompleted(task.id);
                      await scheduler.onTaskCompleted(task.id);
                    } else {
                      await repo.update(task.copyWith(status: TaskStatus.pending, clearCompletedAt: true));
                    }
                  },
                )
              else
                SizedBox(
                  width: 56,
                  child: Text(
                    _timeLabel(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        decoration: done ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.hourlyReminder)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🔔 Reminder setiap 1 jam',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
