// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'schedule_preview_card.dart';

/// Muestra una cuadrícula de previsiones de horarios generados.

/// Cada celda de la cuadrícula representa un horario y es interactiva.
/// El diseño es adaptable para web, escritorio y dispositivos móviles.
/// Implementa paginación para manejar de forma eficiente un gran número de horarios.
class ScheduleGridWidget extends StatefulWidget {
  /// La lista de todos los horarios generados, donde cada horario es una lista de clases.
  final List<List<ClassOption>> allSchedules;

  /// Callback que se ejecuta cuando se toca un horario, devolviendo su índice.
  final Function(int) onScheduleTap;

  /// Mapa de colores para las materias.
  final Map<String, Color> subjectColors;

  /// Determina si se debe usar el layout para móvil.
  final bool isMobileLayout;

  /// Determina si el GridView debe ser scrollable. Se usa para anidar en otros scrollables.
  final bool isScrollable;

  /// Controlador de scroll opcional, para manejar la paginación desde un scrollable padre.
  final ScrollController? scrollController;

  /// Página actual para la paginación
  final int currentPage;

  /// Items por página para la paginación
  final int itemsPerPage;

  /// Si se muestra la estrella de favoritos.
  final bool showFavoriteButton;

  /// Si se usan etiquetas con letras (A, B, C) en vez de números (#1, #2, #3).
  final bool useLetterLabels;

  /// Si el widget debe llenar todo el espacio del padre (para vista de 1 sola grilla).
  final bool fillParent;

  /// Etiqueta personalizada para el modo fillParent (ej: 'A', 'B', 'C').
  final String? fillParentLabel;

  /// Resuelve el color de relleno de cada bloque. Si se provee, tiene prioridad
  /// sobre [subjectColors] (coloreo por materia). Se usa para colorear por
  /// estado de cupos en los horarios destacados (Fase 2). Si es null, se
  /// mantiene el coloreo por materia.
  final Color Function(ClassOption)? colorResolver;

  /// Si en móvil debe paginar (en vez de mostrar todos los horarios). Por
  /// defecto false para no alterar otros usos.
  final bool paginateOnMobile;

  /// Resuelve la etiqueta de la esquina de cada horario por su índice real.
  /// Si se provee, tiene prioridad sobre [useLetterLabels]. Se usa en Destacados
  /// para mostrar el nombre (o la letra estable) en vez de una letra posicional.
  final String Function(int index)? labelBuilder;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
    required this.subjectColors,
    this.isMobileLayout = false,
    this.isScrollable = true,
    this.scrollController,
    this.currentPage = 1,
    this.itemsPerPage = 10,
    this.showFavoriteButton = true,
    this.useLetterLabels = false,
    this.fillParent = false,
    this.fillParentLabel,
    this.colorResolver,
    this.paginateOnMobile = false,
    this.labelBuilder,
  }) : super(key: key);

  @override
  State<ScheduleGridWidget> createState() => _ScheduleGridWidgetState();
}

class _ScheduleGridWidgetState extends State<ScheduleGridWidget> {
  // Usa el controlador pasado o crea uno nuevo.
  late final ScrollController _scrollController;
  bool _isInternalController = false;

  List<List<ClassOption>> _displayedSchedules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Determina qué controlador usar.
    if (widget.scrollController == null) {
      _scrollController = ScrollController();
      _isInternalController = true;
    } else {
      _scrollController = widget.scrollController!;
    }

    _loadSchedulesForCurrentPage();
  }

  @override
  void didUpdateWidget(covariant ScheduleGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Comparar por contenido (no por identidad de lista): los padres suelen
    // reconstruir una lista nueva con los mismos horarios en cada rebuild
    // (p. ej. `[selectedSchedule]`), y comparar por identidad recargaba la
    // grilla en cada notificación del provider (parpadeo). listEquals evita
    // recargar cuando los horarios no cambian realmente.
    final bool pageChanged = widget.currentPage != oldWidget.currentPage;
    if (!listEquals(widget.allSchedules, oldWidget.allSchedules) ||
        pageChanged ||
        widget.itemsPerPage != oldWidget.itemsPerPage) {
      _loadSchedulesForCurrentPage();
      // Al cambiar de página, la grilla scrolleable (escritorio) debe volver
      // al inicio: si no, la página siguiente aparece desplazada al punto
      // donde quedó la anterior. En móvil el reset lo hace el padre con
      // Scrollable.ensureVisible sobre el ListView externo (aquí la grilla no
      // es scrolleable), así que solo aplica cuando este widget es el que
      // scrollea.
      if (pageChanged && widget.isScrollable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    // Solo elimina el controlador si fue creado internamente.
    if (_isInternalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _loadSchedulesForCurrentPage() {
    setState(() {
      // En móvil sin paginación explícita, mostrar todos los horarios.
      if (widget.isMobileLayout && !widget.paginateOnMobile) {
        _displayedSchedules = widget.allSchedules;
      } else {
        // PC, o móvil con paginación: aplicar la página actual.
        final int startIndex = (widget.currentPage - 1) * widget.itemsPerPage;
        final int endIndex = (startIndex + widget.itemsPerPage).clamp(0, widget.allSchedules.length);

        _displayedSchedules = widget.allSchedules.sublist(
          startIndex.clamp(0, widget.allSchedules.length),
          endIndex,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Color> subjectColors = widget.subjectColors;

    // Modo fillParent: renderiza un solo horario llenando todo el padre
    if (widget.fillParent && _displayedSchedules.isNotEmpty) {
      final schedule = _displayedSchedules[0];
      final int realIndex = (widget.currentPage - 1) * widget.itemsPerPage;
      return GestureDetector(
        onTap: () => widget.onScheduleTap(realIndex),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Stack(
            children: [
              SchedulePreview(
                schedule: schedule,
                subjectColors: subjectColors,
                scheduleIndex: realIndex,
                labelOverride: widget.fillParentLabel ??
                    (widget.useLetterLabels ? 'A' : null),
                colorResolver: widget.colorResolver,
              ),
              if (widget.showFavoriteButton)
                Positioned(
                  top: 2,
                  right: 2,
                  child: ScheduleFavoriteStar(schedule: schedule),
                ),
            ],
          ),
        ),
      );
    }

    int crossAxisCount = widget.isMobileLayout ? 1 : 2;
    double childAspectRatio = widget.isMobileLayout ? 1.8 : 1.5;

    return GridView.builder(
      physics: widget.isScrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      shrinkWrap: !widget.isScrollable,
      // Asigna el controlador SOLO si el widget es el que se desplaza.
      // Si isScrollable es false, el controlador ya está siendo usado por el
      // ListView padre y adjuntarlo aquí causa el error. La paginación
      // funciona igual porque el listener ya está activo.
      controller: widget.isScrollable ? _scrollController : null,
      padding: const EdgeInsets.all(8),
      itemCount: _displayedSchedules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final schedule = _displayedSchedules[index];
        final int realIndex = (widget.currentPage - 1) * widget.itemsPerPage + index;

        return SchedulePreviewCard(
          schedule: schedule,
          subjectColors: subjectColors,
          scheduleIndex: realIndex,
          labelOverride: widget.labelBuilder != null
              ? widget.labelBuilder!(realIndex)
              : (widget.useLetterLabels
                  ? String.fromCharCode(65 + index)
                  : null),
          colorResolver: widget.colorResolver,
          showFavoriteButton: widget.showFavoriteButton,
          onTap: () => widget.onScheduleTap(realIndex),
        );
      },
    );
  }
}
