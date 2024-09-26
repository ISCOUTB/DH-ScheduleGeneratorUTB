// lib/models/subject.dart
class Subject {
  final String name;
  final List<Schedule> schedule;
  final int credits;

  Subject({
    required this.name,
    required this.schedule,
    required this.credits,
  });
}

class Schedule {
  final String day;
  final String time;

  Schedule({
    required this.day,
    required this.time,
  });
}
