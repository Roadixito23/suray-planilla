import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../models/feriado.dart';
import '../painters/planilla_painter.dart';
import '../services/pdf_cache_service.dart';
import 'horarios_dialog.dart';
import 'tanda_screen.dart';

enum PaperSize { a4, carta }

extension PaperSizeInfo on PaperSize {
  String get label => this == PaperSize.a4 ? 'A4' : 'Carta';
  String get dimensions =>
      this == PaperSize.a4 ? '210 × 297 mm' : '215.9 × 279.4 mm';
  double get widthMm => this == PaperSize.a4 ? 210 : 215.9;
  double get heightMm => this == PaperSize.a4 ? 297 : 279.4;
  double get aspectRatio => widthMm / heightMm;
}

const _kBlue = Color(0xFF7B1F2E);
const _kHunterGreen = Color(0xFF355E3B);
const _kBlueDark = Color(0xFF4A0D17);
const _kDivider = Color(0xFFDDDDDD);
const _kSelected = Color(0xFFF5DDE0);

enum _AppView { planilla, tanda, horarios }

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialHorarios});
  final HorariosData? initialHorarios;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PaperSize _paper = PaperSize.a4;
  String _destination = 'Coyhaique';
  String _time = '00:00';
  String _date = '29/05';
  bool _isPrintingPlanilla = false;
  late final TransformationController _transform;
  late final PdfCacheService _pdfCache;
  final _repaintKey = GlobalKey();
  final _canvasKey = GlobalKey();
  _AppView _view = _AppView.planilla;
  final _zoomNotifier = ValueNotifier<double>(1.0);
  final _tandaWeekNotifier = ValueNotifier<DateTime?>(null);
  final _tandaDayNotifier = ValueNotifier<DateTime?>(null);
  final _tandaModeNotifier = ValueNotifier<TandaMode>(TandaMode.semana);
  final _feriadosTandaNotifier = ValueNotifier<Map<String, Feriado>>({});
  late final ValueNotifier<HorariosData> _horariosNotifier;

  void _onHorariosChanged(HorariosData data) {
    _horariosNotifier.value = data;
  }

  @override
  void initState() {
    super.initState();
    _horariosNotifier = ValueNotifier<HorariosData>(
      widget.initialHorarios ??
          const HorariosData(lunesViernes: [], sabado: [], domingoFeriado: []),
    );
    _transform = TransformationController();
    _pdfCache = PdfCacheService()..attach(_capturePng);
    Future.microtask(() => _invalidateCache());
  }

  @override
  void dispose() {
    _transform.dispose();
    _pdfCache.dispose();
    _zoomNotifier.dispose();
    _tandaWeekNotifier.dispose();
    _tandaDayNotifier.dispose();
    _tandaModeNotifier.dispose();
    _horariosNotifier.dispose();
    _feriadosTandaNotifier.dispose();
    super.dispose();
  }

  void _invalidateCache() {
    _pdfCache.invalidate(_paper == PaperSize.a4, _destination, _time, _date);
  }

  /// Captura la planilla como PNG desde el RepaintBoundary.
  /// Debe ejecutarse en el main thread (accede al render tree).
  Future<Uint8List?> _capturePng() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  void _setZoom(double scale) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size;
    final cx = (size?.width ?? 0) / 2;
    final cy = (size?.height ?? 0) / 2;
    _transform.value = Matrix4.identity()
      ..translate(cx * (1 - scale), cy * (1 - scale))
      ..scale(scale, scale);
    _zoomNotifier.value = scale;
  }

  Future<void> _printPdf() async {
    if (_isPrintingPlanilla) return;
    setState(() => _isPrintingPlanilla = true);
    try {
      await Future.wait([
        _pdfCache
            .getPdfBytes(
              isA4: _paper == PaperSize.a4,
              destination: _destination,
              time: _time,
              date: _date,
            )
            .then((bytes) => Printing.layoutPdf(onLayout: (_) async => bytes)),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
    } finally {
      if (mounted) setState(() => _isPrintingPlanilla = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD0D0D0),
      body: Row(
        children: [
          // ── Panel izquierdo: controles ──
          SizedBox(
            width: 442,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SidebarHeader(
                    activeView: _view,
                    onViewChanged: (v) {
                      setState(() => _view = v);
                      if (v == _AppView.planilla) _invalidateCache();
                    },
                    onPrint: (_view == _AppView.planilla && !_isPrintingPlanilla)
                        ? _printPdf
                        : null,
                    isPrinting:
                        _isPrintingPlanilla && _view == _AppView.planilla,
                  ),
                  if (_view == _AppView.planilla)
                    Expanded(
                      child: _SidebarControls(
                        paper: _paper,
                        destination: _destination,
                        time: _time,
                        date: _date,
                        onPaperChanged: (p) {
                          setState(() => _paper = p);
                          _invalidateCache();
                        },
                        onZoom: _setZoom,
                        onDestinationChanged: (d) {
                          setState(() => _destination = d);
                          _invalidateCache();
                        },
                        onTimeChanged: (t) {
                          setState(() => _time = t);
                          _invalidateCache();
                        },
                        onDateChanged: (d) {
                          setState(() => _date = d);
                          _invalidateCache();
                        },
                      ),
                    )
                  else if (_view == _AppView.tanda)
                    Expanded(
                      child: TandaPanel(
                        weekNotifier: _tandaWeekNotifier,
                        horariosNotifier: _horariosNotifier,
                        feriadosNotifier: _feriadosTandaNotifier,
                        modeNotifier: _tandaModeNotifier,
                        dayNotifier: _tandaDayNotifier,
                      ),
                    )
                  else
                    Expanded(
                      child: HorariosCrudPanel(
                        onMutate: _onHorariosChanged,
                        dataNotifier: _horariosNotifier,
                      ),
                    ),
                  if (_view == _AppView.planilla)
                    _StatusBar(
                      paper: _paper,
                      zoomNotifier: _zoomNotifier,
                      onZoom: _setZoom,
                      cacheStatus: _pdfCache.statusNotifier,
                    ),
                ],
              ),
            ),
          ),
          // ── Divisor ──
          Container(width: 1, color: const Color(0xFFBBBBBB)),
          // ── Panel derecho: visor ──
          Expanded(
            child: switch (_view) {
              _AppView.planilla => _DocumentCanvas(
                key: _canvasKey,
                paper: _paper,
                transform: _transform,
                destination: _destination,
                time: _time,
                date: _date,
                repaintKey: _repaintKey,
              ),
              _AppView.tanda => TandaViewer(
                weekNotifier: _tandaWeekNotifier,
                horariosNotifier: _horariosNotifier,
                feriadosNotifier: _feriadosTandaNotifier,
                modeNotifier: _tandaModeNotifier,
                dayNotifier: _tandaDayNotifier,
              ),
              _AppView.horarios => HorariosViewer(
                dataNotifier: _horariosNotifier,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar: encabezado con navegación y acciones
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final _AppView activeView;
  final ValueChanged<_AppView> onViewChanged;
  final VoidCallback? onPrint;
  final bool isPrinting;

  const _SidebarHeader({
    required this.activeView,
    required this.onViewChanged,
    this.onPrint,
    this.isPrinting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBlueDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── App title row ──
          Container(
            height: 47,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.grid_on, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Suray Planilla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onPrint != null || isPrinting)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isPrinting
                          ? _kHunterGreen.withAlpha(160)
                          : _kHunterGreen,
                      borderRadius: BorderRadius.circular(5),
                      child: InkWell(
                        onTap: isPrinting ? null : onPrint,
                        borderRadius: BorderRadius.circular(5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPrinting)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.print_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              const SizedBox(width: 7),
                              Text(
                                activeView == _AppView.planilla
                                    ? 'Imprimir Planilla'
                                    : 'Imprimir Tanda',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Nav tabs ──
          Container(
            color: _kBlue,
            child: Row(
              children: [
                _SideNavBtn(
                  label: 'Planilla',
                  icon: Icons.description_outlined,
                  active: activeView == _AppView.planilla,
                  onTap: activeView != _AppView.planilla
                      ? () => onViewChanged(_AppView.planilla)
                      : null,
                ),
                _SideNavBtn(
                  label: 'Tanda',
                  icon: Icons.view_week_outlined,
                  active: activeView == _AppView.tanda,
                  onTap: activeView != _AppView.tanda
                      ? () => onViewChanged(_AppView.tanda)
                      : null,
                ),
                _SideNavBtn(
                  label: 'Horarios',
                  icon: Icons.schedule_rounded,
                  active: activeView == _AppView.horarios,
                  onTap: activeView != _AppView.horarios
                      ? () => onViewChanged(_AppView.horarios)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _SideNavBtn({
    required this.label,
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : Colors.white54),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar: panel de controles de planilla
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarControls extends StatelessWidget {
  final PaperSize paper;
  final String destination;
  final String time;
  final String date;
  final ValueChanged<PaperSize> onPaperChanged;
  final ValueChanged<double> onZoom;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<String> onDateChanged;

  const _SidebarControls({
    required this.paper,
    required this.destination,
    required this.time,
    required this.date,
    required this.onPaperChanged,
    required this.onZoom,
    required this.onDestinationChanged,
    required this.onTimeChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Destino ──
          _SideSection(
            title: 'Destino',
            child: Row(
              children: [
                _DestinationBtn(
                  label: 'Coyhaique',
                  current: destination,
                  onTap: () => onDestinationChanged('Coyhaique'),
                ),
                const SizedBox(width: 10),
                _DestinationBtn(
                  label: 'Aysen',
                  current: destination,
                  onTap: () => onDestinationChanged('Aysen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          // ── Fecha y Hora ──
          _SideSection(
            title: 'Fecha y Hora',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SideField(
                  label: 'Hora (HH:MM)',
                  hint: '00:00',
                  initialValue: time,
                  onChanged: onTimeChanged,
                  formatter: _TimeInputFormatter(),
                ),
                const SizedBox(height: 13),
                _SideField(
                  label: 'Fecha (DD/MM)',
                  hint: '29/05',
                  initialValue: date,
                  onChanged: onDateChanged,
                  formatter: _DateInputFormatter(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          // ── Tamaño de hoja ──
          _SideSection(
            title: 'Tamaño de hoja',
            child: Row(
              children: [
                _PaperBtn(
                  size: PaperSize.a4,
                  current: paper,
                  onTap: () => onPaperChanged(PaperSize.a4),
                ),
                const SizedBox(width: 10),
                _PaperBtn(
                  size: PaperSize.carta,
                  current: paper,
                  onTap: () => onPaperChanged(PaperSize.carta),
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          // ── Zoom ──
          _SideSection(
            title: 'Zoom',
            child: Wrap(
              spacing: 8,
              children: [
                _RibbonBtn(
                  icon: Icons.zoom_in,
                  label: '100%',
                  onTap: () => onZoom(1.0),
                ),
                _RibbonBtn(
                  icon: Icons.zoom_out,
                  label: '75%',
                  onTap: () => onZoom(0.75),
                ),
                _RibbonBtn(
                  icon: Icons.fit_screen_outlined,
                  label: 'Ajustar',
                  onTap: () => onZoom(1.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SideSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 5),
        const Divider(height: 1, color: _kDivider),
      ],
    );
  }
}

class _SideField extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextInputFormatter formatter;

  const _SideField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    required this.formatter,
  });

  @override
  State<_SideField> createState() => _SideFieldState();
}

class _SideFieldState extends State<_SideField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 117,
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _ctrl,
            onChanged: widget.onChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [widget.formatter],
            maxLength: 5,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: widget.hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: _kDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: _kBlue),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatters de entrada
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

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final result = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _RibbonBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RibbonBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 29, color: const Color(0xFF444444)),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperBtn extends StatelessWidget {
  final PaperSize size;
  final PaperSize current;
  final VoidCallback onTap;

  const _PaperBtn({
    required this.size,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = size == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? _kSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: sel ? _kBlue : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 29,
              color: sel ? _kBlue : const Color(0xFF444444),
            ),
            const SizedBox(height: 3),
            Text(
              size.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                color: sel ? _kBlue : Colors.black87,
              ),
            ),
            Text(
              size == PaperSize.a4 ? '210×297' : '216×279',
              style: const TextStyle(fontSize: 10, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationBtn extends StatelessWidget {
  final String label;
  final String current;
  final VoidCallback onTap;

  const _DestinationBtn({
    required this.label,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = label == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? _kSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: sel ? _kBlue : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 29,
              color: sel ? _kBlue : const Color(0xFF444444),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                color: sel ? _kBlue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas del documento
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentCanvas extends StatelessWidget {
  final PaperSize paper;
  final TransformationController transform;
  final String destination;
  final String time;
  final String date;
  final GlobalKey repaintKey;

  const _DocumentCanvas({
    super.key,
    required this.paper,
    required this.transform,
    required this.destination,
    required this.time,
    required this.date,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transform,
      minScale: 0.2,
      maxScale: 12.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: AspectRatio(
            aspectRatio: paper.aspectRatio,
            child: RepaintBoundary(
              key: repaintKey,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(4, 6),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: PlanillaPainter(
                    destination: destination,
                    time: time,
                    date: date,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de estado
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final PaperSize paper;
  final ValueNotifier<double> zoomNotifier;
  final ValueChanged<double> onZoom;
  final ValueNotifier<PdfCacheStatus> cacheStatus;

  const _StatusBar({
    required this.paper,
    required this.zoomNotifier,
    required this.onZoom,
    required this.cacheStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: _kBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Página 1 de 1',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Text(
            paper.dimensions,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(width: 16),
          // ── Indicador de estado PDF ──
          ValueListenableBuilder<PdfCacheStatus>(
            valueListenable: cacheStatus,
            builder: (_, status, _) => _PdfStatusChip(status: status),
          ),
          const Spacer(),
          // Controles de zoom
          ValueListenableBuilder<double>(
            valueListenable: zoomNotifier,
            builder: (_, zoom, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => onZoom((zoom - 0.1).clamp(0.2, 4.0)),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onZoom((zoom + 0.1).clamp(0.2, 4.0)),
                  child: const Icon(Icons.add, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Indicador de estado del PDF
// ─────────────────────────────────────────────────────────────────────────────
class _PdfStatusChip extends StatelessWidget {
  final PdfCacheStatus status;
  const _PdfStatusChip({required this.status});

  static const _style = TextStyle(color: Colors.white70, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PdfCacheStatus.idle => const SizedBox.shrink(),
      PdfCacheStatus.preparing => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
          SizedBox(width: 7),
          Text('Preparando PDF…', style: _style),
        ],
      ),
      PdfCacheStatus.ready => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent),
          SizedBox(width: 5),
          Text('PDF listo', style: _style),
        ],
      ),
      PdfCacheStatus.error => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.orangeAccent,
          ),
          SizedBox(width: 5),
          Text('Error al preparar', style: _style),
        ],
      ),
    };
  }
}
