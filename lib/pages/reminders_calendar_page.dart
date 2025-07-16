import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/glass_card.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_gradients.dart';

class RemindersCalendarPage extends StatefulWidget {
  const RemindersCalendarPage({super.key});

  @override
  State<RemindersCalendarPage> createState() => _RemindersCalendarPageState();
}

class _RemindersCalendarPageState extends State<RemindersCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Reminder>> _reminders = {};
  final TextEditingController _reminderController = TextEditingController();
  final ReminderService _reminderService = ReminderService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final allReminders = await _reminderService.getAllReminders();
    setState(() {
      _reminders.clear();
      for (final reminder in allReminders) {
        final normalized = _normalizeDate(reminder.date);
        _reminders.putIfAbsent(normalized, () => []);
        _reminders[normalized]!.add(reminder);
      }
    });
  }

  List<Reminder> _getRemindersForDay(DateTime day) {
    return _reminders[_normalizeDate(day)] ?? [];
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _addReminder(DateTime day, Reminder reminder) async {
    final normalized = _normalizeDate(day);
    setState(() {
      if (_reminders[normalized] == null) {
        _reminders[normalized] = [];
      }
      _reminders[normalized]!.add(reminder);
    });
    await _reminderService.addReminder(reminder);
    await _notificationService.scheduleNotification(
      id: reminder.hashCode,
      title: 'Reminder',
      body: reminder.text,
      scheduledTime: DateTime(
        reminder.date.year,
        reminder.date.month,
        reminder.date.day,
        reminder.time.hour,
        reminder.time.minute,
      ),
    );
    await _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Reminders Calendar',
        backgroundColor: colorScheme.primary.withAlpha((0.85 * 255).toInt()),
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: appBackgroundGradient(context),
              ),
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(18),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                            colorScheme.surface.withAlpha((0.05 * 255).toInt()),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderColor: colorScheme.primary.withAlpha(
                          (0.2 * 255).toInt(),
                        ),
                        borderWidth: 1.5,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.06 * 255).toInt()),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reminders Calendar',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox.shrink(),
                                TextButton.icon(
                                  icon: Icon(Icons.today, size: 18),
                                  label: Text('Today'),
                                  onPressed: () {
                                    setState(() {
                                      _focusedDay = DateTime.now();
                                      _selectedDay = DateTime.now();
                                    });
                                  },
                                ),
                              ],
                            ),
                            TableCalendar<String>(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2100, 12, 31),
                              focusedDay: _focusedDay,
                              selectedDayPredicate:
                                  (day) =>
                                      _selectedDay != null &&
                                      _normalizeDate(day) ==
                                          _normalizeDate(_selectedDay!),
                              eventLoader:
                                  (day) =>
                                      _getRemindersForDay(day)
                                          .map((reminder) => reminder.text)
                                          .toList(),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              rowHeight: 60,
                              calendarStyle: CalendarStyle(
                                markerDecoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: colorScheme.tertiary.withAlpha(
                                    (0.7 * 255).toInt(),
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                defaultTextStyle: TextStyle(
                                  color: colorScheme.onSurface,
                                ),
                                weekendTextStyle: TextStyle(
                                  color: colorScheme.tertiary,
                                ),
                                outsideTextStyle: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(
                                    (0.4 * 255).toInt(),
                                  ),
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                ),
                                weekendStyle: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.tertiary,
                                  fontSize: 12,
                                ),
                              ),
                              headerStyle: HeaderStyle(
                                titleTextStyle: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                formatButtonVisible: false,
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  color: colorScheme.primary,
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.primary,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withAlpha(
                                    (0.7 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedDay != null) ...[
                              Text(
                                'Reminders for \\${_selectedDay!.toLocal().toString().split(' ')[0]}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._getRemindersForDay(_selectedDay!).map(
                                (reminder) => ListTile(
                                  leading: const Icon(Icons.alarm),
                                  title: Text(
                                    '${reminder.time.format(context)} - ${reminder.text}',
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      await _reminderService.deleteReminder(
                                        reminder,
                                      );
                                      await _loadReminders();
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _reminderController,
                                        decoration: const InputDecoration(
                                          hintText: 'Add a reminder...',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () async {
                                        final text =
                                            _reminderController.text.trim();
                                        if (text.isNotEmpty &&
                                            _selectedDay != null) {
                                          final pickedTime =
                                              await showTimePicker(
                                                context: context,
                                                initialTime: TimeOfDay.now(),
                                              );
                                          if (pickedTime != null) {
                                            _addReminder(
                                              _selectedDay!,
                                              Reminder(
                                                date: _selectedDay!,
                                                time: pickedTime,
                                                text: text,
                                              ),
                                            );
                                            _reminderController.clear();
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
