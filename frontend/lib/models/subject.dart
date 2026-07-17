// lib/models/subject.dart
import 'class_option.dart';
import '../utils/credit_utils.dart';

class Subject {
  final String code;
  final String name;

  /// Créditos de la materia. Decimal: hay materias de 0.5 créditos.
  final double credits;
  final List<ClassOption> classOptions;

  Subject({
    required this.code,
    required this.name,
    required this.credits,
    required this.classOptions,
  });

  /// Identidad de la materia: el par (código, nombre).
  ///
  /// Ninguno de los dos es único por separado —así lo declara la PK compuesta
  /// `materia_pkey (codigomateria, nombre)` y por eso la API pide ambos—:
  /// hay 24 nombres repartidos entre varios códigos (ej. "Práctica Profesional"
  /// en 14 carreras) y 5 códigos con varios nombres (ej. `RULEI02B` = "Inglés Ii"
  /// e "Inglés Ii - Derecho"). Usar solo el nombre mezcla materias distintas
  /// (mismo color, mismo bloque); usar solo el código mezcla sus filtros.
  ///
  /// Debe coincidir con `ClassOption.subjectKey` y con `subject_key()` del
  /// backend: es la llave con la que viajan los filtros.
  String get key => '$code|$name';

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      code: json['code'],
      name: json['name'],
      credits: parseCredits(json['credits']),
      classOptions: (json['classOptions'] as List)
          .map((e) => ClassOption.fromJson(e))
          .toList(),
    );
  }
}
