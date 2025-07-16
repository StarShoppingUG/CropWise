import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class ReminderService {
  static const String _remindersKey = 'reminders_list';

  // Singleton pattern
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  Future<List<Reminder>> getAllReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = prefs.getStringList(_remindersKey) ?? [];
    return remindersJson
        .map((jsonStr) => Reminder.fromJson(json.decode(jsonStr)))
        .toList();
  }

  Future<void> addReminder(Reminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getAllReminders();
    reminders.add(reminder);
    final remindersJson =
        reminders.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(_remindersKey, remindersJson);
  }

  Future<void> clearReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_remindersKey);
  }

  // For dashboard: get next N reminders, sorted by date/time ascending (soonest first)
  Future<List<Reminder>> getNextReminders(int count) async {
    final all = await getAllReminders();
    all.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
    final now = DateTime.now();
    // Only show reminders whose full DateTime is after now
    final upcoming =
        all.where((reminder) {
          final reminderDateTime = DateTime(
            reminder.date.year,
            reminder.date.month,
            reminder.date.day,
            reminder.time.hour,
            reminder.time.minute,
          );
          return reminderDateTime.isAfter(now);
        }).toList();
    return upcoming.take(count).toList();
  }

  Future<void> updateReminder(
    Reminder oldReminder,
    Reminder newReminder,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getAllReminders();
    final index = reminders.indexWhere(
      (r) =>
          r.date == oldReminder.date &&
          r.time.hour == oldReminder.time.hour &&
          r.time.minute == oldReminder.time.minute &&
          r.text == oldReminder.text,
    );
    if (index != -1) {
      reminders[index] = newReminder;
      final remindersJson =
          reminders.map((r) => json.encode(r.toJson())).toList();
      await prefs.setStringList(_remindersKey, remindersJson);
    }
  }

  Future<void> deleteReminder(Reminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getAllReminders();
    reminders.removeWhere(
      (r) =>
          r.date == reminder.date &&
          r.time.hour == reminder.time.hour &&
          r.time.minute == reminder.time.minute &&
          r.text == reminder.text,
    );
    final remindersJson =
        reminders.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(_remindersKey, remindersJson);
  }
}
