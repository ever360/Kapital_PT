import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

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

    // Aplicar estilo de barra de estado inmediatamente según el tema actual
    Future.microtask(() {
      if (mounted) {
        final isDark = Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).isDarkMode;
        SystemChrome.setSystemUIOverlayStyle(
          ThemeProvider.getSystemUIOverlayStyle(isDark),
        );
      }
    });

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
                        primaryColor.withValues(alpha: 0.25),
                        const Color(0xFF0D0D0D),
                      ]
                    : [primaryColor.withValues(alpha: 0.8), Colors.white],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -40,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  right: -60,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark ? Colors.blueAccent : AppColors.doradoKapital)
                              .withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 34,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.20),
                              blurRadius: 48,
                              spreadRadius: -16,
                              offset: const Offset(0, 26),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : primaryColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(
                                            alpha: 0.55,
                                          ),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'INICIALIZANDO ENTORNO',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            FadeTransition(
                              opacity: _fadeLogo,
                              child: Hero(
                                tag: 'logo',
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        primaryColor.withValues(alpha: 0.22),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/logoKapital.png',
                                    width: 136,
                                    height: 136,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FadeTransition(
                              opacity: _fadeLogo,
                              child: Column(
                                children: [
                                  ShimmerText(
                                    text: 'Kapital',
                                    style: TextStyle(
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Finanzas operativas con presencia premium, control centralizado y velocidad en tiempo real.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      letterSpacing: 0.6,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeLogo,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? primaryColor : AppColors.doradoKapital,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Cargando núcleo visual',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
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
