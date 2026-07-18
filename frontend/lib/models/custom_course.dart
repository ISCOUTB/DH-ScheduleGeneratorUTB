// lib/models/custom_course.dart
import 'schedule.dart';

/// Un curso personalizado del usuario: un curso que declara (uno que ya
/// decidió/matriculó, o una variación) para que el generador arme el horario a
/// su alrededor. Cuelga de una materia existente del catálogo.
///
/// Ver docs/issues/17-07-2026-rfc-cursos-personalizados.md
class CustomCourse {
  final int id;

  /// Materia a la que pertenece: el par (código, nombre) — su identidad.
  final String code;
  final String name;
  final double credits;

  /// NRC efectivo: el que puso el usuario o uno sintético `CP{id}` del backend.
  final String nrc;

  final String? type;
  final String? professor;
  final String? campus;

  /// Si entra en la generación (el switch "usa el mío / usa los ofertados").
  final bool activo;

  /// Bloques de horario del curso (día + rango).
  final List<Schedule> bloques;

  const CustomCourse({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.nrc,
    required this.activo,
    required this.bloques,
    this.type,
    this.professor,
    this.campus,
  });

  /// Identidad de la materia, consistente con `Subject.key` / `ClassOption.subjectKey`.
  String get subjectKey => '$code|$name';

  factory CustomCourse.fromJson(Map<String, dynamic> json) {
    return CustomCourse(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      credits: (json['credits'] as num).toDouble(),
      nrc: json['nrc'] as String,
      activo: json['activo'] as bool? ?? true,
      type: json['type'] as String?,
      professor: json['professor'] as String?,
      campus: json['campus'] as String?,
      bloques: (json['bloques'] as List)
          .map((b) => Schedule.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Payload para enviar este curso (activo) al endpoint de generación. El
  /// backend lo usa como dominio de su materia.
  Map<String, dynamic> toGenerationJson() => {
        'code': code,
        'name': name,
        'credits': credits,
        'nrc': nrc,
        'type': type,
        'professor': professor,
        'campus': campus,
        'bloques': bloques.map((s) => s.toJson()).toList(),
      };
}
