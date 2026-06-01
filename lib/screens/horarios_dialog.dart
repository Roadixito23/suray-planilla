import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claves de SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
const _kKeyLV = 'horarios_lunes_viernes';
const _kKeySab = 'horarios_sabado';
const _kKeyDom = 'horarios_domingo_feriado';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo
// ─────────────────────────────────────────────────────────────────────────────
class HorariosData {
  final List<String> lunesViernes;
  final List<String> sabado;
  final List<String> domingoFeriado;

  const HorariosData({
    required this.lunesViernes,
    required this.sabado,
    required this.domingoFeriado,
  });

  HorariosData copyWith({
    List<String>? lunesViernes,
    List<String>? sabado,
    List<String>? domingoFeriado,
  }) {
    return HorariosData(
      lunesViernes: lunesViernes ?? this.lunesViernes,
      sabado: sabado ?? this.sabado,
      domingoFeriado: domingoFeriado ?? this.domingoFeriado,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistencia
// ─────────────────────────────────────────────────────────────────────────────
Future<HorariosData> loadHorarios() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> load(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  return HorariosData(
    lunesViernes: load(_kKeyLV),
    sabado: load(_kKeySab),
    domingoFeriado: load(_kKeyDom),
  );
}

Future<void> saveHorarios(HorariosData data) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kKeyLV, jsonEncode(data.lunesViernes));
  await prefs.setString(_kKeySab, jsonEncode(data.sabado));
  await prefs.setString(_kKeyDom, jsonEncode(data.domingoFeriado));
}

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de colores
// ─────────────────────────────────────────────────────────────────────────────
// Lunes–Viernes → Hunter Green
const _kLVColor = Color(0xFF355E3B);
const _kLVLight = Color(0xFFECF4EC);
const _kLVBorder = Color(0xFFAFCDB2);
const _kLVDark = Color(0xFF1F3D23);
// Sábado → Ámbar dorado
const _kSabColor = Color(0xFF7A5C14);
const _kSabLight = Color(0xFFF5EDD8);
const _kSabBorder = Color(0xFFCFB26A);
const _kSabDark = Color(0xFF54400D);
// Domingo/Feriado → Burdeo
const _kDomColor = Color(0xFF7B1F2E);
const _kDomLight = Color(0xFFF5E8EA);
const _kDomBorder = Color(0xFFCCA0A8);
const _kDomDark = Color(0xFF4A0D17);

// ─────────────────────────────────────────────────────────────────────────────
// Panel CRUD de Horarios (panel izquierdo del layout de dos columnas)
// ─────────────────────────────────────────────────────────────────────────────
class HorariosCrudPanel extends StatefulWidget {
  final ValueChanged<HorariosData> onMutate;
  final ValueNotifier<HorariosData> dataNotifier;

  const HorariosCrudPanel({
    super.key,
    required this.onMutate,
    required this.dataNotifier,
  });

