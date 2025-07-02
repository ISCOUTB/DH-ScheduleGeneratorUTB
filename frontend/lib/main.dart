// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'data/subjects_data.dart';
import 'models/subject.dart';
import 'models/class_option.dart';
import 'widgets/search_widget.dart';
import 'widgets/added_subjects_widgets.dart';
import 'widgets/schedule_grid_widget.dart';
import 'widgets/schedule_overview_widget.dart';
import 'widgets/filter_widget.dart';
import 'utils/schedule_generator.dart';
import 'pages/auth_callback_page.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:url_strategy/url_strategy.dart';
import 'widgets/user_menu_button.dart';

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

  // Función para obtener el nombre de usuario del token JWT almacenado en localStorage
  String? getUserNameFromToken() {
    final token = html.window.localStorage['id_token'];
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    final payload = parts[1];
    final normalized = base64.normalize(payload);
    final decoded = utf8.decode(base64.decode(normalized));
    final payloadMap = json.decode(decoded);

    return payloadMap['name'] ?? payloadMap['preferred_username'];
  }

  // Función para obtener el color de una materia según su índice
  Color getSubjectColor(int index) {
    return subjectColors[index % subjectColors.length];
  }

  List<Subject> addedSubjects = [];
  late Future<List<Subject>> futureSubjects;
  int usedCredits = 0;
  final int creditLimit = 20;
  final TextEditingController subjectController = TextEditingController();

  List<List<ClassOption>> allSchedules = [];
  int? selectedScheduleIndex;

  bool isSearchOpen = false;
  bool isFilterOpen = false;
  bool isOverviewOpen = false;
  bool isExpandedView = false;
  bool isFullExpandedView = false;

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

    // Verifica si el token ya está almacenado en localStorage
    print('TOKEN AL ENTRAR A HOME: ${html.window.localStorage['id_token']}');

    // Comprobamos si hay sesión activa
    final token = html.window.localStorage['id_token'];
    if (token == null) {
      _redirectToMicrosoftLogin(); // redirige automáticamente si no hay sesión
      return; // evita que siga ejecutando el resto del initState
    }

    // Si hay token, continúa con lo demás como siempre
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    futureSubjects = fetchSubjectsFromApi();
  }

  void _redirectToMicrosoftLogin() {
    const tenantId = '1ae0c106-3b63-42fd-9149-52d736399d5a';
    const clientId = 'de6b5a9b-9cdf-4484-ba51-aa45bf431e52';
    const redirectUri = 'http://localhost:5173/auth';

    final authUrl =
        'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize'
        '?client_id=$clientId'
        '&response_type=id_token'
        '&redirect_uri=$redirectUri'
        '&response_mode=fragment'
        '&scope=openid email profile'
        '&nonce=abc123'
        '&state=xyz456';

    html.window.location.href = authUrl;
  }

  void _logout() {
    html.window.localStorage.remove('id_token');
    _redirectToMicrosoftLogin();
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

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      showCustomNotification(context, 'No hay materias seleccionadas',
          icon: Icons.error, color: Colors.red);
      return;
    }

    List<List<ClassOption>> horariosValidos =
        obtenerHorariosValidos(addedSubjects, appliedFilters);

    if (horariosValidos.isEmpty) {
      showCustomNotification(context, 'No se encontraron horarios validos',
          icon: Icons.info, color: Colors.red);
    } else {
      setState(() {
        allSchedules = horariosValidos;
        selectedScheduleIndex = null;

        if (isMobile() &&
            MediaQuery.of(context).orientation == Orientation.portrait) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Por favor, gira tu dispositivo para ver los horarios')),
          );
        }
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
    final userName = getUserNameFromToken();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0051FF),
            elevation: 0,
            title: Row(
              children: [
                UserMenuButton(userName: userName, onLogout: _logout),
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
                      if (!isExpandedView) ...[
                        Row(
                          children: [
                            Expanded(
                                child: _MainCardButton(
                                    color: const Color(0xFF0051FF),
                                    icon: Icons.search,
                                    label: "Buscar materia",
                                    onTap: () =>
                                        setState(() => isSearchOpen = true))),
                            const SizedBox(width: 20),
                            Expanded(
                                child: _MainCardButton(
                                    color: const Color(0xFF0051FF),
                                    icon: Icons.filter_alt,
                                    label: "Realizar filtro",
                                    onTap: () =>
                                        setState(() => isFilterOpen = true))),
                            const SizedBox(width: 20),
                            Expanded(
                                child: _MainCardButton(
                                    color: const Color(0xFFFF2F2F),
                                    icon: Icons.delete_outline,
                                    label: "Limpiar Horarios",
                                    onTap: clearSchedules)),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8CFF62),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            onPressed: generateSchedule,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Generar Horarios",
                                    style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(width: 10),
                                Icon(Icons.calendar_month, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
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
                Container(
                  width: isFullExpandedView ? 60 : 340,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    padding: isFullExpandedView
                        ? const EdgeInsets.only(top: 12)
                        : const EdgeInsets.all(20),
                    child: isFullExpandedView
                        ? Column(
                            children: [
                              const SizedBox(height: 4),
                              Center(
                                child: Tooltip(
                                  message: "Mostrar panel",
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_left,
                                        size: 32, color: Colors.black54),
                                    onPressed: () {
                                      setState(() {
                                        isFullExpandedView = false;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título y botón de expansión
                              Row(
                                children: [
                                  const Text("Materias seleccionadas",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: "Encoger panel",
                                    icon: const Icon(Icons.chevron_right,
                                        size: 32, color: Colors.black54),
                                    onPressed: () {
                                      setState(() {
                                        isFullExpandedView = true;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      ...addedSubjects
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final subject = entry.value;
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: ListTile(
                                            leading: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: getSubjectColor(idx),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            title: Text(subject.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.remove,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  removeSubject(subject),
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: () => setState(
                                              () => isSearchOpen = true),
                                          icon: const Icon(Icons.add),
                                          label: const Text("Agregar materia"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => setState(
                                        () => isExpandedView = !isExpandedView),
                                    icon: Icon(isExpandedView
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen),
                                    label: Text(isExpandedView
                                        ? "Vista Normal"
                                        : "Expandir Vista"),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "Créditos: ",
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: "$usedCredits/$creditLimit",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(
                                                0xFF2979FF), // Azul y en negrilla
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
              AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black45),
              ),
              FutureBuilder<List<Subject>>(
                future: futureSubjects,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SearchSubjectsWidget(
                    subjectController: subjectController,
                    allSubjects: snapshot.data!,
                    onSubjectSelected: (subject) {
                      addSubject(subject);
                      setState(() => isSearchOpen = false);
                    },
                    closeWindow: () => setState(() => isSearchOpen = false),
                  );
                },
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
              AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black45),
              ),
              ScheduleOverviewWidget(
                schedule: allSchedules[selectedScheduleIndex!],
                onClose: closeScheduleOverview,
              ),
            ],
          ),
      ],
    );
  }
}

class _MainCardButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MainCardButton(
      {super.key,
      required this.color,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  State<_MainCardButton> createState() => _MainCardButtonState();
}

class _MainCardButtonState extends State<_MainCardButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color hoverColor = widget.color.withOpacity(0.8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _isHovered ? hoverColor : widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
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