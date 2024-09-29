// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';

class SearchSubjectsWidget extends StatefulWidget {
  final TextEditingController subjectController;
  final List<Subject> allSubjects;
  final Function(Subject) onSubjectSelected;
  final VoidCallback closeWindow;

  const SearchSubjectsWidget({
    Key? key,
    required this.subjectController,
    required this.allSubjects,
    required this.onSubjectSelected,
    required this.closeWindow,
  }) : super(key: key);

  @override
  _SearchSubjectsWidgetState createState() => _SearchSubjectsWidgetState();
}

class _SearchSubjectsWidgetState extends State<SearchSubjectsWidget> {
  List<Subject> filteredSubjects = [];

  void filterSubjects(String query) {
    setState(() {
      filteredSubjects = widget.allSubjects.where((subject) {
        String lowerCaseQuery = query.toLowerCase();
        return subject.name.toLowerCase().contains(lowerCaseQuery) ||
            subject.code.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Campo de búsqueda con autocompletado
            TextField(
              controller: widget.subjectController,
              decoration: const InputDecoration(
                labelText: 'Buscar Materia',
              ),
              onChanged: filterSubjects,
            ),
            const SizedBox(height: 10),
            // Lista de sugerencias
            Expanded(
              child: filteredSubjects.isEmpty
                  ? const Center(child: Text('No hay resultados'))
                  : ListView.builder(
                      itemCount: filteredSubjects.length,
                      itemBuilder: (context, index) {
                        var subject = filteredSubjects[index];
                        return ListTile(
                          title: Text(subject.name),
                          subtitle: Text(
                            subject.code,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          onTap: () {
                            widget.onSubjectSelected(subject);
                          },
                        );
                      },
                    ),
            ),
            // Botón de cerrar
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: widget.closeWindow,
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
