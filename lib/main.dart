import 'package:flutter/material.dart';

void main() {
  runApp(const KapitalApp());
}

class KapitalApp extends StatefulWidget {
  const KapitalApp({super.key});

  @override
  State<KapitalApp> createState() => _KapitalAppState();
}

class _KapitalAppState extends State<KapitalApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Cambia automáticamente según el estado
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // 🌞 MODO CLARO
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),

      // 🌙 MODO OSCURO
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),

      home: Scaffold(
        appBar: AppBar(
          title: const Text('Kapital BR'),
          actions: [
            IconButton(
              icon: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            _isDarkMode ? "Modo Oscuro Activado 🌙" : "Modo Claro Activado 🌞",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
