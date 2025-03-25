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

class WebScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child; // Desactiva el efecto de desplazamiento nativo en la web.
  }
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
      scrollBehavior: WebScrollBehavior(),
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
  late Future<List<Subject>> futureSubjects;
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

    //Se cargan las materias
    futureSubjects = fetchSubjectsFromApi();
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
                              physics:
                                  const BouncingScrollPhysics(), // O `ClampingScrollPhysics()`
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '¡Bienvenido al Generador de Horarios UTB! (Actualizado 30/01/2025 12:30 PM)',
                                    style: TextStyle(
                                      fontSize:
                                          26, // Tamaño ligeramente más grande
                                      color:
                                          Colors.white, // Color blanco clásico
                                      fontFamily:
                                          "Futura", // Fuente personalizada
                                      fontWeight: FontWeight
                                          .w500, // Grosor medio para un toque elegante
                                      letterSpacing:
                                          1.5, // Espaciado entre letras
                                      shadows: [
                                        Shadow(
                                          offset:
                                              Offset(1, 1), // Sombras sutiles
                                          blurRadius: 3,
                                          color: Colors
                                              .black45, // Sombras en tono gris
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 60),
                                  const Text(
                                    'A tu izquierda encontraras una barra de botones con las siguientes funciones:',
                                    style: TextStyle(
                                      fontSize:
                                          20, // Tamaño adecuado para mantener legibilidad
                                      color: Colors
                                          .white, // Color blanco para contraste
                                      fontWeight: FontWeight
                                          .w400, // Grosor regular para un look elegante
                                      letterSpacing:
                                          1.2, // Espaciado sutil entre letras
                                      fontFamily:
                                          "Futura", // Fuente personalizada
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1), // Sombra suave
                                          blurRadius: 2,
                                          color: Colors
                                              .black38, // Tono gris oscuro para mayor sutileza
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 35),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.2, // 20% del anch
                                        ), // Espacio horizontal
                                        child: Row(
                                          mainAxisSize: MainAxisSize
                                              .min, // Limita el ancho del Row al contenido
                                          children: const [
                                            Icon(Icons.search,
                                                color: Colors
                                                    .white), // Ícono de búsqueda
                                            SizedBox(
                                                width:
                                                    10), // Espacio entre el ícono y el texto
                                            Expanded(
                                              child: Text(
                                                'Para buscar y agregar materias.',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          height:
                                              10), // Espacio entre elementos

                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.2, // 20% del anch
                                        ), // Espacio horizontal
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.list,
                                                color: Colors
                                                    .white), // Ícono de lista
                                            SizedBox(
                                                width:
                                                    10), // Espacio entre el ícono y el texto
                                            Expanded(
                                              child: Text(
                                                'Revisar materias previamente seleccionadas.',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          height:
                                              10), // Espacio entre elementos

                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.2, // 20% del anch
                                        ), // Espacio horizontal
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.filter_list,
                                                color: Colors
                                                    .white), // Ícono de filtros
                                            SizedBox(
                                                width:
                                                    10), // Espacio entre el ícono y el texto
                                            Expanded(
                                              child: Text(
                                                'Aplicar filtros (evitar días, profesores, etc.).',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          height:
                                              10), // Espacio entre elementos

                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.2, // 20% del anch
                                        ), // Espacio horizontal
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.delete_outline,
                                                color: Colors
                                                    .white), // Ícono de papelera
                                            SizedBox(
                                                width:
                                                    10), // Espacio entre el ícono y el texto
                                            Expanded(
                                              child: Text(
                                                'Borrar horarios previamente generados.',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          height:
                                              10), // Espacio entre elementos

                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.2, // 20% del anch
                                        ), // Espacio horizontal
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.calendar_today,
                                                color: Colors
                                                    .yellow), // Ícono de calendario
                                            SizedBox(
                                                width:
                                                    10), // Espacio entre el ícono y el texto
                                            Expanded(
                                              child: Text(
                                                '¡Generar horarios! Puedes pulsar sobre ellos para ver los detalles de las materias.',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Colors.white),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          height:
                                              30), // Espacio antes de la firma

                                      // Widget de texto para la firma de los autores
                                      const Text(
                                        'Autores: Gabriel Mantilla y Diego Peña',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
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
                      child: FutureBuilder<List<Subject>>(
                        future: futureSubjects,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          if (snapshot.hasError) {
                            return Text(
                                'Error al cargar materias: ${snapshot.error}');
                          }

                          final subjects = snapshot.data!;

                          return SearchSubjectsWidget(
                            subjectController: subjectController,
                            allSubjects: subjects,
                            onSubjectSelected: (subject) {
                              addSubject(subject);
                              subjectController.clear();
                              // El widget sigue abierto
                            },
                            closeWindow: () {
                              setState(() {
                                isSearchOpen = false;
                              });
                            },
                          );
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
