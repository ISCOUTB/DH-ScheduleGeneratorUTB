// lib/providers/schedule_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';
import '../models/class_option.dart';
import '../services/api_service.dart';

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

  /// Créditos actualmente en uso.
  int _usedCredits = 0;
  int get usedCredits => _usedCredits;

  /// Límite de créditos.
  final int creditLimit = AppConfig.defaultCreditLimit;

  /// Mapa de colores asignados a cada materia.
  final Map<String, Color> _subjectColorMap = {};
  Map<String, Color> get subjectColorMap => Map.unmodifiable(_subjectColorMap);

  // ============================================================
  // ESTADO: Horarios
  // ============================================================

  /// Todos los horarios generados por la API.
  List<List<ClassOption>> _allSchedules = [];
  List<List<ClassOption>> get allSchedules => List.unmodifiable(_allSchedules);

  /// Horarios base sin filtros de NRC (usados para calcular NRCs viables).
  List<List<ClassOption>> _baseSchedulesForNrcCalculation = [];

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
  // MÉTODOS: Gestión de materias
  // ============================================================

  /// Añade una materia a la lista de seleccionadas.
  /// 
  /// Retorna un mensaje de error si no se puede agregar, null si fue exitoso.
  String? addSubject(Subject subject) {
    // Verificar duplicados
    if (_addedSubjects.any((s) => s.code == subject.code && s.name == subject.name)) {
      return 'La materia ya ha sido agregada';
    }

    // Verificar límite de créditos
    int newTotalCredits = _usedCredits + subject.credits;
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
    final subjectCode = subject.code;

    // Limpiar filtros asociados
    if (_appliedFilters['professors'] != null && _appliedFilters['professors'] is Map) {
      (_appliedFilters['professors'] as Map).remove(subjectCode);
    }
    if (_appliedFilters['nrcs'] != null && _appliedFilters['nrcs'] is Map) {
      (_appliedFilters['nrcs'] as Map).remove(subjectCode);
    }
    if (_apiFiltersForGeneration['include_professors'] != null) {
      (_apiFiltersForGeneration['include_professors'] as Map).remove(subjectCode);
    }
    if (_apiFiltersForGeneration['exclude_professors'] != null) {
      (_apiFiltersForGeneration['exclude_professors'] as Map).remove(subjectCode);
    }
    if (_apiFiltersForGeneration['selected_nrcs'] != null) {
      (_apiFiltersForGeneration['selected_nrcs'] as Map).remove(subjectCode);
    }

    // Eliminar materia
    _addedSubjects.removeWhere((s) => s.code == subject.code && s.name == subject.name);
    _usedCredits -= subject.credits;

    notifyListeners();

    // Regenerar horarios o limpiar
    if (_addedSubjects.isNotEmpty) {
      generateSchedules();
    } else {
      _allSchedules.clear();
      _baseSchedulesForNrcCalculation.clear();
      _selectedScheduleIndex = null;
      notifyListeners();
    }
  }

  /// Asigna un color a una materia si aún no tiene uno.
  void _assignColorToSubject(Subject subject) {
    if (!_subjectColorMap.containsKey(subject.name)) {
      final color = kSubjectColors[_subjectColorMap.length % kSubjectColors.length];
      _subjectColorMap[subject.name] = color;
    }
  }

  /// Obtiene el color asignado a una materia.
  Color getSubjectColor(int index) => kSubjectColors[index % kSubjectColors.length];

  // ============================================================
  // MÉTODOS: Generación de horarios
  // ============================================================

  /// Genera horarios con las materias y filtros actuales.
  Future<String?> generateSchedules() async {
    if (_addedSubjects.isEmpty) {
      return 'Por favor, agrega al menos una materia.';
    }

    _isLoading = true;
    clearError();
    notifyListeners();

    try {
      final schedules = await _apiService.generateSchedules(
        subjects: _addedSubjects,
        filters: {
          ..._apiFiltersForGeneration,
          ..._currentOptimizations,
        },
        creditLimit: creditLimit,
      );

      _allSchedules = schedules;
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
        bool hasFilters = _apiFiltersForGeneration.isNotEmpty &&
            _apiFiltersForGeneration.values.any((value) => 
                value != false && value != null && value != '');

        String message;
        IconData icon;
        Color color;

        if (hasFilters) {
          message = 'No se encontraron horarios con los filtros aplicados. Intenta relajar algunos filtros; pero si lo que hiciste fue agregar una materia nueva, posiblemente se trate de un cruce de horario.';
          icon = Icons.filter_alt_off;
          color = Colors.orange;
        } else {
          message = 'No se pueden generar horarios con estas materias. Puede haber cruces de horarios o incompatibilidades.';
          icon = Icons.schedule_send;
          color = Colors.red.shade600;
        }

        _errorMessage = message;
        _errorIcon = icon;
        _errorColor = color;
        return message;
      }

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
  /// Retorna un mapa donde la clave es el código de la materia y el valor
  /// es un conjunto de NRCs que aparecen en al menos uno de los horarios generados por la API.
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
        viableNrcsMap[subject.code] = subject.classOptions.map((c) => c.nrc).toSet();
      }
      return viableNrcsMap;
    }

    // Iterar sobre los horarios BASE (sin filtros de NRC) generados por la API
    // y extraer qué NRCs aparecen en combinaciones válidas
    for (var schedule in _baseSchedulesForNrcCalculation) {
      for (var classOption in schedule) {
        // Agregar el NRC de cada clase al conjunto viable de su materia
        viableNrcsMap
            .putIfAbsent(classOption.subjectCode, () => <String>{})
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
}
