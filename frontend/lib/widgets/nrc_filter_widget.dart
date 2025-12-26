// lib/widgets/nrc_filter_widget.dart
import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/class_option.dart';
import 'package:diacritic/diacritic.dart';

/// Widget que permite al usuario seleccionar NRCs específicos de una materia.
///
/// Muestra los NRCs agrupados jerárquicamente (Teóricos con sus Labs asociados)
/// y permite seleccionar combinaciones específicas.
class NrcFilterWidget extends StatefulWidget {
  /// La materia de la cual se mostrarán los NRCs.
  final Subject subject;

  /// Mapa de NRCs seleccionados (nrc -> isSelected).
  final Map<String, bool> selectedNrcs;

  /// Callback que se ejecuta cuando la selección de NRCs cambia.
  final Function(Map<String, bool>) onSelectionChanged;

  /// Set de NRCs viables (que aparecen en horarios generados).
  /// Si es null, todos los NRCs se consideran viables.
  final Set<String>? viableNrcs;

  const NrcFilterWidget({
    Key? key,
    required this.subject,
    required this.selectedNrcs,
    required this.onSelectionChanged,
    this.viableNrcs,
  }) : super(key: key);

  @override
  _NrcFilterWidgetState createState() => _NrcFilterWidgetState();
}

class _NrcFilterWidgetState extends State<NrcFilterWidget> {
  /// Lista de NRCs agrupados y ordenados para mostrar.
  List<NrcDisplayItem> displayItems = [];

  /// Mapa de NRCs seleccionados (copia local).
  late Map<String, bool> selectedNrcs;

  /// Controlador para el campo de búsqueda.
  TextEditingController searchController = TextEditingController();

  /// Lista filtrada según el término de búsqueda.
  List<NrcDisplayItem> filteredItems = [];

  @override
  void initState() {
    super.initState();
    selectedNrcs = Map.from(widget.selectedNrcs);
    _buildDisplayItems();
    filteredItems = List.from(displayItems);
  }

  @override
  void didUpdateWidget(NrcFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian los NRCs viables, reconstruir la lista
    if (widget.viableNrcs != oldWidget.viableNrcs) {
      _buildDisplayItems();
      filterItems(searchController.text);
    }
  }

  /// Construye la lista de items a mostrar, agrupando teóricos con sus labs.
  void _buildDisplayItems() {
    // Agrupar por groupId
    Map<int, List<ClassOption>> groupedByGroupId = {};
    for (var option in widget.subject.classOptions) {
      // Filtrar por viabilidad: solo incluir NRCs que sean viables
      if (widget.viableNrcs != null && !widget.viableNrcs!.contains(option.nrc)) {
        continue; // Saltar este NRC si no es viable
      }
      groupedByGroupId.putIfAbsent(option.groupId, () => []).add(option);
    }

    displayItems.clear();

    // Ordenar grupos por el primer NRC del grupo
    var sortedGroups = groupedByGroupId.entries.toList()
      ..sort((a, b) => a.value.first.nrc.compareTo(b.value.first.nrc));

    for (var group in sortedGroups) {
      List<ClassOption> options = group.value;

      // Separar teóricos, labs y teorico-practicos
      List<ClassOption> teoricos =
          options.where((o) => o.type == 'Teórico').toList();
      List<ClassOption> labs =
          options.where((o) => o.type == 'Laboratorio').toList();
      List<ClassOption> teoricoPracticos =
          options.where((o) => o.type == 'Teorico-practico').toList();

      // Teorico-practicos se muestran independientes
      for (var tp in teoricoPracticos) {
        displayItems.add(NrcDisplayItem(
          classOption: tp,
          indentLevel: 0,
          hasChildren: false,
        ));
      }

      // Teóricos con sus labs
      if (teoricos.isNotEmpty) {
        for (var teorico in teoricos) {
          displayItems.add(NrcDisplayItem(
            classOption: teorico,
            indentLevel: 0,
            hasChildren: labs.isNotEmpty,
          ));

          // Agregar labs indentados si hay
          if (labs.isNotEmpty) {
            for (var lab in labs) {
              displayItems.add(NrcDisplayItem(
                classOption: lab,
                indentLevel: 1,
                hasChildren: false,
              ));
            }
          }
        }
      } else {
        // Labs sin teórico (independientes)
        for (var lab in labs) {
          displayItems.add(NrcDisplayItem(
            classOption: lab,
            indentLevel: 0,
            hasChildren: false,
          ));
        }
      }
    }
  }

  /// Filtra los items según el término de búsqueda.
  void filterItems(String query) {
    setState(() {
      String normalizedQuery = removeDiacritics(query.toLowerCase());

      if (normalizedQuery.isEmpty) {
        filteredItems = List.from(displayItems);
      } else {
        filteredItems = displayItems.where((item) {
          var option = item.classOption;
          String searchText =
              '${option.nrc} ${option.type} ${option.professor} ${option.campus} ${_formatSchedules(option)}'
                  .toLowerCase();
          String normalizedText = removeDiacritics(searchText);
          return normalizedText.contains(normalizedQuery);
        }).toList();
      }
    });
  }

