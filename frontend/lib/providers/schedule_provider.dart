// lib/providers/schedule_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';
import '../models/class_option.dart';
import '../models/custom_course.dart';
import '../models/schedule.dart';
import '../models/schedule_diagnosis.dart';
import '../services/api_service.dart';
import '../utils/credit_utils.dart';
import '../utils/platform_service_stub.dart'
    if (dart.library.html) '../utils/platform_service_web.dart';

/// Provider que maneja el estado global de la aplicación de horarios.
/// 
/// Contiene toda la lógica de negocio relacionada con:
/// - Materias seleccionadas
/// - Horarios generados
/// - Filtros aplicados
/// - Opciones de optimización
/// - Estado de la UI (paneles abiertos, carga, etc.)
class ScheduleProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // ============================================================
  // ESTADO: Materias
  // ============================================================

  /// Lista de materias seleccionadas por el usuario.
  List<Subject> _addedSubjects = [];
  List<Subject> get addedSubjects => List.unmodifiable(_addedSubjects);

  /// Lista completa de materias disponibles (para búsqueda).
  List<SubjectSummary> _allSubjectsList = [];
  List<SubjectSummary> get allSubjectsList => List.unmodifiable(_allSubjectsList);

  /// Indica si las materias han sido cargadas.
  bool _areSubjectsLoaded = false;
  bool get areSubjectsLoaded => _areSubjectsLoaded;

  /// Créditos actualmente en uso. Decimal: hay materias de 0.5 créditos.
  double _usedCredits = 0;
  double get usedCredits => _usedCredits;

  /// Límite de créditos.
  final double creditLimit = AppConfig.defaultCreditLimit;

  /// Mapa de colores asignados a cada materia.
  final Map<String, Color> _subjectColorMap = {};
  Map<String, Color> get subjectColorMap => Map.unmodifiable(_subjectColorMap);

  // ============================================================
  // ESTADO: Cursos personalizados
  // ============================================================

  /// Cursos personalizados del usuario (todos, se agrupan por materia).
  List<CustomCourse> _customCourses = [];
  List<CustomCourse> get customCourses => List.unmodifiable(_customCourses);

  /// Cursos personalizados de una materia (por su `subjectKey`).
  List<CustomCourse> customCoursesForKey(String subjectKey) =>
      _customCourses.where((c) => c.subjectKey == subjectKey).toList();

  /// Cuántos cursos personalizados hay (para el aviso del header).
  int get customCoursesCount => _customCourses.length;

  /// Cursos personalizados agrupados por materia (`subjectKey`), para el anidado.
  Map<String, List<CustomCourse>> get customCoursesByKey {
    final map = <String, List<CustomCourse>>{};
    for (final c in _customCourses) {
      map.putIfAbsent(c.subjectKey, () => []).add(c);
    }
    return map;
  }

  /// Los que entran a la generación: activos y cuya materia está en la lista de
  /// trabajo. Un curso de una materia no seleccionada no afecta el horario.
  List<CustomCourse> get _activeCustomsForGeneration {
    final keys = _addedSubjects.map((s) => s.key).toSet();
    return _customCourses
        .where((c) => c.activo && keys.contains(c.subjectKey))
        .toList();
  }

  // ============================================================
  // ESTADO: Horarios
  // ============================================================

  /// Todos los horarios generados por la API.
  List<List<ClassOption>> _allSchedules = [];
  List<List<ClassOption>> get allSchedules => List.unmodifiable(_allSchedules);

  /// True si el backend truncó la lista por el cap móvil (había más).
  bool _schedulesTruncated = false;
  bool get schedulesTruncated => _schedulesTruncated;

  /// Horarios base sin filtros de NRC (usados para calcular NRCs viables).
  List<List<ClassOption>> _baseSchedulesForNrcCalculation = [];

  /// Explicación del último resultado vacío (null si hay horarios).
  ScheduleDiagnosis? _lastDiagnosis;
  ScheduleDiagnosis? get lastDiagnosis => _lastDiagnosis;

  /// Estado roto: hay materias agregadas pero el generador no encontró ningún
  /// horario. Mientras dure, no se permite agregar más materias (ver RFC §3):
  /// si ya no hay horarios, agregar otra jamás los va a crear, y además se
  /// perdería la invariante de que el estado anterior siempre fue satisfacible
  /// —que es lo que permite señalar culpables—. Se desbloquea solo, porque
  /// quitar una materia o relajar un filtro regenera al instante.
  bool get isBlockedByConflict =>
      _addedSubjects.isNotEmpty && _allSchedules.isEmpty && !_isLoading;

  /// Índice del horario seleccionado para vista detallada.
  int? _selectedScheduleIndex;
  int? get selectedScheduleIndex => _selectedScheduleIndex;

  /// Paginación
  int _currentPage = 1;
  int get currentPage => _currentPage;

  int _itemsPerPage = AppConfig.defaultItemsPerPage;
  int get itemsPerPage => _itemsPerPage;

  int get totalPages => _allSchedules.isEmpty 
      ? 1 
      : ((_allSchedules.length - 1) ~/ _itemsPerPage) + 1;

  // ============================================================
  // ESTADO: Filtros
  // ============================================================

  /// Filtros aplicados (estado de la UI).
  Map<String, dynamic> _appliedFilters = {};
  Map<String, dynamic> get appliedFilters => Map.unmodifiable(_appliedFilters);

  /// Filtros para enviar a la API.
  Map<String, dynamic> _apiFiltersForGeneration = {};

  /// Opciones de optimización.
  Map<String, dynamic> _currentOptimizations = {
    'optimizeGaps': false,
    'optimizeFreeDays': false,
  };
  Map<String, dynamic> get currentOptimizations => Map.unmodifiable(_currentOptimizations);

  // ============================================================
  // ESTADO: UI
  // ============================================================

  /// Indica si está cargando.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Control de paneles abiertos.
  bool _isSearchOpen = false;
  bool get isSearchOpen => _isSearchOpen;

  bool _isFilterOpen = false;
  bool get isFilterOpen => _isFilterOpen;

  bool _isOverviewOpen = false;
  bool get isOverviewOpen => _isOverviewOpen;

  bool _isMobileMenuOpen = false;
  bool get isMobileMenuOpen => _isMobileMenuOpen;

  bool _isExpandedView = false;
  bool get isExpandedView => _isExpandedView;

  bool _isFullExpandedView = false;
  bool get isFullExpandedView => _isFullExpandedView;

  /// Mensaje de error actual (null si no hay error).
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Icono asociado al mensaje de error.
  IconData? _errorIcon;
  IconData? get errorIcon => _errorIcon;

  /// Color asociado al mensaje de error.
  Color? _errorColor;
  Color? get errorColor => _errorColor;

  // ============================================================
  // MÉTODOS: Carga inicial
  // ============================================================

  /// Carga la lista de materias desde la API.
  Future<void> loadAllSubjects() async {
    try {
      final subjects = await _apiService.getAllSubjects();
      _allSubjectsList = subjects;
      _areSubjectsLoaded = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar la lista de materias: ${e.toString()}';
      _errorIcon = Icons.error;
      _errorColor = Colors.red;
      notifyListeners();
    }
  }

  // ============================================================
  // MÉTODOS: Cursos personalizados
  // ============================================================

  /// Carga los cursos personalizados del usuario.
  Future<void> loadCustomCourses() async {
    try {
      _customCourses = await _apiService.getCustomCourses();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando cursos personalizados: $e');
    }
  }

  /// Si un cambio en cursos personalizados afecta la generación actual
  /// (la materia está en la lista de trabajo), regenera.
  void _regenerateIfAffects(String subjectKey) {
    if (_addedSubjects.any((s) => s.key == subjectKey)) {
      generateSchedules();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _errorIcon = Icons.error;
    _errorColor = Colors.red;
    notifyListeners();
  }

  /// Crea un curso personalizado y **agrega su materia a la lista de trabajo**
  /// si no estaba, para que el curso entre a la generación enseguida. Retorna
  /// el curso, o null si falló.
  Future<CustomCourse?> createCustomCourse({
    required String code,
    required String name,
    required List<Schedule> bloques,
    String? etiqueta,
    String? nrc,
    String? type,
    String? professor,
    String? campus,
    bool activo = true,
  }) async {
    try {
      final cc = await _apiService.createCustomCourse(
        code: code, name: name, bloques: bloques, etiqueta: etiqueta, nrc: nrc,
        type: type, professor: professor, campus: campus, activo: activo,
      );
      _customCourses = [..._customCourses, cc];
      if (!isSubjectInList(cc.subjectKey)) {
        // addSubject notifica y regenera con el nuevo curso ya presente.
        addSubjectFromCustom(cc);
      } else {
        notifyListeners();
        _regenerateIfAffects(cc.subjectKey);
      }
      return cc;
    } catch (e) {
      _setError('No se pudo crear el curso personalizado: ${e.toString()}');
      return null;
    }
  }

  /// Actualiza un curso personalizado (bloques, datos, o el switch `activo`).
  Future<void> updateCustomCourse(
    int id, {
    List<Schedule>? bloques,
    String? etiqueta,
    String? nrc,
    String? type,
    String? professor,
    String? campus,
    bool? activo,
  }) async {
    try {
      final updated = await _apiService.updateCustomCourse(
        id, bloques: bloques, etiqueta: etiqueta, nrc: nrc, type: type,
        professor: professor, campus: campus, activo: activo,
      );
      _customCourses = [
        for (final c in _customCourses) if (c.id == id) updated else c
      ];
      notifyListeners();
      _regenerateIfAffects(updated.subjectKey);
    } catch (e) {
      _setError('No se pudo actualizar el curso personalizado: ${e.toString()}');
    }
  }

  /// Enciende/apaga el switch de un curso personalizado.
  Future<void> toggleCustomCourse(int id, bool activo) =>
      updateCustomCourse(id, activo: activo);

  /// Elimina un curso personalizado.
  Future<void> deleteCustomCourse(int id) async {
    final idx = _customCourses.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final key = _customCourses[idx].subjectKey;
    try {
      await _apiService.deleteCustomCourse(id);
      _customCourses = [
        for (final c in _customCourses) if (c.id != id) c
      ];
      notifyListeners();
      _regenerateIfAffects(key);
    } catch (e) {
      _setError('No se pudo eliminar el curso personalizado: ${e.toString()}');
    }
  }

  // ============================================================
  // MÉTODOS: Gestión de materias
  // ============================================================

  /// Agrega a la lista de trabajo la materia de un curso personalizado.
  ///
  /// La materia puede no tener oferta (ese es el caso de uso), así que se
  /// construye un `Subject` mínimo sin `classOptions`: para la generación basta,
  /// porque su dominio lo aporta el curso personalizado activo. Retorna mensaje
  /// de error o null.
  String? addSubjectFromCustom(CustomCourse cc) {
    return addSubject(Subject(
      code: cc.code,
      name: cc.name,
      credits: cc.credits,
      classOptions: const [],
    ));
  }

  /// Si la materia de un curso personalizado ya está en la lista de trabajo.
  bool isSubjectInList(String subjectKey) =>
      _addedSubjects.any((s) => s.key == subjectKey);

  /// Añade una materia a la lista de seleccionadas.
  ///
  /// Retorna un mensaje de error si no se puede agregar, null si fue exitoso.
  String? addSubject(Subject subject) {
    // Verificar duplicados
    if (_addedSubjects.any((s) => s.code == subject.code && s.name == subject.name)) {
      return 'La materia ya ha sido agregada';
    }

    // Estado roto: agregar otra materia no puede crear horarios donde ya no los
    // hay, y rompería la invariante que permite señalar culpables (RFC §3).
    if (isBlockedByConflict) {
      return 'Resuelve el cruce actual antes de agregar otra materia.';
    }

    // Verificar límite de créditos. Se redondea la suma para que acumular medios
    // créditos no deje 20.000000000000004 y rechace una materia que sí cabe.
    final double newTotalCredits = roundCredits(_usedCredits + subject.credits);
    if (newTotalCredits > creditLimit) {
      return 'Límite de créditos alcanzado';
    }

    // Asignar color
    _assignColorToSubject(subject);

    // Agregar materia
    _addedSubjects.add(subject);
    _usedCredits = newTotalCredits;
    notifyListeners();

    // Generar horarios automáticamente
    generateSchedules();

    // Advertencia si excede 18 créditos
    if (_usedCredits > AppConfig.warningCreditThreshold) {
      return 'Advertencia: Ha excedido los 18 créditos';
    }

    return null;
  }

  /// Elimina una materia de la lista de seleccionadas.
  void removeSubject(Subject subject) {
    // Los filtros están llaveados por el par (código, nombre). Borrarlos por el
    // código solo le tumbaba los filtros a la materia vecina que compartiera
    // código (ej. RULEI02B = "Inglés Ii" e "Inglés Ii - Derecho").
    final subjectKey = subject.key;

    // Limpiar filtros asociados
    if (_appliedFilters['professors'] != null && _appliedFilters['professors'] is Map) {
      (_appliedFilters['professors'] as Map).remove(subjectKey);
    }
    if (_appliedFilters['nrcs'] != null && _appliedFilters['nrcs'] is Map) {
      (_appliedFilters['nrcs'] as Map).remove(subjectKey);
    }
    if (_apiFiltersForGeneration['include_professors'] != null) {
      (_apiFiltersForGeneration['include_professors'] as Map).remove(subjectKey);
    }
    if (_apiFiltersForGeneration['exclude_professors'] != null) {
      (_apiFiltersForGeneration['exclude_professors'] as Map).remove(subjectKey);
    }
    if (_apiFiltersForGeneration['selected_nrcs'] != null) {
      (_apiFiltersForGeneration['selected_nrcs'] as Map).remove(subjectKey);
    }

    // Eliminar materia
    _addedSubjects.removeWhere((s) => s.code == subject.code && s.name == subject.name);
    _usedCredits = roundCredits(_usedCredits - subject.credits);

    notifyListeners();

    // Regenerar horarios o limpiar
    if (_addedSubjects.isNotEmpty) {
      generateSchedules();
    } else {
      _allSchedules.clear();
      _schedulesTruncated = false;
      _baseSchedulesForNrcCalculation.clear();
      _selectedScheduleIndex = null;
      notifyListeners();
    }
  }

  /// Asigna un color a una materia si aún no tiene uno.
  ///
  /// La llave es `Subject.key` —el par (código, nombre)—, no el nombre: hay
  /// materias distintas que se llaman igual (ej. "Materiales I" existe como
  /// `IMECM01A` y `DISET01B`) y con el nombre como llave la segunda heredaba el
  /// color de la primera, quedando indistinguibles en la grilla.
  void _assignColorToSubject(Subject subject) {
    if (!_subjectColorMap.containsKey(subject.key)) {
      final color = kSubjectColors[_subjectColorMap.length % kSubjectColors.length];
      _subjectColorMap[subject.key] = color;
    }
  }

  /// Obtiene el color asignado a una materia.
  Color getSubjectColor(int index) => kSubjectColors[index % kSubjectColors.length];

  // ============================================================
  // MÉTODOS: Generación de horarios
  // ============================================================

  /// Une nombres en lenguaje natural: "A", "A y B", "A, B y C".
  String _joinNames(List<String> names) {
    if (names.length <= 1) return names.isEmpty ? '' : names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
  }

  /// Une alternativas: "A", "A o B", "A, B o C". Las opciones de quitado son
  /// excluyentes (basta una), así que van con "o" y no con "y".
  String _joinAlternatives(List<String> names) {
    if (names.length <= 1) return names.isEmpty ? '' : names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} o ${names.last}';
  }

  /// La materia que aparece en TODOS los pares, si existe: es el caso de "una
  /// materia choca con varias" y permite nombrarla como el eje del problema.
  String? _commonSubjectInPairs(List<List<String>> pairs) {
    if (pairs.isEmpty) return null;
    for (final candidate in pairs.first) {
      if (pairs.every((p) => p.contains(candidate))) return candidate;
    }
    return null;
  }

  /// Arma el mensaje a partir del diagnóstico del backend (ver RFC §8).
  ///
  /// Dos reglas: en la columna **estructural** no se mencionan los filtros (son
  /// irrelevantes y solo confunden), y en la columna **filtros** siempre se dan
  /// las dos salidas —relajar el filtro **o** quitar la materia—, porque hay
  /// usuarios que no piensan ceder el filtro.
  String _messageForDiagnosis(ScheduleDiagnosis? d) {
    if (d == null) {
      // El backend no mandó diagnóstico (versión vieja o caso no previsto).
      return 'No se pueden generar horarios con estas materias.';
    }

    // Menú de quitado: son alternativas, basta una.
    final salida = d.removalOptions.isEmpty
        ? ''
        : ' Si quitas ${_joinAlternatives(d.removalOptions)}, sí hay horarios.';

    // Solo con blame=filtros. Vacío ahí significa que es la combinación de
    // filtros y no uno puntual, así que no se señala a ninguno.
    final filtro = d.blockingFilters.isEmpty
        ? ''
        : ' Relajando ${_joinAlternatives(d.blockingFilters.map((f) => f.label).toList())} también se resuelve.';

    switch (d.shape) {
      case 'sin_oferta':
        final cuales = _joinNames(d.subjects);
        return d.subjects.length > 1
            ? '$cuales no tienen cursos en la oferta de este periodo. Quítalas para continuar.'
            : '$cuales no tiene cursos en la oferta de este periodo. Quítala para continuar.';

      case 'materia_sin_opciones':
        final cuales = _joinNames(d.subjects);
        return 'Tus filtros no dejan ningún curso disponible de $cuales.'
            ' Relaja el filtro o quita la materia.$filtro';

      case 'par_incompatible':
        final comun = _commonSubjectInPairs(d.pairs);
        final conFiltros = d.blame != 'estructural';
        final prefijo = conFiltros ? 'Con tus filtros actuales, ' : '';

        if (d.pairs.length == 1) {
          final p = d.pairs.first;
          // Nombrar el par ya dice qué hacer (quitar una de las dos): no se
          // agrega el menú de quitado, sería ruido.
          final cola = conFiltros ? '' : ': no hay forma de tomarlas juntas';
          return '$prefijo${p[0]} se cruza con ${p[1]}$cola.'
              ' Quita una de las dos.$filtro';
        }

        if (comun != null) {
          // Una materia contra varias: ella es el eje del problema.
          final otras =
              d.pairs.map((p) => p[0] == comun ? p[1] : p[0]).toList();
          return '$prefijo$comun se cruza con ${_joinNames(otras)}.'
              ' Tendrías que quitarlas todas, o quitar $comun.$filtro';
        }

        final pares = d.pairs.map((p) => '${p[0]} con ${p[1]}').toList();
        return '${prefijo}se cruzan ${_joinNames(pares)}.$salida$filtro';

      case 'conjunto_incompatible':
      default:
        final base = d.blame == 'estructural'
            ? 'Estas materias no caben todas juntas (de a dos sí cabrían).'
            : 'Tus filtros dejan sin opciones a esta combinación de materias.';
        return '$base$salida$filtro';
    }
  }

  /// Genera horarios con las materias y filtros actuales.
  Future<String?> generateSchedules() async {
    if (_addedSubjects.isEmpty) {
      return 'Por favor, agrega al menos una materia.';
    }

    _isLoading = true;
    clearError();
    notifyListeners();

    try {
      final result = await _apiService.generateSchedules(
        subjects: _addedSubjects,
        filters: {
          ..._apiFiltersForGeneration,
          ..._currentOptimizations,
        },
        creditLimit: creditLimit,
        // Solo los dispositivos móviles reciben el cap (memoria limitada).
        isMobile: PlatformService().isMobileUserAgent(),
        // Cursos personalizados activos de las materias en la lista.
        activeCustomCourses: _activeCustomsForGeneration,
      );
      final schedules = result.schedules;

      _allSchedules = schedules;
      _schedulesTruncated = result.truncated;
      _currentPage = 1;
      
      // Si NO hay filtros de NRC aplicados, guardar estos horarios como base
      // para calcular NRCs viables. Esto permite que al aplicar filtros de NRC,
      // los demás NRCs no desaparezcan del filtro.
      bool hasNrcFilters = _apiFiltersForGeneration.containsKey('selected_nrcs') &&
          (_apiFiltersForGeneration['selected_nrcs'] as Map?)?.isNotEmpty == true;
      
      if (!hasNrcFilters) {
        _baseSchedulesForNrcCalculation = schedules;
      }
      
      _isLoading = false;
      notifyListeners();

      if (schedules.isEmpty) {
        _lastDiagnosis = result.diagnosis;
        final message = _messageForDiagnosis(result.diagnosis);
        final bool byFilters = result.diagnosis?.isFiltersFault ?? false;

        _errorMessage = message;
        _errorIcon = byFilters ? Icons.filter_alt_off : Icons.schedule_send;
        _errorColor = byFilters ? Colors.orange : Colors.red.shade600;
        return message;
      }

      _lastDiagnosis = null;
      return null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error al generar horarios: ${e.toString()}';
      _errorIcon = Icons.error;
      _errorColor = Colors.red;
      notifyListeners();
      return _errorMessage;
    }
  }

  // ============================================================
  // MÉTODOS: Filtros
  // ============================================================

  /// Aplica filtros y regenera horarios.
  void applyFilters(Map<String, dynamic> stateFilters, Map<String, dynamic> apiFilters) {
    _appliedFilters = stateFilters;
    _apiFiltersForGeneration = {
      ...apiFilters,
      ..._currentOptimizations,
    };
    _isFilterOpen = false;
    notifyListeners();

    if (_addedSubjects.isNotEmpty) {
      generateSchedules();
    }
  }

  /// Limpia todos los filtros.
  void clearFilters() {
    _appliedFilters.clear();
    _apiFiltersForGeneration = {..._currentOptimizations};
    notifyListeners();

    if (_addedSubjects.isNotEmpty) {
      generateSchedules();
    }
  }

  /// Actualiza las opciones de optimización.
  void updateOptimizations(Map<String, dynamic> optimizations) {
    _currentOptimizations = optimizations;
    _apiFiltersForGeneration = {
      ..._apiFiltersForGeneration,
      ...optimizations,
    };
    notifyListeners();

    if (_allSchedules.isNotEmpty && _addedSubjects.isNotEmpty) {
      generateSchedules();
    }
  }

  /// Obtiene los NRCs viables para cada materia basándose en los horarios generados.
  ///
  /// Retorna un mapa donde la clave es `Subject.key` —el par (código, nombre)—
  /// y el valor es un conjunto de NRCs que aparecen en al menos uno de los
  /// horarios generados por la API. La llave es el par y no el código porque el
  /// código no identifica una materia por sí solo (ver `Subject.key`); con el
  /// código, dos materias homónimas mezclaban sus NRCs viables.
  ///
  /// IMPORTANTE: Usa los horarios BASE (sin filtros de NRC) para calcular viabilidad.
  /// Esto permite que al aplicar un filtro de NRC, los demás NRCs sigan visibles
  /// y el usuario pueda cambiar de combinación sin que desaparezcan opciones.
  Map<String, Set<String>> getViableNrcsFromSchedules() {
    final Map<String, Set<String>> viableNrcsMap = {};

    // Si no hay horarios base generados, retornar todos los NRCs disponibles
    // (esto permite que el usuario vea todas las opciones antes de generar)
    if (_baseSchedulesForNrcCalculation.isEmpty) {
      for (var subject in _addedSubjects) {
        viableNrcsMap[subject.key] = subject.classOptions.map((c) => c.nrc).toSet();
      }
      return viableNrcsMap;
    }

    // Iterar sobre los horarios BASE (sin filtros de NRC) generados por la API
    // y extraer qué NRCs aparecen en combinaciones válidas
    for (var schedule in _baseSchedulesForNrcCalculation) {
      for (var classOption in schedule) {
        // Agregar el NRC de cada clase al conjunto viable de su materia
        viableNrcsMap
            .putIfAbsent(classOption.subjectKey, () => <String>{})
            .add(classOption.nrc);
      }
    }
    
    return viableNrcsMap;
  }

  // ============================================================
  // MÉTODOS: Limpieza
  // ============================================================

  /// Limpia completamente el estado de la aplicación.
  void clearAll() {
    _baseSchedulesForNrcCalculation.clear();
    _allSchedules.clear();
    _schedulesTruncated = false;
    _selectedScheduleIndex = null;
    _addedSubjects.clear();
    _usedCredits = 0;
    _subjectColorMap.clear();
    _appliedFilters.clear();
    _apiFiltersForGeneration.clear();
    _currentOptimizations = {
      'optimizeGaps': false,
      'optimizeFreeDays': false,
    };
    _isSearchOpen = false;
    _isFilterOpen = false;
    _isOverviewOpen = false;
    _isExpandedView = false;
    _isFullExpandedView = false;
    notifyListeners();
  }

  // ============================================================
  // MÉTODOS: UI
  // ============================================================

  void setSearchOpen(bool value) {
    _isSearchOpen = value;
    notifyListeners();
  }

  void setFilterOpen(bool value) {
    _isFilterOpen = value;
    notifyListeners();
  }

  void setOverviewOpen(bool value) {
    _isOverviewOpen = value;
    notifyListeners();
  }

  void setMobileMenuOpen(bool value) {
    _isMobileMenuOpen = value;
    notifyListeners();
  }

  void setExpandedView(bool value) {
    _isExpandedView = value;
    notifyListeners();
  }

  void setFullExpandedView(bool value) {
    _isFullExpandedView = value;
    notifyListeners();
  }

  void toggleExpandedView() {
    _isExpandedView = !_isExpandedView;
    notifyListeners();
  }

  void toggleMobileMenu() {
    _isMobileMenuOpen = !_isMobileMenuOpen;
    notifyListeners();
  }

  /// Selecciona un horario para ver en detalle.
  void selectSchedule(int index) {
    _selectedScheduleIndex = index;
    _isOverviewOpen = true;
    notifyListeners();
  }

  /// Cierra la vista de detalle del horario.
  void closeScheduleOverview() {
    _isOverviewOpen = false;
    notifyListeners();
  }

  // --- Navegación entre horarios de la MISMA página (detalle en generación) ---

  /// Índice (en allSchedules) del primer horario de la página actual.
  int get _pageStartIndex => (_currentPage - 1) * _itemsPerPage;

  /// Índice (exclusivo) donde termina la página actual.
  int get _pageEndIndex =>
      (_pageStartIndex + _itemsPerPage).clamp(0, _allSchedules.length);

  /// Si el detalle puede ir al horario anterior sin salir de la página actual.
  bool get canSelectPrevInPage =>
      _isOverviewOpen &&
      _selectedScheduleIndex != null &&
      _selectedScheduleIndex! > _pageStartIndex;

  /// Si el detalle puede ir al horario siguiente sin salir de la página actual.
  bool get canSelectNextInPage =>
      _isOverviewOpen &&
      _selectedScheduleIndex != null &&
      _selectedScheduleIndex! < _pageEndIndex - 1;

  /// Mueve la selección del detalle al horario anterior de la misma página.
  /// No cruza de página ni hace wrap.
  void selectPrevInPage() {
    if (canSelectPrevInPage) {
      _selectedScheduleIndex = _selectedScheduleIndex! - 1;
      notifyListeners();
    }
  }

  /// Mueve la selección del detalle al horario siguiente de la misma página.
  /// No cruza de página ni hace wrap.
  void selectNextInPage() {
    if (canSelectNextInPage) {
      _selectedScheduleIndex = _selectedScheduleIndex! + 1;
      notifyListeners();
    }
  }

  /// Si desde el detalle hay una página siguiente a la que saltar. Activo en
  /// CUALQUIER horario de la página (no solo en el último): el botón de página
  /// es un salto libre, no la continuación del recorrido horario a horario.
  bool get canGoToNextPageFromOverview =>
      _isOverviewOpen &&
      _selectedScheduleIndex != null &&
      _currentPage < totalPages;

  /// Salta a la página siguiente y selecciona su PRIMER horario (el detalle
  /// sigue abierto).
  void goToNextPageFromOverview() {
    if (!canGoToNextPageFromOverview) return;
    _currentPage += 1;
    _selectedScheduleIndex = _pageStartIndex;
    notifyListeners();
  }

  /// Si desde el detalle hay una página anterior a la que volver. Activo en
  /// CUALQUIER horario de la página.
  bool get canGoToPrevPageFromOverview =>
      _isOverviewOpen &&
      _selectedScheduleIndex != null &&
      _currentPage > 1;

  /// Vuelve a la página anterior y selecciona su PRIMER horario (el detalle
  /// sigue abierto).
  void goToPrevPageFromOverview() {
    if (!canGoToPrevPageFromOverview) return;
    _currentPage -= 1;
    _selectedScheduleIndex = _pageStartIndex;
    notifyListeners();
  }

  // ============================================================
  // MÉTODOS: Paginación
  // ============================================================

  void setCurrentPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void setItemsPerPage(int items) {
    _itemsPerPage = items;
    _currentPage = 1; // Resetear a primera página
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _errorIcon = null;
    _errorColor = null;
    notifyListeners();
  }

  // ============================================================
  // ESTADO: Favoritos (Horarios Destacados)
  // ============================================================

  /// Set de signatures de los favoritos del usuario (para lookup O(1)).
  Set<String> _favoriteSignatures = {};

  /// Mapa de signature → favorite ID del servidor (necesario para DELETE).
  final Map<String, int> _favoriteIdBySignature = {};

  /// Horarios favoritos cargados del servidor (para la pantalla dedicada).
  List<List<ClassOption>> _favoriteSchedules = [];
  List<List<ClassOption>> get favoriteSchedules => List.unmodifiable(_favoriteSchedules);

  /// Indica si los favoritos están cargándose.
  bool _isFavoritesLoading = false;
  bool get isFavoritesLoading => _isFavoritesLoading;

  /// Si los favoritos se cargaron al menos una vez. Evita mostrar el
  /// empty-state antes de la primera carga (causa de parpadeo al entrar).
  bool _favoritesLoadedOnce = false;
  bool get favoritesLoadedOnce => _favoritesLoadedOnce;

  /// Cantidad máxima de favoritos permitidos.
  int _maxFavoritesAllowed = 20;
  int get maxFavoritesAllowed => _maxFavoritesAllowed;

  /// Número de favoritos actuales.
  int get favoritesCount => _favoriteSignatures.length;

  /// Término académico actual (definido por el servidor).
  String _currentTerm = '';
  String get currentTerm => _currentTerm;

  /// Término seleccionado actualmente en la UI de favoritos.
  String _selectedTerm = '';
  String get selectedTerm => _selectedTerm;

  /// Términos disponibles con favoritos.
  List<String> _availableTerms = [];
  List<String> get availableTerms => List.unmodifiable(_availableTerms);

  /// Estado de cupos del horario mostrado: `{ nrc: {available, total} }` (Fase 2).
  Map<String, Map<String, int>> _selectedScheduleStatus = {};
  Map<String, Map<String, int>> get selectedScheduleStatus =>
      Map.unmodifiable(_selectedScheduleStatus);

  /// Cupos de los NRC de **todos** los favoritos del término actual:
  /// `{ nrc: {available, total} }`.
  ///
  /// Es lo que permite marcar con un aviso cada tarjeta del sidebar sin tener
  /// que abrir su detalle: `selectedScheduleStatus` solo cubre el horario que se
  /// está viendo. Se llena de una sola vez (el endpoint recibe la lista de NRC).
  Map<String, Map<String, int>> _allFavoritesStatus = {};
  Map<String, Map<String, int>> get allFavoritesStatus =>
      Map.unmodifiable(_allFavoritesStatus);

  /// Si la grilla de favoritos colorea por estado de cupos (true) o por materia.
  bool _statusColorMode = false;
  bool get statusColorMode => _statusColorMode;

  /// Si se está cargando el estado de cupos.
  bool _isStatusLoading = false;
  bool get isStatusLoading => _isStatusLoading;

  // ============================================================
  // MÉTODOS: Favoritos
  // ============================================================

  /// Calcula una signature determinista para un horario (NRCs ordenados).
  String computeSignature(List<ClassOption> schedule) {
    final nrcs = schedule.map((c) => c.nrc).toList()..sort();
    return nrcs.join('-');
  }

  /// Verifica si un horario es favorito.
  bool isFavorite(List<ClassOption> schedule) {
    return _favoriteSignatures.contains(computeSignature(schedule));
  }

  /// Carga los términos disponibles desde el servidor.
  Future<void> loadFavoriteTerms() async {
    try {
      final data = await _apiService.getFavoriteTerms();
      _currentTerm = data['currentTerm'] as String;
      _availableTerms = List<String>.from(data['availableTerms'] as List);

      // Si no hay término seleccionado, usar el actual
      if (_selectedTerm.isEmpty) {
        _selectedTerm = _currentTerm;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando términos de favoritos: $e');
    }
  }

  /// Cambia el término seleccionado y recarga favoritos.
  Future<void> switchFavoriteTerm(String term) async {
    if (term == _selectedTerm) return; // Sin cambio, no recargar
    _selectedTerm = term;
    // El estado de cupos solo aplica al término actual; limpiar al cambiar.
    _selectedScheduleStatus = {};
    _allFavoritesStatus = {};
    notifyListeners();
    await loadFavorites(term: term);
    // Los favoritos del término nuevo tienen otros NRC: recalcular los avisos.
    await loadStatusForAllFavorites();
  }

  /// Activa o desactiva el coloreo por estado de cupos.
  void setStatusColorMode(bool value) {
    if (_statusColorMode == value) return;
    _statusColorMode = value;
    notifyListeners();
  }

  /// Carga los cupos de **todos** los favoritos en una sola llamada, para poder
  /// avisar cuáles tienen problemas sin abrirlos uno por uno.
  ///
  /// Solo aplica al término actual: la tabla `Curso` solo tiene el periodo
  /// vigente y Banner reutiliza NRCs, así que en periodos pasados el mapa queda
  /// vacío y no se marca nada (ver RFC Fase 2, §2.6).
  Future<void> loadStatusForAllFavorites() async {
    if (_selectedTerm != _currentTerm || _favoriteSchedules.isEmpty) {
      _allFavoritesStatus = {};
      notifyListeners();
      return;
    }

    // Set: varios favoritos comparten NRCs y no tiene sentido pedirlos repetidos.
    final nrcs = <String>{
      for (final schedule in _favoriteSchedules)
        for (final option in schedule) option.nrc
    }.toList();

    try {
      _allFavoritesStatus = await _apiService.getFavoritesStatus(nrcs);
    } catch (e) {
      debugPrint('Error cargando estado de cupos de favoritos: $e');
      // Mapa vacío = no se pudo consultar; el aviso no se muestra en vez de
      // alarmar con datos que no se tienen.
      _allFavoritesStatus = {};
    }
    notifyListeners();
  }

  /// Carga el estado de cupos de un horario. Solo aplica al término actual:
  /// la tabla `Curso` solo tiene el periodo vigente y Banner reutiliza NRCs,
  /// así que para periodos pasados se deja vacío (ver RFC Fase 2, §2.6).
  Future<void> loadStatusForSchedule(List<ClassOption> schedule) async {
    if (_selectedTerm != _currentTerm) {
      _selectedScheduleStatus = {};
      notifyListeners();
      return;
    }

    final nrcs = schedule.map((c) => c.nrc).toList();
    _isStatusLoading = true;
    notifyListeners();

    try {
      _selectedScheduleStatus = await _apiService.getFavoritesStatus(nrcs);
    } catch (e) {
      debugPrint('Error cargando estado de cupos: $e');
      _selectedScheduleStatus = {};
    } finally {
      _isStatusLoading = false;
      notifyListeners();
    }
  }

  /// Carga los favoritos del servidor para un término específico.
  /// Si [silent] es true, no muestra indicador de carga (recarga en segundo plano).
  Future<void> loadFavorites({String? term, bool silent = false}) async {
    if (!silent) {
      _isFavoritesLoading = true;
      notifyListeners();
    }

    try {
      final data = await _apiService.getFavorites(term: term ?? _selectedTerm);
      final favorites = data['favorites'] as List<dynamic>;
      _maxFavoritesAllowed = data['maxAllowed'] ?? 20;

      _favoriteSignatures.clear();
      _favoriteIdBySignature.clear();
      _favoriteSchedules.clear();

      for (final fav in favorites) {
        final signature = fav['signature'] as String;
        final favoriteId = fav['id'] as int;
        _favoriteSignatures.add(signature);
        _favoriteIdBySignature[signature] = favoriteId;

        // Deserializar el schedule_json a List<ClassOption>
        final scheduleJson = fav['schedule_json'] as List<dynamic>;
        final schedule = scheduleJson
            .map<ClassOption>((co) => ClassOption.fromJson(co as Map<String, dynamic>))
            .toList();
        _favoriteSchedules.add(schedule);
      }

      // Fallback: si loadFavoriteTerms no funcionó, usar el term de esta respuesta
      final responseTerm = data['term'] as String?;
      if (responseTerm != null && responseTerm.isNotEmpty) {
        if (_currentTerm.isEmpty) _currentTerm = responseTerm;
        if (_selectedTerm.isEmpty) _selectedTerm = responseTerm;
        if (!_availableTerms.contains(responseTerm)) {
          _availableTerms = [responseTerm, ..._availableTerms];
        }
      }
    } catch (e) {
      debugPrint('Error cargando favoritos: $e');
    } finally {
      _isFavoritesLoading = false;
      _favoritesLoadedOnce = true;
      notifyListeners();
    }
  }

  /// Agrega o quita un horario de favoritos (toggle).
  Future<void> toggleFavorite(List<ClassOption> schedule) async {
    final signature = computeSignature(schedule);

    if (_favoriteSignatures.contains(signature)) {
      // Quitar de favoritos
      final favoriteId = _favoriteIdBySignature[signature];
      if (favoriteId != null) {
        try {
          await _apiService.deleteFavorite(favoriteId);
          _favoriteSignatures.remove(signature);
          _favoriteIdBySignature.remove(signature);
          _favoriteSchedules.removeWhere((s) => computeSignature(s) == signature);
          notifyListeners();
        } catch (e) {
          _errorMessage = 'Error al quitar de destacados: ${e.toString()}';
          _errorIcon = Icons.error;
          _errorColor = Colors.red;
          notifyListeners();
        }
      }
    } else {
      // Agregar a favoritos
      if (_favoriteSignatures.length >= _maxFavoritesAllowed) {
        _errorMessage = 'Límite de $_maxFavoritesAllowed horarios destacados alcanzado';
        _errorIcon = Icons.warning;
        _errorColor = Colors.orange;
        notifyListeners();
        return;
      }

      try {
        final scheduleJson = schedule.map((c) => c.toJson()).toList();
        final result = await _apiService.createFavorite(
          signature: signature,
          schedule: scheduleJson,
        );
        final favorite = result['favorite'];
        _favoriteSignatures.add(signature);
        _favoriteIdBySignature[signature] = favorite['id'];
        _favoriteSchedules.insert(0, schedule);
        notifyListeners();
      } catch (e) {
        _errorMessage = 'Error al guardar en destacados: ${e.toString()}';
        _errorIcon = Icons.error;
        _errorColor = Colors.red;
        notifyListeners();
      }
    }
  }

  /// Elimina un favorito por su índice en la lista de favoritos cargados.
  Future<void> removeFavoriteAt(int index) async {
    if (index < 0 || index >= _favoriteSchedules.length) return;

    final schedule = _favoriteSchedules[index];
    final signature = computeSignature(schedule);
    final favoriteId = _favoriteIdBySignature[signature];

    if (favoriteId != null) {
      try {
        await _apiService.deleteFavorite(favoriteId);
        _favoriteSignatures.remove(signature);
        _favoriteIdBySignature.remove(signature);
        _favoriteSchedules.removeAt(index);
        notifyListeners();
      } catch (e) {
        _errorMessage = 'Error al eliminar destacado: ${e.toString()}';
        _errorIcon = Icons.error;
        _errorColor = Colors.red;
        notifyListeners();
      }
    }
  }
}
