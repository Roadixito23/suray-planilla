import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Estado visible en la UI ──────────────────────────────────────────────────
enum PdfCacheStatus { idle, preparing, ready, error }

// ── Función top-level para compute() — corre en un Isolate separado ──────────
// Recibe (pngBytes, isA4) y devuelve los bytes del PDF serializado.
Future<Uint8List> _buildPdfInIsolate((Uint8List, bool) args) async {
  final (pngBytes, isA4) = args;
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: isA4 ? PdfPageFormat.a4 : PdfPageFormat.letter,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Transform.rotate(
        angle: math.pi,
        child: pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain),
      ),
    ),
  );
  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
/// Servicio de caché de PDF con pre-renderizado en segundo plano.
///
/// Flujo:
///   1. Al cambiar configuración → [invalidate()] → debounce 600 ms → pre-render
///   2. Al tocar "Imprimir"      → [getPdfBytes()] → caché hit → instantáneo
///      (o awaita la operación en curso si todavía está renderizando)
// ─────────────────────────────────────────────────────────────────────────────
class PdfCacheService {
  /// Notifier que la UI observa para mostrar el indicador de estado.
  final statusNotifier = ValueNotifier<PdfCacheStatus>(PdfCacheStatus.idle);

  Uint8List? _cachedPdfBytes;
  String? _cachedKey;   // key del resultado guardado en _cachedPdfBytes
  String? _pendingKey;  // key más reciente recibida (puede cambiar mid-flight)

  Future<Uint8List>? _inflightFuture;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Callback que captura la planilla como PNG (provisto por HomeScreen).
  /// Debe ejecutarse en el main thread porque accede al RenderRepaintBoundary.
  Future<Uint8List?> Function()? _captureCallback;

  // ── API pública ─────────────────────────────────────────────────────────────

  /// Registra el callback de captura. Llamar en initState de HomeScreen.
  void attach(Future<Uint8List?> Function() captureCallback) {
    _captureCallback = captureCallback;
  }

  /// Invalida el caché y programa un pre-render para 600 ms después.
  /// Llamar cada vez que cambie paper, destination, time o date.
  void invalidate(bool isA4, String destination, String time, String date) {
    final key = _key(isA4, destination, time, date);
    _pendingKey = key;

    if (_cachedKey == key) {
      _setStatus(PdfCacheStatus.ready); // ya en caché para esta config
      return;
    }

    _setStatus(PdfCacheStatus.idle);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_disposed) _startWork(key, isA4);
    });
  }

  /// Retorna los bytes del PDF:
  ///   • Instantáneo si el caché es válido.
  ///   • Awaita la operación en curso si ya está pre-renderizando.
  ///   • Lanza la operación ahora si nada está en curso.
  Future<Uint8List> getPdfBytes({
    required bool isA4,
    required String destination,
    required String time,
    required String date,
  }) {
    final key = _key(isA4, destination, time, date);
    _pendingKey = key;

    // Caché hit
    if (_cachedKey == key && _cachedPdfBytes != null) {
      return Future.value(_cachedPdfBytes!);
    }

    // Hay una operación en curso — se une a ella
    if (_inflightFuture != null) {
      return _inflightFuture!;
    }

    // Nada en curso: cancela el debounce y renderiza ahora
    _debounceTimer?.cancel();
    return _startWork(key, isA4);
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    statusNotifier.dispose();
  }

  // ── Internos ────────────────────────────────────────────────────────────────

  static String _key(bool isA4, String dest, String time, String date) =>
      '$isA4|$dest|$time|$date';

  void _setStatus(PdfCacheStatus s) {
    if (!_disposed) statusNotifier.value = s;
  }

  Future<Uint8List> _startWork(String key, bool isA4) {
    final future = _doWork(key, isA4);
    _inflightFuture = future;
    return future;
  }

  Future<Uint8List> _doWork(String key, bool isA4) async {
    try {
      _setStatus(PdfCacheStatus.preparing);

      // Captura bitmap en main thread (obligatorio por RenderRepaintBoundary)
      final pngBytes = await _captureCallback?.call();
      if (pngBytes == null) throw Exception('No se pudo capturar la planilla');

      // Serializa el PDF en un Isolate (Dart puro, no bloquea UI)
      final pdfBytes = await compute(_buildPdfInIsolate, (pngBytes, isA4));

      // Solo almacena si la config no cambió mientras procesaba
      if (key == _pendingKey) {
        _cachedKey = key;
        _cachedPdfBytes = pdfBytes;
        _setStatus(PdfCacheStatus.ready);
      }

      return pdfBytes;
    } catch (_) {
      _setStatus(PdfCacheStatus.error);
      rethrow;
    } finally {
      _inflightFuture = null;
    }
  }
}
