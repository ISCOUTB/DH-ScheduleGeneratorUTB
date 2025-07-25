// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import '../models/subject_summary.dart'; // 1. Importar el nuevo modelo
import 'package:diacritic/diacritic.dart';

/// Un widget de diálogo que permite al usuario buscar y seleccionar una materia.
///
/// Muestra una lista de materias que se puede filtrar por nombre o código.
/// Utiliza `SubjectSummary` para mostrar información básica de las materias.
class SearchSubjectsWidget extends StatefulWidget {
  /// Controlador para el campo de texto de búsqueda.
  final TextEditingController subjectController;

  /// Callback que se ejecuta cuando el usuario selecciona una materia de la lista.
  final Function(SubjectSummary) onSubjectSelected;

  /// Callback para cerrar el diálogo.
  final VoidCallback closeWindow;

  /// La lista completa de todas las materias disponibles para la búsqueda.
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
  /// Lista de materias que coinciden con el criterio de búsqueda actual.
  List<SubjectSummary> _filteredSubjects = [];

  @override
  void initState() {
    super.initState();
    // Inicializa la lista filtrada con todas las materias.
    _filteredSubjects = widget.allSubjects;
    // Escucha los cambios en el campo de texto para filtrar la lista.
    widget.subjectController.addListener(_filterListener);
  }

  /// Listener que se activa con los cambios del `subjectController`.
  void _filterListener() {
    filterSubjects(widget.subjectController.text);
  }

  @override
  void dispose() {
    // Elimina el listener para evitar fugas de memoria.
    widget.subjectController.removeListener(_filterListener);
    super.dispose();
  }

  /// Filtra la lista de `allSubjects` basándose en una consulta de búsqueda.
  /// La búsqueda no distingue mayúsculas/minúsculas ni acentos.
  void filterSubjects(String query) {
    setState(() {
      String normalizedQuery = removeDiacritics(query.toLowerCase());
      // Si la consulta está vacía, muestra todas las materias.
      if (normalizedQuery.isEmpty) {
        _filteredSubjects = widget.allSubjects;
        return;
      }
      // Filtra por nombre o código de la materia.
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
    // Detectar si la vista es para móvil para ajustar el layout
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      // Reducir el margen exterior en móviles
      insetPadding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: GestureDetector(
        onTap: () {}, // Evita que el diálogo se cierre al hacer clic dentro
        child: Container(
          // Ancho flexible y altura que se ajusta al contenido
          width: isMobile ? double.infinity : 500,
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // La columna se ajusta a su contenido
            children: [
              // Encabezado del diálogo.
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC7B), // Verde principal
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                // Padding vertical reducido en móvil
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 4 : 16),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.white),
                    const SizedBox(width: 10),
                    // Tamaño de fuente consistente
                    const Text(
                      'Buscar Materia',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
              // Mensaje informativo
              Container(
                // Padding y margen reducidos en móvil
                padding: EdgeInsets.all(isMobile ? 4 : 12),
                margin: EdgeInsets.only(bottom: isMobile ? 8 : 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Busca la materia por nombre o código. Si no la ves, revisa la escritura o ten en cuenta que puede estar llena.',
                        // Tamaño de fuente reducido en móvil
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: isMobile ? 12 : 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Campo de texto para la búsqueda.
              TextField(
                controller: widget.subjectController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar Materia',
                ),
                onChanged: filterSubjects,
              ),
              const SizedBox(height: 10),
              // Lista de resultados de la búsqueda.
              // Flexible para que la lista ocupe el espacio restante
              Flexible(
                child: _filteredSubjects.isEmpty &&
                        widget.subjectController.text.isNotEmpty
                    ? const Center(child: Text('No hay resultados'))
                    : ListView.builder(
                        shrinkWrap: true, // Se ajusta al contenido
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          var subject = _filteredSubjects[index];
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
              // Botón para cerrar el diálogo.
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