  /// Alterna la selección de un NRC con lógica de teórico-laboratorio.
  /// 
  /// Reglas:
  /// - Si se selecciona un LABORATORIO → se selecciona automáticamente su TEÓRICO
  /// - Si se deselecciona un TEÓRICO → se deseleccionan todos sus LABORATORIOS
  /// - Si se selecciona/deselecciona un TEÓRICO sin labs → comportamiento normal
  /// - Si se deselecciona un LABORATORIO → el teórico puede seguir seleccionado
  void toggleSelection(String nrc) {
    setState(() {
      // Buscar la opción de clase correspondiente al NRC
      ClassOption? clickedOption;
      try {
        clickedOption = widget.subject.classOptions
            .firstWhere((opt) => opt.nrc == nrc);
      } catch (e) {
        return; // Si no se encuentra el NRC, salir
      }
      
      bool newValue = !(selectedNrcs[nrc] ?? false);
      selectedNrcs[nrc] = newValue;
      
      // CASO 1: Se está SELECCIONANDO un LABORATORIO
      // → Buscar y seleccionar automáticamente su teórico padre
      if (newValue && clickedOption.type == 'Laboratorio') {
        // Buscar el teórico del mismo grupo
        try {
          ClassOption parentTeorico = widget.subject.classOptions.firstWhere(
            (opt) => opt.groupId == clickedOption!.groupId && opt.type == 'Teórico',
          );
          selectedNrcs[parentTeorico.nrc] = true;
        } catch (e) {
          // No hay teórico padre, continuar normalmente
        }
      }
      
      // CASO 2: Se está DESELECCIONANDO un TEÓRICO
      // → Deseleccionar automáticamente todos sus laboratorios
      if (!newValue && clickedOption.type == 'Teórico') {
        // Buscar todos los laboratorios del mismo grupo
        List<ClassOption> childLabs = widget.subject.classOptions
            .where((opt) => opt.groupId == clickedOption!.groupId && opt.type == 'Laboratorio')
            .toList();
        
        for (var lab in childLabs) {
          selectedNrcs[lab.nrc] = false;
        }
      }
      
      widget.onSelectionChanged(selectedNrcs);
    });
  }

  /// Formatea los horarios de una clase para mostrar.
  String _formatSchedules(ClassOption option) {
    if (option.schedules.isEmpty) return 'Por definir';

    // Agrupar por día
    Map<String, List<String>> schedulesByDay = {};
    for (var schedule in option.schedules) {
      schedulesByDay.putIfAbsent(schedule.day, () => []).add(schedule.time);
    }

    // Formatear
    List<String> parts = [];
    schedulesByDay.forEach((day, times) {
      String dayShort = _getDayAbbreviation(day);
      parts.add('$dayShort ${times.first}');
    });

    return parts.join(', ');
  }

  /// Obtiene abreviatura del día.
  String _getDayAbbreviation(String day) {
    const abbr = {
      'Lunes': 'L',
      'Martes': 'M',
      'Miércoles': 'X',
      'Jueves': 'J',
      'Viernes': 'V',
      'Sábado': 'S',
      'Domingo': 'D',
    };
    return abbr[day] ?? day.substring(0, 1);
  }

  /// Obtiene ícono según el tipo de clase.
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Teórico':
        return Icons.school;
      case 'Laboratorio':
        return Icons.science;
      case 'Teorico-practico':
        return Icons.book;
      default:
        return Icons.class_;
    }
  }

  /// Obtiene ícono según la modalidad (inferida del campus).
  IconData _getModalityIcon(String campus) {
    String campusLower = campus.toLowerCase();
    if (campusLower.contains('virtual') || campusLower.contains('remoto')) {
      return Icons.computer;
    } else if (campusLower.contains('híbrido') || campusLower.contains('hibrido')) {
      return Icons.sync_alt;
    } else {
      return Icons.location_on;
    }
  }

  /// Obtiene texto de modalidad.
  String _getModalityText(String campus) {
    String campusLower = campus.toLowerCase();
    if (campusLower.contains('virtual') || campusLower.contains('remoto')) {
      return 'Virtual';
    } else if (campusLower.contains('híbrido') || campusLower.contains('hibrido')) {
      return 'Híbrido';
    } else {
      return 'Presencial';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de búsqueda
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Buscar NRC, profesor, horario...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: filterItems,
          ),
        ),
        // Lista de NRCs
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    searchController.text.isNotEmpty
                        ? 'No hay resultados para la búsqueda'
                        : 'No hay NRCs disponibles para esta materia',
                    style: TextStyle(color: textColor),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final option = item.classOption;
                    final isSelected = selectedNrcs[option.nrc] ?? false;

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 16.0 * item.indentLevel,
                      ),
                      child: CheckboxListTile(
                        title: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Primera línea: Tipo y NRC
                                  Row(
                                    children: [
                                      Icon(
                                        _getTypeIcon(option.type),
                                        size: 16,
                                        color: textColor.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${option.type} NRC-${option.nrc}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Segunda línea: Modalidad
                                  Row(
                                    children: [
                                      Icon(
                                        _getModalityIcon(option.campus),
                                        size: 14,
                                        color: textColor.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getModalityText(option.campus),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  // Ícono de tipo
                                  Icon(
                                    _getTypeIcon(option.type),
                                    size: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  // Tipo y NRC
                                  Flexible(
                                    child: Text(
                                      '${option.type} NRC-${option.nrc}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Ícono de modalidad
                                  Icon(
                                    _getModalityIcon(option.campus),
                                    size: 14,
                                    color: textColor.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  // Modalidad
                                  Text(
                                    _getModalityText(option.campus),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prof. ${option.professor}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              _formatSchedules(option),
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (_) => toggleSelection(option.nrc),
                        controlAffinity: ListTileControlAffinity.trailing,
                        dense: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

/// Clase auxiliar para representar un item en la lista de NRCs.
class NrcDisplayItem {
  final ClassOption classOption;
  final int indentLevel; // 0 = sin indentar, 1 = indentado (labs)
  final bool hasChildren; // true si es un teórico que tiene labs

  NrcDisplayItem({
    required this.classOption,
    required this.indentLevel,
    required this.hasChildren,
  });
}