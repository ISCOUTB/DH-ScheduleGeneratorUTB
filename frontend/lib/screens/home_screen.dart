// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../models/subject.dart';
import '../providers/schedule_provider.dart';
import '../services/api_service.dart';

// Widgets existentes
import '../widgets/search_widget.dart';
import '../widgets/filter_widget.dart';
import '../widgets/subjects_panel.dart';
import '../widgets/main_actions_panel.dart';
import '../widgets/schedule_grid_widget.dart';
import '../widgets/schedule_overview_widget.dart';
import '../widgets/schedule_sort_widget.dart';

// Nuevos widgets extraídos
import '../widgets/common/common.dart';
import '../widgets/dialogs/dialogs.dart';
import '../widgets/layout/layout.dart';

// Utils
import '../utils/platform_service_stub.dart'
    if (dart.library.html) '../utils/platform_service_web.dart';

/// Pantalla principal de la aplicación.
class HomeScreen extends StatefulWidget {
  final String title;
  final User currentUser;
  final VoidCallback onLogout;

  const HomeScreen({
    Key? key,
    required this.title,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final PlatformService _platformService = PlatformService();
  final ScrollController _mobileScrollController = ScrollController();
  final TransformationController _transformationController = TransformationController();
  
  late FocusNode _focusNode;
  Orientation? _previousOrientation;
  bool _showWelcomeDialog = true;
  String? _lastShownError;
  int _errorShowCount = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _checkAndShowImportantNotice();
      
      // Cargar materias usando el provider
      context.read<ScheduleProvider>().loadAllSubjects();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }

  bool _isMobile() {
    if (kIsWeb) {
      return _platformService.isMobileUserAgent();
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _checkAndShowImportantNotice() {
    if (kIsWeb) {
      final hasSeenNotice = _platformService.getLocalStorage('has_seen_important_notice');
      if (hasSeenNotice == null || hasSeenNotice != 'true') {
        _showImportantNoticeDialog();
      }
    } else if (_showWelcomeDialog) {
      _showImportantNoticeDialog();
    }
  }

  void _showImportantNoticeDialog() {
    ImportantNoticeDialog.show(
      context,
      onDismiss: () {
        if (kIsWeb) {
          _platformService.setLocalStorage('has_seen_important_notice', 'true');
        } else {
          setState(() => _showWelcomeDialog = false);
        }
      },
    );
  }

  Future<void> _launchURL(String urlString) async {
    final provider = context.read<ScheduleProvider>();
    if (provider.isMobileMenuOpen) {
      provider.setMobileMenuOpen(false);
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showCustomNotification(context, 'No se pudo abrir el enlace',
            icon: Icons.error, color: Colors.red);
      }
    }
  }

  void _openTutorial() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=rFi0M0gcMHM');
    if (!await launchUrl(url)) {
      showCustomNotification(context, 'No se pudo abrir el tutorial',
          icon: Icons.error, color: Colors.red);
    }
  }

  Future<void> _handleAddSubject(Subject subject) async {
    final provider = context.read<ScheduleProvider>();
    
    // Evento de Analytics
    analytics.logEvent(
      name: 'add_subject',
      parameters: {
        'subject_code': subject.code,
        'subject_name': subject.name,
        'credits': subject.credits,
      },
    );

    final message = provider.addSubject(subject);
    
    if (message != null) {
      if (message.contains('Advertencia')) {
        showCustomNotification(context, message, icon: Icons.info, color: Colors.orange);
      } else if (message.contains('agregada') || message.contains('alcanzado')) {
        showCustomNotification(context, message, 
            icon: Icons.info, 
            color: message.contains('alcanzado') ? Colors.red : Colors.green);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Materia agregada: ${subject.name}')),
    );
  }

  void _handleRemoveSubject(Subject subject) {
    final provider = context.read<ScheduleProvider>();
    provider.removeSubject(subject);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Materia eliminada: ${subject.name}')),
    );
  }

  void _handleClearSchedules() {
    ClearConfirmationDialog.show(
      context,
      onConfirm: () {
        context.read<ScheduleProvider>().clearAll();
        showCustomNotification(context, 'Aplicación reiniciada completamente.',
            icon: Icons.refresh, color: Colors.green);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobileLayout = constraints.maxWidth < AppConfig.mobileBreakpoint;

        return Consumer<ScheduleProvider>(
          builder: (context, provider, child) {
            // Se muestra si hay un error y es diferente al último mostrado
            // O si es el mismo pero hubo un clearError() en el medio (detectado por el contador)
            if (provider.errorMessage != null && !provider.isLoading) {
              final currentError = '${provider.errorMessage}_${_errorShowCount}';
              
              if (_lastShownError != currentError) {
                _lastShownError = currentError;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && provider.errorMessage != null) {
                    showCustomNotification(
                      context, 
                      provider.errorMessage!,
                      icon: provider.errorIcon ?? Icons.error,
                      color: provider.errorColor ?? Colors.red,
                    );
                    _errorShowCount++;
                    provider.clearError();
                  }
                });
              }
            } else if (provider.errorMessage == null && _lastShownError != null) {
              // Reset cuando no hay error
              _lastShownError = null;
            }
            
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: (isMobileLayout && provider.isSearchOpen)
                  ? null
                  : _buildAppBar(isMobileLayout, provider),
              body: Stack(
                children: [
                  // Contenido principal
                  isMobileLayout
                      ? _buildMobileLayout(provider)
                      : _buildDesktopLayout(provider, isMobileLayout),

                  // FAB para móvil
                  if (isMobileLayout)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: SpeedDialMenu(
                        onSearch: () => provider.setSearchOpen(true),
                        onFilter: () => provider.setFilterOpen(true),
                        onTutorial: _openTutorial,
                        onShowCreators: () => CreatorsDialog.show(context),
                        onClear: _handleClearSchedules,
                      ),
                    ),

                  // Contador de horarios (móvil)
                  if (isMobileLayout && provider.allSchedules.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: ScheduleCounterBadge(count: provider.allSchedules.length),
                    ),

                  // Overlays
                  ..._buildOverlays(provider, isMobileLayout),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobileLayout, ScheduleProvider provider) {
    return AppBar(
      backgroundColor: AppColors.primary,
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
        if (!isMobileLayout) ..._buildDesktopActions(provider),
        if (isMobileLayout) ...[
          _buildMobileUserMenu(),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => provider.toggleMobileMenu(),
          ),
        ],
        const SizedBox(width: 16),
      ],
    );
  }

  List<Widget> _buildDesktopActions(ScheduleProvider provider) {
    return [
      _buildNavButton('Mi UTB', 'https://www.utb.edu.co/mi-utb/'),
      _buildNavButton('Turnos', 'https://sites.google.com/view/turnos-de-matricula-web-utb/turnos?authuser=0'),
      _buildNavButton('Mallas', 'https://sites.google.com/utb.edu.co/mallasutb/mallas-curriculares'),
      _buildNavButton('Electivas', 'https://sites.google.com/utb.edu.co/stuplan-electivas/electivas'),
      _buildNavButton('Reportar Error', 'https://docs.google.com/forms/d/e/1FAIpQLSeG6F1lWErfKEtTo4R8OmF6ZCpjrqKqosn_7KLgHpLCYTuDFw/viewform?usp=publish-editor'),
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
    ];
  }

  Widget _buildNavButton(String text, String url) {
    return TextButton(
      style: TextButton.styleFrom(overlayColor: Colors.transparent),
      onPressed: () => _launchURL(url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: NavLink(text: text),
      ),
    );
  }

  Widget _buildMobileUserMenu() {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Text(
          widget.currentUser.initials,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      tooltip: widget.currentUser.displayName,
      color: Colors.white,
      offset: const Offset(0, 50),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentUser.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (widget.currentUser.email != null)
                Text(
                  widget.currentUser.email!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              const Divider(),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      onSelected: (String value) {
        if (value == 'logout') {
          widget.onLogout();
        }
      },
    );
  }

  List<Widget> _buildOverlays(ScheduleProvider provider, bool isMobileLayout) {
    final overlays = <Widget>[];

    // Menú móvil
    if (isMobileLayout && provider.isMobileMenuOpen) {
      overlays.add(
        Positioned(
          top: 0,
          right: 0,
          child: MobileMenu(
            items: [
              MobileMenuItem(label: 'Mi UTB', onTap: () => _launchURL('https://www.utb.edu.co/mi-utb/')),
              MobileMenuItem(label: 'Turnos', onTap: () => _launchURL('https://sites.google.com/view/turnos-de-matricula-web-utb/turnos?authuser=0')),
              MobileMenuItem(label: 'Mallas', onTap: () => _launchURL('https://sites.google.com/utb.edu.co/mallasutb/mallas-curriculares')),
              MobileMenuItem(label: 'Electivas', onTap: () => _launchURL('https://sites.google.com/utb.edu.co/stuplan-electivas/electivas')),
              MobileMenuItem(label: 'Reportar Error', onTap: () => _launchURL('https://docs.google.com/forms/d/e/1FAIpQLSeG6F1lWErfKEtTo4R8OmF6ZCpjrqKqosn_7KLgHpLCYTuDFw/viewform?usp=publish-editor')),
            ],
          ),
        ),
      );
    }

    // Loading
    if (provider.isLoading) {
      overlays.add(const LoadingOverlay(message: 'Generando horarios...'));
    }

    // Search
    if (provider.isSearchOpen) {
      overlays.add(_buildSearchOverlay(provider));
    }

    // Filter
    if (provider.isFilterOpen) {
      overlays.add(_buildFilterOverlay(provider));
    }

    // Schedule Overview
    if (provider.isOverviewOpen && provider.selectedScheduleIndex != null) {
      overlays.add(_buildOverviewOverlay(provider));
    }

    return overlays;
  }

  Widget _buildSearchOverlay(ScheduleProvider provider) {
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black45),
        Center(
          child: provider.areSubjectsLoaded
              ? SearchSubjectsWidget(
                  subjectController: TextEditingController(),
                  allSubjects: provider.allSubjectsList,
                  onSubjectSelected: (subjectSummary) async {
                    provider.setSearchOpen(false);
                    
                    try {
                      final fullSubject = await _apiService.getSubjectDetails(
                        subjectSummary.code,
                        subjectSummary.name,
                      );
                      _handleAddSubject(fullSubject);
                    } catch (e) {
                      if (mounted) {
                        showCustomNotification(context, 'Error al cargar detalles: ${e.toString()}',
                            icon: Icons.error, color: Colors.red);
                      }
                    }
                  },
                  closeWindow: () => provider.setSearchOpen(false),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildFilterOverlay(ScheduleProvider provider) {
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black45),
        Center(
          child: FilterWidget(
            closeWindow: () => provider.setFilterOpen(false),
            onApplyFilters: provider.applyFilters,
            onClearFilters: provider.clearFilters,
            currentFilters: provider.appliedFilters,
            addedSubjects: provider.addedSubjects,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewOverlay(ScheduleProvider provider) {
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black45),
        Center(
          child: ScheduleOverviewWidget(
            schedule: provider.allSchedules[provider.selectedScheduleIndex!],
            onClose: provider.closeScheduleOverview,
            subjectColors: provider.subjectColorMap,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ScheduleProvider provider) {
    return ListView(
      controller: _mobileScrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        ScheduleSortWidget(
          currentOptimizations: provider.currentOptimizations,
          onOptimizationChanged: provider.updateOptimizations,
          isEnabled: provider.allSchedules.isNotEmpty,
          isMobileLayout: true,
        ),
        const SizedBox(height: 16),
        SubjectsPanel(
          isFullExpandedView: provider.isFullExpandedView,
          addedSubjects: provider.addedSubjects,
          usedCredits: provider.usedCredits,
          creditLimit: provider.creditLimit,
          subjectColors: provider.subjectColorMap,
          onShowPanel: () => provider.setFullExpandedView(false),
          onHidePanel: () => provider.setFullExpandedView(true),
          onAddSubject: () => provider.setSearchOpen(true),
          onToggleExpandView: () => provider.toggleExpandedView(),
          onRemoveSubject: _handleRemoveSubject,
          isExpandedView: provider.isExpandedView,
          isMobileLayout: true,
        ),
        const SizedBox(height: 16),
        _buildScheduleArea(provider, isMobileLayout: true),
      ],
    );
  }

  Widget _buildDesktopLayout(ScheduleProvider provider, bool isMobileLayout) {
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_isMobile() && _previousOrientation != null && _previousOrientation != currentOrientation) {
      _transformationController.value = Matrix4.identity();
    }
    _previousOrientation = currentOrientation;

    return _isMobile()
        ? InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.25,
            maxScale: 4.0,
            constrained: false,
            child: SizedBox(
              width: 1400,
              height: 900,
              child: _buildBodyContent(provider, isMobileLayout),
            ),
          )
        : _buildBodyContent(provider, isMobileLayout);
  }

  Widget _buildBodyContent(ScheduleProvider provider, bool isMobileLayout) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!provider.isExpandedView) ...[
                  MainActionsPanel(
                    onSearch: () => provider.setSearchOpen(true),
                    onFilter: () => provider.setFilterOpen(true),
                    onClear: _handleClearSchedules,
                    onGenerate: _openTutorial,
                  ),
                  const SizedBox(height: 20),
                  _buildSortAndClearRow(provider, isMobileLayout),
                  const SizedBox(height: 24),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      _buildScheduleArea(provider, isMobileLayout: false),
                      if (provider.allSchedules.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: PaginationControl(
                            currentPage: provider.currentPage,
                            totalPages: provider.totalPages,
                            itemsPerPage: provider.itemsPerPage,
                            totalItems: provider.allSchedules.length,
                            onPageChanged: provider.setCurrentPage,
                            onItemsPerPageChanged: provider.setItemsPerPage,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          SubjectsPanel(
            isFullExpandedView: provider.isFullExpandedView,
            addedSubjects: provider.addedSubjects,
            usedCredits: provider.usedCredits,
            creditLimit: provider.creditLimit,
            subjectColors: provider.subjectColorMap,
            onShowPanel: () => provider.setFullExpandedView(false),
            onHidePanel: () => provider.setFullExpandedView(true),
            onAddSubject: () => provider.setSearchOpen(true),
            onToggleExpandView: () => provider.toggleExpandedView(),
            onRemoveSubject: _handleRemoveSubject,
            isExpandedView: provider.isExpandedView,
            isMobileLayout: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndClearRow(ScheduleProvider provider, bool isMobileLayout) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double totalWidth = constraints.maxWidth;
        double spaceBetween = 20;
        double clearButtonWidth = (totalWidth - 2 * spaceBetween) / 3;
        double sortWidth = totalWidth - clearButtonWidth - spaceBetween;

        return Row(
          children: [
            SizedBox(
              width: sortWidth,
              child: ScheduleSortWidget(
                currentOptimizations: provider.currentOptimizations,
                onOptimizationChanged: provider.updateOptimizations,
                isEnabled: provider.allSchedules.isNotEmpty,
                isMobileLayout: isMobileLayout,
              ),
            ),
            SizedBox(width: spaceBetween),
            SizedBox(
              width: clearButtonWidth,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _handleClearSchedules,
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
                    Icon(Icons.refresh, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleArea(ScheduleProvider provider, {required bool isMobileLayout}) {
    if (provider.allSchedules.isEmpty) {
      return Container(
        height: isMobileLayout ? 300 : null,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade400, width: 2),
        ),
        child: Center(
          child: Text(
            "Vista previa del horario",
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ScheduleGridWidget(
      allSchedules: provider.allSchedules,
      onScheduleTap: provider.selectSchedule,
      isMobileLayout: isMobileLayout,
      subjectColors: provider.subjectColorMap,
      currentPage: provider.currentPage,
      itemsPerPage: provider.itemsPerPage,
      isScrollable: !isMobileLayout,
      scrollController: isMobileLayout ? _mobileScrollController : null,
    );
  }
}
