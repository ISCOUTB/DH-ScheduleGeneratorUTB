// lib/widgets/custom_course/custom_course_wizard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:diacritic/diacritic.dart';

import '../../config/constants.dart';
import '../../models/custom_course.dart';
import '../../models/schedule.dart';
import '../../models/subject_summary.dart';
import '../../providers/schedule_provider.dart';
import '../../services/api_service.dart';

// Días y horas de la grilla. Los bloques de clase terminan siempre en :50
// (una clase de 1h que empieza a las 9 termina 9:50; una de 2h que empieza a
// las 8 termina 9:50). Por eso el usuario marca HORAS y el rango se arma solo.
const List<String> _kFullDays = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const List<String> _kAbbrevDays = [
  'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
];
const int _kFirstHour = 7;
const int _kLastHour = 20;

/// Paso a paso para crear o editar un curso personalizado:
/// 1) materia (del catálogo), 2) franja (grilla clic/arrastre), 3) datos.
class CustomCourseWizard extends StatefulWidget {
  final CustomCourse? existing;
  const CustomCourseWizard({Key? key, this.existing}) : super(key: key);

  static Future<void> show(BuildContext context, {CustomCourse? existing}) {
    return showDialog(
      context: context,
      builder: (_) => CustomCourseWizard(existing: existing),
    );
  }

  @override
  State<CustomCourseWizard> createState() => _CustomCourseWizardState();
}

class _CustomCourseWizardState extends State<CustomCourseWizard> {
  final ApiService _api = ApiService();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _profController = TextEditingController();
  final TextEditingController _nrcController = TextEditingController();

  int _step = 0;
  List<SubjectSummary> _catalog = [];
  bool _loadingCatalog = true;
  SubjectSummary? _materia;
  final Set<String> _selected = {}; // "dayIdx:hour"
  bool _saving = false;

  Timer? _nrcDebounce;
  bool _nrcChecking = false;
  String? _nrcError; // "ya existe en la materia X" / "debe tener 4 dígitos"

