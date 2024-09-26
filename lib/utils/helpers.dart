// lib/utils/helpers.dart
import 'dart:math';
import '../models/subject.dart';
import '../models/subject_offer.dart';

// lib/utils/helpers.dart
String getRandomTime() {
  List<String> possibleTimes = [
    '08:00 - 09:00',
    '09:00 - 10:00',
    '10:00 - 11:00',
    '11:00 - 12:00',
    '12:00 - 13:00',
    '13:00 - 14:00',
    '14:00 - 15:00',
    '15:00 - 16:00',
    '16:00 - 17:00',
    '17:00 - 18:00',
    '18:00 - 19:00',
    '19:00 - 20:00',
  ];

  Random random = Random();
  return possibleTimes[random.nextInt(possibleTimes.length)];
}


List<SubjectOffer> generateSubjectOffers(
    List<String> possibleSubjects, List<String> possibleDays) {
  Random random = Random();
  List<SubjectOffer> subjectOffers = [];

  for (var subjectName in possibleSubjects) {
    int credits = random.nextInt(3) + 2;
    List<Subject> availableSchedules = [];

    int numOffers = random.nextInt(3) + 1; // Entre 1 y 3 ofertas por materia

    for (int i = 0; i < numOffers; i++) {
      int numDays = random.nextInt(2) + 2;
      List<Schedule> schedule = [];

      List<String> availableDays = List.from(possibleDays);
      for (int j = 0; j < numDays; j++) {
        if (availableDays.isEmpty) break;
        String day =
            availableDays.removeAt(random.nextInt(availableDays.length));
        String time = getRandomTime();
        schedule.add(Schedule(day: day, time: time));
      }

      availableSchedules.add(Subject(
        name: subjectName,
        schedule: schedule,
        credits: credits,
      ));
    }

    subjectOffers.add(SubjectOffer(
      name: subjectName,
      credits: credits,
      availableSchedules: availableSchedules,
    ));
  }

  return subjectOffers;
}
