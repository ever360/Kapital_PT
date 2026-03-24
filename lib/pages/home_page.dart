import 'package:flutter/material.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/widgets/kapital_drawer.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key}); // aquí no puede ser const

  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050816)
          : const Color(0xFFF9F6ED),
      drawer: const KapitalDrawer(),
      appBar: AppBar(
        title: Text(
          "KAPITAL",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark
            ? const Color(0xFF050816)
            : const Color(0xFFF9F6ED),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch_rounded, size: 80, color: primary),
            const SizedBox(height: 24),
            Text(
              "¡Bienvenido a Kapital! 🚀",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Tu panel administrativo está listo.",
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
