import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feriado.dart';
import '../models/paper_size.dart';
import '../painters/planilla_painter.dart';
import '../services/feriados_service.dart';
import 'horarios_dialog.dart';

enum TandaMode { dia, semana }

// ── Claves de SharedPreferences (avance de Tanda) ──────────────────────────────
const _kKeyTandaPrintedWeek = 'tanda_printed_week';
const _kKeyTandaPrintedDays = 'tanda_printed_days';
const _kKeyTandaDestination = 'tanda_day_destination';

// ── Colores ───────────────────────────────────────────────────────────────────
const _kLVColor = Color(0xFF355E3B);
const _kLVLight = Color(0xFFECF4EC);
const _kLVBorder = Color(0xFFAFCDB2);
const _kLVDark = Color(0xFF1F3D23);
const _kSabColor = Color(0xFF7A5C14);
const _kSabLight = Color(0xFFF5EDD8);
const _kSabBorder = Color(0xFFCFB26A);
const _kSabDark = Color(0xFF54400D);
const _kDomColor = Color(0xFF7B1F2E);
const _kDomLight = Color(0xFFF5E8EA);
const _kDomBorder = Color(0xFFCCA0A8);
const _kDomDark = Color(0xFF4A0D17);
const _kHeaderDark = Color(0xFF4A0D17);
const _kBandBg = Color(0xFFF5DDE0);

