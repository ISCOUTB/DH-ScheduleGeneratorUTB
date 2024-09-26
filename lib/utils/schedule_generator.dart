// lib/utils/schedule_generator.dart
import '../models/subject.dart';
import '../models/subject_offer.dart';

// Generar combinaciones de horarios sin conflictos
List<List<Map<String, List<String>>>> generateMultipleSchedules(
    List<SubjectOffer> addedSubjectOffers, List<String> possibleDays) {
  // Crear una lista de listas de Subjects (horarios disponibles para cada materia)
  List<List<Subject>> subjectsSchedules = addedSubjectOffers
      .map((offer) => offer.availableSchedules)
      .toList();

  // Generar todas las combinaciones posibles de horarios
  List<List<Subject>> scheduleCombinations =
      generateScheduleCombinations(subjectsSchedules);

  List<List<Map<String, List<String>>>> allSchedules = [];

  for (var combination in scheduleCombinations) {
    // Verificar conflictos en la combinación
    if (!hasCombinationConflict(combination)) {
      List<Map<String, List<String>>> weeklySchedule = [];

      for (var day in possibleDays) {
        List<String> subjectsForDay = [];
        for (var subject in combination) {
          for (var schedule in subject.schedule) {
            if (schedule.day == day) {
              subjectsForDay.add('${subject.name} (${schedule.time})');
            }
          }
        }
        weeklySchedule.add({day: subjectsForDay});
      }

      allSchedules.add(weeklySchedule);
    }
  }

  return allSchedules;
}

// Generar todas las combinaciones posibles de horarios
List<List<Subject>> generateScheduleCombinations(
    List<List<Subject>> subjectsSchedules) {
  List<List<Subject>> allCombinations = [];

  void combine(int index, List<Subject> currentCombination) {
    if (index == subjectsSchedules.length) {
      allCombinations.add(List.from(currentCombination));
      return;
    }

    for (var subject in subjectsSchedules[index]) {
      currentCombination.add(subject);
      combine(index + 1, currentCombination);
      currentCombination.removeLast();
    }
  }

  combine(0, []);
  return allCombinations;
}

// Verificar si hay conflictos en una combinación de materias
bool hasCombinationConflict(List<Subject> combination) {
  Map<String, String> scheduleMap = {};

  for (var subject in combination) {
    for (var schedule in subject.schedule) {
      String key = '${schedule.day}-${schedule.time}';
      if (scheduleMap.containsKey(key)) {
        return true; // Hay un conflicto
      } else {
        scheduleMap[key] = subject.name;
      }
    }
  }
  return false;
}
