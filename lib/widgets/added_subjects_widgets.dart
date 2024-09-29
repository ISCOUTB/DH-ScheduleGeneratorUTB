// lib/widgets/added_subjects_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';

class AddedSubjectsWidget extends StatelessWidget {
  final List<Subject> addedSubjects;
  final int usedCredits;
  final int creditLimit;
  final VoidCallback closeWindow;
  final Function(Subject subject) onRemoveSubject; // Nueva función para manejar la eliminación

  const AddedSubjectsWidget({
    Key? key,
    required this.addedSubjects,
    required this.usedCredits,
    required this.creditLimit,
    required this.closeWindow,
    required this.onRemoveSubject, // Parámetro añadido
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
                itemCount: addedSubjects.length,
                itemBuilder: (context, index) {
                  var subject = addedSubjects[index];
                  String subjectName = subject.name;
                  int credits = subject.credits;
                  String subjectCode = subject.code;

                  return ListTile(
                    title: Text(subjectName),
                    subtitle: Text('Código: $subjectCode\nCréditos: $credits'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        onRemoveSubject(subject); // Llamar a la función para eliminar la materia
                      },
                    ),
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
