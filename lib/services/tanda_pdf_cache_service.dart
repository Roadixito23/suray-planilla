import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/paper_size.dart';

// ── Función top-level para compute() — corre en un Isolate separado ──────────
// Recibe las páginas ya rasterizadas (PNG) en orden de impresión, junto con
// qué página lleva encabezado, y arma el PDF final (Dart puro, no bloquea UI).
Future<Uint8List> buildTandaPdfInIsolate(
  (
    List<Uint8List> pageBytes,
    List<bool> isEarliestFlags,
    PdfPageFormat pageFormat,
    String dayName,
    String dateStr,
    double headerHeightPt,
  )
  args,
) async {
  final (pageBytes, isEarliestFlags, pageFormat, dayName, dateStr, headerHeightPt) = args;
  final doc = pw.Document();

  for (var i = 0; i < pageBytes.length; i++) {
    final isEarliest = isEarliestFlags[i];
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.SizedBox(
              height: headerHeightPt,
              child: isEarliest
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            dayName,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: headerHeightPt * 0.42,
                            ),
                          ),
                          pw.Spacer(),
                          pw.Text(
                            dateStr,
                            style: pw.TextStyle(fontSize: headerHeightPt * 0.42),
                          ),
                        ],
                      ),
                    )
                  : pw.SizedBox.shrink(),
            ),
            pw.Image(
              pw.MemoryImage(pageBytes[i]),
              height: pageFormat.height - headerHeightPt,
              fit: pw.BoxFit.fill,
            ),
          ],
        ),
      ),
    );
  }

  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
/// Caché en memoria (por sesión) de las páginas de ticket ya rasterizadas
/// para la impresión de Tanda.
///
/// Cada entrada es el PNG de una hoja completa de 45 boletos para una
/// combinación exacta de (destino, fecha, hora, papel) — el raster no
/// depende del encabezado (que se agrega como widget PDF nativo por encima
/// de la imagen), así que la misma imagen sirve tenga o no encabezado.
///
/// Reimprimir un día ya generado en la misma sesión salta por completo el
/// costoso ciclo Canvas → Picture → Image → PNG.
// ─────────────────────────────────────────────────────────────────────────────
class TandaPdfCacheService {
  TandaPdfCacheService._();
  static final TandaPdfCacheService instance = TandaPdfCacheService._();

  static const int maxEntries = 150;

  /// LinkedHashMap actúa como LRU: la clave leída/escrita más recientemente
  /// queda al final; al superar [maxEntries] se descarta la más antigua.
  final LinkedHashMap<String, Uint8List> _raster = LinkedHashMap();

  static String key({
    required String destination,
    required DateTime date,
    required String time,
    required PaperSize paper,
  }) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$destination|$dateKey|$time|${paper.name}';
  }

  Uint8List? get(String key) {
    final bytes = _raster.remove(key);
    if (bytes == null) return null;
    _raster[key] = bytes; // reinserta al final → más recientemente usado
    return bytes;
  }

  void put(String key, Uint8List bytes) {
    _raster.remove(key);
    _raster[key] = bytes;
    if (_raster.length > maxEntries) {
      _raster.remove(_raster.keys.first);
    }
  }
}
