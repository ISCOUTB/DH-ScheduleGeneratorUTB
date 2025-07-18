// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'models/subject.dart';
import 'models/subject_summary.dart';
import 'models/class_option.dart';
import 'widgets/search_widget.dart';
import 'widgets/schedule_grid_widget.dart';
import 'widgets/filter_widget.dart';
import 'package:url_strategy/url_strategy.dart';
import 'services/api_service.dart';
import 'widgets/subjects_panel.dart';
import 'widgets/main_actions_panel.dart';
import 'widgets/schedule_overview_widget.dart';
import 'widgets/schedule_sort_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase para que funcione correctamente
  // para cualquier plataforma (web, android, ios).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Comportamiento de scroll personalizado para la web que elimina el "glow" de sobredescroll.
class WebScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

/// Widget raíz de la aplicación.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define el tema global de la aplicación.
    final ThemeData theme = ThemeData(
      primarySwatch: Colors.indigo,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
        accentColor: Colors.amber,
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'Generador de Horarios UTB',
      scrollBehavior: WebScrollBehavior(),
      theme: theme,
      // Define las rutas de navegación de la aplicación.
      routes: {
        '/': (context) => const MyHomePage(title: 'Generador de Horarios UTB'),
      },
    );
  }
}

/// Página principal de la aplicación que contiene la lógica y la interfaz de usuario.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// Estado de [MyHomePage]. Contiene toda la lógica de la interfaz.
class _MyHomePageState extends State<MyHomePage> {
  // Servicios para la autenticación y la comunicación con la API.
  // final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService(); // Instancia de ApiService
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Paleta de colores para asignar a las materias en el horario.
  final List<Color> subjectColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.indigoAccent,
    Colors.pinkAccent,
    Colors.limeAccent,
    Colors.deepOrangeAccent,
    Colors.lightBlueAccent,
    Colors.lightGreenAccent,
    Colors.deepPurpleAccent,
  ];

  /// Devuelve un color para una materia basado en su índice.
  Color getSubjectColor(int index) {
    return subjectColors[index % subjectColors.length];
  }

  // --- ESTADO DE LA APLICACIÓN ---

  // Materias seleccionadas por el usuario.
  List<Subject> addedSubjects = [];
  int usedCredits = 0;
  final int creditLimit = 20;
  final TextEditingController subjectController = TextEditingController();

  // Lista completa de materias disponibles para búsqueda.
  List<SubjectSummary> _allSubjectsList = [];
  bool _areSubjectsLoaded = false; // Indica si las materias han sido cargadas.

  // Horarios generados por la API.
  List<List<ClassOption>> allSchedules = [];
  int?
      selectedScheduleIndex; // Índice del horario seleccionado para la vista detallada.

  // Controladores de estado para la visibilidad de los paneles y overlays.
  bool isSearchOpen = false;
  bool isFilterOpen = false;
  bool isOverviewOpen = false;
  bool isExpandedView =
      false; // Controla la vista expandida del panel de materias.
  bool isFullExpandedView = false; // Controla si el panel lateral está oculto.
  bool _isLoading = false; // Controla la visibilidad del indicador de carga.

  // Filtros aplicados por el usuario.
  Map<String, dynamic> appliedFilters =
      {}; // Para mantener el estado de la UI de filtros.
  Map<String, dynamic> apiFiltersForGeneration = {}; // Para enviar a la API.

  // Opciones de optimización de horarios
  Map<String, dynamic> currentOptimizations = {
    'optimizeGaps': false,
    'optimizeFreeDays': false,
  };

  // Control para mostrar el mensaje de advertencia solo la primera vez
  bool _showWelcomeDialog = true;

  late FocusNode _focusNode;
  final TransformationController _transformationController =
      TransformationController();
  Orientation? _previousOrientation;

  /// Comprueba si la plataforma es móvil.
  bool isMobile() {
    if (kIsWeb) {
      // En la web, la forma más fiable de diferenciar es a través del User Agent del navegador.
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      // Buscamos palabras clave comunes que indican que es un navegador móvil.
      return userAgent.contains('mobi') ||
          userAgent.contains('android') ||
          userAgent.contains('iphone') ||
          userAgent.contains('ipad');
    } else {
      // Mantenemos la lógica original para compilaciones nativas (Android/iOS).
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }
  }

  @override
  void initState() {
    super.initState();

    // Carga la lista de todas las materias al iniciar.
    _loadAllSubjects();

    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      // Verificar si se debe mostrar el diálogo de advertencia
      _checkAndShowImportantNotice();
    });
  }

  /// Carga la lista de resúmenes de materias desde la API.
  void _loadAllSubjects() async {
    try {
      final subjects = await _apiService.getAllSubjects();
      if (mounted) {
        setState(() {
          _allSubjectsList = subjects;
          _areSubjectsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
            context, 'Error al cargar la lista de materias: ${e.toString()}',
            icon: Icons.error, color: Colors.red);
      }
    }
  }

  /// Verifica si se debe mostrar el mensaje de advertencia y lo muestra si es necesario
  void _checkAndShowImportantNotice() {
    if (kIsWeb) {
      // En web, usar localStorage
      final hasSeenNotice =
          html.window.localStorage['has_seen_important_notice'];
      if (hasSeenNotice == null || hasSeenNotice != 'true') {
        _showImportantNoticeDialog();
      }
    } else {
      // En móvil, mostrar solo una vez por sesión
      if (_showWelcomeDialog) {
        _showImportantNoticeDialog();
      }
    }
  }

  /// Muestra el diálogo de advertencia importante al abrir la aplicación
  void _showImportantNoticeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.red.shade600,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'IMPORTANTE',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: 400,
            child: Text(
              'Antes de tomar decisiones basadas en un horario generado, te recomendamos verificar la información directamente en Banner, ya que este generador es una herramienta de apoyo y la fuente oficial de horarios, NRC y disponibilidad es Banner.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0051FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Marcar que ya vió el mensaje
                if (kIsWeb) {
                  html.window.localStorage['has_seen_important_notice'] =
                      'true';
                } else {
                  setState(() {
                    _showWelcomeDialog = false;
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Añade una materia a la lista de seleccionadas, validando créditos y duplicados.
  void addSubject(Subject subject) {
    if (addedSubjects
        .any((s) => s.code == subject.code && s.name == subject.name)) {
      showCustomNotification(context, 'La materia ya ha sido agregada',
          icon: Icons.info, color: Colors.green);
      return;
    }

    int newTotalCredits = usedCredits + subject.credits;
    if (newTotalCredits > creditLimit) {
      showCustomNotification(context, 'Limite de creditos alcanzados',
          icon: Icons.info, color: Colors.red);
      return;
    }

    // Evento de Analytics
    analytics.logEvent(
      name: 'add_subject',
      parameters: {
        'subject_code': subject.code,
        'subject_name': subject.name,
        'credits': subject.credits,
      },
    );

    setState(() {
      usedCredits = newTotalCredits;
      addedSubjects.add(subject);

      if (usedCredits > 18) {
        showCustomNotification(
            context, 'Advertencia: Ha excedido los 18 creditos',
            icon: Icons.info, color: Colors.green);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia agregada: ${subject.name}')),
      );
    });

    // Generar horarios automáticamente al agregar una materia
    generateSchedule();
  }

  /// Elimina una materia de la lista de seleccionadas y limpia sus filtros asociados.
  void removeSubject(Subject subject) {
    final subjectCode = subject.code;

    setState(() {
      // 1. Limpiar los filtros asociados a esta materia

      // Limpia de los filtros de estado de la UI
      if (appliedFilters['professors'] != null &&
          appliedFilters['professors'] is Map) {
        (appliedFilters['professors'] as Map).remove(subjectCode);
      }

      // Limpia de los filtros que se envían a la API
      if (apiFiltersForGeneration['include_professors'] != null &&
          apiFiltersForGeneration['include_professors'] is Map) {
        (apiFiltersForGeneration['include_professors'] as Map)
            .remove(subjectCode);
      }
      if (apiFiltersForGeneration['exclude_professors'] != null &&
          apiFiltersForGeneration['exclude_professors'] is Map) {
        (apiFiltersForGeneration['exclude_professors'] as Map)
            .remove(subjectCode);
      }

      // 2. Eliminar la materia y actualizar los créditos.
      addedSubjects
          .removeWhere((s) => s.code == subject.code && s.name == subject.name);
      usedCredits -= subject.credits;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia eliminada: ${subject.name}')),
      );
    });

    // 3. Regenerar horarios.
    if (addedSubjects.isNotEmpty) {
      generateSchedule();
    } else {
      setState(() {
        allSchedules.clear();
        selectedScheduleIndex = null;
      });
    }
  }

  /// Limpia completamente el estado de la aplicación.
  void clearSchedules() {
    setState(() {
      // Limpiar horarios generados
      allSchedules.clear();
      selectedScheduleIndex = null;

      // Limpiar materias seleccionadas
      addedSubjects.clear();
      usedCredits = 0;

      // Limpiar filtros aplicados
      appliedFilters.clear();
      apiFiltersForGeneration.clear();

      // Resetear opciones de optimización
      currentOptimizations = {
        'optimizeGaps': false,
        'optimizeFreeDays': false,
      };

      // Cerrar todos los paneles abiertos
      isSearchOpen = false;
      isFilterOpen = false;
      isOverviewOpen = false;
      isExpandedView = false;
      isFullExpandedView = false;

      // Limpiar el controlador de búsqueda
      subjectController.clear();
    });
    showCustomNotification(context, 'Aplicación reiniciada completamente.',
        icon: Icons.refresh, color: Colors.green);
  }


  /// Limpia solo los filtros aplicados y regenera los horarios.
  void clearFilters() {
    setState(() {
      appliedFilters.clear();
      // Resetea los filtros de la API, manteniendo solo las optimizaciones.
      apiFiltersForGeneration = {
        ...currentOptimizations,
      };
    });

    // Si hay materias, regeneramos el horario sin los filtros.
    if (addedSubjects.isNotEmpty) {
      generateSchedule();
    }
  }

  /// Aplica los filtros seleccionados y regenera los horarios si hay materias.
  void applyFilters(
      Map<String, dynamic> stateFilters, Map<String, dynamic> apiFilters) {
    setState(() {
      // Guardamos los filtros para mantener el estado de la UI
      appliedFilters = stateFilters;
      // Combinamos los filtros de la API con las optimizaciones actuales
      apiFiltersForGeneration = {
        ...apiFilters,
        ...currentOptimizations,
      };
      isFilterOpen = false;
    });

    // Si hay materias, regeneramos automáticamente el horario con los filtros
    if (addedSubjects.isNotEmpty) {
      generateSchedule();
    }
  }

  /// Llama a la API para generar los horarios con las materias y filtros actuales.
  Future<void> generateSchedule() async {
    if (addedSubjects.isEmpty) {
      showCustomNotification(context, 'Por favor, agrega al menos una materia.',
          icon: Icons.warning, color: Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Mapea las materias agregadas a sus códigos para enviarlas a la API.
      final schedules = await _apiService.generateSchedules(
        subjects: addedSubjects, // Lista de materias seleccionadas
        // Combina filtros aplicados por el usuario con optimizaciones actuales
        filters: {
          ...apiFiltersForGeneration,
          ...currentOptimizations,
        },
        creditLimit: creditLimit, // Límite de créditos para la generación
      );

      if (mounted) {
        setState(() {
          allSchedules = schedules;
          _isLoading = false;
        });
        if (schedules.isEmpty) {
          // Determinar el mensaje apropiado según si hay filtros aplicados
          String message;
          IconData icon;
          Color color;

          bool hasFilters = apiFiltersForGeneration.isNotEmpty &&
              apiFiltersForGeneration.values.any(
                  (value) => value != false && value != null && value != '');

          if (hasFilters) {
            message =
                'No se encontraron horarios con los filtros aplicados. Intenta relajar algunos filtros; pero si lo que hiciste fue agregar una materia nueva, posiblemente se trate de un cruce de horario.';
            icon = Icons.filter_alt_off;
            color = Colors.orange;
          } else {
            message =
                'No se pueden generar horarios con estas materias. Puede haber cruces de horarios o incompatibilidades.';
            icon = Icons.schedule_send;
            color = Colors.red.shade600;
          }

          showCustomNotification(context, message, icon: icon, color: color);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showCustomNotification(
            context, 'Error al generar horarios: ${e.toString()}',
            icon: Icons.error, color: Colors.red);
      }
    }
  }

  /// Función placeholder para el botón "Generar Horarios" (sin funcionalidad)
  void generateScheduleButtonAction() {
    // Botón sin funcionalidad por ahora - se le dará otro uso más adelante
    showCustomNotification(context, 'Funcionalidad en desarrollo...',
        icon: Icons.info, color: Colors.blue);
  }

  /// Abre el overlay con la vista detallada de un horario específico.
  void openScheduleOverview(int index) {
    setState(() {
      selectedScheduleIndex = index;
      isOverviewOpen = true;
    });
  }

  // Cierra el overlay de la vista detallada del horario.
  void closeScheduleOverview() {
    setState(() {
      isOverviewOpen = false;
    });
  }

  /// Maneja los cambios en las opciones de optimización de horarios.
  void onOptimizationChanged(Map<String, dynamic> optimizations) {
    setState(() {
      currentOptimizations = optimizations;
      // También actualizamos los filtros de la API para incluir las optimizaciones
      apiFiltersForGeneration = {
        ...apiFiltersForGeneration,
        ...optimizations,
      };
    });

    // Si hay horarios generados, los regeneramos con las nuevas optimizaciones
    if (allSchedules.isNotEmpty && addedSubjects.isNotEmpty) {
      generateSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detecta el cambio de orientación y resetea el InteractiveViewer si es necesario.
    final currentOrientation = MediaQuery.of(context).orientation;
    if (isMobile() &&
        _previousOrientation != null &&
        _previousOrientation != currentOrientation) {
      _transformationController.value =
          Matrix4.identity(); // Resetea el zoom y pan
    }
    _previousOrientation = currentOrientation;

    // Stack principal para poder mostrar overlays sobre la pantalla principal.
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0051FF),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF8CFF62),
              child: const Icon(
                Icons.calendar_today,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Generador de Horarios UTB",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
      body: isMobile()
          ? InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.25,
              maxScale: 4.0,
              constrained:
                  false, // Permite que el contenido sea más grande que la pantalla
              child: SizedBox(
                width: 1400, // Ancho fijo para simular una vista de escritorio
                height: 900, // Altura fija
                child: _buildBodyContent(),
              ),
            )
          : _buildBodyContent(),
    );
  }

  /// Construye el contenido principal del cuerpo de la página.
  Widget _buildBodyContent() {
    // El contenido principal ahora se envuelve en un Stack para manejar los overlays internamente.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenido principal (acciones y grilla de horario).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isExpandedView) ...[
                      // Primera fila: Buscar, Filtrar, Generar
                      MainActionsPanel(
                        onSearch: () => setState(() => isSearchOpen = true),
                        onFilter: () => setState(() => isFilterOpen = true),
                        onClear: clearSchedules,
                        onGenerate:
                            generateScheduleButtonAction, // Ahora sin funcionalidad real
                      ),

                      const SizedBox(height: 20),

                      // Segunda fila: Ordenar Horarios por + Limpiar Todo
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculamos el ancho disponible
                          double totalWidth = constraints.maxWidth;
                          double spaceBetween = 20;
                          double clearButtonWidth =
                              (totalWidth - 2 * spaceBetween) /
                                  3; // Mismo ancho que un botón de arriba
                          double sortWidth =
                              totalWidth - clearButtonWidth - spaceBetween;

                          return Row(
                            children: [
                              // Widget de ordenamiento (ocupa espacio de 2 botones + espacio entre ellos)
                              SizedBox(
                                width: sortWidth,
                                child: ScheduleSortWidget(
                                  currentOptimizations: currentOptimizations,
                                  onOptimizationChanged: onOptimizationChanged,
                                  isEnabled: allSchedules.isNotEmpty,
                                ),
                              ),
                              SizedBox(width: spaceBetween),
                              // Botón Limpiar Todo (mismo ancho que botón de arriba)
                              SizedBox(
                                width: clearButtonWidth,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF2F2F),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: clearSchedules,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Limpiar todo",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.refresh,
                                          color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Muestra la grilla de horarios o un mensaje de vista previa.
                    Expanded(
                      //Envolver con un Stack para superponer el contador.
                      child: Stack(
                        children: [
                          allSchedules.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7FA),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: Colors.grey.shade400,
                                          width: 2)),
                                  child: Center(
                                      child: Text("Vista previa del horario",
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500))),
                                )
                              : ScheduleGridWidget(
                                  allSchedules: allSchedules,
                                  onScheduleTap: openScheduleOverview),

                          // Widget para mostrar el contador de horarios generados.
                          if (allSchedules.isNotEmpty)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${allSchedules.length} ${allSchedules.length == 1 ? "horario generado" : "horarios generados"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Panel lateral: modo normal o encogido
              const SizedBox(width: 32),
              SubjectsPanel(
                isFullExpandedView: isFullExpandedView,
                addedSubjects: addedSubjects,
                usedCredits: usedCredits,
                creditLimit: creditLimit,
                getSubjectColor: getSubjectColor,
                onShowPanel: () => setState(() => isFullExpandedView = false),
                onHidePanel: () => setState(() => isFullExpandedView = true),
                onAddSubject: () => setState(() => isSearchOpen = true),
                onToggleExpandView: () =>
                    setState(() => isExpandedView = !isExpandedView),
                onRemoveSubject: removeSubject,
                isExpandedView: isExpandedView,
              ),
            ],
          ),
        ),

        // --- Overlays ---
        // Se renderizan aquí para estar dentro del InteractiveViewer en móvil.

        // Overlay de carga mientras se generan los horarios.
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Generando horarios...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Overlay para buscar y añadir materias.
        if (isSearchOpen)
          Stack(
            children: [
              const ModalBarrier(dismissible: false, color: Colors.black45),
              Center(
                child: _areSubjectsLoaded
                    ? SearchSubjectsWidget(
                        subjectController: subjectController,
                        allSubjects:
                            _allSubjectsList, // Pasamos la lista de resúmenes
                        onSubjectSelected: (subjectSummary) async {
                          subjectController
                              .clear(); // Limpia el campo de texto.
                          setState(() {
                            isSearchOpen =
                                false; // Cierra la búsqueda inmediatamente
                            _isLoading = true; // Muestra el indicador de carga
                          });

                          try {
                            // 1. Llama a la API para obtener los detalles completos
                            final fullSubject = await _apiService
                                .getSubjectDetails(subjectSummary.code);

                            // 2. Llama a la función addSubject original con el objeto completo
                            addSubject(fullSubject);
                          } catch (e) {
                            showCustomNotification(context,
                                'Error al cargar detalles: ${e.toString()}',
                                icon: Icons.error, color: Colors.red);
                          } finally {
                            setState(() {
                              _isLoading =
                                  false; // Oculta el indicador de carga
                            });
                          }
                        },
                        closeWindow: () {
                          subjectController
                              .clear(); // Limpia el campo de texto también al cerrar.
                          setState(() => isSearchOpen = false);
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ],
          ),

        // Overlay para configurar los filtros.
        if (isFilterOpen)
          Stack(
            children: [
              const ModalBarrier(dismissible: false, color: Colors.black45),
              Center(
                child: FilterWidget(
                  closeWindow: () => setState(() => isFilterOpen = false),
                  onApplyFilters: applyFilters,
                  onClearFilters:
                      clearFilters, // Limpia solo los filtros aplicados
                  currentFilters: appliedFilters,
                  addedSubjects: addedSubjects,
                ),
              ),
            ],
          ),

        // Overlay para mostrar la vista detallada de un horario.
        if (isOverviewOpen && selectedScheduleIndex != null)
          Stack(
            children: [
              const ModalBarrier(dismissible: false, color: Colors.black45),
              Center(
                child: ScheduleOverviewWidget(
                  schedule: allSchedules[selectedScheduleIndex!],
                  onClose: closeScheduleOverview,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Muestra una notificación personalizada en un diálogo.
void showCustomNotification(BuildContext context, String message,
    {IconData? icon, Color? color}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: color ?? const Color(0xFF1ABC7B), size: 32),
            if (icon != null) const SizedBox(width: 16),
            Flexible(
                child: Text(message,
                    style:
                        const TextStyle(fontSize: 18, color: Colors.black87))),
          ],
        ),
      ),
    ),
  );
}