  /// Nombre que se usará si el usuario deja el campo vacío (solo para mostrarlo
  /// como pista debajo del campo). Ej. "Curso A".
  String _defaultName = 'Curso A';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    final ex = widget.existing;
    if (ex != null) {
      _materia = SubjectSummary(code: ex.code, name: ex.name, credits: ex.credits);
      _labelController.text = ex.etiqueta ?? '';
      _profController.text = ex.professor ?? '';
      _nrcController.text = ex.nrc.startsWith('CP') ? '' : ex.nrc;
      _selected.addAll(_selectedFromBloques(ex.bloques));
    } else {
      // El campo queda vacío; el default solo se muestra como pista y se aplica
      // al guardar si el usuario no escribe nada.
      _defaultName = _defaultLabel();
    }
  }

  @override
  void dispose() {
    _nrcDebounce?.cancel();
    _labelController.dispose();
    _profController.dispose();
    _nrcController.dispose();
    super.dispose();
  }

  /// Primer "Curso X" (A, B, … Z, AA, …) que no choque con los que ya tiene.
  String _defaultLabel() {
    final taken = context
        .read<ScheduleProvider>()
        .customCourses
        .map((c) => c.etiqueta)
        .whereType<String>()
        .toSet();
    for (int i = 0;; i++) {
      final label = 'Curso ${_excelLetter(i)}';
      if (!taken.contains(label)) return label;
    }
  }

  // 0->A, 25->Z, 26->AA (estilo columna de Excel), por si pasan de 26.
  String _excelLetter(int n) {
    String s = '';
    do {
      s = String.fromCharCode(65 + (n % 26)) + s;
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return s;
  }

  Future<void> _loadCatalog() async {
    try {
      final cat = await _api.getSubjectsCatalog();
      if (mounted) setState(() { _catalog = cat; _loadingCatalog = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  // ── Conversión bloques <-> celdas ──────────────────────────────────────────

  Set<String> _selectedFromBloques(List<Schedule> bloques) {
    final s = <String>{};
    for (final b in bloques) {
      final d = _kFullDays.indexOf(b.day);
      if (d < 0) continue;
      final parts = b.time.split(' - ');
      final start = int.tryParse(parts[0].split(':')[0]) ?? 0;
      final end = parts.length > 1 ? (int.tryParse(parts[1].split(':')[0]) ?? start) : start;
      for (int h = start; h <= end; h++) s.add('$d:$h');
    }
    return s;
  }

  String _p(int h) => h.toString().padLeft(2, '0');

  List<Schedule> _buildBloques() {
    final Map<int, List<int>> byDay = {};
    for (final id in _selected) {
      final p = id.split(':');
      byDay.putIfAbsent(int.parse(p[0]), () => []).add(int.parse(p[1]));
    }
    final out = <Schedule>[];
    byDay.forEach((d, hours) {
      hours.sort();
      int runStart = hours.first, prev = hours.first;
      for (int i = 1; i < hours.length; i++) {
        if (hours[i] == prev + 1) {
          prev = hours[i];
        } else {
          out.add(Schedule(day: _kFullDays[d], time: '${_p(runStart)}:00 - ${_p(prev)}:50'));
          runStart = hours[i];
          prev = hours[i];
        }
      }
      out.add(Schedule(day: _kFullDays[d], time: '${_p(runStart)}:00 - ${_p(prev)}:50'));
    });
    return out;
  }

  // ── Validación NRC en vivo ──────────────────────────────────────────────────

  void _onNrcChanged(String value) {
    _nrcDebounce?.cancel();
    final nrc = value.trim();
    if (nrc.isEmpty) {
      setState(() { _nrcError = null; _nrcChecking = false; });
      return;
    }
    // Un NRC de la oferta tiene 4 dígitos. Con menos, no se consulta al backend.
    if (nrc.length != 4) {
      setState(() { _nrcChecking = false; _nrcError = 'El NRC debe tener 4 dígitos.'; });
      return;
    }
    setState(() { _nrcChecking = true; _nrcError = null; });
    _nrcDebounce = Timer(const Duration(milliseconds: 450), () async {
      final materia = await _api.checkNrcTaken(nrc);
      if (!mounted || _nrcController.text.trim() != nrc) return;
      setState(() {
        _nrcChecking = false;
        _nrcError = materia == null
            ? null
            : 'Ese NRC ya existe en la materia $materia. Usa otro.';
      });
    });
  }

  // ── Guardar ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nrcError != null) return;
    setState(() => _saving = true);

    final bloques = _buildBloques();
    final prof = _profController.text.trim();
    final nrc = _nrcController.text.trim();
    // Si borró el nombre, se le pone el default para que nunca quede sin uno.
    final label = _labelController.text.trim();
    final etiqueta = label.isEmpty ? _defaultLabel() : label;
    final provider = context.read<ScheduleProvider>();

    if (_isEdit) {
      await provider.updateCustomCourse(
        widget.existing!.id,
        bloques: bloques,
        etiqueta: etiqueta,
        professor: prof.isEmpty ? null : prof,
        nrc: nrc.isEmpty ? null : nrc,
      );
    } else {
      await provider.createCustomCourse(
        code: _materia!.code,
        name: _materia!.name,
        bloques: bloques,
        etiqueta: etiqueta,
        professor: prof.isEmpty ? null : prof,
        nrc: nrc.isEmpty ? null : nrc,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ── Navegación de pasos ─────────────────────────────────────────────────────

  bool get _canNext {
    if (_step == 0) return _materia != null;
    if (_step == 1) return _selected.isNotEmpty;
    return true;
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Editar curso personalizado' : 'Nuevo curso personalizado',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _stepsHeader(),
              const Divider(height: 20),
              Expanded(child: _buildStepBody()),
              const Divider(height: 20),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: (_saving || !_canNext) ? null : _next,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_step < 2 ? 'Siguiente' : (_isEdit ? 'Guardar' : 'Crear')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepsHeader() {
    const titles = ['Materia', 'Horario', 'Datos'];
    return Row(
      children: List.generate(titles.length, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: active || done ? AppColors.primary : Colors.grey.shade300,
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${i + 1}', style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.grey.shade700)),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(titles[i], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
              if (i < titles.length - 1) const Expanded(child: Divider(indent: 4, endIndent: 4)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _stepMateria();
      case 1:
        return _stepHorario();
      default:
        return _stepDatos();
    }
  }

  // Paso 1
  Widget _stepMateria() {
    if (_isEdit) {
      return Align(
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
          child: Text('${_materia!.name}  ·  ${_materia!.code}'),
        ),
      );
    }
    if (_loadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿A qué materia pertenece el curso?', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Autocomplete<SubjectSummary>(
          displayStringForOption: (s) => '${s.name} (${s.code})',
          optionsBuilder: (value) {
            // Insensible a mayúsculas y tildes (igual que el buscador principal).
            final q = removeDiacritics(value.text.toLowerCase().trim());
            if (q.isEmpty) return const Iterable<SubjectSummary>.empty();
            return _catalog.where((s) =>
                removeDiacritics(s.name.toLowerCase()).contains(q) ||
                removeDiacritics(s.code.toLowerCase()).contains(q));
          },
          onSelected: (s) => setState(() => _materia = s),
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            if (_materia != null && controller.text.isEmpty) {
              controller.text = '${_materia!.name} (${_materia!.code})';
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: _dec('Busca por nombre o código'),
            );
          },
        ),
        if (_materia != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Seleccionada: ${_materia!.name} · ${_materia!.credits.toStringAsFixed(_materia!.credits.truncateToDouble() == _materia!.credits ? 0 : 1)} cr.',
                style: TextStyle(color: Colors.grey.shade700)),
          ),
      ],
    );
  }

  // Paso 2. En pantallas anchas: grilla clic/arrastre. En móvil: formulario
  // agregar-bloque (día + De/A), más cómodo que celdas diminutas.
  Widget _stepHorario() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isMobile ? 'Agrega los bloques de clase.' : 'Marca los bloques (clic o arrastrando).',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('Los minutos son automáticos: cada bloque de 1h termina en :50.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Expanded(
          child: isMobile
              ? _BlockForm(selected: _selected, onChanged: () => setState(() {}))
              : _GridSelector(selected: _selected, onChanged: () => setState(() {})),
        ),
      ],
    );
  }

  // Paso 3
  Widget _stepDatos() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos opcionales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 12),
          _fieldLabel(_isEdit
              ? 'Nombre del curso (opcional)'
              : 'Nombre del curso (Por defecto: $_defaultName)'),
          const SizedBox(height: 4),
          TextField(
            controller: _labelController,
            decoration: _dec(_defaultName),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Profesor (opcional)'),
          const SizedBox(height: 4),
          TextField(controller: _profController, decoration: _dec('Ej. Juan Pérez')),
          const SizedBox(height: 16),
          Row(
            children: [
              _fieldLabel('NRC (opcional)'),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Cada curso de la oferta tiene un NRC único de 4 dígitos.\n'
                    'Si el que escribes ya existe, ese curso está en la oferta:\n'
                    'te equivocaste al digitar, o el curso ya existe y no hay que crearlo.',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _nrcController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: _onNrcChanged,
            decoration: _dec('4 dígitos').copyWith(
              suffixIcon: _nrcChecking
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : (_nrcError == null && _nrcController.text.trim().isNotEmpty
                      ? const Icon(Icons.check, color: Colors.green)
                      : null),
              errorText: _nrcError,
            ),
          ),
          const SizedBox(height: 8),
          _resumen(),
        ],
      ),
    );
  }

  Widget _resumen() {
    final bloques = _buildBloques();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_materia?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...bloques.map((b) => Text('${b.day} ${b.time}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
        ],
      ),
    );
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  /// Etiqueta de un campo: oscura y en negrita, para que resalte más que el
  /// texto que se escribe adentro.
  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      );

}

