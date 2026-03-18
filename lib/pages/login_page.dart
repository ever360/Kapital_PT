import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kapital_app/pages/register_page.dart';
import 'package:kapital_app/pages/super_admin_home.dart';
import 'package:kapital_app/pages/master_page.dart';
import 'package:kapital_app/pages/socio_home.dart';
import 'package:kapital_app/pages/cobrador_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
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
          final String? googleName = user.userMetadata?['full_name'] as String?
              ?? user.userMetadata?['name'] as String?;
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
                  .select('is_active')
                  .eq('id', empresaId)
                  .single();
              final bool empresaActiva = empresa['is_active'] ?? false;
              if (!empresaActiva) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🔒 Tu empresa está suspendida. Contacta al administrador.',
                    ),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 4),
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
          String mensaje = !isApproved
              ? "Tu cuenta está pendiente de aprobación."
              : "Tu cuenta está inactiva.";
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
        await supabase.auth.signInWithPassword(email: email, password: password);
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
            content: Text("Inicia sesión manualmente una vez para activar la huella."),
          ),
        );
        return;
      }
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Inicia sesión en Kapital con tu huella',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error biométrico: $e")));
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
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: themeProvider.isDarkMode ? Colors.white54 : Colors.black54,
        ),
        prefixIcon: Icon(
          icon,
          color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: themeProvider.isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Image.asset(iconPath, height: 24),
        label: Text(
          label,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: themeProvider.isDarkMode ? Colors.white30 : Colors.black26,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDark = themeProvider.isDarkMode;

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
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),

                            // Logo
                            Hero(
                              tag: 'logo',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: isDark ? 0.15 : 0.4,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/logoKapital.png',
                                  height: size.height * 0.14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                            Text(
                              "Iniciar Sesión",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Bienvenido de nuevo a Kapital",
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 35),

                            // Email
                            _buildTextField(
                              context: context,
                              controller: emailController,
                              hint: 'Correo electrónico',
                              obscure: false,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu correo';
                                }
                                if (!value.contains('@')) return 'Correo inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Contraseña
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
                                        color: AppColors.primary(isDark),
                                      ),
                                      onPressed: authenticateWithBiometrics,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),

                            // Botón Entrar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary(isDark),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isLoading ? null : loginWithEmail,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Entrar",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // Olvidé contraseña
                            TextButton(
                              onPressed: _isLoading ? null : forgotPassword,
                              child: Text(
                                "¿Olvidaste tu contraseña?",
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // Separador
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    "O continúa con",
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),

                            // Google
                            _buildSocialButton(
                              context,
                              'Google',
                              'assets/icons/google_icon.png',
                              _isLoading ? () {} : signInWithGoogle,
                            ),
                            const SizedBox(height: 30),

                            // Registro
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "¿No tienes cuenta? ",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Regístrate",
                                      style: TextStyle(
                                        color: AppColors.primary(isDark),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Versión
                            Text(
                              'v1.5.0 - Premium Redesign Update',
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black38,
                                fontSize: 11,
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
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? AppColors.verdeSupabase : AppColors.doradoKapital,
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
