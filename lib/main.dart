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

  @override
  void initState() {
    super.initState();
    // Inicialmente no mostramos horarios
  }

  void defineManualSchedules() {
    // Horario 1
    List<ClassOption> schedule1 = [
      // Física Mecánica
      ClassOption(
        type: 'Teórico',
        subjectName: 'Física Mecánica',
        schedules: [
          Schedule(day: 'Martes', time: '10:00 - 11:50'),
          Schedule(day: 'Jueves', time: '15:00 - 16:50'),
        ],
        professor: 'Vilma',
        nrc: '1001',
        groupId: 1,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        schedules: [
          Schedule(day: 'Lunes', time: '13:00 - 14:50'),
        ],
        professor: 'Kevin Mendoza',
        nrc: '1002',
        groupId: 1,
      ),
      // Cálculo Integral
      ClassOption(
        type: 'Teórico',
        subjectName: 'Cálculo Integral',
        schedules: [
          Schedule(day: 'Lunes', time: '10:00 - 11:50'),
          Schedule(day: 'Miércoles', time: '10:00 - 11:50'),
        ],
        professor: 'Carlos Pérez',
        nrc: '2001',
        groupId: 1,
      ),
      // Programación
      ClassOption(
        type: 'Teórico',
        subjectName: 'Programación',
        schedules: [
          Schedule(day: 'Martes', time: '08:00 - 09:50'),
          Schedule(day: 'Jueves', time: '08:00 - 09:50'),
        ],
        professor: 'Ana Martínez',
        nrc: '3001',
        groupId: 1,
      ),
      // Química General
      ClassOption(
        type: 'Teórico',
        subjectName: 'Química General',
        schedules: [
          Schedule(day: 'Miércoles', time: '13:00 - 14:50'),
          Schedule(day: 'Viernes', time: '13:00 - 14:50'),
        ],
        professor: 'Pedro Gómez',
        nrc: '4001',
        groupId: 1,
      ),
      // Inglés
      ClassOption(
        type: 'Teórico',
        subjectName: 'Inglés',
        schedules: [
          Schedule(day: 'Jueves', time: '11:00 - 12:50'),
          Schedule(day: 'Viernes', time: '08:00 - 09:50'),
        ],
        professor: 'Laura Torres',
        nrc: '5001',
        groupId: 1,
      ),
    ];

    // Horario 2
    List<ClassOption> schedule2 = [
      // Física Mecánica - otro grupo o profesor
      ClassOption(
        type: 'Teórico',
        subjectName: 'Física Mecánica',
        schedules: [
          Schedule(day: 'Lunes', time: '09:00 - 10:50'),
          Schedule(day: 'Viernes', time: '13:00 - 14:50'),
        ],
        professor: 'Yony Pastrana',
        nrc: '1005',
        groupId: 3,
      ),
      ClassOption(
        subjectName: 'Física Mecánica',
        type: 'Laboratorio',
        schedules: [
          Schedule(day: 'Martes', time: '13:00 - 14:50'),
        ],
        professor: 'Kevin Mendoza',
        nrc: '1006',
        groupId: 3,
      ),
      // Cálculo Integral - otro grupo o profesor
      ClassOption(
        type: 'Teórico',
        subjectName: 'Cálculo Integral',
        schedules: [
          Schedule(day: 'Martes', time: '13:00 - 14:50'),
        ],
        professor: 'Carlos Payares',
        nrc: '2007',
        groupId: 2,
      ),
      // Programación - otro grupo o profesor
      ClassOption(
        type: 'Teórico',
        subjectName: 'Programación',
        schedules: [
          Schedule(day: 'Miércoles', time: '13:00 - 14:50'),
          Schedule(day: 'Martes', time: '16:00 - 16:50'),
        ],
        professor: 'Carlos Botero',
        nrc: '5004',
        groupId: 4,
      ),
      // Álgebra Lineal
      ClassOption(
        type: 'Teórico',
        subjectName: 'Álgebra Lineal',
        schedules: [
          Schedule(day: 'Lunes', time: '13:00 - 14:50'),
          Schedule(day: 'Jueves', time: '16:00 - 16:50'),
        ],
        professor: 'Andy Domínguez',
        nrc: '4006',
        groupId: 6,
      ),
      // Inglés 1
      ClassOption(
        subjectName: 'Inglés 1',
        type: 'Teórico',
        schedules: [
          Schedule(day: 'Viernes', time: '18:00 - 19:50'),
          Schedule(day: 'Sábado', time: '08:00 - 09:50'),
        ],
        professor: 'Cindy Paola',
        nrc: '3003',
        groupId: 3,
      ),
    ];

    // Asignamos los horarios a la lista de todos los horarios
    setState(() {
      allSchedules = [schedule1, schedule2];
      selectedScheduleIndex = null;
    });
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

  void generateSchedule() {
    // En lugar de generar horarios basados en las materias agregadas,
    // utilizamos los horarios manuales predefinidos.
    defineManualSchedules();
  }

  // Puedes comentar o mantener las funciones auxiliares si lo deseas.
  // Mantenerlas no afecta el funcionamiento actual y pueden ser útiles posteriormente.

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
                        child: const Icon(Icons.schedule, color: Colors.white),
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
                  child: SearchSubjectsWidget(
                    subjectController: subjectController,
                    allSubjects: subjects,
                    onSubjectSelected: (subject) {
                      addSubject(subject);
                      setState(() {
                        isSearchOpen = false;
                        subjectController.clear();
                      });
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
                  child: AddedSubjectsWidget(
                    addedSubjects: addedSubjects,
                    usedCredits: usedCredits,
                    creditLimit: creditLimit,
                    closeWindow: () {
                      setState(() {
                        isAddedSubjectsOpen = false;
                      });
                    },
                  ),
                ),
              ),
            ),
          // Mostrar horario seleccionado
          if (selectedScheduleIndex != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedScheduleIndex = null;
                });
              },
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: ScheduleOverviewWidget(
                    schedule: allSchedules[selectedScheduleIndex!],
                    onClose: () {
                      setState(() {
                        selectedScheduleIndex = null;
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