/// Grilla interactiva de selección de bloques. Clic para alternar una celda;
/// arrastre para seleccionar un **rango**: la celda ancla (donde se empieza) y
/// la del cursor definen un rectángulo. Al arrastrar de vuelta el rectángulo se
/// encoge, así que si te pasas de franja, devuelves el mouse y se corrige (sin
/// tener que soltar y borrar a mano). El modo (marcar/borrar) lo fija el ancla:
/// si empiezas sobre una celda vacía, el rango marca; si empiezas sobre una
/// llena, el rango borra.
class _GridSelector extends StatefulWidget {
  final Set<String> selected;
  final VoidCallback onChanged;
  const _GridSelector({required this.selected, required this.onChanged});

  @override
  State<_GridSelector> createState() => _GridSelectorState();
}

class _GridSelectorState extends State<_GridSelector> {
  static const double _labelW = 40;
  static const double _headerH = 22;
  static const double _cellH = 26;

  // Estado del arrastre: celda ancla, snapshot de la selección al empezar, y si
  // el rango marca (true) o borra (false).
  int? _aDay, _aHour;
  Set<String> _base = {};
  bool _paint = true;

  // Celda exacta bajo el punto, o null si cae en las cabeceras/fuera.
  List<int>? _cellAt(Offset local, double cellW) {
    if (local.dx < _labelW || local.dy < _headerH) return null;
    final day = ((local.dx - _labelW) / cellW).floor();
    final hour = _kFirstHour + ((local.dy - _headerH) / _cellH).floor();
    if (day < 0 || day >= _kAbbrevDays.length) return null;
    if (hour < _kFirstHour || hour > _kLastHour) return null;
    return [day, hour];
  }

