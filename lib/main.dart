import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

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
  String searchResult = ''; // Para almacenar el resultado de búsqueda

  final TextEditingController careerController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController nrcController = TextEditingController();

  Future<void> searchSubject(String subject) async {
    const url =
        'https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/courseSearch/courseSearch';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Parsear el HTML
        var document = html_parser.parse(response.body);
        var courseElements = document.querySelectorAll('.course-class-name');
        bool exists =
            courseElements.any((element) => element.text.contains(subject));

        setState(() {
          searchResult = exists ? 'Materia existe' : 'Materia no existe';
        });
      } else {
        setState(() {
          searchResult = 'Error al acceder a la información.';
        });
      }
    } catch (e) {
      setState(() {
        searchResult = 'Error: $e';
      });
    }
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
                            controller: careerController,
                            decoration: const InputDecoration(
                              labelText: 'Por carrera...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: subjectController,
                            decoration: const InputDecoration(
                              labelText: 'Por materia...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: nrcController,
                            decoration: const InputDecoration(
                              labelText: 'Por NRC...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              searchSubject(subjectController.text);
                            },
                            child: const Text('Buscar'),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            searchResult.isNotEmpty
                                ? searchResult
                                : 'Resultados de búsqueda aparecerán aquí.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          const Text('Créditos utilizados: 0'), // Añadido
                          const Text('Límite de créditos: 20'), // Añadido
                        ],
                      ),
                    ),
                  if (selectedIndex == 1) // Mostrar un mensaje en "Horarios"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const Text('No hay horarios generados.'),
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
