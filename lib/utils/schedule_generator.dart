// lib/utils/schedule_generator.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/class_option.dart';
import '../models/schedule.dart';

class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);

  bool overlaps(TimeOfDayRange other) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final otherStartMinutes = other.start.hour * 60 + other.start.minute;
    final otherEndMinutes = other.end.hour * 60 + other.end.minute;

    return (startMinutes < otherEndMinutes) && (endMinutes > otherStartMinutes);
  }

  bool contains(TimeOfDay time) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }
}

// Función para obtener combinaciones de opciones de clase para una asignatura
List<List<ClassOption>> obtenerCombinacionesDeOpciones(Subject asignatura) {
  Map<int, List<ClassOption>> opcionesPorGrupo = {};

  // Agrupar las opciones de clase por groupId
  for (var opcion in asignatura.classOptions) {
    int groupId = opcion.groupId;
    opcionesPorGrupo.putIfAbsent(groupId, () => []);
    opcionesPorGrupo[groupId]!.add(opcion);
  }

  List<List<ClassOption>> combinaciones = [];

  // Generar combinaciones posibles para cada grupo
  for (var opcionesGrupo in opcionesPorGrupo.values) {
    List<ClassOption> opcionesTeoricas = [];
    List<ClassOption> opcionesPracticas = [];
    List<ClassOption> opcionesTeoricoPracticas = [];

    for (var opcion in opcionesGrupo) {
      if (opcion.type == 'Teórico') {
        opcionesTeoricas.add(opcion);
      } else if (opcion.type == 'Laboratorio') {
        opcionesPracticas.add(opcion);
      } else if (opcion.type == 'Teorico-practico') {
        opcionesTeoricoPracticas.add(opcion);
      }
    }

    // Generar combinaciones posibles
    if (opcionesTeoricoPracticas.isNotEmpty) {
      for (var opcionTP in opcionesTeoricoPracticas) {
        combinaciones.add([opcionTP]);
      }
    }

    if (opcionesTeoricas.isNotEmpty && opcionesPracticas.isNotEmpty) {
      for (var teorica in opcionesTeoricas) {
        for (var practica in opcionesPracticas) {
          combinaciones.add([teorica, practica]);
        }
      }
    } else if (opcionesTeoricas.isNotEmpty) {
      for (var opcion in opcionesTeoricas) {
        combinaciones.add([opcion]);
      }
    } else if (opcionesPracticas.isNotEmpty) {
      for (var opcion in opcionesPracticas) {
        combinaciones.add([opcion]);
      }
    }
  }

  return combinaciones;
}

// Función para obtener todos los horarios válidos usando backtracking
List<List<ClassOption>> obtenerHorariosValidos(
    List<Subject> asignaturas, Map<String, dynamic> appliedFilters) {
  List<List<ClassOption>> horariosValidos = [];

  // Obtener las combinaciones de opciones para cada asignatura
  List<List<List<ClassOption>>> combinacionesPorAsignatura = [];

  for (var asignatura in asignaturas) {
    var combinaciones = obtenerCombinacionesDeOpciones(asignatura);
    combinacionesPorAsignatura.add(combinaciones);
  }

  void backtrack(int nivel, List<ClassOption> horarioActual) {
    if (nivel == combinacionesPorAsignatura.length) {
      // Hemos seleccionado una opción para cada asignatura
      if (cumpleConFiltros(horarioActual, appliedFilters)) {
        horariosValidos.add(List.from(horarioActual));
      }
      return;
    }

    for (var opcionGrupo in combinacionesPorAsignatura[nivel]) {
      // Verificar si la opción no tiene conflictos con el horario actual
      if (!tieneConflictos(horarioActual, opcionGrupo)) {
        // Añadir las opciones al horario actual
        horarioActual.addAll(opcionGrupo);
        // Continuar al siguiente nivel
        backtrack(nivel + 1, horarioActual);
        // Quitar las opciones añadidas (backtracking)
        horarioActual.removeRange(
            horarioActual.length - opcionGrupo.length, horarioActual.length);
      }
    }
  }

  backtrack(0, []);

  // Optimizar horarios si es necesario
  bool optimizeFreeDays = appliedFilters['optimizeFreeDays'] == true;
  bool optimizeGaps = appliedFilters['optimizeGaps'] == true;

  if (optimizeFreeDays || optimizeGaps) {
    horariosValidos.sort((a, b) {
      double scoreA = 0;
      double scoreB = 0;

      if (optimizeFreeDays) {
        int freeDaysA = calcularDiasLibres(horario: a);
        int freeDaysB = calcularDiasLibres(horario: b);
        // Mayor cantidad de días libres, mayor puntuación
        scoreA +=
            freeDaysA * 1000; // Multiplicamos por 1000 para darle más peso
        scoreB += freeDaysB * 1000;
      }

      if (optimizeGaps) {
        int gapsA = calcularHuecos(horario: a);
        int gapsB = calcularHuecos(horario: b);
        // Menor cantidad de huecos, mayor puntuación
        scoreA -= gapsA; // Restamos los huecos
        scoreB -= gapsB;
      }

      // Ordenar de mayor a menor puntuación
      return scoreB.compareTo(scoreA);
    });
  }

  return horariosValidos;
}

