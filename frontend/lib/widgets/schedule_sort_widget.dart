// /frontend/lib/widgets/schedule_sort_widget.dart
import 'package:flutter/material.dart';

/// Widget para ordenar y configurar la optimización de horarios generados
class ScheduleSortWidget extends StatefulWidget {
  /// Opciones de optimización actuales
  final Map<String, dynamic> currentOptimizations;

  /// Callback cuando cambian las opciones de optimización
  final Function(Map<String, dynamic>) onOptimizationChanged;

  /// Si el widget está habilitado o no
  final bool isEnabled;

  /// Determina si se debe usar el layout para móvil
  final bool isMobileLayout;

  const ScheduleSortWidget({
    Key? key,
    required this.currentOptimizations,
    required this.onOptimizationChanged,
    this.isEnabled = true,
    this.isMobileLayout = false, // <-- CAMBIO: Nuevo parámetro
  }) : super(key: key);

  @override
  _ScheduleSortWidgetState createState() => _ScheduleSortWidgetState();
}

class _ScheduleSortWidgetState extends State<ScheduleSortWidget> {
  bool _optimizeGaps = false;
  bool _optimizeFreeDays = false;

  @override
  void initState() {
    super.initState();
    _initializeFromCurrentOptimizations();
  }

  @override
  void didUpdateWidget(ScheduleSortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si las optimizaciones cambiaron desde el exterior, actualizar el estado interno
    if (widget.currentOptimizations != oldWidget.currentOptimizations) {
      _initializeFromCurrentOptimizations();
    }
  }

  /// Inicializa el estado basado en las optimizaciones actuales
  void _initializeFromCurrentOptimizations() {
    setState(() {
      _optimizeGaps = widget.currentOptimizations['optimizeGaps'] ?? false;
      _optimizeFreeDays =
          widget.currentOptimizations['optimizeFreeDays'] ?? false;
    });
  }

  /// Maneja el cambio de optimización de huecos
  void _handleGapsChange(bool value) {
    if (!widget.isEnabled) return;

    setState(() {
      _optimizeGaps = value;
    });

    _notifyOptimizationChanged();
  }

  /// Maneja el cambio de optimización de días libres
  void _handleFreeDaysChange(bool value) {
    if (!widget.isEnabled) return;

    setState(() {
      _optimizeFreeDays = value;
    });

    _notifyOptimizationChanged();
  }

  /// Notifica los cambios al widget padre
  void _notifyOptimizationChanged() {
    widget.onOptimizationChanged({
      'optimizeGaps': _optimizeGaps,
      'optimizeFreeDays': _optimizeFreeDays,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lógica para elegir el layout
    return widget.isMobileLayout ? _buildMobileLayout() : _buildDesktopLayout();
  }

  // Layout original extraído a su propio método
  Widget _buildDesktopLayout() {
    return Container(
      height: 60,
      decoration: _buildContainerDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTitleContent(),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildOption(
                      'Menos huecos',
                      _optimizeGaps,
                      _handleGapsChange,
                    ),
                  ),
                  _buildSeparator(),
                  Expanded(
                    child: _buildOption(
                      'Más días libres',
                      _optimizeFreeDays,
                      _handleFreeDaysChange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nuevo método para el layout móvil
  Widget _buildMobileLayout() {
    return Container(
      decoration: _buildContainerDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleContent(),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 4),
          _buildOption('Menos huecos', _optimizeGaps, _handleGapsChange),
          _buildOption(
              'Más días libres', _optimizeFreeDays, _handleFreeDaysChange),
        ],
      ),
    );
  }

  // --- Métodos de ayuda para construir partes de la UI ---

  /// Construye la decoración del contenedor principal
  BoxDecoration _buildContainerDecoration() {
    return BoxDecoration(
      color: widget.isEnabled ? Colors.white : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: widget.isEnabled ? Colors.grey.shade300 : Colors.grey.shade200,
        width: 1.5,
      ),
      boxShadow: widget.isEnabled
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          : [],
    );
  }

  /// Construye el título "Ordenar Horarios por:" con su ícono
  Widget _buildTitleContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sort,
          color: widget.isEnabled ? Colors.grey.shade700 : Colors.grey.shade400,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          'Ordenar Horarios por:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                widget.isEnabled ? Colors.grey.shade800 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  /// Construye una fila de opción con texto y switch
  Widget _buildOption(String label, bool value, ValueChanged<bool> onChanged) {
    final textStyle = TextStyle(
      fontSize: 14, // Aumentado para mejor legibilidad en móvil
      fontWeight: FontWeight.w400,
      color: widget.isEnabled ? Colors.grey.shade700 : Colors.grey.shade400,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Transform.scale(
          scale: 0.85, // Ligeramente más grande
          child: Switch(
            value: value,
            onChanged: widget.isEnabled ? onChanged : null,
            activeColor: Colors.amber.shade600,
            activeTrackColor: Colors.amber.shade300,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade300,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  /// Construye el separador vertical
  Widget _buildSeparator() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
