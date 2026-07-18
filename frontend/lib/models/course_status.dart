// lib/models/course_status.dart
import 'package:flutter/material.dart';
import 'class_option.dart';

/// Estado de cupos de un curso, usado para el coloreo de la grilla de
/// horarios destacados (RFC Fase 2).
enum CourseStatus { safe, caution, atRisk, eliminated }

/// Calcula el estado a partir de los cupos disponibles y totales.
///
/// Umbrales (RFC §2.2):
/// - Eliminado: sin cupos disponibles (`available <= 0`) o sin total válido.
/// - Seguro:    `available / total > 50%`.
/// - Precaución:`available / total` entre 20% y 50% (inclusive).
/// - En riesgo: `available / total < 20%` con `available > 0`.
CourseStatus computeCourseStatus(int available, int total) {
  if (available <= 0 || total <= 0) return CourseStatus.eliminated;
  final ratio = available / total;
  if (ratio > 0.5) return CourseStatus.safe;
  if (ratio >= 0.2) return CourseStatus.caution;
  return CourseStatus.atRisk;
}

/// Estado de un curso dado el mapa de cupos `{ nrc: {available, total} }`.
/// Un NRC ausente del mapa (no existe en la tabla `Curso`) se trata como
/// eliminado.
CourseStatus statusForClass(
  ClassOption option,
  Map<String, Map<String, int>> seatsByNrc,
) {
  final seats = seatsByNrc[option.nrc];
  if (seats == null) return CourseStatus.eliminated;
  return computeCourseStatus(seats['available'] ?? 0, seats['total'] ?? 0);
}

/// Problemas de un horario guardado frente a los cupos **actuales**.
class ScheduleIssues {
  /// Clases que siguen en la oferta pero se quedaron sin cupos.
  final int noSeats;

  /// Clases cuyo NRC ya no aparece en la oferta (se cayó o le cambiaron el NRC).
  final int notOffered;

  const ScheduleIssues({this.noSeats = 0, this.notOffered = 0});

  bool get any => noSeats > 0 || notOffered > 0;
  int get total => noSeats + notOffered;
}

/// Cuenta los problemas de un horario según el mapa de cupos `{nrc: {...}}`.
///
/// Con el mapa **vacío** devuelve "sin problemas": significa que no se pudo
/// consultar el estado, y no se alarma con datos que no se tienen (mismo
/// criterio que el detalle, que en ese caso avisa en vez de pintar todo gris).
ScheduleIssues issuesForSchedule(
  List<ClassOption> schedule,
  Map<String, Map<String, int>> seatsByNrc,
) {
  if (seatsByNrc.isEmpty) return const ScheduleIssues();

  int noSeats = 0;
  int notOffered = 0;
  for (final option in schedule) {
    // Los cursos personalizados (NRC sintético "CP...") están fuera de la oferta
    // a propósito: no son un problema. Excluirlos evita un falso "fuera de oferta".
    if (option.nrc.startsWith('CP')) continue;

    final seats = seatsByNrc[option.nrc];
    if (seats == null) {
      notOffered++;
    } else if ((seats['available'] ?? 0) <= 0) {
      noSeats++;
    }
  }
  return ScheduleIssues(noSeats: noSeats, notOffered: notOffered);
}

/// Texto del aviso de un horario con problemas. Dice **qué** y **cuántas**, en
/// vez de un "hay un problema" genérico: el dato ya se tiene.
String scheduleIssuesMessage(ScheduleIssues issues) {
  final partes = <String>[];
  if (issues.noSeats > 0) {
    partes.add(issues.noSeats == 1
        ? '1 clase sin cupos'
        : '${issues.noSeats} clases sin cupos');
  }
  if (issues.notOffered > 0) {
    partes.add(issues.notOffered == 1
        ? '1 clase que ya no está en la oferta'
        : '${issues.notOffered} clases que ya no están en la oferta');
  }
  return '${partes.join(' y ')}. Abre el detalle para ver cuáles.';
}

/// Color de relleno del bloque en la grilla. Se usan los tonos saturados de la
/// RFC (borde) como relleno: en celdas pequeñas leen mejor que los fondos
/// claros y mantienen texto blanco legible.
Color courseStatusColor(CourseStatus status) {
  switch (status) {
    case CourseStatus.safe:
      return const Color(0xFF28A745); // verde
    case CourseStatus.caution:
      return const Color(0xFFE67E22); // naranja
    case CourseStatus.atRisk:
      return const Color(0xFFDC3545); // rojo
    case CourseStatus.eliminated:
      return const Color(0xFF6C757D); // gris (más oscuro que el borde RFC para contraste)
  }
}

/// Etiqueta legible del estado (para la leyenda).
String courseStatusLabel(CourseStatus status) {
  switch (status) {
    case CourseStatus.safe:
      return 'Seguro';
    case CourseStatus.caution:
      return 'Precaución';
    case CourseStatus.atRisk:
      return 'En riesgo';
    case CourseStatus.eliminated:
      return 'Eliminado';
  }
}
