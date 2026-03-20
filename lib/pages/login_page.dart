import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kapital_app/pages/register_page.dart';
import 'package:kapital_app/pages/super_admin_home.dart';
import 'package:kapital_app/pages/master_page.dart';
import 'package:kapital_app/pages/socio_home.dart';
import 'package:kapital_app/pages/cobrador_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  bool _canCheckBiometrics = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (kIsWeb) return;
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final canCheck = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final availableBiometrics = await auth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _canCheckBiometrics =
              (canCheck || availableBiometrics.isNotEmpty) && isDeviceSupported;
        });
      }
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  void _setupAuthListener() {
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        _checkProfileExistsAndRedirect(session.user, isManual: false);
      }
    });
    Future.delayed(Duration.zero, () {
      final session = supabase.auth.currentSession;
      if (session != null) {
        _checkProfileExistsAndRedirect(session.user, isManual: false);
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkProfileExistsAndRedirect(
    User user, {
    bool isManual = false,
  }) async {
    if (mounted && isManual) setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;

      if (profile == null) {
        final provider = user.appMetadata['provider'] ?? '';
        if (provider == 'google') {
          final String? googleEmail = user.email;
          final String? googleName =
              user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String?;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterPage(
                emailFromGoogle: googleEmail,
                nameFromGoogle: googleName,
                googleUser: user,
              ),
            ),
          );
        } else {
          final messenger = ScaffoldMessenger.of(context);
          await supabase.auth.signOut();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Error al registrar perfil. Intenta de nuevo."),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isLoading = false);
        }
      } else {
        final bool isApproved = profile['isApproved'] ?? false;
        final bool isActive = profile['isActive'] ?? false;
        final String rol = profile['rol'] ?? 'cobrador';

        if (isApproved && isActive) {
          final String nombre = profile['nombre'] ?? rol;
          final String? empresaId = profile['empresa_id'];

          if (rol != 'master' && empresaId != null) {
            try {
              final empresa = await supabase
                  .from('empresas')
                  .select('is_active, nombre')
                  .eq('id', empresaId)
                  .single();
              final bool empresaActiva = empresa['is_active'] ?? false;
              if (!empresaActiva) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🔒 ${empresa['nombre'] ?? 'Tu empresa'} está suspendida. '
                      'Contacta al administrador o al soporte.',
                    ),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 5),
                  ),
                );
                await supabase.auth.signOut();
                if (mounted) setState(() => _isLoading = false);
                return;
              }
            } catch (e) {
              debugPrint('Error verificando empresa: $e');
            }
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Bienvenido, $nombre",
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );

          Widget homePage;
          if (rol == 'master') {
            homePage = const MasterHomePage();
          } else if (rol == 'admin' ||
              rol == 'super_admin' ||
              rol == 'admin_pendiente') {
            homePage = const SuperAdminHomePage();
          } else if (rol == 'socio') {
            homePage = const SocioHomePage();
          } else {
            homePage = const CobradorHomePage();
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => homePage),
          );
        } else {
          String mensaje;
          if (!isApproved && rol == 'admin_pendiente') {
            mensaje =
                "⏳ Tu cuenta aún no ha sido aprobada. Si eres empresa, el Master revisará tu solicitud pronto.";
          } else if (!isApproved) {
            mensaje =
                "⏳ Tu acceso está pendiente de aprobación por tu administrador.";
          } else {
            mensaje =
                "🚫 Tu cuenta está inactiva. Contacta al administrador de tu empresa.";
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
          );
          await supabase.auth.signOut();
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> loginWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final email = emailController.text.trim();
        final password = passwordController.text.trim();
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await storage.write(key: 'user_email', value: email);
        await storage.write(key: 'user_password', value: password);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email o Contraseña inválidos"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ingresa un correo válido primero"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://reset-callback',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Correo de recuperación enviado. Revisa tu bandeja."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> authenticateWithBiometrics() async {
    try {
      final String? savedEmail = await storage.read(key: 'user_email');
      final String? savedPassword = await storage.read(key: 'user_password');
      if (savedEmail == null || savedPassword == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Inicia sesión manualmente una vez para activar la huella.",
            ),
          ),
        );
        return;
      }
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Verifica tu identidad para acceder',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Kapital',
            signInHint: 'Toca el sensor de huella',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(cancelButton: 'Cancelar'),
        ],
      );
      if (didAuthenticate) {
        setState(() => _isLoading = true);
        await supabase.auth.signInWithPassword(
          email: savedEmail,
          password: savedPassword,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error biométrico: $e")));
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? 'https://ever360.github.io/Kapital_PT/'
            : 'io.supabase.flutter://login-callback',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error con Google: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : primary.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String label,
    String iconPath,
    VoidCallback onPressed,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Image.asset(iconPath, height: 24),
        label: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.025)
              : Colors.white.withValues(alpha: 0.72),
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : primary.withValues(alpha: 0.14),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBackdropOrb({
    required double size,
    required Alignment alignment,
    required Color color,
  }) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.26),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBadge(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'PLATAFORMA OPERATIVA KAPITAL',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF050816),
                            Color(0xFF0D0D0D),
                            Color(0xFF101A17),
                          ]
                        : const [
                            Color(0xFFF9F6ED),
                            Color(0xFFF3F7F4),
                            Color(0xFFFFFFFF),
                          ],
                  ),
                ),
              ),
            ),
            _buildBackdropOrb(
              size: size.width * 0.9,
              alignment: const Alignment(-1.15, -0.95),
              color: isDark ? primary : AppColors.doradoKapital,
            ),
            _buildBackdropOrb(
              size: size.width * 0.72,
              alignment: const Alignment(1.1, -0.2),
              color: Colors.blueAccent,
            ),
            _buildBackdropOrb(
              size: size.width * 0.82,
              alignment: const Alignment(-0.9, 1.0),
              color: isDark ? Colors.tealAccent : Colors.orangeAccent,
            ),
            // Contenido principal
            SingleChildScrollView(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 18),
                            _buildTopBadge(isDark, primary),
                            const SizedBox(height: 24),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 24,
                                  sigmaY: 24,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.68),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : primary.withValues(alpha: 0.10),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(
                                          alpha: isDark ? 0.18 : 0.10,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: -10,
                                        offset: const Offset(0, 24),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      28,
                                      24,
                                      24,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isDark
                                                  ? [
                                                      Colors.white.withValues(
                                                        alpha: 0.05,
                                                      ),
                                                      primary.withValues(
                                                        alpha: 0.06,
                                                      ),
                                                    ]
                                                  : [
                                                      Colors.white,
                                                      primary.withValues(
                                                        alpha: 0.10,
                                                      ),
                                                    ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: primary.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Hero(
                                                tag: 'logo',
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: RadialGradient(
                                                      colors: [
                                                        primary.withValues(
                                                          alpha: 0.22,
                                                        ),
                                                        primary.withValues(
                                                          alpha: 0.0,
                                                        ),
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: primary
                                                            .withValues(
                                                              alpha: isDark
                                                                  ? 0.26
                                                                  : 0.18,
                                                            ),
                                                        blurRadius: 36,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Image.asset(
                                                    'assets/logoKapital.png',
                                                    height: size.height * 0.12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Acceso Seguro',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.7,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Control financiero, operación en tiempo real y administración inteligente en una sola superficie.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white60
                                                      : Colors.black54,
                                                  fontSize: 13,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        _buildTextField(
                                          context: context,
                                          controller: emailController,
                                          hint: 'Correo electrónico',
                                          obscure: false,
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Por favor ingresa tu correo';
                                            }
                                            if (!value.contains('@')) {
                                              return 'Correo inválido';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _buildTextField(
                                          context: context,
                                          controller: passwordController,
                                          hint: 'Contraseña',
                                          obscure: _obscurePassword,
                                          icon: Icons.lock_outline,
                                          keyboardType: TextInputType.text,
                                          textInputAction: TextInputAction.done,
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_canCheckBiometrics)
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.fingerprint,
                                                    color: primary,
                                                  ),
                                                  onPressed:
                                                      authenticateWithBiometrics,
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                            .visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54,
                                                ),
                                                onPressed: () => setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                ),
                                              ),
                                            ],
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Ingresa tu contraseña';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 22),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primary,
                                              foregroundColor: Colors.black,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 18,
                                                  ),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                              ),
                                            ),
                                            onPressed: _isLoading
                                                ? null
                                                : loginWithEmail,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.black,
                                                          strokeWidth: 2.2,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Entrar al sistema',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: 0.6,
                                                        ),
                                                      ),
                                                      SizedBox(width: 10),
                                                      Icon(
                                                        Icons
                                                            .north_east_rounded,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : forgotPassword,
                                            child: Text(
                                              '¿Olvidaste tu contraseña?',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.12,
                                                      )
                                                    : primary.withValues(
                                                        alpha: 0.14,
                                                      ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                'Acceso alternativo',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.7,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.12,
                                                      )
                                                    : primary.withValues(
                                                        alpha: 0.14,
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _buildSocialButton(
                                          context,
                                          'Continuar con Google',
                                          'assets/icons/google_icon.png',
                                          _isLoading ? () {} : signInWithGoogle,
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '¿No tienes cuenta? ',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const RegisterPage(),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  'Regístrate',
                                                  style: TextStyle(
                                                    color: primary,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'v1.6.0 - Push Notifications & Kapital Branding',
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black38,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Botón de tema flotante arriba a la derecha (sin AppBar)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => themeProvider.toggleTheme(),
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark
                          ? AppColors.verdeSupabase
                          : AppColors.doradoKapital,
                    ),
                    tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
