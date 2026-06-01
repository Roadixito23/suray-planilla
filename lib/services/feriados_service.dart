import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feriado.dart';

class FeriadosService {
  // API primaria (Nager Date — CDN global, sin clave)
  static const _nager = 'https://date.nager.at/api/v3/PublicHolidays';

  // API secundaria (gobierno Chile — puede fallar en algunos entornos)
  static const _digital = 'https://apis.digital.gob.cl/fl/feriados';

  static final _cache = <int, List<Feriado>>{};
  static final _cacheMonthKey = <int, String>{}; // year → "YYYY-MM"

  static bool isCached(int year) => _cache.containsKey(year);

  static bool _isCacheStale(int year) {
    final saved = _cacheMonthKey[year];
    if (saved == null) return true;
    final now = DateTime.now();
    return saved != '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static Future<List<Feriado>> fetchYear(int year) async {
    if (_cache.containsKey(year) && !_isCacheStale(year)) return _cache[year]!;

    // 1 — Intentar Nager Date
    try {
      final res = await http
          .get(Uri.parse('$_nager/$year/CL'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => Feriado.fromNager(e as Map<String, dynamic>))
            .toList();
        _cache[year] = list;
        _cacheMonthKey[year] = _monthKey();
        return list;
      }
    } catch (_) {/* intentar siguiente */}

    // 2 — Intentar APIs Digital Chile
    try {
      final res = await http
          .get(Uri.parse('$_digital/$year'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => Feriado.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache[year] = list;
        _cacheMonthKey[year] = _monthKey();
        return list;
      }
    } catch (_) {/* intentar siguiente */}

    // 3 — Datos estáticos de respaldo
    final fallback = _staticFeriados[year];
    if (fallback != null) {
      _cache[year] = fallback;
      _cacheMonthKey[year] = _monthKey();
      return fallback;
    }

    throw Exception(
      'Sin conexión a Internet y no hay datos locales para $year.',
    );
  }

  // ── Datos estáticos Chile 2025-2027 ────────────────────────────────────────
  static final _staticFeriados = <int, List<Feriado>>{
    2025: _build(2025, [
      ('2025-01-01', 'Año Nuevo', true),
      ('2025-04-18', 'Viernes Santo', true),
      ('2025-04-19', 'Sábado Santo', false),
      ('2025-05-01', 'Día del Trabajo', true),
      ('2025-05-21', 'Glorias Navales', true),
      ('2025-06-20', 'Día Nacional de los Pueblos Indígenas', true),
      ('2025-06-29', 'San Pedro y San Pablo', true),
      ('2025-07-16', 'Virgen del Carmen', true),
      ('2025-08-15', 'Asunción de la Virgen', true),
      ('2025-09-18', 'Independencia Nacional', true),
      ('2025-09-19', 'Glorias del Ejército', true),
      ('2025-10-12', 'Encuentro de Dos Mundos', true),
      ('2025-10-25', 'Día Iglesias Evangélicas y Protestantes', false),
      ('2025-11-01', 'Día de Todos los Santos', true),
      ('2025-12-08', 'Inmaculada Concepción', true),
      ('2025-12-25', 'Navidad', true),
    ]),
    2026: _build(2026, [
      ('2026-01-01', 'Año Nuevo', true),
      ('2026-04-03', 'Viernes Santo', true),
      ('2026-04-04', 'Sábado Santo', false),
      ('2026-05-01', 'Día del Trabajo', true),
      ('2026-05-21', 'Glorias Navales', true),
      ('2026-06-21', 'Día Nacional de los Pueblos Indígenas', true),
      ('2026-06-29', 'San Pedro y San Pablo', true),
      ('2026-07-16', 'Virgen del Carmen', true),
      ('2026-08-15', 'Asunción de la Virgen', true),
      ('2026-09-18', 'Independencia Nacional', true),
      ('2026-09-19', 'Glorias del Ejército', true),
      ('2026-10-12', 'Encuentro de Dos Mundos', true),
      ('2026-10-31', 'Día Iglesias Evangélicas y Protestantes', false),
      ('2026-11-01', 'Día de Todos los Santos', true),
      ('2026-12-08', 'Inmaculada Concepción', true),
      ('2026-12-25', 'Navidad', true),
    ]),
    2027: _build(2027, [
      ('2027-01-01', 'Año Nuevo', true),
      ('2027-03-26', 'Viernes Santo', true),
      ('2027-03-27', 'Sábado Santo', false),
      ('2027-05-01', 'Día del Trabajo', true),
      ('2027-05-21', 'Glorias Navales', true),
      ('2027-06-21', 'Día Nacional de los Pueblos Indígenas', true),
      ('2027-06-29', 'San Pedro y San Pablo', true),
      ('2027-07-16', 'Virgen del Carmen', true),
      ('2027-08-15', 'Asunción de la Virgen', true),
      ('2027-09-18', 'Independencia Nacional', true),
      ('2027-09-19', 'Glorias del Ejército', true),
      ('2027-10-12', 'Encuentro de Dos Mundos', true),
      ('2027-10-30', 'Día Iglesias Evangélicas y Protestantes', false),
      ('2027-11-01', 'Día de Todos los Santos', true),
      ('2027-12-08', 'Inmaculada Concepción', true),
      ('2027-12-25', 'Navidad', true),
    ]),
  };

  static List<Feriado> _build(
    int year,
    List<(String, String, bool)> data,
  ) =>
      data
          .map(
            (e) => Feriado(
              nombre: e.$2,
              fecha: DateTime.parse(e.$1),
              tipo: 'Civil',
              irrenunciable: e.$3,
              comentarios: '',
            ),
          )
          .toList();
}
