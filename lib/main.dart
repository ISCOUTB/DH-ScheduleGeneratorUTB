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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class WebScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
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
      title: 'Gene de Horarios UTB',
      scrollBehavior: WebScrollBehavior(),
      theme: theme,
      home: const MyHomePage(title: 'Gene de Horarios UTB'),
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
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    futureSubjects = fetchSubjectsFromApi();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void addSubject(Subject subject) {
    if (addedSubjects.any((s) => s.code == subject.code && s.name == subject.name)) {
      showCustomNotification(context, 'La materia ya ha sido agregada', icon: Icons.info, color: Colors.green);
      return;
    }

    int newTotalCredits = usedCredits + subject.credits;
    if (newTotalCredits > creditLimit) {
      showCustomNotification(context, 'Limite de creditos alcanzados', icon: Icons.info, color: Colors.red);
      return;
    }

    setState(() {
      usedCredits = newTotalCredits;
      addedSubjects.add(subject);

      if (usedCredits > 18) {
        showCustomNotification(context, 'Advertencia: Ha excedido los 18 creditos', icon: Icons.info, color: Colors.green);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia agregada: ${subject.name}')),
      );
    });
  }

  void removeSubject(Subject subject) {
    setState(() {
      addedSubjects.removeWhere((s) => s.code == subject.code && s.name == subject.name);
      usedCredits -= subject.credits;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materia eliminada: ${subject.name}')),
      );
    });
  }

  void generateSchedule() {
    if (addedSubjects.isEmpty) {
      showCustomNotification(context, 'No hay materias seleccionadas', icon: Icons.error, color: Colors.red);
      return;
    }

    List<List<ClassOption>> horariosValidos = obtenerHorariosValidos(addedSubjects, appliedFilters);

    if (horariosValidos.isEmpty) {
      showCustomNotification(context, 'No se encontraron horarios validos', icon: Icons.info, color: Colors.red);
    } else {
      setState(() {
        allSchedules = horariosValidos;
        selectedScheduleIndex = null;

        if (isMobile() && MediaQuery.of(context).orientation == Orientation.portrait) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, gira tu dispositivo para ver los horarios')),
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
    showCustomNotification(context, 'Horarios generados eliminados', icon: Icons.info, color: Colors.green);
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 0, 94, 255),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Text("Generador de Horarios", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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
                            Expanded(child: _MainCardButton(color: Colors.blue, icon: Icons.search, label: "Buscar materia", onTap: () => setState(() => isSearchOpen = true))),
                            const SizedBox(width: 20),
                            Expanded(child: _MainCardButton(color: Colors.blue, icon: Icons.filter_alt, label: "Realizar filtro", onTap: () => setState(() => isFilterOpen = true))),
                            const SizedBox(width: 20),
                            Expanded(child: _MainCardButton(color: Colors.red, icon: Icons.delete_outline, label: "Limpiar Horarios", onTap: clearSchedules)),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5AF48E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: generateSchedule,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Generar Horarios", style: TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)),
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
                                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade400, width: 2)),
                                child: Center(child: Text("Vista previa del horario", style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
                              )
                            : ScheduleGridWidget(allSchedules: allSchedules, onScheduleTap: openScheduleOverview),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(
                  width: 340,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Materias seleccionadas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 18),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                ...addedSubjects.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final subject = entry.value;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: getSubjectColor(idx),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove, color: Colors.red),
                                        onPressed: () => removeSubject(subject),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() => isSearchOpen = true),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => setState(() => isExpandedView = !isExpandedView),
                              icon: Icon(isExpandedView ? Icons.fullscreen_exit : Icons.fullscreen),
                              label: Text(isExpandedView ? "Vista Normal" : "Expandir Vista"),
                            ),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Créditos: ",
                                    style: TextStyle(fontSize: 16, color: Colors.black),
                                  ),
                                  TextSpan(
                                    text: "$usedCredits/$creditLimit",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2979FF), // Azul y en negrilla
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
        if (isSearchOpen)
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
        if (isFilterOpen)
          FilterWidget(
            closeWindow: () => setState(() => isFilterOpen = false),
            onApplyFilters: applyFilters,
            currentFilters: appliedFilters,
            addedSubjects: addedSubjects,
          ),
        if (isOverviewOpen && selectedScheduleIndex != null)
          ScheduleOverviewWidget(
            schedule: allSchedules[selectedScheduleIndex!],
            onClose: closeScheduleOverview,
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

  const _MainCardButton({super.key, required this.color, required this.icon, required this.label, required this.onTap});

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
            boxShadow: _isHovered ? [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

void showCustomNotification(BuildContext context, String message, {IconData? icon, Color? color}) {
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
            if (icon != null) Icon(icon, color: color ?? const Color(0xFF1ABC7B), size: 32),
            if (icon != null) const SizedBox(width: 16),
            Flexible(child: Text(message, style: const TextStyle(fontSize: 18, color: Colors.black87))),
          ],
        ),
      ),
    ),
  );
}