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
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
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
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 80,
              color: primary,
            ),
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
