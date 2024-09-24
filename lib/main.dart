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
  int selectedIndex = 0; // Para rastrear el índice seleccionado en el riel
  List<Map<String, dynamic>> searchResults = []; // Resultados de búsqueda
  int usedCredits = 0; // Créditos usados
  final int creditLimit = 20; // Límite de créditos
  List<Map<String, dynamic>> addedSubjects = []; // Lista de materias agregadas

  final TextEditingController subjectController = TextEditingController();

  // Lista de posibles nombres de materias
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

  // Lista de posibles días
  final List<String> possibleDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  // Mapa para almacenar créditos por nombre de materia
  final Map<String, int> subjectCredits = {};

  // Función para generar una hora aleatoria en formato de 24 horas.
  String getRandomTime() {
    Random random = Random();
    int hour = random.nextInt(12) + 8; // Horas entre 8:00 y 20:00
    int minuteStart = 0; // Minuto de inicio siempre es 00
    int endHour = hour + 2; // Clases de 2 horas
    int minuteEnd = 50; // Minuto final siempre es 50

    return '${hour.toString().padLeft(2, '0')}:${minuteStart.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${minuteEnd.toString().padLeft(2, '0')}';
  }

  // Función para generar una lista de materias aleatorias con créditos
  List<Map<String, dynamic>> generateRandomSubjects(int count) {
    Random random = Random();
    List<Map<String, dynamic>> generatedSubjects = [];

    for (int i = 0; i < count; i++) {
      // Seleccionar un nombre de materia al azar
      String subjectName =
          possibleSubjects[random.nextInt(possibleSubjects.length)];

      // Verificar si la materia ya tiene créditos asignados
      int credits;
      if (subjectCredits.containsKey(subjectName)) {
        credits = subjectCredits[subjectName]!; // Obtener créditos existentes
      } else {
        // Generar un número aleatorio de créditos entre 2 y 4
        credits = random.nextInt(3) + 2;
        subjectCredits[subjectName] = credits; // Asignar créditos al mapa
      }

      // Generar un número aleatorio de días para la materia (2 o 3)
      int numDays = random.nextInt(2) + 2;
      List<Map<String, String>> schedule = [];

      // Seleccionar días aleatorios sin repetir
      List<String> availableDays = List.from(possibleDays);
      for (int j = 0; j < numDays; j++) {
        String day =
            availableDays.removeAt(random.nextInt(availableDays.length));
        String time = getRandomTime();
        schedule.add({'day': day, 'time': time});
      }

      // Agregar la materia con su horario y créditos a la lista generada
      generatedSubjects.add({
        'name': subjectName,
        'schedule': schedule,
        'credits': credits, // Agregar créditos a la materia
      });
    }

    return generatedSubjects;
  }

  void searchSubject(String subject) {
    String lowerCaseSubject = subject.toLowerCase();

    // Buscar si el nombre ingresado coincide con alguna materia en la lista generada
    setState(() {
      searchResults = subjects
          .where((element) =>
              element['name']!.toLowerCase().contains(lowerCaseSubject))
          .toList();

      if (searchResults.isEmpty) {
        // Mostrar mensaje si no se encontró la materia
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la materia')),
        );
      }
    });
  }

  void addCredits(
      String subjectName, List<Map<String, String>> schedule, int credits) {
    bool alreadyAdded =
        addedSubjects.any((subject) => subject['name'] == subjectName);

    if (alreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta materia ya está en tu horario')),
      );
      return;
    }

    setState(() {
      if (usedCredits + credits <= creditLimit) {
        usedCredits += credits; // Sumar créditos de la materia agregada
        addedSubjects.add(
            {'name': subjectName, 'schedule': schedule, 'credits': credits});
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

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione materias antes de generar')),
      );
    } else {
      // Aquí puedes agregar la lógica para generar horarios
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generando horarios...')),
      );
    }
  }

  // Generar materias aleatorias al iniciar
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    subjects = generateRandomSubjects(20); // Generar 20 materias aleatorias
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
                searchResults =
                    []; // Resetear los resultados al cambiar de sección
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20), // Espacio superior
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
                  if (selectedIndex == 0) // Solo mostrar en "Inicio"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          TextField(
                            controller: subjectController,
                            decoration: const InputDecoration(
                              labelText: 'Por materia...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              searchSubject(subjectController
                                  .text); // Buscar la materia ingresada
                            },
                            child: const Text('Buscar'),
                          ),
                          const SizedBox(height: 20),
                          if (searchResults.isNotEmpty) ...[
                            // Mostrar los resultados de búsqueda con días y horarios
                            SizedBox(
                              height:
                                  300, // Altura ajustada para la lista de resultados
                              child: ListView.builder(
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  var subject = searchResults[index];
                                  return Card(
                                    child: Column(
                                      children: [
                                        Text(
                                          'Materia: ${subject['name']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        ...subject['schedule']
                                            .map<Widget>((schedule) {
                                          return Text(
                                            '${schedule['day']}: ${schedule['time']}',
                                            textAlign: TextAlign.center,
                                          );
                                        }).toList(),
                                        Text(
                                          'Créditos: ${subject['credits']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            addCredits(
                                                subject['name'],
                                                subject['schedule'],
                                                subject['credits']);
                                          },
                                          child: const Text('Agregar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else
                            Text(
                              'Resultados de búsqueda aparecerán aquí.',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          const SizedBox(height: 20),
                          Text(
                            'Créditos usados: $usedCredits. Límite de créditos: $creditLimit.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  if (selectedIndex == 1) // Mostrar las materias agregadas
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          if (addedSubjects.isEmpty)
                            const Text('No hay materias agregadas.')
                          else
                            Column(
                              children: addedSubjects.map((subject) {
                                return ListTile(
                                  title: Text(subject['name']!),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: subject['schedule']
                                        .map<Widget>((schedule) => Text(
                                              '${schedule['day']}: ${schedule['time']}',
                                            ))
                                        .toList(),
                                  ),
                                  trailing:
                                      Text('Créditos: ${subject['credits']}'),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  if (selectedIndex ==
                      2) // Mostrar solo el botón en la sección "Horarios"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: generateSchedule,
                            child: const Text('Generar Horarios'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

