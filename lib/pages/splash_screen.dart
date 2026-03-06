import 'package:flutter/material.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _fadeLogo;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _radiusAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    // Después de 3 segundos, verifica sesión y navega
    Timer(const Duration(seconds: 3), () async {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (!mounted) return;

      if (session != null) {
        // Ya hay sesión, el listener en login_page o la lógica aquí puede redirigir
        // Para simplificar, mandamos a login y la lógica de login_page se encargará
        // del redireccionamiento basado en el perfil que ya existe.
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _radiusAnimation,
        builder: (context, child) {
            final isDark = themeProvider.isDarkMode;
            final primaryColor = AppColors.primary(isDark);
            
            return Container(
              width: screenWidth,
              height: screenHeight,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: _radiusAnimation.value,
                  colors: isDark 
                      ? [primaryColor.withValues(alpha: 0.3), const Color(0xFF121212)] 
                      : [primaryColor, Colors.white],
                  stops: const [0.0, 1.0],
                ),
              ),
            child: _radiusAnimation.value >= 1.5
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeLogo,
                        child: Image.asset(
                          'assets/logoKapital.png',
                          width: 150,
                          height: 150,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const ShimmerText(
                        text: "Kapital",
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Más que real, una experiencia única",
                        style: TextStyle(
                          fontSize: 18, 
                          color: isDark ? Colors.white70 : Colors.black87
                        ),
                      ),
                      const SizedBox(height: 30),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(isDark ? primaryColor : Colors.white),
                        strokeWidth: 3,
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}

// Texto con efecto shimmer dorado
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ShimmerText({super.key, required this.text, required this.style});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final primaryColor = AppColors.primary(themeProvider.isDarkMode);
        
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [Colors.white, primaryColor, Colors.white],
              stops: const [0.2, 0.5, 0.8],
              begin: Alignment(-1.0 + _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}
