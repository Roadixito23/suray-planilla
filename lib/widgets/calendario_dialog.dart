import 'package:flutter/material.dart';
import '../models/feriado.dart';
import '../services/feriados_service.dart';

// ── Constantes de nombre ─────────────────────────────────────────────────────
const _meses = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const _dias = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

// ── Colores ──────────────────────────────────────────────────────────────────
const _cBlue = Color(0xFF2B579A);
const _cBlueDark = Color(0xFF1E3F73);
const _cBlueFaint = Color(0xFFDEEAF8);
const _cRed = Color(0xFFD32F2F);
const _cRedDark = Color(0xFF7B0000);
const _cBg = Color(0xFFF8F9FC);

// ─────────────────────────────────────────────────────────────────────────────
// Entry point: función helper para abrir el diálogo
// ─────────────────────────────────────────────────────────────────────────────
void showCalendarioDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const CalendarioDialog(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class CalendarioDialog extends StatefulWidget {
  const CalendarioDialog({super.key});

  @override
  State<CalendarioDialog> createState() => _CalendarioDialogState();
}

class _CalendarioDialogState extends State<CalendarioDialog> {
  late DateTime _month;
  final _feriadosMap = <String, Feriado>{};
  final _loadedYears = <int>{};
  bool _loading = true;
  String? _error;
  Feriado? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadYear(now.year);
  }

  // ── Helpers de fecha ───────────────────────────────────────────────────────
  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get _daysInMonth =>
      DateTime(_month.year, _month.month + 1, 0).day;

  int get _firstWeekday =>
      DateTime(_month.year, _month.month, 1).weekday - 1; // 0=Lu

  // ── Carga de datos ─────────────────────────────────────────────────────────
  String? _source; // descripción de la fuente usada

  Future<void> _loadYear(int year) async {
    if (_loadedYears.contains(year)) return;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final list = await FeriadosService.fetchYear(year);
      if (!mounted) return;
      final isStatic = FeriadosService.isCached(year) &&
          list.isNotEmpty &&
          list.first.comentarios.isEmpty;
      setState(() {
        for (final f in list) {
          _feriadosMap[_key(f.fecha)] = f;
        }
        _loadedYears.add(year);
        _loading = false;
        _source = isStatic ? 'datos locales (sin conexión)' : 'date.nager.at';
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Navegación ─────────────────────────────────────────────────────────────
  void _prevMonth() {
    final prev = DateTime(_month.year, _month.month - 1);
    setState(() { _month = prev; _selected = null; });
    _loadYear(prev.year);
  }

  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    setState(() { _month = next; _selected = null; });
    _loadYear(next.year);
  }

  // ── Feriados del mes activo ────────────────────────────────────────────────
  List<Feriado> get _feriadosMes {
    return _feriadosMap.values
        .where((f) =>
            f.fecha.year == _month.year && f.fecha.month == _month.month)
        .toList()
      ..sort((a, b) => a.fecha.day.compareTo(b.fecha.day));
  }

  // ── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenH * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _loading
                  ? const _LoadingPanel()
                  : _error != null
                      ? _ErrorPanel(
                          error: _error!,
                          onRetry: () => _loadYear(_month.year),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMonthNav(),
                              _buildDayLabels(),
                              _buildGrid(),
                              _buildFeriadosList(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header azul ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: const BoxDecoration(color: _cBlueDark),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feriados Chile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _source != null
                      ? 'Fuente: $_source'
                      : 'Gobierno de Chile',
                  style: TextStyle(
                    color: Colors.white.withAlpha(160),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Navegación mes/año ────────────────────────────────────────────────────
  Widget _buildMonthNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: _cBlue),
            onPressed: _prevMonth,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_meses[_month.month]}  ${_month.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _cBlue,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: _cBlue),
            onPressed: _nextMonth,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Cabeceras de días ─────────────────────────────────────────────────────
  Widget _buildDayLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: List.generate(7, (i) {
          final isFin = i >= 5;
          return Expanded(
            child: Center(
              child: Text(
                _dias[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isFin ? _cRed.withAlpha(200) : Colors.black38,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Grilla del calendario ─────────────────────────────────────────────────
  Widget _buildGrid() {
    final today = DateTime.now();
    final offset = _firstWeekday;
    final days = _daysInMonth;
    final totalCells = offset + days;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        children: List.generate(rows, (r) {
          return Row(
            children: List.generate(7, (c) {
              final index = r * 7 + c;
              final day = index - offset + 1;

              if (day < 1 || day > days) {
                return const Expanded(child: SizedBox(height: 40));
              }

              final date = DateTime(_month.year, _month.month, day);
              final feriado = _feriadosMap[_key(date)];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selected != null &&
                  _selected!.fecha.day == day &&
                  _selected!.fecha.month == _month.month &&
                  _selected!.fecha.year == _month.year;
              final isFin = c >= 5;

              return Expanded(child: _DayCell(
                day: day,
                feriado: feriado,
                isToday: isToday,
                isSelected: isSelected,
                isWeekend: isFin,
                onTap: feriado != null
                    ? () => setState(() =>
                        _selected = isSelected ? null : feriado)
                    : null,
              ));
            }),
          );
        }),
      ),
    );
  }

  // ── Lista de feriados del mes ─────────────────────────────────────────────
  Widget _buildFeriadosList() {
    final list = _feriadosMes;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 15, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(
              'Sin feriados en ${_meses[_month.month]}',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: _cBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'FERIADOS DE ${_meses[_month.month].toUpperCase()}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...list.map((f) => _FeriadoListItem(
                feriado: f,
                isSelected: _selected?.fecha.day == f.fecha.day &&
                    _selected?.fecha.month == f.fecha.month,
                onTap: () => setState(
                    () => _selected =
                        (_selected?.fecha == f.fecha) ? null : f),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Celda de día
// ─────────────────────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final int day;
  final Feriado? feriado;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.feriado,
    required this.isToday,
    required this.isSelected,
    required this.isWeekend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color textColor = isWeekend ? _cRed.withAlpha(180) : Colors.black87;
    FontWeight weight = FontWeight.normal;
    Border? border;

    if (feriado != null) {
      bgColor = feriado!.irrenunciable ? _cRedDark : _cRed;
      textColor = Colors.white;
      weight = FontWeight.w700;
    } else if (isToday) {
      bgColor = _cBlueFaint;
      textColor = _cBlue;
      weight = FontWeight.w700;
    }

    if (isSelected) {
      border = Border.all(color: Colors.orange.shade600, width: 2);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12.5,
              color: textColor,
              fontWeight: weight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ítem de la lista de feriados
// ─────────────────────────────────────────────────────────────────────────────
class _FeriadoListItem extends StatelessWidget {
  final Feriado feriado;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeriadoListItem({
    required this.feriado,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = feriado.irrenunciable ? _cRedDark : _cRed;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? Colors.orange.withAlpha(30) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Día
            SizedBox(
              width: 28,
              child: Text(
                '${feriado.fecha.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
            ),
            // Dot
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 8),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ),
            // Nombre + tipo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feriado.nombre,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      _Tag(
                        label: feriado.tipo.isEmpty ? 'Civil' : feriado.tipo,
                        color: Colors.blueGrey,
                      ),
                      if (feriado.irrenunciable) ...[
                        const SizedBox(width: 4),
                        _Tag(label: 'Irrenunciable', color: _cRedDark),
                      ],
                    ],
                  ),
                  if (isSelected && feriado.comentarios.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        feriado.comentarios,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
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

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paneles de estado
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _cBlue, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Cargando feriados…',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.black26),
          const SizedBox(height: 12),
          const Text(
            'No se pudieron cargar los feriados',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: _cBlue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
