// lib/models/class_option.dart
import 'schedule.dart';

class ClassOption {
  final String subjectName; // Nombre de la materia
  final String subjectCode; // Añadido: código de la materia
  final String type; // 'Teórico' o 'Laboratorio'
  final List<Schedule> schedules;
  final String professor;
  final String nrc;
  final int groupId; // Para agrupar clases
  final int credits;

  ClassOption({
    required this.subjectName,
    required this.subjectCode, // Añadido al constructor
    required this.type,
    required this.schedules,
    required this.professor,
    required this.nrc,
    required this.groupId,
    required this.credits,
  });
}
