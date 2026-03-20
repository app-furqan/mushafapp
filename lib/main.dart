import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/mushaf_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  runApp(const MushafApp());
}

class MushafApp extends StatelessWidget {
  const MushafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مصحف',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MushafScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2D5A27),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }
}
