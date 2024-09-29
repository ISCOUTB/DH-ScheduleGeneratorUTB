// lib/schedule_generator.dart
import '../models/subject.dart';
import '../models/class_option.dart';
import '../models/schedule.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; 

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

  // Generar combinaciones de opciones teóricas y prácticas por grupo
  for (var opcionesGrupo in opcionesPorGrupo.values) {
    List<ClassOption> opcionesTeoricas = [];
    List<ClassOption> opcionesPracticas = [];

    for (var opcion in opcionesGrupo) {
      if (opcion.type == 'Teórico') {
        opcionesTeoricas.add(opcion);
      } else if (opcion.type == 'Laboratorio') {
        opcionesPracticas.add(opcion);
      }
    }

    // Emparejar opciones teóricas y prácticas
    if (opcionesTeoricas.isNotEmpty && opcionesPracticas.isNotEmpty) {
      for (var teorica in opcionesTeoricas) {
        for (var practica in opcionesPracticas) {
          combinaciones.add([teorica, practica]);
        }
      }
    } else {
      // Si solo hay un tipo de opción
      for (var opcion in opcionesTeoricas + opcionesPracticas) {
        combinaciones.add([opcion]);
      }
    }
  }

  return combinaciones;
}

// Función para generar todas las combinaciones posibles de horarios
List<List<ClassOption>> generarTodosLosHorariosPosibles(List<Subject> asignaturas) {
  // Obtener las combinaciones de opciones para cada asignatura
  List<List<List<ClassOption>>> combinacionesPorAsignatura = [];

  for (var asignatura in asignaturas) {
    var combinaciones = obtenerCombinacionesDeOpciones(asignatura);
    combinacionesPorAsignatura.add(combinaciones);
  }

  // Función recursiva para calcular el producto cartesiano
  List<List<ClassOption>> todosLosHorarios = [];

  void productoCartesiano(
      int profundidad, List<ClassOption> actual, List<List<ClassOption>> resultado) {
    if (profundidad == combinacionesPorAsignatura.length) {
      resultado.add(List.from(actual));
      return;
    }

    for (var opcionSet in combinacionesPorAsignatura[profundidad]) {
      actual.addAll(opcionSet);
      productoCartesiano(profundidad + 1, actual, resultado);
      actual.removeRange(actual.length - opcionSet.length, actual.length);
    }
  }

  productoCartesiano(0, [], todosLosHorarios);
  return todosLosHorarios;
}

// Función para verificar si hay solapamientos entre dos horarios
bool horariosSeSolapan(Schedule a, Schedule b) {
  // Verificar si los días coinciden
  if (a.day != b.day) return false;

  // Parsear los horarios
  TimeOfDayRange rangoA = parseTimeRange(a.time);
  TimeOfDayRange rangoB = parseTimeRange(b.time);

  return rangosSeSolapan(rangoA, rangoB);
}

bool rangosSeSolapan(TimeOfDayRange a, TimeOfDayRange b) {
  final inicioA = a.start.hour * 60 + a.start.minute;
  final finA = a.end.hour * 60 + a.end.minute;
  final inicioB = b.start.hour * 60 + b.start.minute;
  final finB = b.end.hour * 60 + b.end.minute;

  return inicioA < finB && inicioB < finA;
}

// Función para verificar si un horario completo tiene conflictos
bool horarioTieneConflictos(List<ClassOption> horario) {
  List<Schedule> todosLosHorarios = [];

  for (var opcion in horario) {
    todosLosHorarios.addAll(opcion.schedules);
  }

  // Comparar cada horario con los demás
  for (int i = 0; i < todosLosHorarios.length; i++) {
    for (int j = i + 1; j < todosLosHorarios.length; j++) {
      if (horariosSeSolapan(todosLosHorarios[i], todosLosHorarios[j])) {
        return true; // Conflicto encontrado
      }
    }
  }
  return false; // Sin conflictos
}

// Función para obtener todos los horarios válidos (sin conflictos)
List<List<ClassOption>> obtenerHorariosValidos(List<Subject> asignaturas) {
  List<List<ClassOption>> todosLosHorarios = generarTodosLosHorariosPosibles(asignaturas);
  List<List<ClassOption>> horariosValidos = [];

  for (var horario in todosLosHorarios) {
    if (!horarioTieneConflictos(horario)) {
      horariosValidos.add(horario);
    }
  }

  return horariosValidos;
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

// Definición de TimeOfDayRange
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
