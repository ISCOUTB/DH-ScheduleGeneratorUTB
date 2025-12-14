// lib/config/constants.dart
import 'package:flutter/material.dart';

/// Constantes globales de la aplicación.

/// Días de la semana completos (para UI).
const List<String> kDaysOfWeek = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Días de la semana abreviados (para grids compactos).
const List<String> kDaysOfWeekShort = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

/// Franjas horarias disponibles (7:00 AM - 8:00 PM).
const List<String> kTimeSlots = [
  '07:00',
  '08:00',
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
];

/// Franjas horarias extendidas (incluye 21:00 para filtros).
const List<String> kTimeSlotsExtended = [
  '07:00',
  '08:00',
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
  '21:00',
];

/// Paleta de colores para asignar a las materias.
const List<Color> kSubjectColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.indigo,
  Colors.lime,
  Colors.pink,
  Colors.deepOrange,
  Colors.lightBlue,
  Colors.lightGreen,
  Colors.deepPurple,
];

/// Colores principales de la aplicación.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF093AD8);
  static const Color secondary = Color(0xFF0FC4EF);
  static const Color success = Color(0xFF1ABC7B);
  static const Color accent = Color(0xFF71ED37);
  static const Color dark = Color(0xFF2C2A2A);
  static const Color background = Color(0xFFF5F7FA);
}

/// Límites y configuraciones.
class AppConfig {
  AppConfig._();

  static const int defaultCreditLimit = 20;
  static const int warningCreditThreshold = 18;
  static const int defaultItemsPerPage = 10;
  static const double mobileBreakpoint = 600.0;
}
