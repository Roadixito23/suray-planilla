import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIGURACIÓN DE DISEÑO DE LA PLANILLA
//  Modifica este archivo para ajustar visualmente cada boleto sin tocar el
//  painter. Todos los valores de posición/tamaño marcados con "×h" o "×w"
//  son fracciones de la altura o ancho de la celda (0.0 – 1.0).
// ══════════════════════════════════════════════════════════════════════════════

class PlanillaConfig {
  PlanillaConfig._();

  // ── Grilla ──────────────────────────────────────────────────────────────────
  static const int cols = 5;
  static const int rows = 9;

  // ── Proporciones de filas (deben sumar 1.0) ─────────────────────────────────
  /// Fila 1: caja de asiento + texto de destino
  static const double row1Fraction = 0.30;

  /// Fila 2: texto "Presentación..."
  static const double row2Fraction = 0.18;

  /// Fila 3: "Hora" / año
  static const double row3Fraction = 0.35;

  /// Fila 4: "Revise su Boleto" (el resto hasta 1.0)
  // row4 = 1.0 - row1 - row2 - row3 → calculado automáticamente

  // ── Posición de líneas divisorias (independiente del texto) ───────────────────
  /// Posición absoluta de la línea 1 (fracción desde top)
  static const double line1Fraction = 0.38;

  /// Posición absoluta de la línea 2 (fracción desde top)
  static const double line2Fraction = 0.56;

  /// Posición absoluta de la línea 3/gruesa (fracción desde top)
  static const double line3Fraction = 0.83;

  // ── Separador vertical en fila 1 ────────────────────────────────────────────
  /// Fracción del ancho de celda donde cae la línea que separa
  /// la caja de asiento del texto de destino.
  static const double vSeparatorFraction = 0.30;

  // ── Caja de asiento (fila 1 izquierda) ──────────────────────────────────────
  /// Padding izquierdo/superior de la caja respecto al borde de la celda (×w)
  static const double boxPaddingX = 0.035;

  /// Distancia desde el top de la celda hasta el top de la caja (×h)
  static const double boxPaddingTop = 0.045;

  /// Ancho de la caja como fracción del ancho de celda
  static const double boxWidth = 0.33;

  /// Alto de la caja como fracción de row1H
  static const double boxHeightFraction = 0.54;

  /// Espacio entre la caja y la etiqueta "Asiento" (×h)
  static const double boxLabelGap = 0.008;

  // ── Textos ───────────────────────────────────────────────────────────────────

  /// Líneas del destino (fila 1 derecha). Máximo 3 líneas.
  static const List<String> destinationLines = [
    'Aysén',
    'Coyhaique',
    'Intermedios',
  ];

  static const String asientoLabel = 'Asiento';
  static const String presentacionText =
      'Presentación 10 minutos\nantes en el Terminal';
  static const String horaLabel = 'Hora';
  static const String anioText = '2026';
  static const String revisarText = 'Revise su Boleto';

  // ── Tamaños de fuente (×h, altura de celda) ──────────────────────────────────
  static const double fontSizeAsiento = 0.085;
  static const double fontSizeDestino = 0.095;
  static const double fontSizePresentacion = 0.075;
  static const double fontSizeHora = 0.082;
  static const double fontSizeRevise = 0.12;

  // ── Pesos de fuente ──────────────────────────────────────────────────────────
  static const FontWeight weightAsiento = FontWeight.bold;
  static const FontWeight weightDestino = FontWeight.bold;
  static const FontWeight weightPresentacion = FontWeight.normal;
  static const FontWeight weightHora = FontWeight.bold;
  static const FontWeight weightRevise = FontWeight.bold;

  // ── Interlineado ─────────────────────────────────────────────────────────────
  static const double lineHeight = 1.15;

  // ── Grosores de línea ────────────────────────────────────────────────────────
  static const double strokeThin = 0.5;
  static const double strokeThick = 1.4;

  // ── Padding interior de texto (×w o ×h) ──────────────────────────────────────
  /// Padding horizontal para "Hora" y "2026"
  static const double rowHoraPaddingX = 0.02;

  /// Padding entre separador vertical y texto de destino (×w)
  static const double destinoPaddingLeft = 0.02;

  /// Padding derecho del texto de destino (×w)
  static const double destinoPaddingRight = 0.0001;

  /// Offset vertical de la fila de destino desde el top (×h)
  static const double destinoTopOffset = 0.01;

  // ── Colores ───────────────────────────────────────────────────────────────────
  static const Color inkColor = Colors.black;
  static const Color paperColor = Colors.white;
}
