// lib/main.dart
import 'package:flutter/material.dart';
import 'models/subject.dart';
import 'models/subject_offer.dart';
import 'utils/helpers.dart';
import 'utils/schedule_generator.dart';
import 'widgets/search_widget.dart';
import 'widgets/added_subjects_widgets.dart';
import 'widgets/schedule_grid_widget.dart';
import 'widgets/schedule_detail_widget.dart';

void main() {
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
  List<SubjectOffer> searchResults = [];
  int usedCredits = 0;
  final int creditLimit = 20;
  List<SubjectOffer> addedSubjectOffers = []; // Almacenamos SubjectOffers

  final TextEditingController subjectController = TextEditingController();

  final List<String> possibleSubjects = [
    'Matemáticas',
    'Física',
    'Química',
    'Programación',
    'Historia',
    'Estadística',
    'Biología',
    'Literatura',
    'Filosofía',
    'Música'
  ];

  final List<String> possibleDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  List<SubjectOffer> subjectOffers = [];
  List<List<Map<String, List<String>>>> allSchedules = [];
  int? selectedScheduleIndex;

  @override
  void initState() {
    super.initState();
    subjectOffers = generateSubjectOffers(possibleSubjects, possibleDays);
  }

  void searchSubject(String subject) {
    String lowerCaseSubject = subject.toLowerCase();

    setState(() {
      searchResults = subjectOffers
          .where((offer) => offer.name.toLowerCase().contains(lowerCaseSubject))
          .toList();

      if (searchResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la materia')),
        );
      }
    });
  }

  void addSubjectOffer(SubjectOffer offer) {
    // Verificar si la materia ya fue agregada
    if (addedSubjectOffers.any((s) => s.name == offer.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La materia ya ha sido agregada')),
      );
      return;
    }

    int newTotalCredits = usedCredits + offer.credits;

    // Verificar el límite de créditos
    if (newTotalCredits > creditLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite de créditos alcanzado')),
      );
      return;
    }

    setState(() {
      usedCredits = newTotalCredits;
      addedSubjectOffers.add(offer);

      if (usedCredits > 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advertencia: Ha excedido los 18 créditos')),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia agregada: ${offer.name}')),
      );
    });
  }

  void generateSchedule() {
    if (addedSubjectOffers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione materias antes de generar')),
      );
    } else {
      allSchedules = generateMultipleSchedules(addedSubjectOffers, possibleDays);

      if (allSchedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudieron generar horarios sin conflictos')),
        );
        return;
      }

      setState(() {
        selectedScheduleIndex = null; // Reseteamos la selección
      });
    }
  }

  // Controladores para manejar el estado de las ventanas emergentes
  bool isSearchOpen = false;
  bool isAddedSubjectsOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(widget.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
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
                    searchResults: searchResults,
                    searchSubject: searchSubject,
                    addSubjectOffer: addSubjectOffer,
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
                    addedSubjectOffers: addedSubjectOffers,
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
                  child: ScheduleDetailWidget(
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
