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
  List<String> allProfessors = [];
  List<String> filteredProfessors = [];
  List<String> selectedProfessors = [];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allProfessors = obtenerProfesoresDeLaMateria(widget.subject);
    filteredProfessors = allProfessors;
    selectedProfessors = List.from(widget.selectedProfessors);
  }

  List<String> obtenerProfesoresDeLaMateria(Subject subject) {
    Set<String> professorsSet = {};

    for (var classOption in subject.classOptions) {
      if (classOption.professor.isNotEmpty) {
        professorsSet.add(classOption.professor);
      }
    }

    List<String> professorsList = professorsSet.toList();
    professorsList.sort();
    return professorsList;
  }

  void filterProfessors(String query) {
    setState(() {
      String normalizedQuery = removeDiacritics(query.toLowerCase());
      filteredProfessors = allProfessors.where((professor) {
        String normalizedProfessor = removeDiacritics(professor.toLowerCase());
        return normalizedProfessor.contains(normalizedQuery);
      }).toList();
    });
  }

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
      children: [
        // Campo de búsqueda
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar Profesor',
          ),
          onChanged: filterProfessors,
        ),
        const SizedBox(height: 10),
        // Lista de profesores
        Expanded(
          child: filteredProfessors.isEmpty
              ? const Center(child: Text('No hay resultados'))
              : ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filteredProfessors.length,
                  itemBuilder: (context, index) {
                    String professor = filteredProfessors[index];
                    bool isSelected = selectedProfessors.contains(professor);

                    return ListTile(
                      title: Text(
                        professor,
                        style: TextStyle(
                            fontSize:
                                14), // Reducir tamaño de fuente si es necesario
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected ? Colors.blue : null,
                        ),
                        onPressed: () => toggleSelection(professor),
                      ),
                      onTap: () => toggleSelection(professor),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