// ── Strings ───────────────────────────────────────────────────────────────────
const _meses = [
  '',
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _longNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _shortNames = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
// Sin tildes para el PDF (fuente básica)
const _pdfNames = [
  'Lunes',
  'Martes',
  'Miercoles',
  'Jueves',
  'Viernes',
  'Sabado',
  'Domingo',
];

// ── Helpers ───────────────────────────────────────────────────────────────────
DateTime _weekMon(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _fmtFull(DateTime d) => '${d.day} ${_meses[d.month]} ${d.year}';

Color _accent(int wd) => wd <= 5
    ? _kLVColor
    : wd == 6
    ? _kSabColor
    : _kDomColor;
Color _light(int wd) => wd <= 5
    ? _kLVLight
    : wd == 6
    ? _kSabLight
    : _kDomLight;
Color _border(int wd) => wd <= 5
    ? _kLVBorder
    : wd == 6
    ? _kSabBorder
    : _kDomBorder;
Color _dark(int wd) => wd <= 5
    ? _kLVDark
    : wd == 6
    ? _kSabDark
    : _kDomDark;
List<String> _timesFor(int wd, HorariosData d) => wd <= 5
    ? d.lunesViernes
    : wd == 6
    ? d.sabado
    : d.domingoFeriado;

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<String> _timesForDate(
  DateTime date,
  HorariosData d,
  Map<String, Feriado> feriados,
) {
  final f = feriados[_dateKey(date)];
  if (f == null) return _timesFor(date.weekday, d);
  return f.irrenunciable ? d.domingoFeriado : _timesFor(date.weekday, d);
}

// ─────────────────────────────────────────────────────────────────────────────
// TandaPanel — selector de semana (panel izquierdo)
// ─────────────────────────────────────────────────────────────────────────────
class TandaPanel extends StatefulWidget {
  final ValueNotifier<DateTime?> weekNotifier;
  final ValueNotifier<HorariosData> horariosNotifier;
  final ValueNotifier<Map<String, Feriado>> feriadosNotifier;
  final ValueNotifier<TandaMode> modeNotifier;
  final ValueNotifier<DateTime?> dayNotifier;

  const TandaPanel({
    super.key,
    required this.weekNotifier,
    required this.horariosNotifier,
    required this.feriadosNotifier,
    required this.modeNotifier,
    required this.dayNotifier,
  });

  @override
  State<TandaPanel> createState() => _TandaPanelState();
}

class _TandaPanelState extends State<TandaPanel> {
  late DateTime _month;
  final _loadingYears = <int>{};
  String _dayDestination = 'Coyhaique';
  PaperSize _paper = PaperSize.a4;
  // Índices de días (0=Lun…6=Dom) ya impresos de la semana actual
  final _printedDays = <int>{};
  String? _weekKeyPrinted; // clave de la semana para resetear al cambiar
  // Cooldown de impresión
  bool _isPrintingTanda = false;
  bool _isPrintingDia = false;
  final _printingDays = <int>{};

  Future<void> _guardedPrint({
    required Future<void> Function() printFn,
    required VoidCallback onStart,
    required VoidCallback onEnd,
  }) async {
    onStart();
    try {
      await Future.wait([
        printFn(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
    } finally {
      if (mounted) onEnd();
    }
  }

  // Abre el diálogo de selección de horarios y luego imprime los elegidos.
  // [idx] es el índice en la semana (0–6) para actualizar _printedDays;
  // null cuando se llama desde _buildDiaInfo.
  Future<void> _showSelectAndPrint(
    BuildContext context,
    DateTime date,
    HorariosData data,
    Map<String, Feriado> feriados, {
    int? idx,
    required VoidCallback onStart,
    required VoidCallback onEnd,
  }) async {
    final times = _timesForDate(date, data, feriados);
    if (times.isEmpty) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _SelectTimesDialog(times: times, date: date),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    await _guardedPrint(
      printFn: () => printDiaPdf(
        date,
        data,
        feriados,
        _dayDestination,
        selectedTimes: selected,
        paper: _paper,
      ),
      onStart: onStart,
      onEnd: onEnd,
    );
  }

  void _resetIfNewWeek(DateTime week) {
    final key = _dateKey(week);
    if (key != _weekKeyPrinted) {
      _printedDays.clear();
      _weekKeyPrinted = key;
      _saveProgress();
    }
  }

  // ── Persistencia del avance (días ya impresos + destino) ──
  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final week = prefs.getString(_kKeyTandaPrintedWeek);
    final daysRaw = prefs.getString(_kKeyTandaPrintedDays);
    final dest = prefs.getString(_kKeyTandaDestination);
    if (!mounted) return;
    setState(() {
      if (week != null) _weekKeyPrinted = week;
      if (daysRaw != null) {
        _printedDays
          ..clear()
          ..addAll(List<int>.from(jsonDecode(daysRaw) as List));
      }
      if (dest != null) _dayDestination = dest;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (_weekKeyPrinted != null) {
      await prefs.setString(_kKeyTandaPrintedWeek, _weekKeyPrinted!);
    }
    await prefs.setString(
      _kKeyTandaPrintedDays,
      jsonEncode(_printedDays.toList()),
    );
    await prefs.setString(_kKeyTandaDestination, _dayDestination);
  }

  Future<void> _loadFeriadosForMonth(DateTime month) async {
    final years = {month.year, if (month.month == 12) month.year + 1};
    for (final year in years) {
      if (_loadingYears.contains(year)) continue;
      _loadingYears.add(year);
      try {
        final list = await FeriadosService.fetchYear(year);
        if (!mounted) return;
        final map = Map<String, Feriado>.from(widget.feriadosNotifier.value);
        for (final f in list) {
          map[_dateKey(f.fecha)] = f;
        }
        widget.feriadosNotifier.value = map;
      } catch (_) {
        // silently fail — la tanda sigue funcionando sin feriados
      } finally {
        _loadingYears.remove(year);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.weekNotifier.value != null) {
      final ws = widget.weekNotifier.value!;
      _month = DateTime(ws.year, ws.month);
    } else {
      _month = DateTime(now.year, now.month);
      widget.weekNotifier.value = _weekMon(now);
    }
    Future.microtask(() => _loadFeriadosForMonth(_month));
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Selector de modo ──
          ValueListenableBuilder<TandaMode>(
            valueListenable: widget.modeNotifier,
            builder: (_, mode, _) => Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Semana',
                    selected: mode == TandaMode.semana,
                    onTap: () => widget.modeNotifier.value = TandaMode.semana,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeButton(
                    label: 'Día',
                    selected: mode == TandaMode.dia,
                    onTap: () => widget.modeNotifier.value = TandaMode.dia,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaperSizeButton(
                  size: PaperSize.a4,
                  selected: _paper == PaperSize.a4,
                  onTap: () => setState(() => _paper = PaperSize.a4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PaperSizeButton(
                  size: PaperSize.carta,
                  selected: _paper == PaperSize.carta,
                  onTap: () => setState(() => _paper = PaperSize.carta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCalendar(),
          const SizedBox(height: 16),
          ValueListenableBuilder<TandaMode>(
            valueListenable: widget.modeNotifier,
            builder: (_, mode, _) =>
                mode == TandaMode.semana ? _buildSemanaInfo() : _buildDiaInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildSemanaInfo() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: widget.weekNotifier,
      builder: (_, week, _) {
        if (week == null) return const SizedBox.shrink();
        _resetIfNewWeek(week);
        final end = week.add(const Duration(days: 6));
        return ListenableBuilder(
          listenable: Listenable.merge([
            widget.horariosNotifier,
            widget.feriadosNotifier,
          ]),
          builder: (_, _) {
            final data = widget.horariosNotifier.value;
            final feriados = widget.feriadosNotifier.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Info de semana ──
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kBandBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kDomBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Semana seleccionada',
                        style: TextStyle(fontSize: 10, color: Colors.black45),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _fmtFull(week),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'hasta ${_fmtFull(end)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPrintingTanda
                        ? _kLVColor.withAlpha(160)
                        : _kLVColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                  icon: _isPrintingTanda
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_rounded, size: 16),
                  label: Text(
                    _isPrintingTanda ? 'Imprimiendo…' : 'Imprimir Tanda',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: _isPrintingTanda
                      ? null
                      : () => _guardedPrint(
                          printFn: () =>
                              printTandaPdf(week, data, feriados, paper: _paper),
                          onStart: () =>
                              setState(() => _isPrintingTanda = true),
                          onEnd: () =>
                              setState(() => _isPrintingTanda = false),
                        ),
                ),
                const SizedBox(height: 16),
                // ── TODO list de días ──
                const Text(
                  'Planillas por día',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < 7; i++)
                  _buildDayTodo(week.add(Duration(days: i)), i, data, feriados),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayTodo(
    DateTime date,
    int idx,
    HorariosData data,
    Map<String, Feriado> feriados,
  ) {
    final times = _timesForDate(date, data, feriados);
    final wd = date.weekday;
    final feriadoTodo = feriados[_dateKey(date)];
    final isFeriado = feriadoTodo != null;
    final isIrrenunciable = feriadoTodo?.irrenunciable == true;
    final effectiveWd = isIrrenunciable && wd < 7 ? 7 : wd;
    final ac = _accent(effectiveWd);
    final lt = _light(effectiveWd);
    final done = _printedDays.contains(idx);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: done ? lt : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: done ? ac : const Color(0xFFDDDDDD),
          width: done ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ── Check / círculo ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? ac : Colors.transparent,
                border: Border.all(
                  color: done ? ac : Colors.black26,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          // ── Nombre del día + fecha ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_shortNames[wd - 1]}  ${_fmt(date)}'
                  '${isIrrenunciable ? '  ·  Feriado' : isFeriado ? '  ·  F. Renunciable' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: done ? ac : Colors.black87,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: ac,
                  ),
                ),
                Text(
                  times.isEmpty
                      ? 'Sin horarios'
                      : '${times.length} horario${times.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: times.isEmpty ? Colors.black26 : ac.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          // ── Botones imprimir ──
          if (times.isNotEmpty) ...[
            IconButton(
              tooltip: done ? 'Reimprimir' : 'Imprimir',
              icon: _printingDays.contains(idx)
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey,
                      ),
                    )
                  : Icon(
                      done ? Icons.replay_rounded : Icons.print_rounded,
                      size: 18,
                      color: done ? ac.withAlpha(160) : ac,
                    ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: _printingDays.contains(idx)
                  ? null
                  : () => _guardedPrint(
                      printFn: () => printDiaPdf(
                        date,
                        data,
                        feriados,
                        _dayDestination,
                        paper: _paper,
                      ),
                      onStart: () => setState(() => _printingDays.add(idx)),
                      onEnd: () {
                        setState(() {
                          _printingDays.remove(idx);
                          _printedDays.add(idx);
                        });
                        _saveProgress();
                      },
                    ),
            ),
            if (times.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: 'Seleccionar horarios',
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: _printingDays.contains(idx)
                        ? Colors.black26
                        : Colors.black45,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: _printingDays.contains(idx)
                      ? null
                      : () => _showSelectAndPrint(
                          context,
                          date,
                          data,
                          feriados,
                          idx: idx,
                          onStart: () =>
                              setState(() => _printingDays.add(idx)),
                          onEnd: () {
                            setState(() {
                              _printingDays.remove(idx);
                              _printedDays.add(idx);
                            });
                            _saveProgress();
                          },
                        ),
                ),
              ),
          ] else
            const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildDiaInfo() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.dayNotifier,
        widget.horariosNotifier,
        widget.feriadosNotifier,
      ]),
      builder: (_, _) {
        final day = widget.dayNotifier.value;
        if (day == null) return const SizedBox.shrink();
        final feriados = widget.feriadosNotifier.value;
        final feriadoDia = feriados[_dateKey(day)];
        final isIrrenunciableDia = feriadoDia?.irrenunciable == true;
        final wd = isIrrenunciableDia && day.weekday < 7 ? 7 : day.weekday;
        final times = _timesForDate(
          day,
          widget.horariosNotifier.value,
          feriados,
        );
        final ac = _accent(wd);
        final bo = _border(wd);
        final dayLabel = isIrrenunciableDia
            ? 'Feriado Irrenunciable'
            : feriadoDia != null
            ? 'Feriado Renunciable'
            : _longNames[day.weekday - 1];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _light(wd),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: bo),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: ac,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtFull(day),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${times.length} horario${times.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: ac.withAlpha(180)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Destino ──
            Row(
              children: [
                const Text(
                  'Destino:',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: _dayDestination == 'Coyhaique'
                        ? 'Coyhaique'
                        : 'Aysén',
                    selected: _dayDestination == 'Coyhaique',
                    onTap: () {
                      setState(
                        () => _dayDestination = _dayDestination == 'Coyhaique'
                            ? 'Aysen'
                            : 'Coyhaique',
                      );
                      _saveProgress();
                    },
                    color: ac,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPrintingDia ? ac.withAlpha(160) : ac,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      elevation: 0,
                    ),
                    icon: _isPrintingDia
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded, size: 16),
                    label: Text(
                      _isPrintingDia
                          ? 'Imprimiendo…'
                          : 'Imprimir ${times.length} planilla${times.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: (times.isEmpty || _isPrintingDia)
                        ? null
                        : () => _guardedPrint(
                            printFn: () => printDiaPdf(
                              day,
                              widget.horariosNotifier.value,
                              feriados,
                              _dayDestination,
                              paper: _paper,
                            ),
                            onStart: () =>
                                setState(() => _isPrintingDia = true),
                            onEnd: () =>
                                setState(() => _isPrintingDia = false),
                          ),
                  ),
                ),
                if (times.length > 1) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _isPrintingDia ? Colors.black26 : ac,
                        side: BorderSide(
                          color: _isPrintingDia ? Colors.black12 : bo,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 44),
                      ),
                      onPressed: _isPrintingDia
                          ? null
                          : () => _showSelectAndPrint(
                              context,
                              day,
                              widget.horariosNotifier.value,
                              feriados,
                              onStart: () =>
                                  setState(() => _isPrintingDia = true),
                              onEnd: () =>
                                  setState(() => _isPrintingDia = false),
                            ),
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendar() {
    final offset = DateTime(_month.year, _month.month, 1).weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Cabecera del mes ──
          Container(
            color: _kHeaderDark,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    );
                    _loadFeriadosForMonth(_month);
                  },
                ),
                Expanded(
                  child: Text(
                    '${_meses[_month.month]}  ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    );
                    _loadFeriadosForMonth(_month);
                  },
                ),
              ],
            ),
          ),
          // ── Nombres de días ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      _shortNames[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: i >= 5
                            ? _kDomColor.withAlpha(180)
                            : Colors.black38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Grilla ──
          ListenableBuilder(
            listenable: Listenable.merge([
              widget.feriadosNotifier,
              widget.weekNotifier,
              widget.dayNotifier,
              widget.modeNotifier,
            ]),
            builder: (_, _) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2, right: 2),
              child: _buildGrid(
                offset,
                daysInMonth,
                widget.weekNotifier.value,
                widget.dayNotifier.value,
                widget.modeNotifier.value,
                today,
                widget.feriadosNotifier.value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    int offset,
    int daysInMonth,
    DateTime? selectedWeek,
    DateTime? selectedDay,
    TandaMode mode,
    DateTime today,
    Map<String, Feriado> feriadosMap,
  ) {
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        for (int row = 0; row < rows; row++)
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final day = row * 7 + col - offset + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox(height: 30);
                      }
                      final date = DateTime(_month.year, _month.month, day);
                      final ws = _weekMon(date);
                      final wd = col + 1; // 1=Lun, 7=Dom
                      final feriadoCal = feriadosMap[_dateKey(date)];
                      final isFeriado = feriadoCal != null;
                      final isIrrenunciableCal = feriadoCal?.irrenunciable == true;
                      final effectiveWd = isIrrenunciableCal && wd < 7 ? 7 : wd;
                      final inBand =
                          mode == TandaMode.semana &&
                          selectedWeek != null &&
                          ws.year == selectedWeek.year &&
                          ws.month == selectedWeek.month &&
                          ws.day == selectedWeek.day;
                      final isSelectedDay =
                          mode == TandaMode.dia &&
                          selectedDay != null &&
                          date.year == selectedDay.year &&
                          date.month == selectedDay.month &&
                          date.day == selectedDay.day;
                      final isToday =
                          date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final bandLeft = inBand && (wd == 1 || day == 1);
                      final bandRight =
                          inBand && (wd == 7 || day == daysInMonth);
                      final circleColor = isToday
                          ? _kHeaderDark
                          : isSelectedDay
                          ? _accent(effectiveWd)
                          : Colors.transparent;

                      return GestureDetector(
                        onTap: () {
                          if (mode == TandaMode.dia) {
                            widget.dayNotifier.value = date;
                          } else {
                            widget.weekNotifier.value = ws;
                          }
                        },
                        child: Container(
                          height: 30,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: inBand ? _kBandBg : Colors.transparent,
                            borderRadius: BorderRadius.horizontal(
                              left: bandLeft
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                              right: bandRight
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: circleColor,
                                    shape: BoxShape.circle,
                                    border:
                                        (inBand && !isToday && !isSelectedDay)
                                        ? Border.all(
                                            color: _kHeaderDark.withAlpha(80),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight:
                                            inBand || isToday || isSelectedDay
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                        color: isToday || isSelectedDay
                                            ? Colors.white
                                            : inBand
                                            ? _kHeaderDark
                                            : isIrrenunciableCal
                                            ? _kDomColor
                                            : isFeriado
                                            ? _kSabColor
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isFeriado)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isIrrenunciableCal
                                          ? _kDomColor
                                          : _kSabColor,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TandaViewer — vista de la semana (panel derecho)
// ─────────────────────────────────────────────────────────────────────────────
class TandaViewer extends StatelessWidget {
  final ValueNotifier<DateTime?> weekNotifier;
  final ValueNotifier<HorariosData> horariosNotifier;
  final ValueNotifier<Map<String, Feriado>> feriadosNotifier;
  final ValueNotifier<TandaMode> modeNotifier;
  final ValueNotifier<DateTime?> dayNotifier;

  const TandaViewer({
    super.key,
    required this.weekNotifier,
    required this.horariosNotifier,
    required this.feriadosNotifier,
    required this.modeNotifier,
    required this.dayNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: ValueListenableBuilder<TandaMode>(
        valueListenable: modeNotifier,
        builder: (_, mode, _) {
          if (mode == TandaMode.dia) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: dayNotifier,
              builder: (_, day, _) {
                if (day == null) {
                  return const Center(
                    child: Text(
                      'Selecciona un día en el panel izquierdo',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                  );
                }
                return ValueListenableBuilder<HorariosData>(
                  valueListenable: horariosNotifier,
                  builder: (_, data, _) =>
                      ValueListenableBuilder<Map<String, Feriado>>(
                        valueListenable: feriadosNotifier,
                        builder: (_, feriados, _) =>
                            _buildDaySingle(day, data, feriados),
                      ),
                );
              },
            );
          }
          // ── SEMANA mode ──
          return ValueListenableBuilder<Map<String, Feriado>>(
            valueListenable: feriadosNotifier,
            builder: (_, feriados, _) => ValueListenableBuilder<DateTime?>(
              valueListenable: weekNotifier,
              builder: (_, week, _) {
                if (week == null) {
                  return const Center(
                    child: Text(
                      'Selecciona una semana en el panel izquierdo',
                      style: TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                  );
                }
                return ValueListenableBuilder<HorariosData>(
                  valueListenable: horariosNotifier,
                  builder: (_, data, _) => _buildWeek(week, data, feriados),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySingle(
    DateTime day,
    HorariosData data,
    Map<String, Feriado> feriados,
  ) {
    final feriadoSingle = feriados[_dateKey(day)];
    final wd = day.weekday;
    final feriadoNombre = feriadoSingle?.nombre;
    return Column(
      children: [
        Container(
          color: _kHeaderDark,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white60,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_longNames[wd - 1]}  —  ${_fmtFull(day)}'
                  '${feriadoNombre != null ? '  ·  $feriadoNombre' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: _DayColumn(date: day, data: data, feriados: feriados),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeek(
    DateTime week,
    HorariosData data,
    Map<String, Feriado> feriados,
  ) {
    final end = week.add(const Duration(days: 6));
    return Column(
      children: [
        // ── Encabezado ──
        Container(
          color: _kHeaderDark,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.view_week_outlined,
                color: Colors.white60,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Semana del ${_fmtFull(week)} al ${_fmtFull(end)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // ── 7 columnas ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                for (int i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _DayColumn(
                      date: week.add(Duration(days: i)),
                      data: data,
                      feriados: feriados,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayColumn
// ─────────────────────────────────────────────────────────────────────────────
class _DayColumn extends StatelessWidget {
  final DateTime date;
  final HorariosData data;
  final Map<String, Feriado> feriados;

  const _DayColumn({
    required this.date,
    required this.data,
    required this.feriados,
  });

  @override
  Widget build(BuildContext context) {
    final wd = date.weekday;
    final feriadoObj = feriados[_dateKey(date)];
    final isIrrenunciable = feriadoObj?.irrenunciable == true;
    final colorWd = (isIrrenunciable && wd < 7) ? 7 : wd;
    final ac = _accent(colorWd);
    final lt = _light(colorWd);
    final bo = _border(colorWd);
    final dk = _dark(colorWd);
    final tl = _timesForDate(date, data, feriados);
    final feriadoNombre = feriadoObj?.nombre;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bo, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ac.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Cabecera del día ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ac,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _longNames[wd - 1],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _fmt(date),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 10,
                  ),
                ),
                if (feriadoNombre != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      feriadoNombre,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(210),
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Lista de horarios ──
          if (tl.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '–',
                  style: TextStyle(color: ac.withAlpha(80), fontSize: 20),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                itemCount: tl.length,
                itemBuilder: (_, i) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lt,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: bo),
                  ),
                  child: Text(
                    tl[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dk,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF printing
// ─────────────────────────────────────────────────────────────────────────────
Future<void> printTandaPdf(
  DateTime week,
  HorariosData data,
  Map<String, Feriado> feriados, {
  PaperSize paper = PaperSize.a4,
}) async {
  final font = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: paper.pdfFormat.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Tanda de Horarios  •  ${_fmt(week)} – ${_fmt(week.add(const Duration(days: 6)))}',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 7; i++) ...[
                  if (i > 0) pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: _pdfDayCol(
                      week.add(Duration(days: i)),
                      data,
                      feriados,
                      font,
                      bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

pw.Widget _pdfDayCol(
  DateTime date,
  HorariosData data,
  Map<String, Feriado> feriados,
  pw.Font font,
  pw.Font bold,
) {
  final wd = date.weekday;
  final feriadoPdf = feriados[_dateKey(date)];
  final isIrrenunciablePdf = feriadoPdf?.irrenunciable == true;
  final tl = _timesForDate(date, data, feriados);
  final colorWd = (isIrrenunciablePdf && wd < 7) ? 7 : wd;
  final headerBg = colorWd <= 5
      ? const PdfColor(0.208, 0.369, 0.231) // #355E3B
      : colorWd == 6
      ? const PdfColor(0.478, 0.361, 0.078) // #7A5C14
      : const PdfColor(0.482, 0.122, 0.180); // #7B1F2E

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          color: headerBg,
          child: pw.Column(
            children: [
              pw.Text(
                _pdfNames[wd - 1],
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                _fmt(date),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        if (tl.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              '-',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey400,
              ),
            ),
          )
        else
          ...tl.map(
            (t) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 3,
                horizontal: 4,
              ),
              child: pw.Text(
                t,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF planilla por día
// ─────────────────────────────────────────────────────────────────────────────
Future<void> printDiaPdf(
  DateTime date,
  HorariosData data,
  Map<String, Feriado> feriados,
  String destination, {
  List<String>? selectedTimes,
  PaperSize paper = PaperSize.a4,
}) async {
  final times = selectedTimes ?? _timesForDate(date, data, feriados);
  if (times.isEmpty) return;

  final pageFormat = paper.pdfFormat;
  final double pageW = pageFormat.width;
  final double pageH = pageFormat.height;
  const double scale = 2.0;
  final int imgW = (pageW * scale).round();
  final int imgH = (pageH * scale).round();
  final dateStr = _fmt(date);

  final doc = pw.Document();
  // Se recorre en orden inverso: la impresora suele apilar las hojas boca
  // abajo, por lo que la última en imprimirse queda arriba de la pila.
  // Así, al tomar la pila física, el primer horario queda primero.
  for (final time in times.reversed) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
    );
    PlanillaPainter(
      destination: destination,
      time: time,
      date: dateStr,
    ).paint(canvas, Size(imgW.toDouble(), imgH.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(imgW, imgH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = byteData!.buffer.asUint8List();
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
      ),
    );
  }
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

// ─────────────────────────────────────────────────────────────────────────────
// _SelectTimesDialog — elige qué horarios de un día imprimir
// ─────────────────────────────────────────────────────────────────────────────
class _SelectTimesDialog extends StatefulWidget {
  final List<String> times;
  final DateTime date;

  const _SelectTimesDialog({required this.times, required this.date});

  @override
  State<_SelectTimesDialog> createState() => _SelectTimesDialogState();
}

class _SelectTimesDialogState extends State<_SelectTimesDialog> {
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.times.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.where((s) => s).length;
    return AlertDialog(
      title: const Text('Seleccionar horarios'),
      titleTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _fmtFull(widget.date),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.times.length; i++)
                      CheckboxListTile(
                        dense: true,
                        title: Text(
                          widget.times[i],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _selected[i],
                        onChanged: (v) =>
                            setState(() => _selected[i] = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: count == 0
              ? null
              : () {
                  final result = [
                    for (int i = 0; i < widget.times.length; i++)
                      if (_selected[i]) widget.times[i],
                  ];
                  Navigator.pop(context, result);
                },
          child: Text(
            count == 0
                ? 'Imprimir'
                : 'Imprimir $count planilla${count == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ModeButton — botón de toggle para DIA / SEMANA
// ─────────────────────────────────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ac = color ?? _kHeaderDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ac : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? ac : Colors.black26, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaperSizeButton — botón de selección de tamaño de hoja (A4 / Carta)
// ─────────────────────────────────────────────────────────────────────────────
class _PaperSizeButton extends StatelessWidget {
  final PaperSize size;
  final bool selected;
  final VoidCallback onTap;

  const _PaperSizeButton({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kHeaderDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? _kHeaderDark : Colors.black26,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              size.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
            Text(
              size.dimensions,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white70 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
