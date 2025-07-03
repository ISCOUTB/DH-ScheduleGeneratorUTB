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

void main() {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class WebScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      routes: {
        '/': (context) => const MyHomePage(title: 'Generador de Horarios UTB'),
        '/auth': (context) => const AuthCallbackPage(),
      },
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
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService(); // Instancia de ApiService

  // Paleta de colores igual a la del horario
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

  // Función para obtener el color de una materia según su índice
  Color getSubjectColor(int index) {
    return subjectColors[index % subjectColors.length];
  }

  List<Subject> addedSubjects = [];
  int usedCredits = 0;
  final int creditLimit = 20;
  final TextEditingController subjectController = TextEditingController();

  // --- ESTADO PARA ALMACENAR LA LISTA DE MATERIAS ---
  List<SubjectSummary> _allSubjectsList = [];
  bool _areSubjectsLoaded = false;

  List<List<ClassOption>> allSchedules = [];
  int? selectedScheduleIndex;

  bool isSearchOpen = false;
  bool isFilterOpen = false;
  bool isOverviewOpen = false;
  bool isExpandedView = false;
  bool isFullExpandedView = false;
  bool _isLoading = false;

  Map<String, dynamic> appliedFilters = {};
  late FocusNode _focusNode;

  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();

    if (!_authService.isUserLoggedIn()) {
      _authService.login();
      return;
    }

    // --- CARGAMOS LAS MATERIAS AL INICIAR LA PÁGINA ---
    _loadAllSubjects();

    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // --- FUNCIÓN PARA CARGAR LAS MATERIAS UNA SOLA VEZ ---
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

  void generateSchedule() async {
    if (addedSubjects.isEmpty) {
      showCustomNotification(context, 'No hay materias seleccionadas',
          icon: Icons.error, color: Colors.red);
      return;
    }

    setState(() {
      _isLoading = true; // Inicia la carga
    });

    try {
      final apiService = ApiService();
      final horariosValidos = await apiService.generateSchedules(
        subjects: addedSubjects,
        filters: appliedFilters,
        creditLimit: creditLimit,
      );

      if (horariosValidos.isEmpty) {
        showCustomNotification(context, 'No se encontraron horarios válidos',
            icon: Icons.info, color: Colors.red);
      } else {
        setState(() {
          allSchedules = horariosValidos;
          selectedScheduleIndex = null;
        });
      }
    } catch (e) {
      showCustomNotification(context, 'Error: ${e.toString()}',
          icon: Icons.error, color: Colors.red);
    } finally {
      setState(() {
        _isLoading = false; // Finaliza la carga
      });
    }
  }

  void clearSchedules() {
    setState(() {
      allSchedules.clear();
      selectedScheduleIndex = null;
    });
    showCustomNotification(context, 'Horarios generados eliminados',
        icon: Icons.info, color: Colors.green);
  }

  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      appliedFilters = filters;
      isFilterOpen = false;
    });
  }

  void openScheduleOverview(int index) {
    setState(() {
      selectedScheduleIndex = index;
      isOverviewOpen = true;
    });
  }

  void closeScheduleOverview() {
    setState(() {
      isOverviewOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authService.getUserNameFromToken();
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isExpandedView)
                        MainActionsPanel(
                          onSearch: () => setState(() => isSearchOpen = true),
                          onFilter: () => setState(() => isFilterOpen = true),
                          onClear: clearSchedules,
                          onGenerate: generateSchedule,
                        ),
                      Expanded(
                        child: allSchedules.isEmpty
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
                                onScheduleTap: openScheduleOverview),
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
        // --- Overlay de Carga ---
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

        // --- Buscar materia ---
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
                        onSubjectSelected: (subjectSummary) {
                          // 3. Al seleccionar, creamos un objeto Subject completo
                          final subjectToAdd = Subject(
                            code: subjectSummary.code,
                            name: subjectSummary.name,
                            credits: subjectSummary.credits,
                            classOptions: [], // Lista vacía, no se necesita aquí
                          );
                          addSubject(subjectToAdd);
                          setState(() => isSearchOpen = false);
                        },
                        closeWindow: () => setState(() => isSearchOpen = false),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ],
          ),

        // --- Filtro ---
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
                onApplyFilters: applyFilters,
                currentFilters: appliedFilters,
                addedSubjects: addedSubjects,
              ),
            ],
          ),

        // --- Vista de Horario ---
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
