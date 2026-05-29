import 'package:flutter/material.dart';
import '../config/planilla_config.dart';

class PlanillaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double gapH = 10; // separación horizontal entre boletos
    const double gapV = 3; // separación vertical entre boletos

    final cellW =
        (size.width - gapH * (PlanillaConfig.cols - 1)) / PlanillaConfig.cols;
    final cellH =
        (size.height - gapV * (PlanillaConfig.rows - 1)) / PlanillaConfig.rows;

    for (int row = 0; row < PlanillaConfig.rows; row++) {
      for (int col = 0; col < PlanillaConfig.cols; col++) {
        final left = col * (cellW + gapH);
        final top = row * (cellH + gapV);
        _drawTicket(canvas, Rect.fromLTWH(left, top, cellW, cellH));
      }
    }
  }

  void _drawTicket(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final c = PlanillaConfig.inkColor;

    final thin = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = PlanillaConfig.strokeThin;

    final thick = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = PlanillaConfig.strokeThick;

    // Alturas de fila
    final row1H = h * PlanillaConfig.row1Fraction;
    final row2H = h * PlanillaConfig.row2Fraction;
    final row3H = h * PlanillaConfig.row3Fraction;
    final row4H =
        h *
        (1 -
            PlanillaConfig.row1Fraction -
            PlanillaConfig.row2Fraction -
            PlanillaConfig.row3Fraction);

    final y2 = r.top + row1H;
    final y3 = y2 + row2H;
    final y4 = y3 + row3H;

    // Borde exterior
    canvas.drawRect(r, thin);

    // Separadores horizontales (posición independiente del texto)
    final lineY2 = r.top + h * PlanillaConfig.line1Fraction;
    final lineY3 = r.top + h * PlanillaConfig.line2Fraction;
    final lineY4 = r.top + h * PlanillaConfig.line3Fraction;
    _line(canvas, r.left, lineY2, r.right, lineY2, thin);
    _line(canvas, r.left, lineY3, r.right, lineY3, thin);
    _line(canvas, r.left, lineY4, r.right, lineY4, thick);

    // Separador vertical (fila 1)
    final vx = r.left + w * PlanillaConfig.vSeparatorFraction;
    // _line(canvas, vx, r.top, vx, y2, thin);

    // ── Fila 1 izquierda: caja asiento ──────────────────────────────
    final boxL = r.left + w * PlanillaConfig.boxPaddingX;
    final boxT = r.top + h * PlanillaConfig.boxPaddingTop;
    final boxW = w * PlanillaConfig.boxWidth;
    final boxH = lineY2 - boxT;
    canvas.drawRect(Rect.fromLTWH(boxL, boxT, boxW, boxH), thin);

    // Etiqueta "Asiento" dentro de la caja, margen inferior
    _text(
      canvas,
      PlanillaConfig.asientoLabel,
      Offset(boxL, boxT),
      boxW,
      boxH - 1,
      fontSize: h * PlanillaConfig.fontSizeAsiento,
      weight: PlanillaConfig.weightAsiento,
      align: TextAlign.center,
      alignBottom: true,
    );

    // ── Fila 1 derecha: destino ──────────────────────────────────────
    final dxStart = vx + w * PlanillaConfig.destinoPaddingLeft;
    final dxW = r.right - dxStart - w * PlanillaConfig.destinoPaddingRight;
    _text(
      canvas,
      PlanillaConfig.destinationLines.join('\n'),
      Offset(dxStart, r.top + 5),
      dxW,
      row1H - 1,
      fontSize: h * PlanillaConfig.fontSizeDestino,
      weight: PlanillaConfig.weightDestino,
      align: TextAlign.center,
      maxLines: 3,
      alignTop: true,
    );

    // ── Fila 2: presentación ─────────────────────────────────────────
    _text(
      canvas,
      PlanillaConfig.presentacionText,
      Offset(r.left, y2 + 7),
      w,
      row2H,
      fontSize: h * PlanillaConfig.fontSizePresentacion,
      weight: PlanillaConfig.weightPresentacion,
      align: TextAlign.center,
      maxLines: 2,
    );

    // ── Fila 3: hora / año ───────────────────────────────────────────
    final hPad = w * PlanillaConfig.rowHoraPaddingX;
    _text(
      canvas,
      PlanillaConfig.horaLabel,
      Offset(r.left + hPad, y3 + 7),
      w / 2,
      row3H,
      fontSize: h * PlanillaConfig.fontSizeHora,
      weight: PlanillaConfig.weightHora,
      align: TextAlign.left,
      alignTop: true,
    );
    _text(
      canvas,
      PlanillaConfig.anioText,
      Offset(r.left, y3 + 7),
      w - hPad,
      row3H,
      fontSize: h * PlanillaConfig.fontSizeHora,
      weight: PlanillaConfig.weightHora,
      align: TextAlign.right,
      alignTop: true,
    );

    // ── Fila 4: revise su boleto ─────────────────────────────────────
    _text(
      canvas,
      PlanillaConfig.revisarText,
      Offset(r.left, y4),
      w,
      row4H,
      fontSize: h * PlanillaConfig.fontSizeRevise,
      weight: PlanillaConfig.weightRevise,
      align: TextAlign.center,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _line(Canvas c, double x1, double y1, double x2, double y2, Paint p) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  void _text(
    Canvas canvas,
    String text,
    Offset origin,
    double width,
    double height, {
    required double fontSize,
    FontWeight weight = FontWeight.normal,
    TextAlign align = TextAlign.left,
    int maxLines = 1,
    bool alignBottom = false,
    bool alignTop = false,
  }) {
    final tp =
        TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: PlanillaConfig.inkColor,
              fontSize: fontSize,
              fontWeight: weight,
              height: PlanillaConfig.lineHeight,
              letterSpacing: 0,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: align,
          maxLines: maxLines,
        )..layout(
          minWidth: align == TextAlign.center || align == TextAlign.right
              ? width
              : 0,
          maxWidth: width,
        );

    final dy = alignBottom
        ? origin.dy + height - tp.height
        : alignTop
        ? origin.dy
        : (origin.dy + (height - tp.height) / 2).clamp(
            origin.dy,
            origin.dy + height,
          );
    tp.paint(canvas, Offset(origin.dx, dy));
  }

  @override
  bool shouldRepaint(covariant PlanillaPainter oldDelegate) => false;
}
