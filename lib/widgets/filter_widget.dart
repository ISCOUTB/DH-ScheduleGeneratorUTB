// lib/widgets/filter_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'professor_filter_widget.dart';

class FilterWidget extends StatefulWidget {
  final VoidCallback closeWindow;
  final Function(Map<String, dynamic>) onApplyFilters;
  final Map<String, dynamic> currentFilters;
  final List<Subject> addedSubjects;

  const FilterWidget({
    Key? key,
    required this.closeWindow,
    required this.onApplyFilters,
    required this.currentFilters,
    required this.addedSubjects,
  }) : super(key: key);

  @override
  _FilterWidgetState createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  late Map<String, dynamic> professorsFilters;

  @override
  void initState() {
    super.initState();
    professorsFilters = Map<String, dynamic>.from(widget.currentFilters['professors'] ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      height: 500,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtros por Materia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.closeWindow,
              ),
            ],
          ),
          const Divider(),
          // Contenido
          Expanded(
            child: ListView(
              children: widget.addedSubjects.map((subject) {
                String subjectCode = subject.code;
                Map<String, dynamic> subjectFilter = professorsFilters[subjectCode] ?? {
                  'filterType': 'include',
                  'professors': <String>[],
                };

                return ExpansionTile(
                  leading: const Icon(Icons.book),
                  title: Text(subject.name),
                  children: [
                    // Contenido reorganizado en una fila
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lista de profesores
                        SizedBox(
                          width: 300, // Ancho fijo para hacerlo más angosto
                          height: 200,
                          child: ProfessorFilterWidget(
                            subject: subject,
                            selectedProfessors: List<String>.from(subjectFilter['professors']),
                            onSelectionChanged: (selectedProfessors) {
                              subjectFilter['professors'] = selectedProfessors;
                              professorsFilters[subjectCode] = subjectFilter;
                            },
                          ),
                        ),
                        const SizedBox(width: 16), // Espacio entre los widgets
                        // Opciones de selección única
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile<String>(
                                title: const Text('Incluir profesores seleccionados'),
                                value: 'include',
                                groupValue: subjectFilter['filterType'],
                                onChanged: (value) {
                                  setState(() {
                                    subjectFilter['filterType'] = value!;
                                    professorsFilters[subjectCode] = subjectFilter;
                                  });
                                },
                              ),
                              RadioListTile<String>(
                                title: const Text('No incluir profesores seleccionados'),
                                value: 'exclude',
                                groupValue: subjectFilter['filterType'],
                                onChanged: (value) {
                                  setState(() {
                                    subjectFilter['filterType'] = value!;
                                    professorsFilters[subjectCode] = subjectFilter;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          // Botones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.closeWindow,
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Map<String, dynamic> filters = {
                    'professors': professorsFilters,
                  };
                  widget.onApplyFilters(filters);
                },
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
