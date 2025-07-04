// lib/widgets/added_subjects_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';

/// Un widget que muestra una lista de materias seleccionadas en un diálogo.
class AddedSubjectsWidget extends StatelessWidget {
  /// La lista de materias que han sido agregadas.
  final List<Subject> addedSubjects;

  /// El número de créditos actualmente en uso.
  final int usedCredits;

  /// El límite total de créditos permitido.
  final int creditLimit;

  /// Callback para cerrar el diálogo.
  final VoidCallback closeWindow;

  /// Callback que se ejecuta al eliminar una materia de la lista.
  final Function(Subject subject) onRemoveSubject;

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
    // Construye la interfaz del diálogo.
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
                        onRemoveSubject(subject); // Llama a la función para eliminar la materia
                      },
                    ),
                  );
                },
              ),
            ),
            // Muestra el contador de créditos.
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
