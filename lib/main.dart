// lib/main.dart
import 'package:flutter/material.dart';
import 'data/subjects_data.dart';
import 'models/subject.dart';
import 'models/class_option.dart';
import 'widgets/search_widget.dart';
import 'widgets/added_subjects_widgets.dart';
import 'widgets/schedule_grid_widget.dart';
import 'models/schedule.dart';
import 'widgets/schedule_overview_widget.dart';
import 'package:collection/collection.dart'; //
import 'package:flutter/services.dart'; // Import para manejar eventos de teclado

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Definición de TimeOfDayRange fuera de cualquier clase
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);

  bool overlaps(TimeOfDayRange other) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final otherStartMinutes = other.start.hour * 60 + other.start.minute;
    final otherEndMinutes = other.end.hour * 60 + other.end.minute;

    return (startMinutes < otherEndMinutes) && (endMinutes > otherStartMinutes);
  }
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

  // FocusNode para capturar los eventos del teclado
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Inicialización de variables de estado
    isSearchOpen = false;
    isAddedSubjectsOpen = false;

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
        obtenerHorariosValidos(addedSubjects);

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

  // Funciones para generar los horarios

  List<List<ClassOption>> obtenerHorariosValidos(List<Subject> asignaturas) {
    List<List<ClassOption>> todosLosHorarios =
        generarTodosLosHorariosPosibles(asignaturas);
    List<List<ClassOption>> horariosValidos = [];

    for (var horario in todosLosHorarios) {
      if (!horarioTieneConflictos(horario)) {
        horariosValidos.add(horario);
      }
    }

    return horariosValidos;
  }

  List<List<ClassOption>> generarTodosLosHorariosPosibles(
      List<Subject> asignaturas) {
    // Obtener las combinaciones de opciones para cada asignatura
    List<List<List<ClassOption>>> combinacionesPorAsignatura = [];

    for (var asignatura in asignaturas) {
      var combinaciones = obtenerCombinacionesDeOpciones(asignatura);
      combinacionesPorAsignatura.add(combinaciones);
    }

    // Función recursiva para calcular el producto cartesiano
    List<List<ClassOption>> todosLosHorarios = [];

    void productoCartesiano(int profundidad, List<ClassOption> actual,
        List<List<ClassOption>> resultado) {
      if (profundidad == combinacionesPorAsignatura.length) {
        resultado.add(List.from(actual));
        return;
      }

      for (var opcionSet in combinacionesPorAsignatura[profundidad]) {
        actual.addAll(opcionSet);
        productoCartesiano(profundidad + 1, actual, resultado);
        actual.removeRange(actual.length - opcionSet.length, actual.length);
      }
    }

    productoCartesiano(0, [], todosLosHorarios);
    return todosLosHorarios;
  }

  List<List<ClassOption>> obtenerCombinacionesDeOpciones(Subject asignatura) {
    Map<int, List<ClassOption>> opcionesPorGrupo = {};

    // Agrupar las opciones de clase por groupId
    for (var opcion in asignatura.classOptions) {
      int groupId = opcion.groupId;
      opcionesPorGrupo.putIfAbsent(groupId, () => []);
      opcionesPorGrupo[groupId]!.add(opcion);
    }

    List<List<ClassOption>> combinaciones = [];

    // Generar combinaciones de opciones teóricas y prácticas por grupo
    for (var opcionesGrupo in opcionesPorGrupo.values) {
      List<ClassOption> opcionesTeoricas = [];
      List<ClassOption> opcionesPracticas = [];

      for (var opcion in opcionesGrupo) {
        if (opcion.type == 'Teórico') {
          opcionesTeoricas.add(opcion);
        } else if (opcion.type == 'Laboratorio') {
          opcionesPracticas.add(opcion);
        }
      }

      // Emparejar opciones teóricas y prácticas
      if (opcionesTeoricas.isNotEmpty && opcionesPracticas.isNotEmpty) {
        for (var teorica in opcionesTeoricas) {
          for (var practica in opcionesPracticas) {
            combinaciones.add([teorica, practica]);
          }
        }
      } else {
        // Si solo hay un tipo de opción
        for (var opcion in opcionesTeoricas + opcionesPracticas) {
          combinaciones.add([opcion]);
        }
      }
    }

    return combinaciones;
  }

  bool horarioTieneConflictos(List<ClassOption> horario) {
    List<Schedule> todosLosHorarios = [];

    for (var opcion in horario) {
      todosLosHorarios.addAll(opcion.schedules);
    }

    // Comparar cada horario con los demás
    for (int i = 0; i < todosLosHorarios.length; i++) {
      for (int j = i + 1; j < todosLosHorarios.length; j++) {
        if (horariosSeSolapan(todosLosHorarios[i], todosLosHorarios[j])) {
          return true; // Conflicto encontrado
        }
      }
    }
    return false; // Sin conflictos
  }

  bool horariosSeSolapan(Schedule a, Schedule b) {
    // Verificar si los días coinciden
    if (a.day != b.day) return false;

    // Parsear los horarios
    TimeOfDayRange rangoA = parseTimeRange(a.time);
    TimeOfDayRange rangoB = parseTimeRange(b.time);

    return rangosSeSolapan(rangoA, rangoB);
  }

  bool rangosSeSolapan(TimeOfDayRange a, TimeOfDayRange b) {
    final inicioA = a.start.hour * 60 + a.start.minute;
    final finA = a.end.hour * 60 + a.end.minute;
    final inicioB = b.start.hour * 60 + b.start.minute;
    final finB = b.end.hour * 60 + b.end.minute;

    return inicioA < finB && inicioB < finA;
  }

  TimeOfDayRange parseTimeRange(String rangoHora) {
    List<String> partes = rangoHora.split(' - ');
    TimeOfDay inicio = parseTimeOfDay(partes[0].trim());
    TimeOfDay fin = parseTimeOfDay(partes[1].trim());
    return TimeOfDayRange(inicio, fin);
  }

  TimeOfDay parseTimeOfDay(String horaString) {
    // Eliminar espacios y convertir a mayúsculas
    horaString = horaString.trim().toUpperCase();

    // Verificar si contiene 'AM' o 'PM'
    bool isPM = horaString.contains('PM');
    bool isAM = horaString.contains('AM');

    // Eliminar 'AM' y 'PM' si están presentes
    horaString = horaString.replaceAll('AM', '').replaceAll('PM', '').trim();

    // Separar horas y minutos
    List<String> partesHora = horaString.split(':');
    int hora = int.parse(partesHora[0]);
    int minuto = partesHora.length > 1 ? int.parse(partesHora[1]) : 0;

    // Convertir a formato de 24 horas si es necesario
    if (isPM && hora < 12) {
      hora += 12;
    }
    if (isAM && hora == 12) {
      hora = 0;
    }

    return TimeOfDay(hour: hora, minute: minuto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
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
                          child: const Icon(Icons.calendar_today,
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
                      ? const Text(
                          '¡Bienvenido al Generador de Horarios UTB!',
                          style: TextStyle(fontSize: 24),
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
                              icon: Icon(Icons.arrow_left,
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
                              icon: Icon(Icons.arrow_right,
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