  @override
  State<HorariosCrudPanel> createState() => _HorariosCrudPanelState();
}

class _HorariosCrudPanelState extends State<HorariosCrudPanel> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await loadHorarios();
    if (mounted) {
      widget.dataNotifier.value = data;
      widget.onMutate(data);
      setState(() => _loading = false);
    }
  }

  Future<void> _mutate(HorariosData updated) async {
    widget.dataNotifier.value = updated;
    widget.onMutate(updated);
    await saveHorarios(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<HorariosData>(
      valueListenable: widget.dataNotifier,
      builder: (context, data, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _ScheduleColumn(
                title: 'Lunes – Viernes',
                subtitle: 'Días laborables',
                icon: Icons.work_history_outlined,
                accentColor: _kLVColor,
                darkColor: _kLVDark,
                lightBg: _kLVLight,
                borderColor: _kLVBorder,
                times: data.lunesViernes,
                onChanged: (l) => _mutate(data.copyWith(lunesViernes: l)),
              ),
              const SizedBox(height: 12),
              _ScheduleColumn(
                title: 'Sábado',
                subtitle: 'Fin de semana',
                icon: Icons.weekend_outlined,
                accentColor: _kSabColor,
                darkColor: _kSabDark,
                lightBg: _kSabLight,
                borderColor: _kSabBorder,
                times: data.sabado,
                onChanged: (l) => _mutate(data.copyWith(sabado: l)),
              ),
              const SizedBox(height: 12),
              _ScheduleColumn(
                title: 'Domingo / Feriado',
                subtitle: 'Días festivos',
                icon: Icons.celebration_outlined,
                accentColor: _kDomColor,
                darkColor: _kDomDark,
                lightBg: _kDomLight,
                borderColor: _kDomBorder,
                times: data.domingoFeriado,
                onChanged: (l) => _mutate(data.copyWith(domingoFeriado: l)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visor de Horarios (panel derecho del layout de dos columnas)
// ─────────────────────────────────────────────────────────────────────────────
class HorariosViewer extends StatelessWidget {
  final ValueNotifier<HorariosData> dataNotifier;

  const HorariosViewer({super.key, required this.dataNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HorariosData>(
      valueListenable: dataNotifier,
      builder: (context, data, _) {
        return Container(
          color: const Color(0xFFE8E8E8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ViewerSection(
                    title: 'Lunes – Viernes',
                    subtitle: 'Días laborables',
                    icon: Icons.work_history_outlined,
                    accentColor: _kLVColor,
                    lightBg: _kLVLight,
                    borderColor: _kLVBorder,
                    darkColor: _kLVDark,
                    times: data.lunesViernes,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ViewerSection(
                    title: 'Sábado',
                    subtitle: 'Fin de semana',
                    icon: Icons.weekend_outlined,
                    accentColor: _kSabColor,
                    lightBg: _kSabLight,
                    borderColor: _kSabBorder,
                    darkColor: _kSabDark,
                    times: data.sabado,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ViewerSection(
                    title: 'Domingo / Feriado',
                    subtitle: 'Días festivos',
                    icon: Icons.celebration_outlined,
                    accentColor: _kDomColor,
                    lightBg: _kDomLight,
                    borderColor: _kDomBorder,
                    darkColor: _kDomDark,
                    times: data.domingoFeriado,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ViewerSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color lightBg;
  final Color borderColor;
  final Color darkColor;
  final List<String> times;

  const _ViewerSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.lightBg,
    required this.borderColor,
    required this.darkColor,
    required this.times,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${times.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Time list
          if (times.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(icon, size: 32, color: accentColor.withAlpha(60)),
                  const SizedBox(height: 8),
                  Text(
                    'Sin horarios',
                    style: TextStyle(
                      color: accentColor.withAlpha(120),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: times
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: lightBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 13,
                              color: accentColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: darkColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Columna de horarios (una por categoría de día)
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduleColumn extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color darkColor;
  final Color lightBg;
  final Color borderColor;
  final List<String> times;
  final ValueChanged<List<String>> onChanged;

  const _ScheduleColumn({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.darkColor,
    required this.lightBg,
    required this.borderColor,
    required this.times,
    required this.onChanged,
  });

  @override
  State<_ScheduleColumn> createState() => _ScheduleColumnState();
}

class _ScheduleColumnState extends State<_ScheduleColumn> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final val = _ctrl.text.trim();
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(val)) {
      setState(() => _error = 'Formato inválido (HH:MM)');
      return;
    }
    if (widget.times.contains(val)) {
      setState(() => _error = 'Horario ya existe');
      return;
    }
    setState(() => _error = null);
    final updated = [...widget.times, val]..sort();
    widget.onChanged(updated);
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _delete(int index) {
    final updated = [...widget.times]..removeAt(index);
    widget.onChanged(updated);
  }

  void _edit(int index, String newVal) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(newVal)) return;
    final updated = [...widget.times];
    updated[index] = newVal;
    updated.sort();
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header columna ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.times.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Campo agregar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_TimeInputFormatter()],
                    maxLength: 5,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: '08:30',
                      counterText: '',
                      errorText: _error,
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.add_alarm_outlined,
                        size: 17,
                        color: color,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: widget.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: widget.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 38),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _add,
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: widget.borderColor),
          // ── Lista ──
          if (widget.times.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 36, color: color.withAlpha(60)),
                  const SizedBox(height: 8),
                  Text(
                    'Sin horarios',
                    style: TextStyle(
                      color: color.withAlpha(120),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Agrega uno arriba',
                    style: TextStyle(
                      color: color.withAlpha(80),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: widget.times.length,
              itemBuilder: (_, i) => _TimeCard(
                time: widget.times[i],
                accentColor: color,
                darkColor: widget.darkColor,
                lightBg: widget.lightBg,
                borderColor: widget.borderColor,
                onDelete: () => _delete(i),
                onEdit: (v) => _edit(i, v),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de un horario individual
// ─────────────────────────────────────────────────────────────────────────────
class _TimeCard extends StatefulWidget {
  final String time;
  final Color accentColor;
  final Color darkColor;
  final Color lightBg;
  final Color borderColor;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const _TimeCard({
    required this.time,
    required this.accentColor,
    required this.darkColor,
    required this.lightBg,
    required this.borderColor,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends State<_TimeCard> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.time);
  }

  @override
  void didUpdateWidget(_TimeCard old) {
    super.didUpdateWidget(old);
    if (old.time != widget.time && !_editing) _ctrl.text = widget.time;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onEdit(_ctrl.text.trim());
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: _editing ? Colors.white : widget.lightBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _editing ? widget.accentColor : widget.borderColor,
          width: _editing ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 42,
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_TimeInputFormatter()],
                    maxLength: 5,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.darkColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _commit(),
                  )
                : Text(
                    widget.time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.darkColor,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
          if (_editing) ...[
            IconButton(
              icon: Icon(Icons.check, size: 16, color: widget.accentColor),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: _commit,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.black38),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () {
                _ctrl.text = widget.time;
                setState(() => _editing = false);
              },
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 15,
                color: widget.accentColor.withAlpha(150),
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _editing = true),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red.shade300,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: widget.onDelete,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatter reutilizado (HH:MM)
// ─────────────────────────────────────────────────────────────────────────────
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final result = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2, digits.length.clamp(0, 4))}';
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
