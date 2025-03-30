// lib/mobile/home_mobile.dart
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

class HomeMobile extends StatefulWidget {
  final String title;

  const HomeMobile({super.key, required this.title});

  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
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

        if (MediaQuery.of(context).orientation == Orientation.portrait) {
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
    final orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: orientation == Orientation.portrait
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
            if (orientation == Orientation.portrait && allSchedules.isNotEmpty)
              const Center(
                child: Text(
                  'Por favor, gira tu dispositivo para ver los horarios',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Row(
                children: [
                  if (orientation == Orientation.landscape)
                    Container(
                      width: 60,
                      color: Colors.indigo,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                isSearchOpen = true;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          IconButton(
                            icon: const Icon(Icons.list, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                isAddedSubjectsOpen = true;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          IconButton(
                            icon: const Icon(Icons.filter_list,
                                color: Colors.white),
                            onPressed: () {
                              setState(() {
                                isFilterOpen = true;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                            onPressed: () {
                              clearSchedules();
                            },
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
                              child: const Icon(Icons.calendar_today,
                                  color: Colors.white),
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
                                    '¡Bienvenido al Generador de Horarios UTB!',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 30),
                                  const Text(
                                    'Usa los iconos en la parte inferior para:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  ListTile(
                                    leading: const Icon(Icons.search,
                                        color: Colors.white),
                                    title: const Text(
                                      'Buscar y agregar materias',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.list,
                                        color: Colors.white),
                                    title: const Text(
                                      'Ver materias seleccionadas',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.filter_list,
                                        color: Colors.white),
                                    title: const Text(
                                      'Aplicar filtros',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline,
                                        color: Colors.white),
                                    title: const Text(
                                      'Limpiar horarios',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.calendar_today,
                                        color: Colors.amber),
                                    title: const Text(
                                      'Generar horarios',
                                      style: TextStyle(color: Colors.white),
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
            if (allSchedules.isNotEmpty && orientation == Orientation.landscape)
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
