import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
