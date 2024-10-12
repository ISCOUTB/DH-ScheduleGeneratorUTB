// lib/main.dart
import 'package:flutter/material.dart';
import 'data/subjects_data.dart';
import 'models/subject.dart';
import 'models/class_option.dart';
import 'widgets/search_widget.dart';
import 'widgets/added_subjects_widgets.dart';
import 'widgets/schedule_grid_widget.dart';
import 'widgets/schedule_overview_widget.dart';
import 'widgets/filter_widget.dart';
import 'utils/schedule_generator.dart'; // Importamos el archivo con las funciones de generación
import 'package:flutter/services.dart'; // Import para manejar eventos de teclado

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador de Horarios UTB',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(title: 'Generador de Horarios UTB'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Subject> addedSubjects = [];
  int usedCredits = 0;
  final int creditLimit = 20;

  final TextEditingController subjectController = TextEditingController();

  List<List<ClassOption>> allSchedules = [];
  int? selectedScheduleIndex;

  // Controladores para manejar el estado de las ventanas emergentes
  bool isSearchOpen = false;
  bool isAddedSubjectsOpen = false;
  bool isFilterOpen = false;

  // Aquí declara `appliedFilters`
  Map<String, dynamic> appliedFilters = {};

  // FocusNode para capturar los eventos del teclado
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Inicialización de variables de estado
    isSearchOpen = false;
    isAddedSubjectsOpen = false;
    isFilterOpen = false;

    // Inicializar el FocusNode
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void addSubject(Subject subject) {
    // Verificar si la materia ya fue agregada
    if (addedSubjects.any((s) => s.code == subject.code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La materia ya ha sido agregada')),
      );
      return;
    }

    int newTotalCredits = usedCredits + subject.credits;

    // Verificar el límite de créditos
    if (newTotalCredits > creditLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite de créditos alcanzado')),
      );
      return;
    }

    setState(() {
      usedCredits = newTotalCredits;
      addedSubjects.add(subject);

      if (usedCredits > 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Advertencia: Ha excedido los 18 créditos')),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia agregada: ${subject.name}')),
      );
    });
  }

  void removeSubject(Subject subject) {
    setState(() {
      addedSubjects.removeWhere((s) => s.code == subject.code);
      usedCredits -= subject.credits;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia eliminada: ${subject.name}')),
      );
    });
  }

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay materias seleccionadas')),
      );
      return;
    }

    List<List<ClassOption>> horariosValidos =
        obtenerHorariosValidos(addedSubjects, appliedFilters);

    if (horariosValidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron horarios válidos')),
      );
    } else {
      setState(() {
        allSchedules = horariosValidos;
        selectedScheduleIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Menú lateral personalizado
              Container(
                width: 60,
                color: Colors.deepPurple,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Botón de búsqueda
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isSearchOpen = true;
                          });
                        },
                        child: const Tooltip(
                          message: 'Buscar Materias',
                          child: Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Botón de materias seleccionadas
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isAddedSubjectsOpen = true;
                          });
                        },
                        child: const Tooltip(
                          message: 'Materias Seleccionadas',
                          child: Icon(Icons.list, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Botón de filtros
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isFilterOpen = true;
                          });
                        },
                        child: const Tooltip(
                          message: 'Filtrar Horarios',
                          child: Icon(Icons.filter_list, color: Colors.white),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Botón de generar horarios
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: generateSchedule,
                        child: const Tooltip(
                          message: 'Generar Horarios',
                          child:
                              Icon(Icons.calendar_today, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenido principal
              Expanded(
                child: Center(
                  child: allSchedules.isEmpty
                      ? const Text(
                          '¡Bienvenido al Generador de Horarios UTB!',
                          style: TextStyle(fontSize: 24, color: Colors.white),
                          textAlign: TextAlign.center,
                        )
                      : ScheduleGridWidget(
                          allSchedules: allSchedules,
                          onScheduleTap: (index) {
                            setState(() {
                              selectedScheduleIndex = index;
                            });
                          },
                        ),
                ),
              ),
            ],
          ),
          // Ventana emergente de búsqueda de materias
          if (isSearchOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  isSearchOpen = false;
                });
              },
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap:
                        () {}, // Para evitar que se cierre cuando se toca dentro del widget
                    child: SearchSubjectsWidget(
                      subjectController: subjectController,
                      allSubjects: subjects,
                      onSubjectSelected: (subject) {
                        addSubject(subject);
                        // Aquí se elimina el código que cerraba el widget inmediatamente
                        subjectController.clear();
                        // Deja el widget abierto para permitir más selecciones
                      },
                      closeWindow: () {
                        setState(() {
                          isSearchOpen = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          // Ventana emergente de materias seleccionadas
          if (isAddedSubjectsOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  isAddedSubjectsOpen = false;
                });
              },
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Evita que se cierre cuando se toca dentro
                    child: AddedSubjectsWidget(
                      addedSubjects: addedSubjects,
                      usedCredits: usedCredits,
                      creditLimit: creditLimit,
                      closeWindow: () {
                        setState(() {
                          isAddedSubjectsOpen = false;
                        });
                      },
                      onRemoveSubject: (subject) {
                        removeSubject(subject);
                      },
                    ),
                  ),
                ),
              ),
            ),
          // Ventana emergente de filtros
          // Dentro de tu Stack, al mostrar el FilterWidget
          if (isFilterOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  isFilterOpen = false;
                });
              },
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Evita que se cierre al hacer clic dentro
                    child: FilterWidget(
                      closeWindow: () {
                        setState(() {
                          isFilterOpen = false;
                        });
                      },
                      onApplyFilters: (filters) {
                        setState(() {
                          appliedFilters = filters;
                          isFilterOpen = false;
                        });
                        generateSchedule(); // Regenerar horarios con los filtros aplicados
                      },
                      currentFilters: appliedFilters,
                      addedSubjects: addedSubjects,
                    ),
                  ),
                ),
              ),
            ),
          // Mostrar horario seleccionado con navegación
          if (selectedScheduleIndex != null)
            Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKey: (FocusNode node, RawKeyEvent event) {
                if (event is RawKeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                      selectedScheduleIndex! > 0) {
                    setState(() {
                      selectedScheduleIndex = selectedScheduleIndex! - 1;
                    });
                    return KeyEventResult.handled;
                  } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowRight &&
                      selectedScheduleIndex! < allSchedules.length - 1) {
                    setState(() {
                      selectedScheduleIndex = selectedScheduleIndex! + 1;
                    });
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedScheduleIndex = null;
                  });
                },
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap:
                              () {}, // Evita que se cierre cuando se toca dentro
                          child: ScheduleOverviewWidget(
                            schedule: allSchedules[selectedScheduleIndex!],
                            onClose: () {
                              setState(() {
                                selectedScheduleIndex = null;
                              });
                            },
                          ),
                        ),
                        // Flecha izquierda
                        if (selectedScheduleIndex! > 0)
                          Positioned(
                            left: 10,
                            top: MediaQuery.of(context).size.height / 2 - 30,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_left,
                                  size: 50, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  selectedScheduleIndex =
                                      selectedScheduleIndex! - 1;
                                });
                              },
                            ),
                          ),
                        // Flecha derecha
                        if (selectedScheduleIndex! < allSchedules.length - 1)
                          Positioned(
                            right: 10,
                            top: MediaQuery.of(context).size.height / 2 - 30,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_right,
                                  size: 50, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  selectedScheduleIndex =
                                      selectedScheduleIndex! + 1;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
