// lib/widgets/professor_filter_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'package:diacritic/diacritic.dart';

/// Un widget que permite al usuario buscar y seleccionar profesores de una lista.
///
/// Se utiliza dentro de `FilterWidget` para filtrar por profesor en una materia específica.
class ProfessorFilterWidget extends StatefulWidget {
  /// La materia de la cual se extraerán los profesores.
  final Subject subject;

  /// La lista de profesores actualmente seleccionados.
  final List<String> selectedProfessors;

  /// Callback que se ejecuta cuando la selección de profesores cambia.
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
  /// Lista completa de todos los profesores únicos para la materia.
  List<String> allProfessors = [];

  /// Lista de profesores que coinciden con el término de búsqueda actual.
  List<String> filteredProfessors = [];

  /// Lista de profesores que han sido seleccionados por el usuario.
  List<String> selectedProfessors = [];

  /// Controlador para el campo de texto de búsqueda.
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Extrae los profesores de la materia y los inicializa.
    _extractAllProfessors(widget.subject);
    filterProfessors(''); // Inicializa la lista filtrada con todos los profesores.
    selectedProfessors = List.from(widget.selectedProfessors);
  }

  /// Extrae y unifica la lista de profesores de todas las opciones de clase de una materia.
  void _extractAllProfessors(Subject subject) {
    final professorSet = <String>{};

    for (var classOption in subject.classOptions) {
      if (classOption.professor.isNotEmpty &&
          classOption.professor != "Por Asignar") {
        professorSet.add(classOption.professor);
      }
    }
    // Convierte el Set a una lista ordenada.
    allProfessors = professorSet.toList()..sort();
    filteredProfessors = List.from(allProfessors);
  }

  /// Filtra la lista de profesores basándose en el texto de búsqueda.
  /// La búsqueda no distingue mayúsculas/minúsculas ni acentos.
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

  /// Agrega o remueve un profesor de la lista de selección.
  void toggleSelection(String professor) {
    setState(() {
      if (selectedProfessors.contains(professor)) {
        selectedProfessors.remove(professor);
      } else {
        selectedProfessors.add(professor);
      }
      // Notifica al widget padre sobre el cambio en la selección.
      widget.onSelectionChanged(selectedProfessors);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de texto para buscar profesores.
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
        // Lista de profesores filtrados con checkboxes.
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
