import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador de horarios UTB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Generador de horarios UTB'),
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
  int selectedIndex = 0;
  List<Map<String, dynamic>> searchResults = [];
  int usedCredits = 0;
  final int creditLimit = 20;
  List<Map<String, dynamic>> addedSubjects = [];

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

  final Map<String, int> subjectCredits = {};

  String getRandomTime() {
    Random random = Random();
    int hour = random.nextInt(12) + 8;
    int minuteStart = 0;
    int endHour = hour + 2;
    int minuteEnd = 50;

    return '${hour.toString().padLeft(2, '0')}:${minuteStart.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${minuteEnd.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> generateRandomSubjects(int count) {
    Random random = Random();
    List<Map<String, dynamic>> generatedSubjects = [];

    for (int i = 0; i < count; i++) {
      String subjectName =
          possibleSubjects[random.nextInt(possibleSubjects.length)];
      int credits;
      if (subjectCredits.containsKey(subjectName)) {
        credits = subjectCredits[subjectName]!;
      } else {
        credits = random.nextInt(3) + 2;
        subjectCredits[subjectName] = credits;
      }

      int numDays = random.nextInt(2) + 2;
      List<Map<String, String>> schedule = [];

      List<String> availableDays = List.from(possibleDays);
      for (int j = 0; j < numDays; j++) {
        String day =
            availableDays.removeAt(random.nextInt(availableDays.length));
        String time = getRandomTime();
        schedule.add({'day': day, 'time': time});
      }

      generatedSubjects.add({
        'name': subjectName,
        'schedule': schedule,
        'credits': credits,
      });
    }

    return generatedSubjects;
  }

  void searchSubject(String subject) {
    String lowerCaseSubject = subject.toLowerCase();

    setState(() {
      searchResults = subjects
          .where((element) =>
              element['name']!.toLowerCase().contains(lowerCaseSubject))
          .toList();

      if (searchResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la materia')),
        );
      }
    });
  }

  bool hasScheduleConflict(List<Map<String, String>> newSchedule) {
    for (var newClass in newSchedule) {
      String newDay = newClass['day']!;
      String newTime = newClass['time']!;

      for (var existingSubject in addedSubjects) {
        List<Map<String, String>> existingSchedule =
            existingSubject['schedule'];
        for (var existingClass in existingSchedule) {
          if (existingClass['day'] == newDay &&
              existingClass['time'] == newTime) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void addCredits(String subjectName, List<Map<String, String>> schedule, int credits) {
    // Verificar si hay un conflicto de horarios
    if (hasScheduleConflict(schedule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflicto de horarios con otra materia')),
      );
      return;
    }

    setState(() {
      if (usedCredits + credits <= creditLimit) {
        usedCredits += credits;
        addedSubjects.add(
          {
            'name': subjectName,
            'schedule': schedule,
            'credits': credits,
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Materia agregada: $subjectName')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Límite de créditos alcanzado')),
        );
      }
    });
  }

  // Nueva función para generar el horario semanal
  List<Map<String, List<String>>> generateWeeklySchedule() {
    List<Map<String, List<String>>> weeklySchedule = [];

    for (var day in possibleDays) {
      List<String> subjectsForDay = [];
      for (var subject in addedSubjects) {
        for (var schedule in subject['schedule']) {
          if (schedule['day'] == day) {
            subjectsForDay.add('${subject['name']} (${schedule['time']})');
          }
        }
      }
      weeklySchedule.add({day: subjectsForDay});
    }
    return weeklySchedule;
  }

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione materias antes de generar')),
      );
    } else {
      List<Map<String, List<String>>> weeklySchedule = generateWeeklySchedule();
      // Muestra el horario semanal en un diálogo o en la pantalla
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Horario Semanal'),
            content: SingleChildScrollView(
              child: Column(
                children: weeklySchedule.map((daySchedule) {
                  String day = daySchedule.keys.first;
                  List<String> subjects = daySchedule[day]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...subjects.map((subject) => Text(subject)).toList(),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    }
  }

  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    subjects = generateRandomSubjects(20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: true,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Menú'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Lista de materias'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu),
                label: Text('Horarios'),
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                selectedIndex = index;
                searchResults = [];
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      selectedIndex == 0
                          ? 'Inicio'
                          : selectedIndex == 1
                              ? 'Materias seleccionadas'
                              : 'Horarios',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (selectedIndex == 0) ...[
                    // Mostrar créditos usados y límite de créditos en el menú
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text('Créditos usados: $usedCredits'),
                          Text('Límite de créditos: $creditLimit'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sección para buscar materias
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar materia',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        searchSubject(subjectController.text);
                      },
                      child: const Text('Buscar'),
                    ),
                    const SizedBox(height: 20),
                    // Resultados de la búsqueda
                    if (searchResults.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resultados de la búsqueda:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ...searchResults.map((subject) {
                              return Card(
                                child: ListTile(
                                  title: Text(subject['name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Horario:'),
                                      ...subject['schedule']
                                          .map<Widget>((s) => Text(
                                              '${s['day']} - ${s['time']}'))
                                          .toList(),
                                      Text('Créditos: ${subject['credits']}'),
                                    ],
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      addCredits(
                                          subject['name'],
                                          subject['schedule'],
                                          subject['credits']);
                                    },
                                    child: const Text('Agregar'),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                  ] else if (selectedIndex == 1) ...[
                    // Mostrar las materias seleccionadas
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Materias seleccionadas:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          if (addedSubjects.isNotEmpty)
                            ...addedSubjects.map((subject) {
                              return Card(
                                child: ListTile(
                                  title: Text(subject['name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Horario:'),
                                      ...subject['schedule']
                                          .map<Widget>((s) => Text(
                                              '${s['day']} - ${s['time']}'))
                                          .toList(),
                                      Text('Créditos: ${subject['credits']}'),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          else
                            const Text('No ha seleccionado materias aún.'),
                        ],
                      ),
                    ),
                  ] else if (selectedIndex == 2) ...[
                    // Sección de horarios
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: generateSchedule,
                            child: const Text('Generar Horario'),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



