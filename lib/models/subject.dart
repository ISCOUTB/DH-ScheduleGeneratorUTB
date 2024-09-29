// lib/models/subject.dart
import 'class_option.dart';

class Subject {
  final String code;
  final String name;
  final int credits;
  final List<ClassOption> classOptions;

  Subject({
    required this.code,
    required this.name,
    required this.credits,
    required this.classOptions,
  });
}
