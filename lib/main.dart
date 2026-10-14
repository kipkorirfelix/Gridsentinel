import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  runApp(const GridSentinelApp());
}

class GridSentinelApp extends StatelessWidget {
  const GridSentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GridSentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF15151E)),
        cardTheme: const CardThemeData(color: Color(0xFF1E1E2A)),
      ),
      home: const HomeShell(),
    );
  }
}