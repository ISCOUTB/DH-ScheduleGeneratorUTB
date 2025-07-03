// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import '../models/subject_summary.dart'; // 1. Importar el nuevo modelo
import 'package:diacritic/diacritic.dart';

class SearchSubjectsWidget extends StatefulWidget {
  final TextEditingController subjectController;
  // Cambiamos el tipo de la función para que use SubjectSummary
  // Ahora la función recibe un SubjectSummary en lugar de un Subject.
  final Function(SubjectSummary) onSubjectSelected;
  final VoidCallback closeWindow;
  final List<SubjectSummary> allSubjects;

  const SearchSubjectsWidget({
    Key? key,
    required this.subjectController,
    required this.onSubjectSelected,
    required this.closeWindow,
    required this.allSubjects,
  }) : super(key: key);

  @override
  _SearchSubjectsWidgetState createState() => _SearchSubjectsWidgetState();
}

class _SearchSubjectsWidgetState extends State<SearchSubjectsWidget> {
  // La lista filtrada ahora es de tipo SubjectSummary
  List<SubjectSummary> _filteredSubjects = [];

  @override
  void initState() {
    super.initState();
    // La lista filtrada es, al inicio, la lista completa que nos pasan.
    _filteredSubjects = widget.allSubjects;
    widget.subjectController.addListener(_filterListener);
  }

  void _filterListener() {
    filterSubjects(widget.subjectController.text);
  }

  @override
  void dispose() {
    widget.subjectController.removeListener(_filterListener);
    super.dispose();
  }

  void filterSubjects(String query) {
    setState(() {
      String normalizedQuery = removeDiacritics(query.toLowerCase());
      // Filtra desde la lista original que viene en el widget.
      _filteredSubjects = widget.allSubjects.where((subject) {
        String subjectName = removeDiacritics(subject.name.toLowerCase());
        String subjectCode = removeDiacritics(subject.code.toLowerCase());
        return subjectName.contains(normalizedQuery) ||
            subjectCode.contains(normalizedQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: GestureDetector(
        onTap: () {}, // Evita que el diálogo se cierre al hacer clic dentro
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Encabezado
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC7B), // Verde principal
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text(
                      'Buscar Materia',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.closeWindow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Campo de búsqueda con autocompletado
              TextField(
                controller: widget.subjectController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar Materia',
                ),
                onChanged: filterSubjects,
              ),
              const SizedBox(height: 10),
              // Lista de sugerencias
              Expanded(
                child: _filteredSubjects.isEmpty &&
                        widget.subjectController.text.isNotEmpty
                    ? const Center(child: Text('No hay resultados'))
                    : ListView.builder(
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          var subject = _filteredSubjects[
                              index]; // Ahora es SubjectSummary
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
      ),
    );
  }
}
