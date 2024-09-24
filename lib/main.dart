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

  void addCredits(
      String subjectName, List<Map<String, String>> schedule, int credits) {
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

  // Nueva función para agrupar materias por nombre
  Map<String, List<Map<String, dynamic>>> groupSubjectsByName() {
    Map<String, List<Map<String, dynamic>>> groupedSubjects = {};

    for (var subject in addedSubjects) {
      String name = subject['name'];
      if (groupedSubjects.containsKey(name)) {
        groupedSubjects[name]!.add(subject);
      } else {
        groupedSubjects[name] = [subject];
      }
    }

    return groupedSubjects;
  }

  // Función para generar combinaciones de horarios
  List<List<Map<String, dynamic>>> generateScheduleCombinations(
      Map<String, List<Map<String, dynamic>>> groupedSubjects) {
    List<List<Map<String, dynamic>>> allCombinations = [];

    // Recursión para combinar horarios
    void generateCombination(List<Map<String, dynamic>> currentCombination,
        List<List<Map<String, dynamic>>> remainingGroups) {
      if (remainingGroups.isEmpty) {
        allCombinations.add(List.from(currentCombination));
        return;
      }

      var currentGroup = remainingGroups.first;
      for (var subject in currentGroup) {
        currentCombination.add(subject);
        generateCombination(
            currentCombination, remainingGroups.sublist(1)); // Recursión
        currentCombination.removeLast();
      }
    }

    generateCombination(
      [],
      groupedSubjects.values.toList(),
    );

    return allCombinations;
  }

  // Función actualizada para generar múltiples horarios
  List<List<Map<String, List<String>>>> generateMultipleSchedules() {
    Map<String, List<Map<String, dynamic>>> groupedSubjects =
        groupSubjectsByName();
    List<List<Map<String, dynamic>>> scheduleCombinations =
        generateScheduleCombinations(groupedSubjects);

    List<List<Map<String, List<String>>>> allSchedules = [];

    for (var combination in scheduleCombinations) {
      List<Map<String, List<String>>> weeklySchedule = [];

      for (var day in possibleDays) {
        List<String> subjectsForDay = [];
        for (var subject in combination) {
          for (var schedule in subject['schedule']) {
            if (schedule['day'] == day) {
              subjectsForDay.add('${subject['name']} (${schedule['time']})');
            }
          }
        }
        weeklySchedule.add({day: subjectsForDay});
      }

      allSchedules.add(weeklySchedule);
    }

    return allSchedules;
  }

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione materias antes de generar')),
      );
    } else {
      List<List<Map<String, List<String>>>> allSchedules =
          generateMultipleSchedules();

      // Muestra los múltiples horarios en un diálogo
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Horarios Generados'),
            content: SingleChildScrollView(
              child: Column(
                children: allSchedules.map((weeklySchedule) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: weeklySchedule.map((daySchedule) {
                        String day = daySchedule.keys.first;
                        List<String> subjects = daySchedule[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(day,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...subjects
                                .map((subject) => Text(subject))
                                .toList(),
                            const SizedBox(height: 10),
                          ],
                        );
                      }).toList(),
                    ),
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
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('Buscar Materias'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list),
                label: Text('Materias Seleccionadas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Horarios'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                buildSearchSubjects(),
                buildAddedSubjects(),
                buildScheduleGenerator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchSubjects() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: subjectController,
            decoration: InputDecoration(
              labelText: 'Buscar Materia',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  searchSubject(subjectController.text);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              var subject = searchResults[index];
              String subjectName = subject['name'];
              int credits = subject['credits'];

              return ListTile(
                title: Text(subjectName),
                subtitle: Text('Créditos: $credits'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    addCredits(subjectName, subject['schedule'], credits);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildAddedSubjects() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: addedSubjects.length,
            itemBuilder: (context, index) {
              var subject = addedSubjects[index];
              String subjectName = subject['name'];
              int credits = subject['credits'];
              List<Map<String, String>> schedule = subject['schedule'];

              return ListTile(
                title: Text(subjectName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Créditos: $credits'),
                    ...schedule.map((s) => Text('${s['day']}: ${s['time']}')),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Créditos utilizados: $usedCredits / $creditLimit'),
        ),
      ],
    );
  }

  Widget buildScheduleGenerator() {
    return Center(
      child: ElevatedButton(
        onPressed: generateSchedule,
        child: const Text('Generar Horario'),
      ),
    );
  }
}



