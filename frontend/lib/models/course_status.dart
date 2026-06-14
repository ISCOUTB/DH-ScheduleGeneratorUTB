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
