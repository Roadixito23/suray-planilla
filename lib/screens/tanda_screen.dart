import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feriado.dart';
import '../models/paper_size.dart';
import '../painters/planilla_painter.dart';
import '../services/feriados_service.dart';
import 'horarios_dialog.dart';

// ── Claves de SharedPreferences (avance de Tanda) ──────────────────────────────
const _kKeyTandaPrintedWeek = 'tanda_printed_week';
const _kKeyTandaPrintedDays = 'tanda_printed_days';
const _kKeyTandaDestination = 'tanda_day_destination';
const _kKeyTandaPaperSize = 'tanda_paper_size';

// ── Colores ───────────────────────────────────────────────────────────────────
const _kLVColor = Color(0xFF355E3B);
const _kLVLight = Color(0xFFECF4EC);
const _kLVBorder = Color(0xFFAFCDB2);
const _kSabColor = Color(0xFF7A5C14);
const _kSabLight = Color(0xFFF5EDD8);
const _kSabBorder = Color(0xFFCFB26A);
const _kDomColor = Color(0xFF7B1F2E);
const _kDomLight = Color(0xFFF5E8EA);
const _kDomBorder = Color(0xFFCCA0A8);
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

// Día efectivo para colorear (un feriado irrenunciable se trata como domingo).
int _effectiveWeekday(DateTime date, Map<String, Feriado> feriados) {
  final f = feriados[_dateKey(date)];
  return (f?.irrenunciable == true && date.weekday < 7) ? 7 : date.weekday;
}

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
    onEnd();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TandaController — estado compartido de impresión/avance entre panel
// izquierdo y derecho (destino, tamaño de hoja, días impresos, día activo).
// ─────────────────────────────────────────────────────────────────────────────
class TandaController extends ChangeNotifier {
  TandaController({
    required this.horariosNotifier,
    required this.feriadosNotifier,
    required this.weekNotifier,
    required this.dayNotifier,
  }) {
    weekNotifier.addListener(_onWeekChanged);
  }

  final ValueNotifier<HorariosData> horariosNotifier;
  final ValueNotifier<Map<String, Feriado>> feriadosNotifier;
  final ValueNotifier<DateTime?> weekNotifier;
  final ValueNotifier<DateTime?> dayNotifier;

