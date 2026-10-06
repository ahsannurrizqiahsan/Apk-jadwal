import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<TaskModel>> _monthEvents = {};

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    final repo = context.read<TaskRepository>();
    final events = await repo.getForMonth(month);
    if (mounted) setState(() => _monthEvents = events);
  }

  List<TaskModel> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _monthEvents[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    context.watch<TaskRepository>(); // refresh saat ada perubahan dari voice command

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('Kalender', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<TaskModel>(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2035, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: _eventsForDay,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focused) {
                  _focusedDay = focused;
                  _loadMonth(focused);
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: _eventsForDay(_selectedDay).isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Tidak ada kegiatan pada tanggal ini.')),
                      ),
                    ]
                  : _eventsForDay(_selectedDay)
                      .map((t) => _DayEventTile(task: t))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.task});
  final TaskModel task;

  IconData _iconFor(TaskType type) {
    switch (type) {
      case TaskType.schedule:
        return Icons.event_rounded;
      case TaskType.task:
        return Icons.check_circle_outline_rounded;
      case TaskType.note:
        return Icons.sticky_note_2_outlined;
      case TaskType.reminder:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = task.time != null
        ? '${task.time!.hour.toString().padLeft(2, '0')}.${task.time!.minute.toString().padLeft(2, '0')}'
        : '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(_iconFor(task.type)),
        title: Text(task.title),
        subtitle: Text(timeLabel),
        trailing: task.hourlyReminder ? const Text('🔔') : null,
      ),
    );
  }
}
