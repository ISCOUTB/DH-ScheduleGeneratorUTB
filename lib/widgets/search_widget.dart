// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import '../models/subject_offer.dart';

class SearchSubjectsWidget extends StatelessWidget {
  final TextEditingController subjectController;
  final List<SubjectOffer> searchResults;
  final Function(String) searchSubject;
  final Function(SubjectOffer) addSubjectOffer;
  final VoidCallback closeWindow;

  const SearchSubjectsWidget({
    Key? key,
    required this.subjectController,
    required this.searchResults,
    required this.searchSubject,
    required this.addSubjectOffer,
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
            // Barra de búsqueda
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: 'Buscar Materia',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    searchSubject(subjectController.text);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Lista de resultados
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  var offer = searchResults[index];
                  String subjectName = offer.name;
                  int credits = offer.credits;

                  return ListTile(
                    title: Text(subjectName),
                    subtitle: Text('Créditos: $credits'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        addSubjectOffer(offer);
                      },
                    ),
                  );
                },
              ),
            ),
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
