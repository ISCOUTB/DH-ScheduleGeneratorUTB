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
  String searchResult = ''; // Para mostrar el resultado de la búsqueda
  int usedCredits = 0; // Créditos usados
  final int creditLimit = 20; // Límite de créditos

  // Lista de materias dummy con horarios
  List<Map<String, String>> subjects = [
    {'name': 'Matemáticas', 'schedule': '8:00 AM - 10:00 AM'},
    {'name': 'Física', 'schedule': '10:00 AM - 12:00 PM'},
    {'name': 'Química', 'schedule': '1:00 PM - 3:00 PM'},
    {'name': 'Programación', 'schedule': '3:00 PM - 5:00 PM'},
    {'name': 'Historia', 'schedule': '5:00 PM - 7:00 PM'},
  ];

  final TextEditingController subjectController = TextEditingController();

  void searchSubject(String subject) {
    // Buscar si el nombre ingresado coincide con alguna materia en la lista
    var foundSubject = subjects.firstWhere(
        (element) => element['name']!.toLowerCase() == subject.toLowerCase(),
        orElse: () => {});

    setState(() {
      if (foundSubject.isNotEmpty) {
        // Si se encuentra la materia, mostrar su nombre y horario
        searchResult =
            'Nombre de la materia: ${foundSubject['name']}\nHorario: ${foundSubject['schedule']}';
      } else {
        // Si no se encuentra la materia, mostrar que no se encontró
        searchResult = 'Materia no encontrada';
      }
    });
  }

  void addCredits() {
    // Sumar 3 créditos cada vez que el usuario agrega una materia
    setState(() {
      if (usedCredits + 3 <= creditLimit) {
        usedCredits += 3;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Materia agregada. Créditos usados: $usedCredits')),
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
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Horarios'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu),
                label: Text('Menú'),
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                selectedIndex = index;
                searchResult =
                    ''; // Resetear el resultado al cambiar de sección
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
                      selectedIndex == 0 ? 'Inicio' : 'Horarios',
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
                          if (searchResult.isNotEmpty) ...[
                            TextButton(
                              onPressed: () {
                                addCredits(); // Sumar créditos al agregar la materia
                              },
                              child: Text(
                                '$searchResult\n(pulse para agregar)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
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
                  if (selectedIndex == 1) // Mostrar un mensaje en "Horarios"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: const [
                          SizedBox(height: 20),
                          Text('No hay horarios generados.'),
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

