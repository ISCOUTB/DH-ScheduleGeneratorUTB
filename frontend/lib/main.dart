// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'models/subject.dart';
import 'models/subject_summary.dart';
import 'models/class_option.dart';
import 'widgets/search_widget.dart';
import 'widgets/schedule_grid_widget.dart';
import 'widgets/filter_widget.dart';
import 'pages/auth_callback_page.dart';
import 'package:url_strategy/url_strategy.dart';
import 'widgets/user_menu_button.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'widgets/subjects_panel.dart';
import 'widgets/main_actions_panel.dart';
import 'widgets/schedule_overview_widget.dart';

/// Punto de entrada principal de la aplicación.
void main() {
  setPathUrlStrategy(); // Configura la estrategia de URL para web, eliminando el #.
  WidgetsFlutterBinding.ensureInitialized();
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
        '/auth': (context) =>
            const AuthCallbackPage(), // Página de callback para autenticación.
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
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService(); // Instancia de ApiService

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
  int? selectedScheduleIndex; // Índice del horario seleccionado para la vista detallada.

  // Controladores de estado para la visibilidad de los paneles y overlays.
  bool isSearchOpen = false;
  bool isFilterOpen = false;
  bool isOverviewOpen = false;
  bool isExpandedView = false; // Controla la vista expandida del panel de materias.
  bool isFullExpandedView = false; // Controla si el panel lateral está oculto.
  bool _isLoading = false; // Controla la visibilidad del indicador de carga.

  // Filtros aplicados por el usuario.
  Map<String, dynamic> appliedFilters = {}; // Para mantener el estado de la UI de filtros.
  Map<String, dynamic> apiFiltersForGeneration = {}; // Para enviar a la API.
  late FocusNode _focusNode;

  /// Comprueba si la plataforma es móvil.
  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();

    // Redirige al login si el usuario no está autenticado.
    if (!_authService.isUserLoggedIn()) {
      _authService.login();
      return;
    }

    // Carga la lista de todas las materias al iniciar.
    _loadAllSubjects();

    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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
  }

  /// Elimina una materia de la lista de seleccionadas.
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

  /// Limpia la lista de horarios generados.
  void clearSchedules() {
    setState(() {
      allSchedules.clear();
      selectedScheduleIndex = null;
    });
    showCustomNotification(
        context, 'Los horarios generados han sido limpiados.',
        icon: Icons.info, color: Colors.green);
  }

  /// Aplica los filtros seleccionados y regenera los horarios si hay materias.
  void applyFilters(
      Map<String, dynamic> stateFilters, Map<String, dynamic> apiFilters) {
    setState(() {
      // Guardamos los filtros para mantener el estado de la UI
      appliedFilters = stateFilters;
      // Guardamos los filtros formateados para la API
      apiFiltersForGeneration = apiFilters;
      isFilterOpen = false;
    });

    // Si hay materias, generamos el horario con los filtros listos para la API
    if (addedSubjects.isNotEmpty) {
      generateSchedule(); // Ya no se necesita pasar el parámetro
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
      // --- LLAMADA CORREGIDA ---
      // Ahora coincide con la firma de ApiService
      final schedules = await _apiService.generateSchedules(
        subjects: addedSubjects, // Corregido
        filters: apiFiltersForGeneration,
        creditLimit: creditLimit, // Corregido
      );

      if (mounted) {
        setState(() {
          allSchedules = schedules;
          _isLoading = false;
        });
        if (schedules.isEmpty) {
          showCustomNotification(
              context, 'No se encontraron horarios con los filtros aplicados.',
              icon: Icons.info, color: Colors.orange);
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

  /// Abre el overlay con la vista detallada de un horario específico.
  void openScheduleOverview(int index) {
    setState(() {
      selectedScheduleIndex = index;
      isOverviewOpen = true;
    });
  }

  /// Cierra el overlay de la vista detallada del horario.
  void closeScheduleOverview() {
    setState(() {
      isOverviewOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authService.getUserNameFromToken();
    // Stack principal para poder mostrar overlays sobre la pantalla principal.
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0051FF),
            elevation: 0,
            title: Row(
              children: [
                UserMenuButton(
                    userName: userName,
                    onLogout: _authService.logout), // Usa el servicio
                const SizedBox(width: 12),
                const Text("Generador de Horarios",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contenido principal (acciones y grilla de horario).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isExpandedView)
                        MainActionsPanel(
                          onSearch: () => setState(() => isSearchOpen = true),
                          onFilter: () => setState(() => isFilterOpen = true),
                          onClear: clearSchedules,
                          onGenerate:
                              generateSchedule, // Esto ahora es correcto
                        ),
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
        ),
        // --- Overlays ---

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
                          subjectController.clear(); // Limpia el campo de texto.
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
                          subjectController.clear(); // Limpia el campo de texto también al cerrar.
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
              AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black45),
              ),
              FilterWidget(
                closeWindow: () => setState(() => isFilterOpen = false),
                // --- ACTUALIZAR LA LLAMADA PARA QUE COINCIDA ---
                onApplyFilters: applyFilters,
                currentFilters: appliedFilters,
                addedSubjects: addedSubjects,
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
