// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb y defaultTargetPlatform
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
    final ThemeData theme = ThemeData(
      primarySwatch: Colors.indigo,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
        accentColor: Colors.amber,
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Generador de Horarios UTB',
      theme: theme,
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

  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

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
    if (addedSubjects
        .any((s) => s.code == subject.code && s.name == subject.name)) {
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
      addedSubjects
          .removeWhere((s) => s.code == subject.code && s.name == subject.name);
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

        // Si estamos en móvil y en modo vertical, mostrar mensaje
        if (isMobile() &&
            MediaQuery.of(context).orientation == Orientation.portrait) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Por favor, gira tu dispositivo para ver los horarios'),
            ),
          );
        }
      });
    }
  }

  // Nueva función para limpiar los horarios generados
  void clearSchedules() {
    setState(() {
      allSchedules.clear();
      selectedScheduleIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Horarios generados eliminados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool mobile = isMobile();
    var orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: mobile && orientation == Orientation.portrait
          ? null
          : (mobile && orientation == Orientation.landscape)
              ? null
              : AppBar(
                  title: Text(widget.title),
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
      bottomNavigationBar: mobile && orientation == Orientation.portrait
          ? BottomAppBar(
              color: Colors.indigo,
              child: Container(
                height: kToolbarHeight,
                alignment: Alignment.center,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade900, Colors.indigo.shade500],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Si estamos en móvil y en modo vertical, y hay horarios generados, mostrar mensaje
            if (mobile &&
                orientation == Orientation.portrait &&
                allSchedules.isNotEmpty)
              // Mostrar mensaje solicitando girar el dispositivo
              Center(
                child: Text(
                  'Por favor, gira tu dispositivo para ver los horarios',
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Row(
                children: [
                  // Menú lateral personalizado
                  Container(
                    width: 60,
                    color: Colors.indigo,
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
                              child:
                                  Icon(Icons.filter_list, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Botón para limpiar horarios generados
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              clearSchedules();
                            },
                            child: const Tooltip(
                              message: 'Limpiar Horarios Generados',
                              child: Icon(Icons.delete_outline,
                                  color: Colors.white),
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
                              child: Icon(Icons.calendar_today,
                                  color: Colors.white),
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
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '¡Bienvenido al Generador de Horarios UTB! (Actualizado 26/01/2025 08:00 PM)',
                                    style: TextStyle(
                                        fontSize: 24, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Instrucciones:',
                                    style: TextStyle(
                                        fontSize: 20, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '1. Haz clic en el ícono de búsqueda en la barra lateral izquierda para buscar y agregar materias.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '2. Una vez agregadas las materias, puedes revisar las materias seleccionadas haciendo clic en el ícono de lista.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '3. Opcionalmente, puedes aplicar filtros haciendo clic en el ícono de filtro.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '4. Para generar los horarios posibles, haz clic en el botón amarillo con el ícono de calendario en la parte inferior de la barra lateral.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '5. Los horarios generados aparecerán en la pantalla. Puedes presionar sobre ellos para ver los detalles de las materias.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '6. Para limpiar los horarios generados, haz clic en el ícono de la papelera en la barra lateral.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
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
            // Contador de horarios generados
            if (allSchedules.isNotEmpty)
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${allSchedules.length} horarios generados',
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
