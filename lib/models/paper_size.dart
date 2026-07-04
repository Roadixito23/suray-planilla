import 'package:pdf/pdf.dart';

enum PaperSize { a4, carta }

extension PaperSizeInfo on PaperSize {
  String get label => this == PaperSize.a4 ? 'A4' : 'Carta';
  String get dimensions =>
      this == PaperSize.a4 ? '210 × 297 mm' : '215.9 × 279.4 mm';
  double get widthMm => this == PaperSize.a4 ? 210 : 215.9;
  double get heightMm => this == PaperSize.a4 ? 297 : 279.4;
  double get aspectRatio => widthMm / heightMm;
  PdfPageFormat get pdfFormat =>
      this == PaperSize.a4 ? PdfPageFormat.a4 : PdfPageFormat.letter;
}
