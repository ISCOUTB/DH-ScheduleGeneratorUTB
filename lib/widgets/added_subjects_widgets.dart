// lib/widgets/added_subjects_widget.dart
import 'package:flutter/material.dart';
import '../models/subject_offer.dart';

class AddedSubjectsWidget extends StatelessWidget {
  final List<SubjectOffer> addedSubjectOffers;
  final int usedCredits;
  final int creditLimit;
  final VoidCallback closeWindow;

  const AddedSubjectsWidget({
    Key? key,
    required this.addedSubjectOffers,
    required this.usedCredits,
    required this.creditLimit,
    required this.closeWindow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Materias Seleccionadas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: addedSubjectOffers.length,
                itemBuilder: (context, index) {
                  var offer = addedSubjectOffers[index];
                  String subjectName = offer.name;
                  int credits = offer.credits;

                  return ListTile(
                    title: Text(subjectName),
                    subtitle: Text('Créditos: $credits'),
                  );
                },
              ),
            ),
            Text('Créditos utilizados: $usedCredits / $creditLimit'),
            // Botón de cerrar
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: closeWindow,
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
