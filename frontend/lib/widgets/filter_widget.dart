// lib/widgets/filter_widget.dart

/// Widget para configurar filtros de profesores y horarios.
/// Permite al usuario definir preferencias para la generación de horarios,
/// incluyendo la selección de profesores y la definición de horas no disponibles.
import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'professor_filter_widget.dart';

/// Widget principal que contiene la lógica y la interfaz para los filtros.
class FilterWidget extends StatefulWidget {
  /// Cierra el diálogo de filtros.
  final VoidCallback closeWindow;

  /// Callback que se ejecuta al aplicar los filtros.
  /// Devuelve dos mapas: uno para el estado de la UI y otro para la API.
  final Function(
          Map<String, dynamic> stateFilters, Map<String, dynamic> apiFilters)
      onApplyFilters;

  /// Callback que se ejecuta cuando se limpian los filtros.
  final VoidCallback onClearFilters;

  /// Filtros actuales para inicializar el estado del widget.
  final Map<String, dynamic> currentFilters;

  /// Materias agregadas por el usuario para las que se pueden aplicar filtros.
  final List<Subject> addedSubjects;

  /// Constructor del widget de filtros.
  const FilterWidget({
    Key? key,
    required this.closeWindow,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.currentFilters,
    required this.addedSubjects,
  }) : super(key: key);

  @override
  _FilterWidgetState createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  /// Almacena los filtros de profesores por materia (incluir/excluir).
  late Map<String, dynamic> _professorsFilters;

  /// Almacena las horas no disponibles por día.
  late Map<String, dynamic> _timeFilters;

  /// Clave para forzar la reconstrucción del widget cuando se limpian los filtros
  Key _widgetKey = UniqueKey();

  /// Días de la semana para la selección de filtros de tiempo.
  final List<String> days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  /// Franjas horarias disponibles para la selección de filtros de tiempo.
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

  /// Inicializa el estado del widget, cargando los filtros actuales.
  @override
  void initState() {
    super.initState();
    // Clonamos los filtros actuales para poder modificarlos localmente
    _professorsFilters =
        Map<String, dynamic>.from(widget.currentFilters['professors'] ?? {});
    _timeFilters =
        Map<String, dynamic>.from(widget.currentFilters['timeFilters'] ?? {});
  }

  /// Función para aplicar los filtros y actualizar el estado del widget.
  /// Procesa y aplica los filtros, generando dos formatos:
  /// 1. Para el estado de la UI (conserva la selección del usuario).
  /// 2. Para la API (formato esperado por el backend).
  // Procesa los filtros de profesores para la API.
  void _applyFilters() {
    Map<String, dynamic> finalProfessorFiltersForApi = {};
    _professorsFilters.forEach((subjectCode, filterData) {
      String filterType = filterData['filterType'];
      List<String> professors = List<String>.from(filterData['professors']);

      if (professors.isNotEmpty) {
        String key = filterType == 'include'
            ? 'include_professors'
            : 'exclude_professors';
        if (finalProfessorFiltersForApi[key] == null) {
          finalProfessorFiltersForApi[key] = {};
        }
        finalProfessorFiltersForApi[key][subjectCode] = professors;
      }
    });

    // Objeto de filtros para la API.
    Map<String, dynamic> filtersForApi = {
      ...finalProfessorFiltersForApi,
      'unavailable_slots': _timeFilters,
    };

    // Objeto de filtros para el estado de la UI.
    Map<String, dynamic> filtersForState = {
      'professors': _professorsFilters,
      'timeFilters': _timeFilters,
    };

    // Llama al callback con ambos mapas de filtros.
    widget.onApplyFilters(filtersForState, filtersForApi);
  }

  /// Construye la interfaz de usuario del widget de filtros.
  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en modo oscuro o claro
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
            // Encabezado con título y botón de cerrar
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
            // Contenido principal con scroll
            Expanded(
              key: _widgetKey, // Clave para forzar reconstrucción
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Sección: Filtros por Materia (Profesores)
                    /// Contiene los filtros para incluir o excluir profesores por materia.
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
                                // Radio buttons para seleccionar tipo de filtro (incluir/excluir)
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
                                // Widget para la selección de profesores
                                SizedBox(
                                  width: 400,
                                  height: 200,
                                  child: ProfessorFilterWidget(
                                    subject: subject,
                                    selectedProfessors: List<String>.from(
                                        subjectFilter['professors']),
                                    onSelectionChanged: (selectedProfessors) {
                                      // Actualiza la lista de profesores seleccionados
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
                    // Sección: Filtros de Horas Disponibles
                    /// Permite al usuario definir las horas en las que no desea tener clases.
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
                          // Chips para seleccionar días de la semana
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
                          // Selección de horas para cada día seleccionado
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
                                // Checkbox para seleccionar/deseleccionar todas las horas del día
                                CheckboxListTile(
                                  activeColor: accentColor,
                                  title: Text(
                                    'Seleccionar todas las horas (Dejar este día completamente libre)',
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
                                // Grid para seleccionar horas específicas
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
                  ],
                ),
              ),
            ),
            // Botones de acción
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón Limpiar filtros
                  TextButton.icon(
                    onPressed: () {
                      // Notifica al padre para que limpie el estado principal.
                      widget.onClearFilters();

                      // Cierra la ventana de filtros.
                      widget.closeWindow();

                      // Muestra una notificación.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Todos los filtros han sido eliminados'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(Icons.clear_all, color: Colors.red.shade600),
                    label: Text(
                      isMobile ? 'Limpiar\nfiltros' : 'Limpiar filtros',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),

                  // Botón para aplicar los filtros configurados
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                    ),
                    onPressed: () {
                      // Validar si hay materias agregadas antes de aplicar
                      if (widget.addedSubjects.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Agrega al menos una materia para aplicar filtros.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return; // Detiene la ejecución si no hay materias
                      }

                      _applyFilters();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Filtros aplicados correctamente'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      isMobile ? 'Aplicar\nfiltros' : 'Aplicar filtros',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
