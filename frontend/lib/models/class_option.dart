// lib/models/class_option.dart
import 'schedule.dart';

class ClassOption {
  final String subjectName;
  final String subjectCode;
  final String type;
  final List<Schedule> schedules;
  final String professor;
  final String nrc;
  final int groupId;
  final int credits;
  final String campus;

  ClassOption({
    required this.subjectName,
    required this.subjectCode,
    required this.type,
    required this.schedules,
    required this.professor,
    required this.nrc,
    required this.groupId,
    required this.credits,
    required this.campus,
  });

  factory ClassOption.fromJson(Map<String, dynamic> json) {
    return ClassOption(
      subjectName: json['subjectName'],
      subjectCode: json['subjectCode'],
      type: json['type'],
      schedules:
          (json['schedules'] as List).map((e) => Schedule.fromJson(e)).toList(),
      professor: json['professor'],
      nrc: json['nrc'],
      groupId: json['groupId'],
      credits: json['credits'],
      campus: json['campus'],
    );
  }
}
