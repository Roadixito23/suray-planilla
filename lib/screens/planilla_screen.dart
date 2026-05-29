import 'package:flutter/material.dart';
import '../painters/planilla_painter.dart';
import 'home_screen.dart';

class PlanillaScreen extends StatelessWidget {
  final PaperSize paperSize;

  const PlanillaScreen({super.key, required this.paperSize});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDDDDD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Planilla ${paperSize.label}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.4,
        maxScale: 12.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AspectRatio(
              aspectRatio: paperSize.aspectRatio,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 20,
                      offset: Offset(6, 6),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: PlanillaPainter(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