  // Igual, pero recortada al borde de la grilla (para que arrastrar por fuera
  // siga extendiendo el rango hasta el límite en vez de detenerse).
  List<int> _clampCell(Offset local, double cellW) {
    final day = ((local.dx - _labelW) / cellW).floor().clamp(0, _kAbbrevDays.length - 1);
    final hour = (_kFirstHour + ((local.dy - _headerH) / _cellH).floor())
        .clamp(_kFirstHour, _kLastHour);
    return [day, hour];
  }

  // Pointer-down: fija ancla, guarda la selección base y el modo, aplica 1 celda.
  void _begin(Offset local, double cellW) {
    final cell = _cellAt(local, cellW);
    if (cell == null) return;
    _aDay = cell[0];
    _aHour = cell[1];
    _base = Set<String>.from(widget.selected);
    _paint = !widget.selected.contains('${_aDay}:${_aHour}');
    _applyRect(cell[0], cell[1]);
  }

  // Arrastre: extiende el rectángulo ancla → celda actual.
  void _extend(Offset local, double cellW) {
    if (_aDay == null) return;
    final cell = _clampCell(local, cellW);
    _applyRect(cell[0], cell[1]);
  }

  // Reaplica sobre la base: fuera del rectángulo queda como estaba; dentro se
  // marca o borra según el modo. Así devolver el mouse revierte lo que sobra.
  void _applyRect(int day, int hour) {
    final d0 = _aDay! < day ? _aDay! : day;
    final d1 = _aDay! > day ? _aDay! : day;
    final h0 = _aHour! < hour ? _aHour! : hour;
    final h1 = _aHour! > hour ? _aHour! : hour;
    final sel = Set<String>.from(_base);
    for (int d = d0; d <= d1; d++) {
      for (int h = h0; h <= h1; h++) {
        final id = '$d:$h';
        if (_paint) {
          sel.add(id);
        } else {
          sel.remove(id);
        }
      }
    }
    widget.selected
      ..clear()
      ..addAll(sel);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - _labelW) / _kAbbrevDays.length;
        return SingleChildScrollView(
          child: Listener(
            // Listener (no GestureDetector): recibe los eventos de puntero
            // directo, sin pasar por la arena de gestos. Así el arrastre
            // responde de una vez — con GestureDetector el reconocedor de pan
            // competía con el tap y el scroll del padre y tardaba en "ganar",
            // por eso solo servía tras esperar un instante.
            onPointerDown: (e) => _begin(e.localPosition, cellW),
            onPointerMove: (e) => _extend(e.localPosition, cellW),
            onPointerUp: (_) => _aDay = null,
            child: Column(
              children: [
                // Cabecera de días
                SizedBox(
                  height: _headerH,
                  child: Row(
                    children: [
                      const SizedBox(width: _labelW),
                      ..._kAbbrevDays.map((d) => SizedBox(
                            width: cellW,
                            child: Center(child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          )),
                    ],
                  ),
                ),
                // Filas por hora
                ...List.generate(_kLastHour - _kFirstHour + 1, (row) {
                  final hour = _kFirstHour + row;
                  return SizedBox(
                    height: _cellH,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _labelW,
                          child: Center(child: Text('${_p(hour)}:00', style: const TextStyle(fontSize: 10, color: Colors.grey))),
                        ),
                        ..._kAbbrevDays.asMap().keys.map((day) {
                          final sel = widget.selected.contains('$day:$hour');
                          return Container(
                            width: cellW,
                            height: _cellH,
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.white,
                              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _p(int h) => h.toString().padLeft(2, '0');
}

/// Selector de bloques para móvil: en vez de una grilla de celdas diminutas,
/// un formulario "Agregar bloque" (Día + De/A). Escribe sobre el mismo
/// `selected` (celdas `dia:hora`) que la grilla, así todo lo demás no cambia.
/// El dropdown "A" solo ofrece horas >= "De" (por la convención :50).
class _BlockForm extends StatefulWidget {
  final Set<String> selected;
  final VoidCallback onChanged;
  const _BlockForm({required this.selected, required this.onChanged});

  @override
  State<_BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends State<_BlockForm> {
  int _day = 0;
  int _start = 8;
  int _end = 8;

  String _p(int h) => h.toString().padLeft(2, '0');

  // Bloques actuales (merge contiguo por día) como [dayIdx, startHour, endHour].
  List<List<int>> _blocks() {
    final Map<int, List<int>> byDay = {};
    for (final id in widget.selected) {
      final p = id.split(':');
      byDay.putIfAbsent(int.parse(p[0]), () => []).add(int.parse(p[1]));
    }
    final out = <List<int>>[];
    final days = byDay.keys.toList()..sort();
    for (final d in days) {
      final hours = byDay[d]!..sort();
      int runStart = hours.first, prev = hours.first;
      for (int i = 1; i < hours.length; i++) {
        if (hours[i] == prev + 1) {
          prev = hours[i];
        } else {
          out.add([d, runStart, prev]);
          runStart = hours[i];
          prev = hours[i];
        }
      }
      out.add([d, runStart, prev]);
    }
    return out;
  }

  void _add() {
    for (int h = _start; h <= _end; h++) {
      widget.selected.add('$_day:$h');
    }
    widget.onChanged();
  }

  void _remove(int day, int start, int end) {
    for (int h = start; h <= end; h++) {
      widget.selected.remove('$day:$h');
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Aún no agregas bloques.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: blocks
                  .map((b) => Chip(
                        label: Text('${_kAbbrevDays[b[0]]} ${_p(b[1])}:00–${_p(b[2])}:50',
                            style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _remove(b[0], b[1], b[2]),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        backgroundColor: const Color(0xFFEFF6FF),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agregar bloque',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                _labeled('Día', DropdownButtonFormField<int>(
                  value: _day,
                  isDense: true,
                  decoration: _ddDec(),
                  items: List.generate(_kFullDays.length, (i) =>
                      DropdownMenuItem(value: i, child: Text(_kFullDays[i]))),
                  onChanged: (v) => setState(() => _day = v ?? 0),
                )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _labeled('De', DropdownButtonFormField<int>(
                        value: _start,
                        isDense: true,
                        decoration: _ddDec(),
                        items: List.generate(_kLastHour - _kFirstHour + 1, (i) {
                          final h = _kFirstHour + i;
                          return DropdownMenuItem(value: h, child: Text('${_p(h)}:00'));
                        }),
                        onChanged: (v) => setState(() {
                          _start = v ?? _kFirstHour;
                          if (_end < _start) _end = _start;
                        }),
                      )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _labeled('A', DropdownButtonFormField<int>(
                        value: _end,
                        isDense: true,
                        decoration: _ddDec(),
                        items: List.generate(_kLastHour - _start + 1, (i) {
                          final h = _start + i;
                          return DropdownMenuItem(value: h, child: Text('${_p(h)}:50'));
                        }),
                        onChanged: (v) => setState(() => _end = v ?? _start),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar bloque'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          field,
        ],
      );

  InputDecoration _ddDec() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}
