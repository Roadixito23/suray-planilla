import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SurayPlanillaApp());
}

class SurayPlanillaApp extends StatelessWidget {
  const SurayPlanillaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suray Planilla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B1F2E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
