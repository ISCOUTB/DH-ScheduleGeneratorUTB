import 'dart:math';
import 'package:flutter/material.dart';

// Función para agrupar materias por nombre
Map<String, List<Map<String, dynamic>>> groupSubjectsByName(List<Map<String, dynamic>> addedSubjects) {
  Map<String, List<Map<String, dynamic>>> groupedSubjects = {};

  for (var subject in addedSubjects) {
    String name = subject['name'];
    if (groupedSubjects.containsKey(name)) {
      groupedSubjects[name]!.add(subject);
    } else {
      groupedSubjects[name] = [subject];
    }
  }

  return groupedSubjects;
}

// Función para generar combinaciones de horarios
List<List<Map<String, dynamic>>> generateScheduleCombinations(
    Map<String, List<Map<String, dynamic>>> groupedSubjects) {
  List<List<Map<String, dynamic>>> allCombinations = [];

  // Recursión para combinar horarios
  void generateCombination(List<Map<String, dynamic>> currentCombination,
      List<List<Map<String, dynamic>>> remainingGroups) {
    if (remainingGroups.isEmpty) {
      allCombinations.add(List.from(currentCombination));
      return;
    }

    var currentGroup = remainingGroups.first;
    for (var subject in currentGroup) {
      currentCombination.add(subject);
      generateCombination(
          currentCombination, remainingGroups.sublist(1)); // Recursión
      currentCombination.removeLast();
    }
  }

  generateCombination(
    [],
    groupedSubjects.values.toList(),
  );

  return allCombinations;
}

// Función actualizada para generar múltiples horarios
List<List<Map<String, List<String>>>> generateMultipleSchedules(
    List<Map<String, dynamic>> addedSubjects, List<String> possibleDays) {
  Map<String, List<Map<String, dynamic>>> groupedSubjects =
      groupSubjectsByName(addedSubjects);
  List<List<Map<String, dynamic>>> scheduleCombinations =
      generateScheduleCombinations(groupedSubjects);

  List<List<Map<String, List<String>>>> allSchedules = [];

  for (var combination in scheduleCombinations) {
    List<Map<String, List<String>>> weeklySchedule = [];

    for (var day in possibleDays) {
      List<String> subjectsForDay = [];
      for (var subject in combination) {
        for (var schedule in subject['schedule']) {
          if (schedule['day'] == day) {
            subjectsForDay.add('${subject['name']} (${schedule['time']})');
          }
        }
      }
      weeklySchedule.add({day: subjectsForDay});
    }

    allSchedules.add(weeklySchedule);
  }

  return allSchedules;
}
