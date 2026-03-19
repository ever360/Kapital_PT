import 'package:flutter/material.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

    // Splash full screen style - Edge-to-Edge consistente
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _radiusAnimation = Tween<double>(begin: 0.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
    );

    _fadeLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
    );

    _controller.forward();

    // Redirección con validación de sesión
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;

      // Restaurar modo normal antes de salir
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      final supabase = Supabase.instance.client;
      if (supabase.auth.currentSession != null) {
        // Redirigir según sesión si es necesario, por ahora a login que maneja el redireccionamiento interno
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
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    final primaryColor = AppColors.primary(isDark);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _radiusAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: _radiusAnimation.value,
                colors: isDark
                    ? [
                        primaryColor.withOpacity(0.25),
                        const Color(0xFF0D0D0D),
                      ]
                    : [primaryColor.withOpacity(0.8), Colors.white],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeLogo,
                        child: Hero(
                          tag: 'logo',
                          child: Image.asset(
                            'assets/logoKapital.png',
                            width: 160,
                            height: 160,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeTransition(
                        opacity: _fadeLogo,
                        child: Column(
                          children: [
                            ShimmerText(
                              text: "Kapital",
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Más que real, una experiencia única",
                              style: TextStyle(
                                fontSize: 16,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white60 : Colors.black45,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeLogo,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? primaryColor : AppColors.doradoKapital,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
        final tp = Provider.of<ThemeProvider>(context);
        final primaryColor = AppColors.primary(tp.isDarkMode);

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
