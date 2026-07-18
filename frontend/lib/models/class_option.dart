// lib/models/class_option.dart
import 'schedule.dart';
import '../utils/credit_utils.dart';

class ClassOption {
  final String subjectName;
  final String subjectCode;
  final String type;
  final List<Schedule> schedules;
  final String professor;
  final String nrc;
  final int groupId;

  /// Créditos de la materia. Decimal: hay materias de 0.5 créditos.
  final double credits;
  final String campus;
  final int seatsAvailable;
  final int seatsMaximum;

  /// True si es un curso personalizado del usuario. Se usa para diferenciarlo
  /// visualmente en la grilla (relleno translúcido + borde de su color).
  final bool isCustom;

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
    required this.seatsAvailable,
    required this.seatsMaximum,
    this.isCustom = false,
  });

  /// Identidad de la materia a la que pertenece esta clase: el par
  /// (código, nombre). Ver `Subject.key` para el porqué. Es la llave para
  /// colorear y agrupar: hacerlo solo por nombre junta materias distintas que
  /// se llaman igual.
  String get subjectKey => '$subjectCode|$subjectName';

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
      credits: parseCredits(json['credits']),
      campus: json['campus'],
      seatsAvailable: json['seatsAvailable'],
      seatsMaximum: json['seatsMaximum'],
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'subjectName': subjectName,
    'subjectCode': subjectCode,
    'type': type,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'professor': professor,
    'nrc': nrc,
    'groupId': groupId,
    'credits': credits,
    'campus': campus,
    'seatsAvailable': seatsAvailable,
    'seatsMaximum': seatsMaximum,
    'isCustom': isCustom,
  };
}