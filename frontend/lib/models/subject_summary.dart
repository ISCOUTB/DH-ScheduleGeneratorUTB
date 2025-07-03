// lib/models/subject_summary.dart


// Modelo ligero de datos, tal como la devuelve el endpoint /api/subjects.
class SubjectSummary {
  final String code;
  final String name;
  final int credits;

  SubjectSummary({
    required this.code,
    required this.name,
    required this.credits,
  });

  factory SubjectSummary.fromJson(Map<String, dynamic> json) {
    // Este modelo no necesita acceder a 'classOptions' porque no es necesario para la representación resumida de la asignatura.
    return SubjectSummary(
      code: json['code'],
      name: json['name'],
      credits: json['credits'],
    );
  }
}