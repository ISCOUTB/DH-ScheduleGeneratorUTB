// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Importación condicional para el servicio de plataforma.
import 'utils/platform_service_stub.dart'
    if (dart.library.html) 'utils/platform_service_web.dart';

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
      fontFamily: 'DM Sans',
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
  // Servicios
  final ApiService _apiService = ApiService();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final PlatformService _platformService = PlatformService();

  // Paleta de colores para asignar a las materias en el horario.
  final List<Color> subjectColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.lime,
    Colors.pink,
    Colors.deepOrange,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.deepPurple,
  ];

  /// Devuelve un color para una materia basado en su índice.
  Color getSubjectColor(int index) =>
      subjectColors[index % subjectColors.length];

  /// Asigna un color a una materia si aún no tiene uno.
  void _assignColorToSubject(Subject subject) {
    if (!subjectColorMap.containsKey(subject.name)) {
      // Asigna el siguiente color disponible de la paleta.
      final color =
          subjectColors[subjectColorMap.length % subjectColors.length];
      setState(() {
        subjectColorMap[subject.name] = color;
      });
    }
  }

  // --- ESTADO DE LA APLICACIÓN ---

  // Mapa de colores para las materias, asignado por nombre de materia.
  Map<String, Color> subjectColorMap = {};

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
  int _itemsPerPage = 10; // Control de paginación de horarios
  int _currentPage = 1; // Página actual de la paginación

  // Controladores de estado para la visibilidad de los paneles y overlays.
  bool isSearchOpen = false;
  bool isFilterOpen = false;
  bool isOverviewOpen = false;
  bool isMobileMenuOpen = false;
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

  // Controlador de scroll para la paginación en móvil.
  final ScrollController _mobileScrollController = ScrollController();

  late FocusNode _focusNode;
  final TransformationController _transformationController =
      TransformationController();
  Orientation? _previousOrientation;

  /// Comprueba si la plataforma es móvil.
  bool isMobile() {
    if (kIsWeb) {
      // En la web, usamos el servicio de plataforma para verificar el user agent.
      return _platformService.isMobileUserAgent();
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

    // Añadir listener al controlador de scroll móvil
    _mobileScrollController.addListener(_onMobileScroll);

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
      // En web, usar el servicio de plataforma para acceder a localStorage
      final hasSeenNotice =
          _platformService.getLocalStorage('has_seen_important_notice');
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
          content: SizedBox(
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
                backgroundColor: const Color(0xFF093AD8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Marcar que ya vió el mensaje
                if (kIsWeb) {
                  _platformService.setLocalStorage(
                      'has_seen_important_notice', 'true');
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

    _mobileScrollController.removeListener(_onMobileScroll);
    _mobileScrollController.dispose();
    super.dispose();
  }

  /// Listener para el scroll en móvil que podría usarse para lógica de paginación global si fuera necesario.
  /// Por ahora, el controlador se pasa directamente al widget de la grilla.
  void _onMobileScroll() {
    // La lógica de paginación ahora está en el ScheduleGridWidget,
    // que escucha a este mismo controlador.
    // Se puede añadir lógica aquí si otros widgets necesitaran reaccionar al scroll.
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

    // Asigna un color a la materia antes de agregarla
    _assignColorToSubject(subject);

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

      // Se puede limpiar el color del mapa si ya no hay materias con ese nombre.
      // Por simplicidad, lo dejamos para mantener consistencia si se vuelve a agregar.

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
    // Diálogo de confirmación
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar acción'),
          content: const Text(
              '¿Estás seguro de que quieres limpiar todo? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sí, limpiar todo'),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
                setState(() {
                  // Limpiar horarios generados
                  allSchedules.clear();
                  selectedScheduleIndex = null;

                  // Limpiar materias seleccionadas
                  addedSubjects.clear();
                  usedCredits = 0;

                  // Limpiar mapa de colores
                  subjectColorMap.clear();

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
                showCustomNotification(
                    context, 'Aplicación reiniciada completamente.',
                    icon: Icons.refresh, color: Colors.green);
              },
            ),
          ],
        );
      },
    );
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
          _currentPage = 1; // Resetear a la primera página
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

  // Función para abrir el tutorial
  /// Abre el enlace del tutorial en una nueva pestaña.
  void _openTutorial() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=rFi0M0gcMHM');
    if (!await launchUrl(url)) {
      showCustomNotification(context, 'No se pudo abrir el tutorial',
          icon: Icons.error, color: Colors.red);
    }
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

  /// Muestra un diálogo con la información de los creadores.
  void _showCreatorsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0051FF)),
              SizedBox(width: 10),
              Text('Acerca de', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La idea y los primeros avances de esta aplicación surgieron en la asignatura Desarrollo de Software de la Universidad Tecnológica de Bolívar, bajo la instrucción del profesor Jairo Enrique Serrano Castañeda.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Equipo del prototipo inicial:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(' • Gabriel Alejandro Mantilla Clavijo', style: TextStyle(fontSize: 13)),
                  const Text(' • Melany Marcela Saez Acuña', style: TextStyle(fontSize: 13)),
                  const Text(' • Eddy Josue Lara Cermeno', style: TextStyle(fontSize: 13)),
                  const Text(' • Julio de Jesús Denubila Vergara', style: TextStyle(fontSize: 13)),
                  const Text(' • Diego Peña Páez', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text(
                    'Equipo de desarrollo actual:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(' • Gabriel Alejandro Mantilla Clavijo', style: TextStyle(fontSize: 13)),
                  const Text(' • Melany Marcela Saez Acuña', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text(
                    'Todos los estudiantes mencionados pertenecen a la Escuela de Transformación Digital, del programa de Ingeniería en Sistemas y Computación de la Universidad Tecnológica de Bolívar (UTB).',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Abre una URL en el navegador
  Future<void> _launchURL(String urlString) async {
    // Cierra el menú móvil si está abierto
    if (isMobileMenuOpen) {
      setState(() {
        isMobileMenuOpen = false;
      });
    }
    
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showCustomNotification(
          context,
          'No se pudo abrir el enlace',
          icon: Icons.error,
          color: Colors.red,
        );
      }
    }
  }

  /// Widget para items del menú móvil
  Widget _buildMobileMenuItem(String label, VoidCallback onTap, {bool isFirst = false, bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Construye el control de selección de cantidad de horarios por página
  Widget _buildPaginationControl() {
    // Calcular total de páginas
    int totalPages = allSchedules.isEmpty ? 1 : ((allSchedules.length - 1) ~/ _itemsPerPage) + 1;
    
    // Asegurar que la página actual no exceda el total
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    
    final pageController = TextEditingController(text: _currentPage.toString());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primera página
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage = 1)
                : null,
            color: Colors.white,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 2),
          // Página anterior
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            color: Colors.white,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 6),
          // Campo de entrada para número de página
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Página',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 40,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: pageController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    final newPage = int.tryParse(value);
                    if (newPage != null && newPage >= 1 && newPage <= totalPages) {
                      setState(() => _currentPage = newPage);
                    } else {
                      pageController.text = _currentPage.toString();
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'de $totalPages',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // Página siguiente
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            color: Colors.white,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 2),
          // Última página
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage = totalPages)
                : null,
            color: Colors.white,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 12),
          // Separador vertical
          Container(
            height: 18,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 12),
          // Selector de items por página
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                dropdownColor: Colors.grey[800],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                items: [4, 8, 10].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value'),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null && newValue != _itemsPerPage) {
                    setState(() {
                      _itemsPerPage = newValue;
                      _currentPage = 1; // Resetear a la primera página
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'por página.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          // Separador vertical
          Container(
            height: 18,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 12),
          // Total de registros
          Text(
            'Horarios: ${allSchedules.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // El LayoutBuilder envuelve todo el Scaffold.
    return LayoutBuilder(builder: (context, constraints) {
      const double mobileBreakpoint = 600.0;
      final bool isMobileLayout = constraints.maxWidth < mobileBreakpoint;

      return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          // Oculta el AppBar en móvil cuando el buscador está abierto
          appBar: (isMobileLayout && isSearchOpen)
              ? null
              : AppBar(
                  backgroundColor: const Color(0xFF093AD8),
                  elevation: 0,
                  toolbarHeight: 66,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SvgPicture.asset(
                        'images/logo_utb.svg',
                        width: 183,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  actions: [
                    // Enlaces (Escritorio)
                    if (!isMobileLayout) ...[
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                        ),
                        onPressed: () => _launchURL('https://www.utb.edu.co/mi-utb/'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _NavLink(text: 'Mi UTB'),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                        ),
                        onPressed: () => _launchURL('https://sites.google.com/view/turnos-de-matricula-web-utb/turnos?authuser=0'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _NavLink(text: 'Turnos'),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                        ),
                        onPressed: () => _launchURL('https://sites.google.com/utb.edu.co/mallasutb/mallas-curriculares'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _NavLink(text: 'Mallas'),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                        ),
                        onPressed: () => _launchURL('https://sites.google.com/utb.edu.co/stuplan-electivas/electivas'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _NavLink(text: 'Electivas'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        tooltip: 'Acerca de los creadores',
                        onPressed: _showCreatorsDialog,
                      ),
                    ],
                    // Menú hamburguesa (Móvil)
                    if (isMobileLayout)
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            isMobileMenuOpen = !isMobileMenuOpen;
                          });
                        },
                      ),
                    const SizedBox(width: 16),
                  ],
                ),
          // El FAB se mueve al Stack para controlar su visibilidad con los modales.
          body: Stack(
            children: [
              // Contenido principal (móvil o escritorio)
              isMobileLayout
                  ? _buildMobileLayout(isMobileLayout)
                  : _buildDesktopLayout(isMobileLayout),

              // Botón flotante (solo en móvil y debajo de los modales)
              if (isMobileLayout)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildSpeedDial(context),
                ),

              // Contador de horarios flotante para la vista móvil.
              if (isMobileLayout && allSchedules.isNotEmpty)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${allSchedules.length} ${allSchedules.length == 1 ? "horario" : "horarios"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // --- Overlays Globales ---

              // Menú móvil desplegable
              if (isMobileLayout && isMobileMenuOpen)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    elevation: 8,
                    color: const Color(0xFF093AD8),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMobileMenuItem('Mi UTB', () => _launchURL('https://www.utb.edu.co/mi-utb/'), isFirst: true),
                          const Divider(color: Colors.white24, height: 1, thickness: 1),
                          _buildMobileMenuItem('Turnos', () => _launchURL('https://sites.google.com/view/turnos-de-matricula-web-utb/turnos?authuser=0')),
                          const Divider(color: Colors.white24, height: 1, thickness: 1),
                          _buildMobileMenuItem('Mallas', () => _launchURL('https://sites.google.com/utb.edu.co/mallasutb/mallas-curriculares')),
                          const Divider(color: Colors.white24, height: 1, thickness: 1),
                          _buildMobileMenuItem('Electivas', () => _launchURL('https://sites.google.com/utb.edu.co/stuplan-electivas/electivas'), isLast: true),
                        ],
                      ),
                    ),
                  ),
                ),
              // Indicador de carga global
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
              if (isSearchOpen)
                Stack(
                  children: [
                    const ModalBarrier(
                        dismissible: false, color: Colors.black45),
                    Center(
                      child: _areSubjectsLoaded
                          ? SearchSubjectsWidget(
                              subjectController: subjectController,
                              allSubjects: _allSubjectsList,
                              onSubjectSelected: (subjectSummary) async {
                                // Se cierra la ventana de búsqueda y mostramos el indicador de carga.
                                subjectController.clear();
                                setState(() {
                                  isSearchOpen = false;
                                  _isLoading = true;
                                });

                                try {
                                  // Se a la API con AMBOS parámetros: código y nombre.
                      
                                  final fullSubject =
                                      await _apiService.getSubjectDetails(
                                          subjectSummary.code,
                                          subjectSummary.name);

                                  // Se usa el objeto completo para añadirlo a la lista.
                                  addSubject(fullSubject);
                                } catch (e) {
                                  // Manejo de errores por si la API falla
                                  if (mounted) {
                                    showCustomNotification(context,
                                        'Error al cargar detalles: ${e.toString()}',
                                        icon: Icons.error, color: Colors.red);
                                  }
                                } finally {
                                  // Se oculta el indicador de carga.
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                }
                              },
                              closeWindow: () {
                                subjectController.clear();
                                setState(() => isSearchOpen = false);
                              },
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                    ),
                  ],
                ),
              if (isFilterOpen)
                Stack(
                  children: [
                    const ModalBarrier(
                        dismissible: false, color: Colors.black45),
                    Center(
                      child: FilterWidget(
                        closeWindow: () => setState(() => isFilterOpen = false),
                        onApplyFilters: applyFilters,
                        onClearFilters: clearFilters,
                        currentFilters: appliedFilters,
                        addedSubjects: addedSubjects,
                      ),
                    ),
                  ],
                ),
              if (isOverviewOpen && selectedScheduleIndex != null)
                Stack(
                  children: [
                    const ModalBarrier(
                        dismissible: false, color: Colors.black45),
                    Center(
                      child: ScheduleOverviewWidget(
                        schedule: allSchedules[selectedScheduleIndex!],
                        onClose: closeScheduleOverview,
                        subjectColors: subjectColorMap,
                      ),
                    ),
                  ],
                ),
            ],
          ));
    });
  }

  /// Construye el SpeedDial para la vista móvil.
  Widget _buildSpeedDial(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.search),
          label: 'Buscar Materia',
          onTap: () => setState(() => isSearchOpen = true),
        ),
        SpeedDialChild(
          child: const Icon(Icons.filter_alt),
          label: 'Realizar Filtro',
          onTap: () => setState(() => isFilterOpen = true),
        ),
        SpeedDialChild(
          child: const Icon(Icons.school),
          label: 'Tutorial',
          onTap: _openTutorial,
        ),
        SpeedDialChild(
          child: const Icon(Icons.info_outline),
          label: 'Creadores',
          onTap: _showCreatorsDialog,
        ),
        SpeedDialChild(
          child: const Icon(Icons.delete_forever, color: Colors.white),
          label: 'Limpiar Todo',
          backgroundColor: const Color(0xFF2C2A2A),
          onTap: clearSchedules,
        ),
      ],
    );
  }

  /// Construye el layout para escritorio.
  Widget _buildDesktopLayout(bool isMobileLayout) {
    final currentOrientation = MediaQuery.of(context).orientation;
    if (isMobile() &&
        _previousOrientation != null &&
        _previousOrientation != currentOrientation) {
      _transformationController.value = Matrix4.identity();
    }
    _previousOrientation = currentOrientation;

    return isMobile()
        ? InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.25,
            maxScale: 4.0,
            constrained: false,
            child: SizedBox(
              width: 1400,
              height: 900,
              child: _buildBodyContent(isMobileLayout),
            ),
          )
        : _buildBodyContent(isMobileLayout);
  }

  /// Construye el layout para móvil.
  Widget _buildMobileLayout(bool isMobileLayout) {
    return ListView(
      controller: _mobileScrollController // Asigna el controlador al ListView
      ,
      padding: const EdgeInsets.all(16.0),
      children: [
        // Se pasa el flag isMobileLayout a cada widget.
        ScheduleSortWidget(
          currentOptimizations: currentOptimizations,
          onOptimizationChanged: onOptimizationChanged,
          isEnabled: allSchedules.isNotEmpty,
          isMobileLayout: isMobileLayout,
        ),
        const SizedBox(height: 16),
        SubjectsPanel(
          isFullExpandedView: isFullExpandedView,
          addedSubjects: addedSubjects,
          usedCredits: usedCredits,
          creditLimit: creditLimit,
          subjectColors: subjectColorMap,
          onShowPanel: () => setState(() => isFullExpandedView = false),
          onHidePanel: () => setState(() => isFullExpandedView = true),
          onAddSubject: () => setState(() => isSearchOpen = true),
          onToggleExpandView: () =>
              setState(() => isExpandedView = !isExpandedView),
          onRemoveSubject: removeSubject,
          isExpandedView: isExpandedView,
          isMobileLayout: isMobileLayout,
        ),
        const SizedBox(height: 16),

        // El contador es un widget flotante global en la vista móvil.
        allSchedules.isEmpty
            ? Container(
                height: 300, // Se le da una altura mínima al placeholder
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade400, width: 2)),
                child: Center(
                    child: Text("Vista previa del horario",
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500))),
              )
            : ScheduleGridWidget(
                allSchedules: allSchedules,
                onScheduleTap: openScheduleOverview,
                isMobileLayout: isMobileLayout,
                subjectColors: subjectColorMap,
                currentPage: _currentPage,
                itemsPerPage: _itemsPerPage,
                // Esta propiedad es para arreglar el scroll.
                isScrollable: false,
                // Pasa el controlador de scroll para que la paginación funcione
                scrollController: _mobileScrollController,
              ),
      ],
    );
  }

  /// Construye el contenido principal del cuerpo de la página (escritorio).
  Widget _buildBodyContent(bool isMobileLayout) {
    return Padding(
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
                  MainActionsPanel(
                    onSearch: () => setState(() => isSearchOpen = true),
                    onFilter: () => setState(() => isFilterOpen = true),
                    onClear: clearSchedules,
                    onGenerate: _openTutorial,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double totalWidth = constraints.maxWidth;
                      double spaceBetween = 20;
                      double clearButtonWidth =
                          (totalWidth - 2 * spaceBetween) / 3;
                      double sortWidth =
                          totalWidth - clearButtonWidth - spaceBetween;

                      return Row(
                        children: [
                          SizedBox(
                            width: sortWidth,
                            child: ScheduleSortWidget(
                              currentOptimizations: currentOptimizations,
                              onOptimizationChanged: onOptimizationChanged,
                              isEnabled: allSchedules.isNotEmpty,
                              isMobileLayout: isMobileLayout,
                            ),
                          ),
                          SizedBox(width: spaceBetween),
                          SizedBox(
                            width: clearButtonWidth,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C2A2A),
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
                Expanded(
                  child: Stack(
                    children: [
                      allSchedules.isEmpty
                          ? Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.grey.shade400, width: 2)),
                              child: Center(
                                  child: Text("Vista previa del horario",
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500))),
                            )
                          : ScheduleGridWidget(
                              allSchedules: allSchedules,
                              onScheduleTap: openScheduleOverview,
                              isMobileLayout: isMobileLayout,
                              subjectColors: subjectColorMap,
                              currentPage: _currentPage,
                              itemsPerPage: _itemsPerPage,
                            ),
                      if (allSchedules.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: _buildPaginationControl(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          SubjectsPanel(
            isFullExpandedView: isFullExpandedView,
            addedSubjects: addedSubjects,
            usedCredits: usedCredits,
            creditLimit: creditLimit,
            subjectColors: subjectColorMap,
            onShowPanel: () => setState(() => isFullExpandedView = false),
            onHidePanel: () => setState(() => isFullExpandedView = true),
            onAddSubject: () => setState(() => isSearchOpen = true),
            onToggleExpandView: () =>
                setState(() => isExpandedView = !isExpandedView),
            onRemoveSubject: removeSubject,
            isExpandedView: isExpandedView,
            isMobileLayout: isMobileLayout,
          ),
        ],
      ),
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

/// Widget para enlaces de navegación con efecto hover
class _NavLink extends StatefulWidget {
  final String text;

  const _NavLink({required this.text});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Text(
        widget.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
          decorationColor: Colors.white,
          decorationThickness: 2,
        ),
      ),
    );
  }
}
