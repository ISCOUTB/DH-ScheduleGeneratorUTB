// lib/models/schedule.dart
class Schedule {
  final String day;
  final String time;

  Schedule({required this.day, required this.time});

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      day: json['day'],
      time: json['time'],
    );
  }
}
