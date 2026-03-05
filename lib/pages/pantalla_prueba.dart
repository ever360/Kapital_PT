import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PantallaPrueba extends StatelessWidget {
  const PantallaPrueba({super.key});

  @override
  Widget build(BuildContext context) {
    // Detecta si el sistema está en modo claro u oscuro
    final brightness = MediaQuery.of(context).platformBrightness;

    // Aplica el estilo dinámico cada vez que se construye la pantalla
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: brightness == Brightness.dark
            ? const Color(0xFF121212)
            : Colors.white,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Pantalla de Prueba")),
      body: const Center(
        child: Text(
          "Cambia el modo claro/oscuro en tu móvil y observa la barra de estado",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