  String destination = 'Coyhaique';
  PaperSize paper = PaperSize.a4;
  // Índices de días (0=Lun…6=Dom) ya impresos de la semana activa.
  final Set<int> printedDays = {};
  bool isPrinting = false;
  String? _weekKeyPrinted;
  bool _disposed = false;

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final week = prefs.getString(_kKeyTandaPrintedWeek);
    final daysRaw = prefs.getString(_kKeyTandaPrintedDays);
    final dest = prefs.getString(_kKeyTandaDestination);
    final paperRaw = prefs.getString(_kKeyTandaPaperSize);
    if (_disposed) return;
    if (week != null) _weekKeyPrinted = week;
    if (daysRaw != null) {
      printedDays
        ..clear()
        ..addAll(List<int>.from(jsonDecode(daysRaw) as List));
    }
    if (dest != null) destination = dest;
    if (paperRaw == 'carta') paper = PaperSize.carta;
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (_weekKeyPrinted != null) {
      await prefs.setString(_kKeyTandaPrintedWeek, _weekKeyPrinted!);
    }
    await prefs.setString(
      _kKeyTandaPrintedDays,
      jsonEncode(printedDays.toList()),
    );
    await prefs.setString(_kKeyTandaDestination, destination);
    await prefs.setString(
      _kKeyTandaPaperSize,
      paper == PaperSize.a4 ? 'a4' : 'carta',
    );
  }

  void setDestination(String d) {
    destination = d;
    notifyListeners();
    _saveProgress();
  }

  void setPaper(PaperSize p) {
    paper = p;
    notifyListeners();
    _saveProgress();
  }

  // Reacciona a cambios de semana: resetea el avance si es una semana nueva
  // y por defecto activa el lunes de esa semana.
  void _onWeekChanged() {
    final week = weekNotifier.value;
    if (week == null) return;
    final key = _dateKey(week);
    final changed = key != _weekKeyPrinted;
    if (changed) {
      printedDays.clear();
      _weekKeyPrinted = key;
    }
    if (changed || dayNotifier.value == null) {
      dayNotifier.value = week;
    }
    if (changed) {
      notifyListeners();
      _saveProgress();
    }
  }

  Future<void> printDay({
    required DateTime date,
    required int idxInWeek,
    required HorariosData data,
    required Map<String, Feriado> feriados,
    required List<String> selectedTimes,
  }) async {
    if (isPrinting || selectedTimes.isEmpty) return;
    await _guardedPrint(
      printFn: () => printDiaPdf(
        date,
        data,
        feriados,
        destination,
        selectedTimes: selectedTimes,
        paper: paper,
      ),
      onStart: () {
        if (_disposed) return;
        isPrinting = true;
        notifyListeners();
      },
      onEnd: () {
        if (_disposed) return;
        isPrinting = false;
        notifyListeners();
      },
    );
    if (_disposed) return;
    printedDays.add(idxInWeek);
    notifyListeners();
    await _saveProgress();
    if (_disposed) return;
    if (idxInWeek < 6) {
      dayNotifier.value = date.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    weekNotifier.removeListener(_onWeekChanged);
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TandaPanel — calendario + navegador de días (panel izquierdo)
// ─────────────────────────────────────────────────────────────────────────────
class TandaPanel extends StatefulWidget {
  final TandaController controller;

  const TandaPanel({super.key, required this.controller});

  @override
  State<TandaPanel> createState() => _TandaPanelState();
}

class _TandaPanelState extends State<TandaPanel> {
  late DateTime _month;
  final _loadingYears = <int>{};

  Future<void> _loadFeriadosForMonth(DateTime month) async {
    final years = {month.year, if (month.month == 12) month.year + 1};
    for (final year in years) {
      if (_loadingYears.contains(year)) continue;
      _loadingYears.add(year);
      try {
        final list = await FeriadosService.fetchYear(year);
        if (!mounted) return;
        final map = Map<String, Feriado>.from(
          widget.controller.feriadosNotifier.value,
        );
        for (final f in list) {
          map[_dateKey(f.fecha)] = f;
        }
        widget.controller.feriadosNotifier.value = map;
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
    final ws = widget.controller.weekNotifier.value;
    _month = ws != null
        ? DateTime(ws.year, ws.month)
        : DateTime(now.year, now.month);
    Future.microtask(() => _loadFeriadosForMonth(_month));
    widget.controller.loadProgress().then((_) {
      if (!mounted) return;
      if (widget.controller.weekNotifier.value == null) {
        widget.controller.weekNotifier.value = _weekMon(now);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tamaño de hoja ──
          AnimatedBuilder(
            animation: widget.controller,
            builder: (_, _) => Row(
              children: [
                Expanded(
                  child: _PaperSizeButton(
                    size: PaperSize.a4,
                    selected: widget.controller.paper == PaperSize.a4,
                    onTap: () => widget.controller.setPaper(PaperSize.a4),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PaperSizeButton(
                    size: PaperSize.carta,
                    selected: widget.controller.paper == PaperSize.carta,
                    onTap: () => widget.controller.setPaper(PaperSize.carta),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCalendar(),
          const SizedBox(height: 16),
          _buildSemanaInfo(),
        ],
      ),
    );
  }

  Widget _buildSemanaInfo() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: widget.controller.weekNotifier,
      builder: (_, week, _) {
        if (week == null) return const SizedBox.shrink();
        final end = week.add(const Duration(days: 6));
        return ListenableBuilder(
          listenable: Listenable.merge([
            widget.controller,
            widget.controller.dayNotifier,
            widget.controller.horariosNotifier,
            widget.controller.feriadosNotifier,
          ]),
          builder: (_, _) {
            final data = widget.controller.horariosNotifier.value;
            final feriados = widget.controller.feriadosNotifier.value;
            final doneCount = widget.controller.printedDays.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Info de semana ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kBandBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDomBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Semana seleccionada',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                          Text(
                            '$doneCount/7 impresos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kDomColor.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmtFull(week),
                        style: const TextStyle(
                          fontSize: 13,
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
                const SizedBox(height: 10),
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
                        label: widget.controller.destination == 'Coyhaique'
                            ? 'Coyhaique'
                            : 'Aysén',
                        selected: widget.controller.destination == 'Coyhaique',
                        onTap: () => widget.controller.setDestination(
                          widget.controller.destination == 'Coyhaique'
                              ? 'Aysen'
                              : 'Coyhaique',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Navegador de días ──
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
    final effectiveWd = _effectiveWeekday(date, feriados);
    final ac = _accent(effectiveWd);
    final lt = _light(effectiveWd);
    final done = widget.controller.printedDays.contains(idx);
    final activeDay = widget.controller.dayNotifier.value;
    final active = activeDay != null && _dateKey(activeDay) == _dateKey(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.controller.dayNotifier.value = date,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: done ? lt : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? ac
                    : (done ? ac : const Color(0xFFDDDDDD)),
                width: active ? 2 : (done ? 1.5 : 1),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ac.withAlpha(70),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // ── Check / círculo ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? ac : Colors.transparent,
                    border: Border.all(
                      color: done ? ac : Colors.black26,
                      width: 1.5,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active || done ? ac : Colors.black87,
                        ),
                      ),
                      Text(
                        times.isEmpty
                            ? 'Sin horarios'
                            : '${times.length} horario${times.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: times.isEmpty
                              ? Colors.black26
                              : ac.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: active ? ac : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
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
              widget.controller.feriadosNotifier,
              widget.controller.weekNotifier,
              widget.controller.dayNotifier,
            ]),
            builder: (_, _) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2, right: 2),
              child: _buildGrid(
                offset,
                daysInMonth,
                widget.controller.weekNotifier.value,
                widget.controller.dayNotifier.value,
                today,
                widget.controller.feriadosNotifier.value,
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
                          selectedWeek != null &&
                          ws.year == selectedWeek.year &&
                          ws.month == selectedWeek.month &&
                          ws.day == selectedWeek.day;
                      final isSelectedDay =
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
                          widget.controller.weekNotifier.value = ws;
                          widget.controller.dayNotifier.value = date;
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
// TandaViewer — workspace de impresión día-a-día (panel derecho)
// ─────────────────────────────────────────────────────────────────────────────
class TandaViewer extends StatelessWidget {
  final TandaController controller;

  const TandaViewer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller,
          controller.weekNotifier,
          controller.dayNotifier,
          controller.horariosNotifier,
          controller.feriadosNotifier,
        ]),
        builder: (_, _) {
          final week = controller.weekNotifier.value;
          if (week == null) {
            return const Center(
              child: Text(
                'Selecciona una semana en el panel izquierdo',
                style: TextStyle(color: Colors.black38, fontSize: 14),
              ),
            );
          }
          final day = controller.dayNotifier.value ?? week;
          final data = controller.horariosNotifier.value;
          final feriados = controller.feriadosNotifier.value;
          final idx = day.weekday - 1; // 0..6, Lunes-based

          return Column(
            children: [
              _buildHeader(day, feriados),
              _buildDayNav(week, day, idx, feriados),
              Expanded(
                child: _DayWorkspace(
                  key: ValueKey(_dateKey(day)),
                  date: day,
                  idx: idx,
                  data: data,
                  feriados: feriados,
                  controller: controller,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(DateTime day, Map<String, Feriado> feriados) {
    final feriadoDia = feriados[_dateKey(day)];
    final wd = day.weekday;
    final feriadoNombre = feriadoDia?.nombre;
    return Container(
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
    );
  }

  Widget _buildDayNav(
    DateTime week,
    DateTime day,
    int idx,
    Map<String, Feriado> feriados,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: idx > 0
                ? () => controller.dayNotifier.value =
                      day.subtract(const Duration(days: 1))
                : null,
          ),
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _DayTab(
                      date: week.add(Duration(days: i)),
                      selected: i == idx,
                      done: controller.printedDays.contains(i),
                      feriados: feriados,
                      onTap: () => controller.dayNotifier.value =
                          week.add(Duration(days: i)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: idx < 6
                ? () => controller.dayNotifier.value =
                      day.add(const Duration(days: 1))
                : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayTab — pestaña de día (Lu-Ma-Mi-Ju-Vi-Sá-Do) en el panel derecho
// ─────────────────────────────────────────────────────────────────────────────
class _DayTab extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool done;
  final Map<String, Feriado> feriados;
  final VoidCallback onTap;

  const _DayTab({
    required this.date,
    required this.selected,
    required this.done,
    required this.feriados,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wd = _effectiveWeekday(date, feriados);
    final ac = _accent(wd);
    final lt = _light(wd);
    final bo = _border(wd);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ac : (done ? lt : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? ac : (done ? bo : Colors.black12),
            width: selected ? 0 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _shortNames[date.weekday - 1],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : (done ? ac : Colors.black54),
              ),
            ),
            Text(
              _fmt(date),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white70 : Colors.black38,
              ),
            ),
            SizedBox(
              height: 11,
              child: done
                  ? Icon(
                      Icons.check_circle,
                      size: 10,
                      color: selected ? Colors.white : ac,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayWorkspace — checklist de horarios + botón de imprimir para el día activo
// ─────────────────────────────────────────────────────────────────────────────
class _DayWorkspace extends StatefulWidget {
  final DateTime date;
  final int idx;
  final HorariosData data;
  final Map<String, Feriado> feriados;
  final TandaController controller;

  const _DayWorkspace({
    super.key,
    required this.date,
    required this.idx,
    required this.data,
    required this.feriados,
    required this.controller,
  });

  @override
  State<_DayWorkspace> createState() => _DayWorkspaceState();
}

class _DayWorkspaceState extends State<_DayWorkspace> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    final times = _timesForDate(widget.date, widget.data, widget.feriados);
    _selected = List.filled(times.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final times = _timesForDate(widget.date, widget.data, widget.feriados);
    if (_selected.length != times.length) {
      _selected = List.filled(times.length, true);
    }
    final wd = _effectiveWeekday(widget.date, widget.feriados);
    final ac = _accent(wd);
    final bo = _border(wd);

    if (times.isEmpty) {
      return const Center(
        child: Text(
          'Sin horarios para este día',
          style: TextStyle(color: Colors.black38, fontSize: 14),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Horarios a imprimir',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: bo),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: times.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: bo.withAlpha(130)),
                    itemBuilder: (_, i) => CheckboxListTile(
                      dense: true,
                      activeColor: ac,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected[i],
                      onChanged: (v) =>
                          setState(() => _selected[i] = v ?? false),
                      title: Text(
                        times[i],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (_, _) {
                  final checkedCount = _selected.where((s) => s).length;
                  final isPrinting = widget.controller.isPrinting;
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPrinting ? ac.withAlpha(160) : ac,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    icon: isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      isPrinting
                          ? 'Imprimiendo…'
                          : 'Imprimir $checkedCount planilla${checkedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: (checkedCount == 0 || isPrinting)
                        ? null
                        : () {
                            final chosen = [
                              for (int i = 0; i < times.length; i++)
                                if (_selected[i]) times[i],
                            ];
                            widget.controller.printDay(
                              date: widget.date,
                              idxInWeek: widget.idx,
                              data: widget.data,
                              feriados: widget.feriados,
                              selectedTimes: chosen,
                            );
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
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
// _ModeButton — botón de toggle (usado hoy para el selector de Destino)
// ─────────────────────────────────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const ac = _kHeaderDark;
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
