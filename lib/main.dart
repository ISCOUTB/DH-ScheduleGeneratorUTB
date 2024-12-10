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
      home: const MyHomePage(
        title: 'Generador de Horarios UTB',
        letras: '',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.letras});

  final String title;
  final String letras;

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

  // Aquí declara appliedFilters
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Container(
            color: Colors.deepPurple,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'Buscar Materias',
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isSearchOpen = true;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Materias Seleccionadas',
                  icon: const Icon(Icons.list, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isAddedSubjectsOpen = true;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Filtrar Horarios',
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isFilterOpen = true;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Generar Horarios',
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: () {
                    generateSchedule();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
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
          // Ventanas emergentes
          if (isSearchOpen)
            buildOverlay(SearchSubjectsWidget(
              subjectController: subjectController,
              allSubjects: subjects,
              onSubjectSelected: (subject) {
                addSubject(subject);
                subjectController.clear();
              },
              closeWindow: () {
                setState(() {
                  isSearchOpen = false;
                });
              },
            )),
          if (isAddedSubjectsOpen)
            buildOverlay(AddedSubjectsWidget(
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
            )),
          if (isFilterOpen)
            buildOverlay(FilterWidget(
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
                generateSchedule();
              },
              currentFilters: appliedFilters,
              addedSubjects: addedSubjects,
            )),
        ],
      ),
    );
  }

  Widget buildOverlay(Widget child) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSearchOpen = isAddedSubjectsOpen = isFilterOpen = false;
        });
      },
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Para evitar que se cierre al hacer clic dentro
            child: child,
          ),
        ),
      ),
    );
  }
}
