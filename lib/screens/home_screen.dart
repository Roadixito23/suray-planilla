import 'package:flutter/material.dart';
import 'planilla_screen.dart';

enum PaperSize { a4, carta }

extension PaperSizeInfo on PaperSize {
  String get label => this == PaperSize.a4 ? 'A4' : 'Carta';
  String get dimensions =>
      this == PaperSize.a4 ? '210 × 297 mm' : '215.9 × 279.4 mm';
  double get widthMm => this == PaperSize.a4 ? 210 : 215.9;
  double get heightMm => this == PaperSize.a4 ? 297 : 279.4;
  double get aspectRatio => widthMm / heightMm;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Suray Planilla',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Selecciona el tamaño de hoja',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.black54, letterSpacing: 0.4),
              ),
              const SizedBox(height: 48),
              _PaperCard(size: PaperSize.a4),
              const SizedBox(height: 24),
              _PaperCard(size: PaperSize.carta),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  final PaperSize size;

  const _PaperCard({required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanillaScreen(paperSize: size),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PaperIcon(ratio: size.aspectRatio),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    size.label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    size.dimensions,
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperIcon extends StatelessWidget {
  final double ratio;

  const _PaperIcon({required this.ratio});

  @override
  Widget build(BuildContext context) {
    const double h = 48;
    final double w = h * ratio;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
    );
  }
}
