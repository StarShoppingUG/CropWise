import 'package:flutter/material.dart';

class Reminder {
  final DateTime date;
  final TimeOfDay time;
  final String text;
  Reminder({required this.date, required this.time, required this.text});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'hour': time.hour,
    'minute': time.minute,
    'text': text,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    date: DateTime.parse(json['date'] as String),
    time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
    text: json['text'] as String,
  );
}
