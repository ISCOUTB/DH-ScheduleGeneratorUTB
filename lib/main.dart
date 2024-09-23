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
  List<Map<String, String>> searchResults = []; // Resultados de búsqueda
  int usedCredits = 0; // Créditos usados
  final int creditLimit = 20; // Límite de créditos
  List<Map<String, String>> addedSubjects = []; // Lista de materias agregadas

  // Lista de materias dummy con horarios, incluyendo duplicados con diferentes horarios
  List<Map<String, String>> subjects = [
    {'name': 'Matemáticas', 'schedule': '8:00 AM - 10:00 AM'},
    {'name': 'Matemáticas', 'schedule': '3:00 PM - 5:00 PM'}, // Duplicado
    {'name': 'Matemáticas', 'schedule': '10:00 AM - 12:00 PM'}, // Duplicado
    {'name': 'Física', 'schedule': '10:00 AM - 12:00 PM'},
    {'name': 'Física', 'schedule': '2:00 PM - 4:00 PM'}, // Duplicado
    {'name': 'Química', 'schedule': '1:00 PM - 3:00 PM'},
    {'name': 'Química', 'schedule': '4:00 PM - 6:00 PM'}, // Duplicado
    {'name': 'Programación', 'schedule': '3:00 PM - 5:00 PM'},
    {'name': 'Programación', 'schedule': '6:00 PM - 8:00 PM'}, // Duplicado
    {'name': 'Historia', 'schedule': '5:00 PM - 7:00 PM'},
    {'name': 'Historia', 'schedule': '7:00 PM - 9:00 PM'}, // Duplicado
    {'name': 'Estadística y Probabilidad', 'schedule': '9:00 AM - 11:00 AM'},
    {
      'name': 'Estadística y Probabilidad',
      'schedule': '1:00 PM - 3:00 PM'
    }, // Duplicado
    {'name': 'Champeta', 'schedule': '2:00 PM - 4:00 PM'},
    {'name': 'Champeta', 'schedule': '4:00 PM - 6:00 PM'}, // Duplicado
  ];

  final TextEditingController subjectController = TextEditingController();

  void searchSubject(String subject) {
    // Convertir a minúsculas para la búsqueda
    String lowerCaseSubject = subject.toLowerCase();

    // Buscar si el nombre ingresado coincide con alguna materia en la lista
    setState(() {
      searchResults = subjects
          .where((element) =>
              element['name']!.toLowerCase().contains(lowerCaseSubject))
          .toList();
    });
  }

  void addCredits(String subjectName, String schedule) {
    // Verificar si la materia ya está en la lista de materias agregadas
    bool alreadyAdded =
        addedSubjects.any((subject) => subject['name'] == subjectName);

    if (alreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta materia ya está en tu horario')),
      );
      return;
    }

    // Sumar 3 créditos cada vez que el usuario agrega una materia
    setState(() {
      if (usedCredits + 3 <= creditLimit) {
        usedCredits += 3;
        addedSubjects.add({'name': subjectName, 'schedule': schedule});
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
            child: Center(
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
                              : "Horarios",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(
                      height:
                          20), // Espacio entre el título y las barras de búsqueda
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
                            Column(
                              children: searchResults.map((subject) {
                                return ElevatedButton(
                                  onPressed: () {
                                    addCredits(
                                        subject['name']!, subject['schedule']!);
                                  },
                                  child: Text(
                                    'Nombre de la materia: ${subject['name']}\nHorario: ${subject['schedule']}\n(pulse para agregar)',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }).toList(),
                            ),
                          ] else
                            Text(
                              'Resultados de búsqueda aparecerán aquí.',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          const SizedBox(height: 20),
                          // Mostrar créditos usados y el límite de créditos
                          Text(
                            'Créditos usados: $usedCredits. Límite de créditos: $creditLimit.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  if (selectedIndex ==
                      1) // Mostrar las materias agregadas en "Horarios"
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
                                  subtitle: Text(subject['schedule']!),
                                );
                              }).toList(),
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

