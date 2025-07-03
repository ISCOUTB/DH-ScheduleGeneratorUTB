// lib/widgets/filter_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'professor_filter_widget.dart';

class FilterWidget extends StatefulWidget {
  final VoidCallback closeWindow;
  // --- CAMBIO EN LA FIRMA DE LA FUNCIÓN ---
  final Function(
          Map<String, dynamic> stateFilters, Map<String, dynamic> apiFilters)
      onApplyFilters;
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
  late Map<String, dynamic> _professorsFilters;
  late Map<String, dynamic> _timeFilters;
  late bool _optimizeGaps;
  late bool _optimizeFreeDays;

  // Días de la semana en orden
  final List<String> days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  // Horas disponibles (en formato de 24 horas)
  final List<String> timeSlots = [
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
  ];

  @override
  void initState() {
    super.initState();
    // Clonamos los filtros actuales para poder modificarlos localmente
    _professorsFilters =
        Map<String, dynamic>.from(widget.currentFilters['professors'] ?? {});
    _timeFilters =
        Map<String, dynamic>.from(widget.currentFilters['timeFilters'] ?? {});
    _optimizeGaps = widget.currentFilters['optimizeGaps'] ?? false;
    _optimizeFreeDays = widget.currentFilters['optimizeFreeDays'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en modo oscuro o claro
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Colores basados en el tema actual
    Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    Color accentColor = Theme.of(context).colorScheme.secondary;

    return Dialog(
      backgroundColor: backgroundColor, // Fondo del diálogo
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 600,
        height: 650,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor, // Color del texto
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: widget.closeWindow,
                ),
              ],
            ),
            const Divider(),
            // Contenido
            Expanded(
              child: SingleChildScrollView(
                // Barra desplazadora aquí
                child: Column(
                  children: [
                    // Filtros por Materia (Profesores)
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor:
                            textColor, // Color de íconos sin seleccionar
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              secondary: accentColor, // Color de acento
                            ),
                      ),
                      child: ExpansionTile(
                        leading: Icon(Icons.book, color: textColor),
                        title: Text('Filtros por Materia',
                            style: TextStyle(color: textColor)),
                        children: widget.addedSubjects.map((subject) {
                          String subjectCode = subject.code;
                          // Aseguramos que el filtro para la materia exista
                          if (_professorsFilters[subjectCode] == null) {
                            _professorsFilters[subjectCode] = {
                              'filterType': 'include',
                              'professors': <String>[]
                            };
                          }
                          Map<String, dynamic> subjectFilter =
                              _professorsFilters[subjectCode];

                          return Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              unselectedWidgetColor: textColor,
                              colorScheme:
                                  Theme.of(context).colorScheme.copyWith(
                                        secondary: accentColor,
                                      ),
                            ),
                            child: ExpansionTile(
                              title: Text(subject.name,
                                  style: TextStyle(color: textColor)),
                              children: [
                                // Opciones de selección única
                                Column(
                                  children: [
                                    RadioListTile<String>(
                                      activeColor: accentColor,
                                      title: Text(
                                          'Incluir profesores seleccionados',
                                          style: TextStyle(color: textColor)),
                                      value: 'include',
                                      groupValue: subjectFilter['filterType'],
                                      onChanged: (value) {
                                        setState(() {
                                          subjectFilter['filterType'] = value!;
                                          _professorsFilters[subjectCode] =
                                              subjectFilter;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      activeColor: accentColor,
                                      title: Text(
                                          'No incluir profesores seleccionados',
                                          style: TextStyle(color: textColor)),
                                      value: 'exclude',
                                      groupValue: subjectFilter['filterType'],
                                      onChanged: (value) {
                                        setState(() {
                                          subjectFilter['filterType'] = value!;
                                          _professorsFilters[subjectCode] =
                                              subjectFilter;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: 400,
                                  height: 200,
                                  child: ProfessorFilterWidget(
                                    subject: subject,
                                    selectedProfessors: List<String>.from(
                                        subjectFilter['professors']),
                                    onSelectionChanged: (selectedProfessors) {
                                      // No necesitamos setState aquí porque el estado se maneja en ProfessorFilterWidget
                                      // y los datos se leen al aplicar.
                                      subjectFilter['professors'] =
                                          selectedProfessors;
                                      _professorsFilters[subjectCode] =
                                          subjectFilter;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filtros de Horas Disponibles
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor: textColor,
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              secondary: accentColor,
                            ),
                      ),
                      child: ExpansionTile(
                        leading: Icon(Icons.access_time, color: textColor),
                        title: Text('Filtros de Horas Disponibles',
                            style: TextStyle(color: textColor)),
                        children: [
                          // Mostrar días con checkboxes ordenados
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: days.map((day) {
                              bool isDaySelected =
                                  _timeFilters.containsKey(day);
                              return FilterChip(
                                label: Text(day,
                                    style: TextStyle(color: textColor)),
                                selected: isDaySelected,
                                selectedColor: accentColor,
                                backgroundColor: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      // Agregar el día con horas no disponibles vacías inicialmente
                                      _timeFilters[day] = <String>[];
                                    } else {
                                      // Remover el día
                                      _timeFilters.remove(day);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          // Para cada día seleccionado, mostrar las horas en orden
                          ...days
                              .where((day) => _timeFilters.containsKey(day))
                              .map((day) {
                            List<String> unavailableHours =
                                List<String>.from(_timeFilters[day] ?? []);

                            // Verificar si todas las horas están seleccionadas
                            bool allHoursSelected =
                                unavailableHours.length == timeSlots.length;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '$day - Selecciona las horas que deseas estar libre:',
                                  style: TextStyle(color: textColor),
                                ),
                                // Opción de seleccionar todas las horas
                                CheckboxListTile(
                                  activeColor: accentColor,
                                  title: Text(
                                    'Seleccionar todas las horas (No tener clases este día)',
                                    style: TextStyle(color: textColor),
                                  ),
                                  value: allHoursSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        // Seleccionar todas las horas
                                        unavailableHours =
                                            List<String>.from(timeSlots);
                                      } else {
                                        // Deseleccionar todas las horas
                                        unavailableHours.clear();
                                      }
                                      _timeFilters[day] = unavailableHours;
                                    });
                                  },
                                ),
                                SizedBox(
                                  width: 400,
                                  height: 100,
                                  child: GridView.count(
                                    crossAxisCount: 4,
                                    childAspectRatio: 3,
                                    children: timeSlots.map((time) {
                                      bool isSelected =
                                          unavailableHours.contains(time);
                                      return FilterChip(
                                        label: Text(time,
                                            style: TextStyle(color: textColor)),
                                        selected: isSelected,
                                        selectedColor: accentColor,
                                        backgroundColor: isDarkMode
                                            ? Colors.grey[800]
                                            : Colors.grey[300],
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              unavailableHours.add(time);
                                            } else {
                                              unavailableHours.remove(time);
                                            }
                                            _timeFilters[day] =
                                                unavailableHours;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Opciones de Optimización
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor: textColor,
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              secondary: accentColor,
                            ),
                      ),
                      child: ExpansionTile(
                        leading: Icon(Icons.sort, color: textColor),
                        title: Text('Opciones de Optimización',
                            style: TextStyle(color: textColor)),
                        children: [
                          SwitchListTile(
                            activeColor: accentColor,
                            trackColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return accentColor
                                      .withOpacity(0.5); // visible en activo
                                }
                                return Colors
                                    .grey.shade400; // visible en inactivo
                              },
                            ),
                            thumbColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.grey.shade200;
                              },
                            ),
                            title: Text('Optimizar Horas (Menos huecos)',
                                style: TextStyle(color: textColor)),
                            value: _optimizeGaps,
                            onChanged: (value) {
                              setState(() {
                                _optimizeGaps = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            activeColor: accentColor,
                            trackColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return accentColor
                                      .withOpacity(0.5); // visible en activo
                                }
                                return Colors
                                    .grey.shade400; // visible en inactivo
                              },
                            ),
                            thumbColor:
                                MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.grey.shade200;
                              },
                            ),
                            title: Text(
                                'Optimizar Días Libres (Más días libres primero)',
                                style: TextStyle(color: textColor)),
                            value: _optimizeFreeDays,
                            onChanged: (value) {
                              setState(() {
                                _optimizeFreeDays = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.closeWindow,
                  child: Text('Cancelar', style: TextStyle(color: accentColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                  ),
                  onPressed: () {
                    // --- LÓGICA DE FILTROS MODIFICADA PARA PERSISTENCIA ---
                    Map<String, dynamic> finalProfessorFiltersForApi = {};
                    _professorsFilters.forEach((subjectCode, filterData) {
                      String filterType = filterData['filterType'];
                      List<String> professors =
                          List<String>.from(filterData['professors']);

                      if (professors.isNotEmpty) {
                        String key = filterType == 'include'
                            ? 'include_professors'
                            : 'exclude_professors';
                        if (finalProfessorFiltersForApi[key] == null) {
                          finalProfessorFiltersForApi[key] = {};
                        }
                        finalProfessorFiltersForApi[key][subjectCode] =
                            professors;
                      }
                    });

                    // Construimos el objeto de filtros que se enviará a la API
                    Map<String, dynamic> filtersForApi = {
                      ...finalProfessorFiltersForApi,
                      'unavailable_slots': _timeFilters,
                      'optimizeGaps': _optimizeGaps,
                      'optimizeFreeDays': _optimizeFreeDays,
                    };

                    // Construimos el objeto de filtros que se guardará en el estado local
                    // ESTA ES LA PARTE CLAVE: Guardamos la estructura completa
                    Map<String, dynamic> filtersForState = {
                      'professors':
                          _professorsFilters, // Guarda el estado interno de los profesores
                      'timeFilters':
                          _timeFilters, // Guarda el estado interno de las horas
                      'optimizeGaps': _optimizeGaps,
                      'optimizeFreeDays': _optimizeFreeDays,
                    };

                    // --- CAMBIO EN LA LLAMADA A LA FUNCIÓN ---
                    // Llamamos a la función de aplicar filtros con ambos mapas
                    widget.onApplyFilters(filtersForState, filtersForApi);

                    widget.closeWindow();
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
