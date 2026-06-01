import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/feriados_service.dart';
import 'home_screen.dart';
import 'horarios_dialog.dart';

const _kBg = Color(0xFF3A0A14); // burdeo oscuro de fondo
const _kGold = Color(0xFFD4AF37); // dorado como complementario al burdeo

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusText = 'Iniciando…';
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _setProgress(double p, String text) {
    if (!mounted) return;
    setState(() {
      _progress = p;
      _statusText = text;
    });
  }

  Future<void> _load() async {
    // 1 — SharedPreferences
    _setProgress(0.1, 'Cargando preferencias…');
    await SharedPreferences.getInstance();

    // 2 — Horarios guardados
    _setProgress(0.4, 'Cargando horarios…');
    HorariosData? horarios;
    try {
      horarios = await loadHorarios();
    } catch (_) {}

    // 3 — Feriados del año en curso
    _setProgress(0.7, 'Cargando feriados…');
    try {
      await FeriadosService.fetchYear(DateTime.now().year);
    } catch (_) {}

    _setProgress(1.0, 'Listo');
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => HomeScreen(initialHorarios: horarios),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Ícono ──
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.grid_on_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                // ── Nombre ──
                const Text(
                  'Suray Planilla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sistema de gestión de boletos',
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 52),
                // ── Barra de progreso ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _progress),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white.withAlpha(30),
                      valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Texto de estado ──
                Text(
                  _statusText,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
