// lib/models/subject_offer.dart
import 'subject.dart';

class SubjectOffer {
  final String name;
  final int credits;
  final List<Subject> availableSchedules;

  SubjectOffer({
    required this.name,
    required this.credits,
    required this.availableSchedules,
  });
}
