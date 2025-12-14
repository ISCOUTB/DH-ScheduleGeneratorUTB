// lib/utils/time_utils.dart
import 'package:flutter/material.dart';

/// Representa un rango de tiempo con hora de inicio y fin.
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeOfDayRange(this.start, this.end);

  /// Duración del rango en minutos.
  int get durationInMinutes {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes - startMinutes;
  }

  /// Verifica si una hora está dentro del rango.
  bool contains(TimeOfDay time) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }
}

/// Funciones de utilidad para manejo de tiempo.
class TimeUtils {
  TimeUtils._();

  /// Parsea una cadena de tiempo (ej. "07:00" o "7:00 AM") a TimeOfDay.
  static TimeOfDay parseTimeOfDay(String timeString) {
    // Eliminar espacios y convertir a mayúsculas
    timeString = timeString.trim().toUpperCase();

    // Verificar si contiene 'AM' o 'PM'
    final bool isPM = timeString.contains('PM');
    final bool isAM = timeString.contains('AM');

    // Eliminar 'AM' y 'PM' si están presentes
    timeString = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

    // Separar horas y minutos
    final List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    // Convertir a formato de 24 horas si es necesario
    if (isPM && hour < 12) {
      hour += 12;
    }
    if (isAM && hour == 12) {
      // Medianoche (12 AM) es la hora 0
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Parsea un rango de tiempo (ej. "07:00 - 09:00") a TimeOfDayRange.
  static TimeOfDayRange parseTimeRange(String timeRange) {
    final List<String> parts = timeRange.split(' - ');
    final TimeOfDay start = parseTimeOfDay(parts[0].trim());
    final TimeOfDay end = parseTimeOfDay(parts[1].trim());
    return TimeOfDayRange(start, end);
  }

  /// Encuentra el índice de una franja horaria para una hora específica.
  /// 
  /// [time] es la hora a buscar.
  /// [timeSlots] es la lista de franjas horarias (ej. ['07:00', '08:00', ...]).
  /// [startHour] es la hora de inicio de la primera franja (default: 7).
  static int getTimeSlotIndex(TimeOfDay time, List<String> timeSlots, {int startHour = 7}) {
    // Si la hora de fin tiene minutos (ej. 14:50), se considera que ocupa
    // toda la franja horaria de la hora de inicio.
    int hourToIndex = time.minute > 0 ? time.hour + 1 : time.hour;
    int index = hourToIndex - startHour;
    return index.clamp(0, timeSlots.length);
  }

  /// Verifica si una hora está dentro de un rango.
  static bool isTimeWithinRange(TimeOfDay time, TimeOfDayRange range) {
    return range.contains(time);
  }

  /// Formatea un TimeOfDay a string (ej. "07:00").
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