// Función para verificar si agregar una nueva opción genera conflictos
bool tieneConflictos(
    List<ClassOption> horarioActual, List<ClassOption> nuevaOpcion) {
  for (var opcionExistente in horarioActual) {
    for (var opcionNueva in nuevaOpcion) {
      if (opcionesEnConflicto(opcionExistente, opcionNueva)) {
        return true;
      }
    }
  }
  return false;
}

// Función para verificar si dos opciones de clase tienen conflicto
bool opcionesEnConflicto(ClassOption opcion1, ClassOption opcion2) {
  for (var schedule1 in opcion1.schedules) {
    for (var schedule2 in opcion2.schedules) {
      if (horariosSeSolapan(schedule1, schedule2)) {
        return true;
      }
    }
  }
  return false;
}

// Función para verificar si hay solapamientos entre dos horarios
bool horariosSeSolapan(Schedule a, Schedule b) {
  // Verificar si los días coinciden
  if (a.day != b.day) return false;

  // Parsear los horarios
  TimeOfDayRange rangoA = parseTimeRange(a.time);
  TimeOfDayRange rangoB = parseTimeRange(b.time);

  return rangoA.overlaps(rangoB);
}

// Función para verificar si un horario cumple con los filtros aplicados
bool cumpleConFiltros(
    List<ClassOption> horario, Map<String, dynamic> appliedFilters) {
  Map<String, dynamic> professorsFilters = appliedFilters['professors'] ?? {};
  Map<String, dynamic> timeFilters = appliedFilters['timeFilters'] ?? {};

  for (var opcion in horario) {
    String subjectCode = opcion.subjectCode;

    // Filtrar por profesores
    if (professorsFilters.containsKey(subjectCode)) {
      Map<String, dynamic> subjectFilter = professorsFilters[subjectCode];
      String filterType = subjectFilter['filterType'] as String;
      List<String> profesoresSeleccionados =
      subjectFilter['professors'] as List<String>;

      // Aplicar el filtro solo si hay profesores seleccionados
      if (profesoresSeleccionados.isNotEmpty) {
        if (filterType == 'include') {
          // Si la opción de clase es impartida por alguno de los profesores seleccionados, es válida
          if (!profesoresSeleccionados.contains(opcion.professor)) {
            return false; // Profesor no está en la lista de inclusión
          }
        } else if (filterType == 'exclude') {
          // Si la opción de clase es impartida por alguno de los profesores excluidos, es inválida
          if (profesoresSeleccionados.contains(opcion.professor)) {
            return false; // Profesor está en la lista de exclusión
          }
        }
      }
    }

    // Filtrar por horas no disponibles
    for (var schedule in opcion.schedules) {
      String day = schedule.day;
      if (timeFilters.containsKey(day)) {
        List<String> unavailableTimes = List<String>.from(timeFilters[day]);
        TimeOfDayRange classTimeRange = parseTimeRange(schedule.time);

        // Verificar si alguna hora no disponible coincide con el horario de la clase
        for (var time in unavailableTimes) {
          TimeOfDay unavailableTime = parseTimeOfDay(time);
          if (classTimeRange.contains(unavailableTime)) {
            return false; // La clase está en una hora no disponible
          }
        }
      }
    }
  }

  return true; // Cumple con todos los filtros
}

