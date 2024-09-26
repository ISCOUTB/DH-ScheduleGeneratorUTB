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
    setState(() {
      // Verifica si la materia ya ha sido añadida
      bool alreadyAdded =
          addedSubjects.any((subject) => subject['name'] == subjectName);

      if (alreadyAdded) {
        // Añade nuevamente la materia pero sin sumar créditos
        addedSubjects.add(
          {
            'name': subjectName,
            'schedule': schedule,
            'credits': credits, // Mantén los créditos originales
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Materia añadida nuevamente: $subjectName')),
        );
      } else {
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
      }
    });
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
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    addCredits(subjectName, schedule, credits);
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
        onPressed: () {
          ScheduleGenerator generator = ScheduleGenerator(addedSubjects);
          List<List<Map<String, List<String>>>> allSchedules =
              generator.generateMultipleSchedules();

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
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                                      .map((subject) => Text('• $subject'))
                                      .toList(),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          );
        },
        child: const Text('Generar Horario'),
      ),
    );
  }

  String getRandomTime() {
    Random random = Random();
    int startHour =
        random.nextInt(10) + 8; // Rango de horas entre 08:00 y 17:00
    int duration = random.nextInt(3) + 1; // Duración entre 1 y 3 horas
    int endHour = startHour + duration;

    // Ajusta si el rango de tiempo excede las 18:00 horas
    if (endHour > 18) {
      endHour = 18;
      startHour = endHour - duration;
    }

    // Formato de tiempo HH:MM con minutos fijos (00 para inicio y 50 para fin)
    String startTime = '${startHour.toString().padLeft(2, '0')}:00';
    String endTime = '${endHour.toString().padLeft(2, '0')}:50';

    return '$startTime - $endTime';
  }
}

class ScheduleGenerator {
  final List<Map<String, dynamic>> addedSubjects;

  ScheduleGenerator(this.addedSubjects);

  List<List<Map<String, List<String>>>> generateMultipleSchedules() {
    Random random = Random();
    int numSchedules = random.nextInt(3) + 2;

    List<List<Map<String, List<String>>>> allSchedules = [];

    for (int i = 0; i < numSchedules; i++) {
      List<Map<String, List<String>>> weeklySchedule = [];

      for (String day in [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado'
      ]) {
        List<String> subjects = [];

        for (var subject in addedSubjects) {
          List<Map<String, String>> schedule = subject['schedule'];

          for (var s in schedule) {
            if (s['day'] == day) {
              subjects.add('${subject['name']} - ${s['time']}');
            }
          }
        }

        weeklySchedule.add({day: subjects});
      }

      allSchedules.add(weeklySchedule);
    }

    return allSchedules;
  }
}




