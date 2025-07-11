// lib/widgets/schedule_sort_widget.dart
import 'package:flutter/material.dart';

/// Widget para ordenar y configurar la optimización de horarios generados
class ScheduleSortWidget extends StatefulWidget {
  /// Opciones de optimización actuales
  final Map<String, dynamic> currentOptimizations;
  
  /// Callback cuando cambian las opciones de optimización
  final Function(Map<String, dynamic>) onOptimizationChanged;
  
  /// Si el widget está habilitado o no
  final bool isEnabled;

  const ScheduleSortWidget({
    Key? key,
    required this.currentOptimizations,
    required this.onOptimizationChanged,
    this.isEnabled = true,
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
      _optimizeFreeDays = widget.currentOptimizations['optimizeFreeDays'] ?? false;
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
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: widget.isEnabled ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isEnabled ? Colors.grey.shade400 : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: widget.isEnabled 
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Icono
            Icon(
              Icons.sort,
              color: widget.isEnabled 
                ? Colors.grey.shade700
                : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            
            // Texto principal
            Text(
              'Ordenar Horarios por:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.isEnabled 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade400,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Opciones con switches
            Expanded(
              child: Row(
                children: [
                  // Opción 1: Menos huecos
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Menos huecos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: widget.isEnabled 
                                ? Colors.grey.shade700 
                                : Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: _optimizeGaps,
                            onChanged: widget.isEnabled ? _handleGapsChange : null,
                            activeColor: Colors.amber.shade600,
                            activeTrackColor: Colors.amber.shade300,
                            inactiveThumbColor: Colors.grey.shade400,
                            inactiveTrackColor: Colors.grey.shade300,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Separador visual
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey.shade400,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  
                  // Opción 2: Días libres
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Más días libres',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: widget.isEnabled 
                                ? Colors.grey.shade700 
                                : Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: _optimizeFreeDays,
                            onChanged: widget.isEnabled ? _handleFreeDaysChange : null,
                            activeColor: Colors.amber.shade600,
                            activeTrackColor: Colors.amber.shade300,
                            inactiveThumbColor: Colors.grey.shade400,
                            inactiveTrackColor: Colors.grey.shade300,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
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
}