// Función para calcular la cantidad total de huecos en un horario
int calcularHuecos({required List<ClassOption> horario}) {
  // Crear una lista de todas las clases con su horario
  List<Map<String, dynamic>> clases = [];

  for (var opcion in horario) {
    for (var schedule in opcion.schedules) {
      TimeOfDayRange timeRange = parseTimeRange(schedule.time);
      clases.add({
        'day': schedule.day,
        'start': timeRange.start,
        'end': timeRange.end,
      });
    }
  }

  int totalGapsMinutes = 0;

  // Agrupar clases por día
  Map<String, List<Map<String, dynamic>>> clasesPorDia = {};
  for (var clase in clases) {
    String day = clase['day'];
    clasesPorDia.putIfAbsent(day, () => []);
    clasesPorDia[day]!.add(clase);
  }

  // Calcular huecos por día
  for (var dia in clasesPorDia.keys) {
    List<Map<String, dynamic>> clasesDelDia = clasesPorDia[dia]!;

    // Ordenar las clases por hora de inicio
    clasesDelDia.sort((a, b) {
      int startA = a['start'].hour * 60 + a['start'].minute;
      int startB = b['start'].hour * 60 + b['start'].minute;
      return startA.compareTo(startB);
    });

    // Calcular los huecos entre clases
    for (int i = 0; i < clasesDelDia.length - 1; i++) {
      TimeOfDay endCurrent = clasesDelDia[i]['end'];
      TimeOfDay startNext = clasesDelDia[i + 1]['start'];
      int gapMinutes = (startNext.hour * 60 + startNext.minute) -
          (endCurrent.hour * 60 + endCurrent.minute);
      if (gapMinutes > 0) {
        totalGapsMinutes += gapMinutes;
      }
    }
  }

  // Retornar el total de huecos en minutos
  return totalGapsMinutes;
}

// Función para calcular la cantidad de días libres en un horario
int calcularDiasLibres({required List<ClassOption> horario}) {
  // Días de la semana
  List<String> allDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  // Obtener los días ocupados en el horario
  Set<String> diasOcupados = {};

  for (var opcion in horario) {
    for (var schedule in opcion.schedules) {
      diasOcupados.add(schedule.day);
    }
  }

  // Calcular los días libres
  int diasLibres = allDays.length - diasOcupados.length;

  return diasLibres;
}

// Funciones auxiliares para parsear horarios
TimeOfDayRange parseTimeRange(String rangoHora) {
  List<String> partes = rangoHora.split(' - ');
  TimeOfDay inicio = parseTimeOfDay(partes[0].trim());
  TimeOfDay fin = parseTimeOfDay(partes[1].trim());
  return TimeOfDayRange(inicio, fin);
}

TimeOfDay parseTimeOfDay(String horaString) {
  // Eliminar espacios y convertir a mayúsculas
  horaString = horaString.trim().toUpperCase();

  // Verificar si contiene 'AM' o 'PM'
  bool isPM = horaString.contains('PM');
  bool isAM = horaString.contains('AM');

  // Eliminar 'AM' y 'PM' si están presentes
  horaString = horaString.replaceAll('AM', '').replaceAll('PM', '').trim();

  // Separar horas y minutos
  List<String> partesHora = horaString.split(':');
  int hora = int.parse(partesHora[0]);
  int minuto = partesHora.length > 1 ? int.parse(partesHora[1]) : 0;

  // Convertir a formato de 24 horas si es necesario
  if (isPM && hora < 12) {
    hora += 12;
  }
  if (isAM && hora == 12) {
    hora = 0;
  }

  return TimeOfDay(hour: hora, minute: minuto);
}
