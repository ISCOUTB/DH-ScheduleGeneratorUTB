// lib/widgets/professor_filter_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'package:diacritic/diacritic.dart';

class ProfessorFilterWidget extends StatefulWidget {
  final Subject subject;
  final List<String> selectedProfessors;
  final Function(List<String>) onSelectionChanged;

  const ProfessorFilterWidget({
    Key? key,
    required this.subject,
    required this.selectedProfessors,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  _ProfessorFilterWidgetState createState() => _ProfessorFilterWidgetState();
}

class _ProfessorFilterWidgetState extends State<ProfessorFilterWidget> {
  // --- ESTADO SIMPLIFICADO A LA VERSIÓN ORIGINAL ---
  List<String> allProfessors = [];
  List<String> filteredProfessors = [];
  List<String> selectedProfessors = [];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extractAllProfessors(widget.subject);
    filterProfessors(''); // Inicializa la lista filtrada
    selectedProfessors = List.from(widget.selectedProfessors);
  }

  // --- FUNCIÓN PARA EXTRAER TODOS LOS PROFESORES EN UNA SOLA LISTA ---
  void _extractAllProfessors(Subject subject) {
    final professorSet = <String>{};

    for (var classOption in subject.classOptions) {
      if (classOption.professor.isNotEmpty &&
          classOption.professor != "Por Asignar") {
        professorSet.add(classOption.professor);
      }
    }
    allProfessors = professorSet.toList()..sort();
    filteredProfessors = List.from(allProfessors);
  }

  void filterProfessors(String query) {
    setState(() {
      String normalizedQuery = removeDiacritics(query.toLowerCase());

      if (normalizedQuery.isEmpty) {
        filteredProfessors = List.from(allProfessors);
      } else {
        filteredProfessors = allProfessors.where((professor) {
          String normalizedProfessor =
              removeDiacritics(professor.toLowerCase());
          return normalizedProfessor.contains(normalizedQuery);
        }).toList();
      }
    });
  }

  // --- SELECCIÓN SIMPLIFICADA ---
  void toggleSelection(String professor) {
    setState(() {
      if (selectedProfessors.contains(professor)) {
        selectedProfessors.remove(professor);
      } else {
        selectedProfessors.add(professor);
      }
      widget.onSelectionChanged(selectedProfessors);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Buscar Profesor',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: filterProfessors,
          ),
        ),
        Expanded(
          child: filteredProfessors.isEmpty
              ? Center(
                  child: Text(searchController.text.isNotEmpty
                      ? 'No hay resultados para la búsqueda'
                      : 'No hay profesores asignados para esta materia'),
                )
              : ListView.builder(
                  itemCount: filteredProfessors.length,
                  itemBuilder: (context, index) {
                    final professor = filteredProfessors[index];
                    final isSelected = selectedProfessors.contains(professor);
                    return CheckboxListTile(
                      title:
                          Text(professor, style: const TextStyle(fontSize: 14)),
                      value: isSelected,
                      onChanged: (_) => toggleSelection(professor),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
