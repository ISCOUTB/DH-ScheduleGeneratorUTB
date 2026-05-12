// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../providers/schedule_provider.dart';
import '../models/class_option.dart';
import '../widgets/schedule_grid_widget.dart';
import '../widgets/schedule_overview_widget.dart';
import '../widgets/common/common.dart';
import '../widgets/dialogs/dialogs.dart';
import '../widgets/layout/layout.dart';

/// Pantalla dedicada para ver los horarios destacados (favoritos) del usuario.
///
/// Desktop: Panel lateral izquierdo con mini-previews de horarios (tarjetas con grilla)
/// + grilla grande del horario seleccionado a la derecha.
/// Mobile: Grilla normal con letras A, B, C en vez de números.
class FavoritesScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;

  const FavoritesScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _selectedIndex = 0;
  bool _showOverview = false;
  bool _sidebarShowInfo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ScheduleProvider>();
      await provider.loadFavoriteTerms();
      // Recargar siempre, pero sin flash de loading si ya hay datos
      await provider.loadFavorites(
        silent: provider.favoriteSchedules.isNotEmpty,
      );
    });
  }

  /// Formatea un código de término para mostrar: "202610" → "2026-10"
  String _formatTerm(String term) {
    if (term.length == 6) {
      return '${term.substring(0, 4)}-${term.substring(4)}';
    }
    return term;
  }

  /// Muestra modal de confirmación al eliminar de un periodo anterior.
  Future<bool> _confirmCrossTermDelete(
      BuildContext context, String term) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE67E22), size: 28),
                SizedBox(width: 12),
                Text('Eliminar de periodo anterior'),
              ],
            ),
            content: Text(
              'Este horario pertenece al periodo ${_formatTerm(term)}. '
              'Los datos de este periodo ya no se actualizan y la eliminación '
              'es irreversible.\n\n¿Deseas continuar?',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Calcula huecos (gaps) entre clases del mismo día.
  int _calculateGaps(List<ClassOption> schedule) {
    final Map<String, List<List<int>>> dayBlocks = {};
    for (final option in schedule) {
      for (final sched in option.schedules) {
        final day = sched.day.substring(0, 3);
        dayBlocks.putIfAbsent(day, () => []);
        final parts = sched.time.split(' - ');
        if (parts.length == 2) {
          final startParts = parts[0].trim().split(':');
          final endParts = parts[1].trim().split(':');
          if (startParts.length == 2 && endParts.length == 2) {
            dayBlocks[day]!.add([
              int.parse(startParts[0]) * 60 + int.parse(startParts[1]),
              int.parse(endParts[0]) * 60 + int.parse(endParts[1]),
            ]);
          }
        }
      }
    }
    int gaps = 0;
    for (final blocks in dayBlocks.values) {
      if (blocks.length < 2) continue;
      blocks.sort((a, b) => a[0].compareTo(b[0]));
      for (int i = 0; i < blocks.length - 1; i++) {
        if (blocks[i][1] < blocks[i + 1][0]) gaps++;
      }
    }
    return gaps;
  }

  /// Calcula días libres (Lun-Sáb sin clases).
  int _calculateFreeDays(List<ClassOption> schedule) {
    final Set<String> usedDays = {};
    for (final option in schedule) {
      for (final sched in option.schedules) {
        usedDays.add(sched.day.substring(0, 3));
      }
    }
    const allDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return allDays.where((d) => !usedDays.contains(d)).length;
  }

  /// Obtiene la lista de nombres de materias de un horario.
  List<String> _getSubjectNames(List<ClassOption> schedule) {
    final Set<String> names = {};
    for (final option in schedule) {
      names.add(option.subjectName);
    }
    return names.toList();
  }

  Map<String, Color> _buildColorMap(List<ClassOption> schedule) {
    final Map<String, Color> colors = {};
    for (final option in schedule) {
      if (!colors.containsKey(option.subjectName)) {
        colors[option.subjectName] =
            kSubjectColors[colors.length % kSubjectColors.length];
      }
    }
    return colors;
  }

  Map<String, Color> _buildColorMapFromAll(List<List<ClassOption>> schedules) {
    final Map<String, Color> colors = {};
    for (final schedule in schedules) {
      for (final option in schedule) {
        if (!colors.containsKey(option.subjectName)) {
          colors[option.subjectName] =
              kSubjectColors[colors.length % kSubjectColors.length];
        }
      }
    }
    return colors;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showCustomNotification(context, 'No se pudo abrir el enlace',
            icon: Icons.error, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobileLayout =
                constraints.maxWidth < AppConfig.mobileBreakpoint;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              appBar: _buildAppBar(isMobileLayout),
              body: Stack(
                children: [
                  _buildBody(provider, isMobileLayout),
                  // Modal overlay con fondo negro (mismo patrón que HomeScreen)
                  if (_showOverview &&
                      _selectedIndex < provider.favoriteSchedules.length)
                    Stack(
                      children: [
                        const ModalBarrier(
                            dismissible: false, color: Colors.black45),
                        Center(
                          child: ScheduleOverviewWidget(
                            schedule:
                                provider.favoriteSchedules[_selectedIndex],
                            onClose: () =>
                                setState(() => _showOverview = false),
                            subjectColors: _buildColorMap(
                                provider.favoriteSchedules[_selectedIndex]),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // APPBAR — Reutiliza el mismo estilo de la app principal
  // ============================================================

  PreferredSizeWidget _buildAppBar(bool isMobileLayout) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      toolbarHeight: 66,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SvgPicture.asset(
                'images/logo_utb.svg',
                width: 183,
                height: 46,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (!isMobileLayout) ...[
          _buildNavButton('Mi UTB', 'https://www.utb.edu.co/mi-utb/'),
          _buildNavButton('Turnos',
              'https://sites.google.com/view/turnos-de-matricula-web-utb/turnos?authuser=0'),
          _buildNavButton('Mallas',
              'https://sites.google.com/utb.edu.co/mallasutb/mallas-curriculares'),
          _buildNavButton('Electivas',
              'https://sites.google.com/utb.edu.co/stuplan-electivas/electivas'),
          _buildNavButton('Reportar Error',
              'https://docs.google.com/forms/d/e/1FAIpQLSeG6F1lWErfKEtTo4R8OmF6ZCpjrqKqosn_7KLgHpLCYTuDFw/viewform?usp=publish-editor'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Acerca de los creadores',
            onPressed: () => CreatorsDialog.show(context),
          ),
          const SizedBox(width: 8),
          UserInfoBadge(
            user: widget.currentUser,
            onLogout: widget.onLogout,
          ),
        ],
        if (isMobileLayout) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Volver al generador',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildNavButton(String text, String url) => TextButton(
        style: TextButton.styleFrom(overlayColor: Colors.transparent),
        onPressed: () => _launchURL(url),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: NavLink(text: text),
        ),
      );

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(ScheduleProvider provider, bool isMobileLayout) {
    if (provider.isFavoritesLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando horarios destacados...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (provider.favoriteSchedules.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobileLayout) {
      return _buildMobileLayout(provider);
    } else {
      return _buildDesktopLayout(provider);
    }
  }

  // ============================================================
  // DESKTOP: Sidebar con mini-previews + Grilla grande
  // ============================================================

  Widget _buildDesktopLayout(ScheduleProvider provider) {
    if (_selectedIndex >= provider.favoriteSchedules.length) {
      _selectedIndex =
          (provider.favoriteSchedules.length - 1).clamp(0, provider.favoriteSchedules.length);
    }

    final selectedSchedule = provider.favoriteSchedules[_selectedIndex];
    final colors = _buildColorMap(selectedSchedule);
    final selectedLabel = String.fromCharCode(65 + _selectedIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar con mini previews / info
        _FavoritesSidebar(
          schedules: provider.favoriteSchedules,
          selectedIndex: _selectedIndex,
          showInfo: _sidebarShowInfo,
          onToggleMode: () => setState(() => _sidebarShowInfo = !_sidebarShowInfo),
          onSelect: (i) => setState(() => _selectedIndex = i),
          onDelete: (i) async {
            // Confirmar si es un periodo diferente al actual
            if (provider.selectedTerm != provider.currentTerm) {
              final confirmed = await _confirmCrossTermDelete(
                  context, provider.selectedTerm);
              if (!confirmed) return;
            }

            final deletingSelected = (i == _selectedIndex);
            final deletingBefore = (i < _selectedIndex);

            await provider.removeFavoriteAt(i);

            // Recargar términos por si quedó vacío el periodo
            provider.loadFavoriteTerms();

            if (provider.favoriteSchedules.isEmpty) {
              setState(() => _selectedIndex = 0);
            } else if (deletingSelected) {
              setState(() {
                if (_selectedIndex >= provider.favoriteSchedules.length) {
                  _selectedIndex = provider.favoriteSchedules.length - 1;
                }
              });
            } else if (deletingBefore) {
              setState(() => _selectedIndex = _selectedIndex - 1);
            }
          },
          buildColorMap: _buildColorMap,
          calculateGaps: _calculateGaps,
          calculateFreeDays: _calculateFreeDays,
          getSubjectNames: _getSubjectNames,
          // Term props
          availableTerms: provider.availableTerms,
          selectedTerm: provider.selectedTerm,
          currentTerm: provider.currentTerm,
          onTermChanged: (term) {
            setState(() => _selectedIndex = 0);
            provider.switchFavoriteTerm(term);
          },
          formatTerm: _formatTerm,
        ),
        // Contenido principal con padding y contorno
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: "Opción A"
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Opción $selectedLabel',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 44, top: 4, bottom: 16),
                  child: Text(
                    'Haz clic en el horario para ver los detalles',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
                // Grilla dentro de un contenedor con contorno
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ScheduleGridWidget(
                      allSchedules: [selectedSchedule],
                      onScheduleTap: (_) =>
                          setState(() => _showOverview = true),
                      subjectColors: colors,
                      isMobileLayout: false,
                      isScrollable: false,
                      showFavoriteButton: false,
                      useLetterLabels: true,
                      fillParent: true,
                      fillParentLabel: selectedLabel,
                      currentPage: 1,
                      itemsPerPage: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE: Grilla con letras
  // ============================================================

  Widget _buildMobileLayout(ScheduleProvider provider) {
    return Column(
      children: [
        // Barra de periodo
        if (provider.availableTerms.isNotEmpty)
          _TermSelectorBar(
            availableTerms: provider.availableTerms,
            selectedTerm: provider.selectedTerm,
            currentTerm: provider.currentTerm,
            onTermChanged: (term) {
              setState(() => _selectedIndex = 0);
              provider.switchFavoriteTerm(term);
            },
            formatTerm: _formatTerm,
          ),
        // Grilla
        Expanded(
          child: ScheduleGridWidget(
            allSchedules: provider.favoriteSchedules,
            onScheduleTap: (index) {
              setState(() {
                _selectedIndex = index;
                _showOverview = true;
              });
            },
            subjectColors: _buildColorMapFromAll(provider.favoriteSchedules),
            isMobileLayout: true,
            showFavoriteButton: true,
            useLetterLabels: true,
            currentPage: 1,
            itemsPerPage: provider.favoriteSchedules.length,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No tienes horarios destacados',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Genera horarios y toca la estrella ⭐ para guardarlos aquí.\n'
              'Tus horarios destacados se conservan entre sesiones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al generador',
                  style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIDEBAR (Desktop) — Mini previews / Info mode
// ============================================================

class _FavoritesSidebar extends StatelessWidget {
  final List<List<ClassOption>> schedules;
  final int selectedIndex;
  final bool showInfo;
  final VoidCallback onToggleMode;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int) onDelete;
  final Map<String, Color> Function(List<ClassOption>) buildColorMap;
  final int Function(List<ClassOption>) calculateGaps;
  final int Function(List<ClassOption>) calculateFreeDays;
  final List<String> Function(List<ClassOption>) getSubjectNames;
  // Term props
  final List<String> availableTerms;
  final String selectedTerm;
  final String currentTerm;
  final ValueChanged<String> onTermChanged;
  final String Function(String) formatTerm;

  const _FavoritesSidebar({
    required this.schedules,
    required this.selectedIndex,
    required this.showInfo,
    required this.onToggleMode,
    required this.onSelect,
    required this.onDelete,
    required this.buildColorMap,
    required this.calculateGaps,
    required this.calculateFreeDays,
    required this.getSubjectNames,
    required this.availableTerms,
    required this.selectedTerm,
    required this.currentTerm,
    required this.onTermChanged,
    required this.formatTerm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          // Título + toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Destacados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                // Toggle entre preview y info
                Tooltip(
                  message: showInfo ? 'Ver previsualizaciones' : 'Ver información',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onToggleMode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: showInfo
                            ? const Color(0xFF2742F5).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        showInfo ? Icons.grid_view : Icons.info_outline,
                        size: 18,
                        color: showInfo
                            ? const Color(0xFF2742F5)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Selector de periodo (solo si hay más de 1)
          if (availableTerms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTerm,
                    isExpanded: true,
                    icon: const Icon(Icons.calendar_month, size: 16,
                        color: Color(0xFF6B7280)),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    items: availableTerms.map((term) {
                      final isCurrent = term == currentTerm;
                      return DropdownMenuItem(
                        value: term,
                        child: Row(
                          children: [
                            Text(formatTerm(term)),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2742F5).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('actual',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF2742F5),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (term) {
                      if (term != null) onTermChanged(term);
                    },
                  ),
                ),
              ),
            ),
          // Lista de tarjetas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: [
                  for (int i = 0; i < schedules.length; i++) ...[
                    _SidebarCard(
                      index: i,
                      isSelected: i == selectedIndex,
                      showInfo: showInfo,
                      onTap: () => onSelect(i),
                      onDelete: () => onDelete(i),
                      schedule: schedules[i],
                      subjectColors: buildColorMap(schedules[i]),
                      huecos: calculateGaps(schedules[i]),
                      diasLibres: calculateFreeDays(schedules[i]),
                      subjectNames: getSubjectNames(schedules[i]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          // Botón volver
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: _BackButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SIDEBAR CARD — Alterna entre preview de grilla e info/stats
// ============================================================

class _SidebarCard extends StatelessWidget {
  final int index;
  final bool isSelected;
  final bool showInfo;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final List<ClassOption> schedule;
  final Map<String, Color> subjectColors;
  final int huecos;
  final int diasLibres;
  final List<String> subjectNames;

  const _SidebarCard({
    required this.index,
    required this.isSelected,
    required this.showInfo,
    required this.onTap,
    required this.onDelete,
    required this.schedule,
    required this.subjectColors,
    required this.huecos,
    required this.diasLibres,
    required this.subjectNames,
  });

  String get _label => String.fromCharCode(65 + index);

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF2742F5) : const Color(0xFFE5E7EB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: const Color(0xFFF3F4F6),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                    color: borderColor, width: isSelected ? 2.5 : 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: showInfo
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildPreviewFace(),
                  secondChild: _buildInfoFace(),
                ),
              ),
            ),
            // Botón eliminar
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cara frontal: mini preview de la grilla
  Widget _buildPreviewFace() {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: IgnorePointer(
        child: ScheduleGridWidget(
          allSchedules: [schedule],
          onScheduleTap: (_) {},
          subjectColors: subjectColors,
          isMobileLayout: false,
          isScrollable: false,
          showFavoriteButton: false,
          useLetterLabels: true,
          fillParent: true,
          fillParentLabel: _label,
          currentPage: 1,
          itemsPerPage: 1,
        ),
      ),
    );
  }

  /// Cara trasera: info con stats
  Widget _buildInfoFace() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(12),
      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letra grande
          Text(
            'Opción $_label',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          // Stats
          _statRow(Icons.timelapse, 'Huecos', huecos.toString()),
          const SizedBox(height: 4),
          _statRow(Icons.wb_sunny_outlined, 'Días libres', diasLibres.toString()),
          const SizedBox(height: 4),
          _statRow(Icons.menu_book, 'Materias', subjectNames.length.toString()),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
      ],
    );
  }
}

// ============================================================
// BOTÓN VOLVER
// ============================================================

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2742F5);
    final bg = _hover ? blue : Colors.transparent;
    final fg = _hover ? Colors.white : blue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                'Volver',
                style: TextStyle(color: fg, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MOBILE — Barra de selección de periodo
// ============================================================

class _TermSelectorBar extends StatelessWidget {
  final List<String> availableTerms;
  final String selectedTerm;
  final String currentTerm;
  final ValueChanged<String> onTermChanged;
  final String Function(String) formatTerm;

  const _TermSelectorBar({
    required this.availableTerms,
    required this.selectedTerm,
    required this.currentTerm,
    required this.onTermChanged,
    required this.formatTerm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, size: 16, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          const Text('Periodo:', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableTerms.map((term) {
                  final isSelected = term == selectedTerm;
                  final isCurrent = term == currentTerm;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onTermChanged(term),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2742F5)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2742F5)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatTerm(term),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF374151),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: isSelected ? Colors.white70 : const Color(0xFF2742F5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
