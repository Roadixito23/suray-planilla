import 'package:flutter/material.dart';
import '../models/paper_size.dart';
import '../painters/planilla_painter.dart';

class PlanillaScreen extends StatefulWidget {
  final PaperSize paperSize;

  const PlanillaScreen({super.key, required this.paperSize});

  @override
  State<PlanillaScreen> createState() => _PlanillaScreenState();
}

class _PlanillaScreenState extends State<PlanillaScreen> {
  String _destination = 'Coyhaique';

  void _toggleDestination() {
    setState(() {
      _destination = _destination == 'Coyhaique' ? 'Aysen' : 'Coyhaique';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDDDDD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Planilla ${widget.paperSize.label}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FilledButton.tonal(
              onPressed: _toggleDestination,
              child: Text(_destination),
            ),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.4,
        maxScale: 12.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AspectRatio(
              aspectRatio: widget.paperSize.aspectRatio,
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
                  painter: PlanillaPainter(
                    destination: _destination,
                    time: '00:00',
                    date: '29/05',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
