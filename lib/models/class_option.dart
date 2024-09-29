// lib/models/class_option.dart
import 'schedule.dart';

class ClassOption {
  final String subjectName; // Agregado: nombre de la materia
  final String type; // 'Teórico' o 'Laboratorio'
  final List<Schedule> schedules;
  final String professor;
  final String nrc;
  final int groupId; // Nuevo atributo para agrupar clases
  final int credits = 3; // Agregado: créditos de la materia
 // Agregado: valor por defecto

  ClassOption({
    required this.subjectName, // Agregado
    required this.type,
    required this.schedules,
    required this.professor,
    required this.nrc,
    required this.groupId,
  });
}
