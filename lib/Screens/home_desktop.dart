// lib/desktop/home_desktop.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/subjects_data.dart';
import '../models/subject.dart';
import '../models/class_option.dart';
import '../widgets/search_widget.dart';
import '../widgets/added_subjects_widgets.dart';
import '../widgets/schedule_grid_widget.dart';
import '../widgets/schedule_overview_widget.dart';
import '../widgets/filter_widget.dart';
import '../utils/schedule_generator.dart';

class HomeDesktop extends StatefulWidget {
  final String title;

  const HomeDesktop({super.key, required this.title});

  @override
  State<HomeDesktop> createState() => _HomeDesktopState();
}

class _HomeDesktopState extends State<HomeDesktop> {
  List<Subject> addedSubjects = [];
  int usedCredits = 0;
  final int creditLimit = 20;

  final TextEditingController subjectController = TextEditingController();

  List<List<ClassOption>> allSchedules = [];
  int? selectedScheduleIndex;

  bool isSearchOpen = false;
  bool isAddedSubjectsOpen = false;
  bool isFilterOpen = false;

  Map<String, dynamic> appliedFilters = {};
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    isSearchOpen = false;
    isAddedSubjectsOpen = false;
    isFilterOpen = false;

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
    if (addedSubjects
        .any((s) => s.code == subject.code && s.name == subject.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La materia ya ha sido agregada')),
      );
      return;
    }

    int newTotalCredits = usedCredits + subject.credits;

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
      });
    }
  }

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
            Row(
              children: [
                Container(
                  width: 60,
                  color: Colors.indigo,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            clearSchedules();
                          },
                          child: const Tooltip(
                            message: 'Limpiar Horarios Generados',
                            child:
                                Icon(Icons.delete_outline, color: Colors.white),
                          ),
                        ),
                      ),
                      const Spacer(),
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
                Expanded(
                  child: Center(
                    child: allSchedules.isEmpty
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '¡Bienvenido al Generador de Horarios UTB! (Actualizado 27/01/2025 06:30 PM)',
                                  style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontFamily: "Futura",
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 60),
                                const Text(
                                  'A tu izquierda encontraras una barra de botones con las siguientes funciones:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.2,
                                    fontFamily: "Futura",
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black38,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 35),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 400),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.search,
                                              color: Colors.white),
                                          SizedBox(width: 10),
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
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 400),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.list, color: Colors.white),
                                          SizedBox(width: 10),
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
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 400),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.filter_list,
                                              color: Colors.white),
                                          SizedBox(width: 10),
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
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 400),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.delete_outline,
                                              color: Colors.white),
                                          SizedBox(width: 10),
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
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 400),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.calendar_today,
                                              color: Colors.yellow),
                                          SizedBox(width: 10),
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
                                    const SizedBox(height: 30),
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
                      onTap: () {},
                      child: SearchSubjectsWidget(
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
                      ),
                    ),
                  ),
                ),
              ),
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
                      onTap: () {},
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
                      onTap: () {},
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
                          generateSchedule();
                        },
                        currentFilters: appliedFilters,
                        addedSubjects: addedSubjects,
                      ),
                    ),
                  ),
                ),
              ),
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
                            onTap: () {},
                            child: ScheduleOverviewWidget(
                              schedule: allSchedules[selectedScheduleIndex!],
                              onClose: () {
                                setState(() {
                                  selectedScheduleIndex = null;
                                });
                              },
                            ),
                          ),
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
