// lib/models/schedule_diagnosis.dart

/// Explicación del backend de por qué no se generó ningún horario.
///
/// Ver `docs/issues/17-07-2026-rfc-diagnostico-sin-horarios.md`. Los dos ejes
/// son independientes: [shape] dice **dónde vive** el conflicto (qué se puede
/// nombrar) y [blame] **de quién es la culpa** (qué se sugiere).
class ScheduleDiagnosis {
  /// Dónde vive el conflicto.
  /// `sin_oferta` — la materia no tiene cursos en el periodo.
  /// `materia_sin_opciones` — una materia sola se quedó sin opciones viables.
  /// `par_incompatible` — un par de materias no tiene ninguna combinación que conviva.
  /// `conjunto_incompatible` — todos los pares caben, pero el conjunto no.
  final String shape;

  /// De quién es la culpa: `datos`, `filtros` o `estructural`.
  final String blame;

  /// Materias señaladas, según el [shape].
  final List<String> subjects;

  /// Pares sin ninguna combinación compatible (solo en `par_incompatible`).
  final List<List<String>> pairs;

  /// Materias tales que, quitándolas, sí habría horarios. Vacío significa que
  /// quitar una sola no alcanza.
  final List<String> removalOptions;

  /// Filtros que, quitados por sí solos, desbloquean. Solo con `blame=filtros`;
  /// vacío ahí significa que es la combinación de filtros, no uno puntual.
  final List<DiagnosisFilter> blockingFilters;

  const ScheduleDiagnosis({
    required this.shape,
    required this.blame,
    this.subjects = const [],
    this.pairs = const [],
    this.removalOptions = const [],
    this.blockingFilters = const [],
  });

  factory ScheduleDiagnosis.fromJson(Map<String, dynamic> json) {
    return ScheduleDiagnosis(
      shape: json['shape'] as String? ?? 'conjunto_incompatible',
      blame: json['blame'] as String? ?? 'estructural',
      subjects: List<String>.from(json['subjects'] as List? ?? const []),
      pairs: (json['pairs'] as List? ?? const [])
          .map<List<String>>((p) => List<String>.from(p as List))
          .toList(),
      removalOptions:
          List<String>.from(json['removalOptions'] as List? ?? const []),
      blockingFilters: (json['blockingFilters'] as List? ?? const [])
          .map<DiagnosisFilter>(
              (f) => DiagnosisFilter.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Si el problema lo causaron los filtros del usuario (y no la oferta).
  bool get isFiltersFault => blame == 'filtros';
}

/// Filtro señalado por el diagnóstico. El texto legible se arma en el front
/// (el backend solo manda el tipo y a qué apunta).
class DiagnosisFilter {
  /// `selected_nrcs` | `include_professors` | `exclude_professors` | `unavailable_slots`
  final String type;

  /// Nombre de la materia, o el día para `unavailable_slots`.
  final String target;

  const DiagnosisFilter({required this.type, required this.target});

  factory DiagnosisFilter.fromJson(Map<String, dynamic> json) => DiagnosisFilter(
        type: json['type'] as String? ?? '',
        target: json['target'] as String? ?? '',
      );

  /// Descripción legible, ej. "las horas no disponibles del martes".
  String get label {
    switch (type) {
      case 'selected_nrcs':
        return 'los NRC seleccionados de $target';
      case 'include_professors':
        return 'los profesores requeridos de $target';
      case 'exclude_professors':
        return 'los profesores excluidos de $target';
      case 'unavailable_slots':
        return 'las horas no disponibles del $target';
      default:
        return 'el filtro de $target';
    }
  }
}
