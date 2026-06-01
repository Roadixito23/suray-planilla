import 'package:flutter/material.dart';
import '../config/planilla_config.dart';

class PlanillaPainter extends CustomPainter {
  final String destination;
  final String time;
  final String date;

  const PlanillaPainter({
    required this.destination,
    required this.time,
    required this.date,
  });
  // ── Numeración del bus (5 cols × 9 rows = 45 asientos) ─────────────────────
  //
  //  Col 0 (ventana izq.)  → impares  1, 3, 5 … 17   (row 0–8)
  //  Col 1 (pasillo izq.)  → pares    2, 4, 6 … 18   (row 0–8)
  //  Col 2 (centro)        → 45 … 37  de arriba a abajo (bottom=37, top=45)
  //  Col 3 (pasillo der.)  → pares   20, 22  … 36   (row 0–8)
  //  Col 4 (ventana der.)  → impares 19, 21  … 35   (row 0–8)
  //
  static int seatNumber(int row, int col) => switch (col) {
    0 => 4 * row + 1, // 1, 5, 9 … 33
    1 => 4 * row + 2, // 2, 6, 10 … 34
    2 => 45 - row,    // 45, 44 … 37
    3 => 4 * row + 4, // 4, 8, 12 … 36
    4 => 4 * row + 3, // 3, 7, 11 … 35
    _ => 0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double gapH = size.width * PlanillaConfig.gapHFraction;
    final double gapV = size.height * PlanillaConfig.gapVFraction;

    final cellW =
        (size.width - gapH * (PlanillaConfig.cols - 1)) / PlanillaConfig.cols;
    final cellH =
        (size.height - gapV * (PlanillaConfig.rows - 1)) / PlanillaConfig.rows;

    for (int row = 0; row < PlanillaConfig.rows; row++) {
      for (int col = 0; col < PlanillaConfig.cols; col++) {
        final left = col * (cellW + gapH);
        final top = row * (cellH + gapV);
        _drawTicket(
          canvas,
          Rect.fromLTWH(left, top, cellW, cellH),
          seatNumber(row, col),
        );
      }
    }
  }

  void _drawTicket(Canvas canvas, Rect r, int seat) {
    final w = r.width;
    final h = r.height;
    final c = PlanillaConfig.inkColor;

    final thin = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * PlanillaConfig.strokeThinFraction;

    final thick = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * PlanillaConfig.strokeThickFraction;

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

    // Etiqueta "Asiento" + número — juntos, centrados verticalmente en la caja
    _textRich(
      canvas,
      [
        TextSpan(
          text: '${PlanillaConfig.asientoLabel}\n',
          style: TextStyle(
            color: PlanillaConfig.inkColor,
            fontSize: boxH * 0.24,
            fontWeight: FontWeight.normal,
            height: PlanillaConfig.lineHeight,
          ),
        ),
        TextSpan(
          text: seat.toString().padLeft(2, '0'),
          style: TextStyle(
            color: PlanillaConfig.inkColor,
            fontSize: boxH * 0.52,
            fontWeight: FontWeight.bold,
            height: PlanillaConfig.lineHeight,
          ),
        ),
      ],
      Offset(boxL, boxT),
      boxW,
      boxH,
      fontSize: boxH * 0.52,
      align: TextAlign.center,
      maxLines: 2,
    );

    // ── Fila 1 derecha: destino ──────────────────────────────────────
    final dxStart = vx + w * PlanillaConfig.destinoPaddingLeft;
    final dxW = r.right - dxStart - w * PlanillaConfig.destinoPaddingRight;
    final double destY = r.top + h * PlanillaConfig.destinoTopOffset;
    _textRich(
      canvas,
      [
        TextSpan(
          text: 'Destino:\n',
          style: TextStyle(
            color: PlanillaConfig.inkColor,
            fontSize: h * PlanillaConfig.fontSizeDestino,
            fontWeight: FontWeight.normal,
            height: PlanillaConfig.lineHeight,
          ),
        ),
        TextSpan(
          text: destination,
          style: TextStyle(
            color: PlanillaConfig.inkColor,
            fontSize: h * PlanillaConfig.fontSizeDestino,
            fontWeight: FontWeight.bold,
            height: PlanillaConfig.lineHeight,
          ),
        ),
        const TextSpan(
          text: '\nIntermedios',
          style: TextStyle(
            color: PlanillaConfig.inkColor,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
      Offset(dxStart, destY),
      dxW,
      row1H - 1,
      align: TextAlign.center,
      maxLines: 3,
      alignTop: true,
      fontSize: h * PlanillaConfig.fontSizeDestino,
    );

    // ── Fila 2: presentación ─────────────────────────────────────────
    _text(
      canvas,
      PlanillaConfig.presentacionText,
      Offset(r.left, lineY2 + 1),
      w,
      lineY3 - lineY2 - 2,
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
      Offset(r.left + hPad, lineY3 + 1),
      w / 2,
      lineY4 - lineY3 - 1,
      fontSize: h * PlanillaConfig.fontSizeHora,
      weight: PlanillaConfig.weightHora,
      align: TextAlign.left,
      alignTop: true,
    );
    // Valor de hora — pegado al margen inferior de fila 3
    _text(
      canvas,
      time,
      Offset(r.left + hPad, y3),
      w / 2,
      row3H - h * PlanillaConfig.textRowVShrink,
      fontSize: h * PlanillaConfig.fontSizeHora * 1.8,
      weight: FontWeight.bold,
      align: TextAlign.left,
      alignBottom: true,
    );
    _text(
      canvas,
      PlanillaConfig.anioText,
      Offset(r.left, lineY3 + 1),
      w - hPad,
      lineY4 - lineY3 - 1,
      fontSize: h * PlanillaConfig.fontSizeHora,
      weight: PlanillaConfig.weightHora,
      align: TextAlign.right,
      alignTop: true,
    );
    // Valor de fecha — pegado al margen inferior de fila 3
    _text(
      canvas,
      date,
      Offset(r.left, y3),
      w - hPad,
      row3H - h * PlanillaConfig.textRowVShrink,
      fontSize: h * PlanillaConfig.fontSizeHora * 1.8,
      weight: FontWeight.bold,
      align: TextAlign.right,
      alignBottom: true,
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

  void _textRich(
    Canvas canvas,
    List<InlineSpan> spans,
    Offset origin,
    double width,
    double height, {
    required double fontSize,
    TextAlign align = TextAlign.left,
    int maxLines = 3,
    bool alignBottom = false,
    bool alignTop = false,
  }) {
    final tp =
        TextPainter(
          text: TextSpan(
            children: spans,
            style: TextStyle(
              fontSize: fontSize,
              height: PlanillaConfig.lineHeight,
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
  bool shouldRepaint(covariant PlanillaPainter oldDelegate) =>
      oldDelegate.destination != destination ||
      oldDelegate.time != time ||
      oldDelegate.date != date;
}
