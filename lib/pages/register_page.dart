import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  /// Si viene de Google, estos campos vienen pre-llenados
  final String? emailFromGoogle;
  final String? nameFromGoogle;
  final User? googleUser;

  const RegisterPage({
    super.key,
    this.emailFromGoogle,
    this.nameFromGoogle,
    this.googleUser,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? _imageUrl;
  bool _obscurePassword = true;
  bool _isLoading = false;

  bool get _isGoogleFlow => widget.googleUser != null;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Pre-llenar datos si vienen de Google
    if (widget.emailFromGoogle != null) {
      emailController.text = widget.emailFromGoogle!;
    }
    if (widget.nameFromGoogle != null) {
      nameController.text = widget.nameFromGoogle!;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _notifyMastersPendingApproval({
    required String userId,
    required String nombre,
    required String? email,
    required String? telefono,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'notify-masters-new-pending',
        body: {
          'user_id': userId,
          'nombre': nombre,
          'email': email,
          'telefono': telefono,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      debugPrint(
        'notify-masters-new-pending status=${response.status} data=${response.data}',
      );

      if (response.status != 200) {
        debugPrint(
          'notify-masters-new-pending devolvio status no exitoso: ${response.status}',
        );
      }
    } catch (e) {
      // No interrumpir el flujo de registro por fallos de notificación
      debugPrint('No se pudo notificar al master: $e');
    }
  }

  Future<void> signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String snackMsg;

        if (_isGoogleFlow) {
          // Verificar si hay invitación pendiente para este email de Google
          final googleEmail = (widget.googleUser!.email ?? '').toLowerCase();
          final googleInvite = await supabase
              .from('invitaciones')
              .select()
              .eq('email', googleEmail)
              .eq('used', false)
              .maybeSingle();

          if (googleInvite != null) {
            await supabase.from('profiles').upsert({
              'id': widget.googleUser!.id,
              'nombre': nameController.text.trim(),
              'telefono': phoneController.text.trim(),
              'foto': _imageUrl,
              'rol': googleInvite['rol'],
              'isApproved': true,
              'isActive': false,
              'empresa_id': googleInvite['empresa_id'],
            });
            await supabase
                .from('invitaciones')
                .update({'used': true, 'profile_id': widget.googleUser!.id})
                .eq('id', googleInvite['id']);
            snackMsg =
                "✅ Te has unido a tu equipo. Espera que el administrador te active.";
          } else {
            // Sin invitación: flujo estándar admin_pendiente
            await supabase.from('profiles').upsert({
              'id': widget.googleUser!.id,
              'nombre': nameController.text.trim(),
              'telefono': phoneController.text.trim(),
              'foto': _imageUrl,
              'rol': 'admin_pendiente',
              'isApproved': false,
              'isActive': false,
              'empresa_id': null,
            });
            await _notifyMastersPendingApproval(
              userId: widget.googleUser!.id,
              nombre: nameController.text.trim(),
              email: widget.googleUser!.email,
              telefono: phoneController.text.trim(),
            );
            snackMsg =
                "✅ Solicitud enviada. El Master revisará tu registro y te dará acceso pronto.";
          }
        } else {
          // Registro normal con email/password
          final authResponse = await supabase.auth.signUp(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

          if (!mounted) return;

          if (authResponse.user != null) {
            final emailLower = emailController.text.trim().toLowerCase();

            // Verificar si hay una invitación pendiente para este email
            final invite = await supabase
                .from('invitaciones')
                .select()
                .eq('email', emailLower)
                .eq('used', false)
                .maybeSingle();

            if (invite != null) {
              // Auto-vincular a la empresa que lo invitó
              await supabase.from('profiles').insert({
                'id': authResponse.user!.id,
                'nombre': nameController.text.trim(),
                'telefono': phoneController.text.trim(),
                'foto': _imageUrl,
                'rol': invite['rol'],
                'isApproved': true,
                'isActive': false, // Admin debe activarlo manualmente
                'empresa_id': invite['empresa_id'],
              });
              // Marcar invitación como usada
              await supabase
                  .from('invitaciones')
                  .update({'used': true, 'profile_id': authResponse.user!.id})
                  .eq('id', invite['id']);
              snackMsg =
                  "✅ Te has unido a tu equipo. Tu admin te dará acceso en breve.";
            } else {
              // Sin invitación: flujo estándar → espera al Master
              await supabase.from('profiles').insert({
                'id': authResponse.user!.id,
                'nombre': nameController.text.trim(),
                'telefono': phoneController.text.trim(),
                'foto': _imageUrl,
                'rol': 'admin_pendiente',
                'isApproved': false,
                'isActive': false,
                'empresa_id': null,
              });
              await _notifyMastersPendingApproval(
                userId: authResponse.user!.id,
                nombre: nameController.text.trim(),
                email: emailLower,
                telefono: phoneController.text.trim(),
              );
              snackMsg =
                  "✅ Solicitud enviada. El Master revisará tu registro y te dará acceso pronto.";
            }
          } else {
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Si fue Google, cerramos sesión para que espere aprobación
        if (_isGoogleFlow) {
          final nav = Navigator.of(context);
          await supabase.auth.signOut();
          if (!mounted) return;
          nav.pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error de Registro"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Entendido"),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
    bool readOnly = false,
    required String? Function(String?) validator,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
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
        suffixIcon:
            suffixIcon ??
            (readOnly
                ? Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: themeProvider.isDarkMode
                        ? Colors.white30
                        : Colors.black26,
                  )
                : null),
        filled: true,
        fillColor: readOnly
            ? (themeProvider.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03))
            : (themeProvider.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Logo con resplandor dorado
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
                              height: size.height * 0.12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isGoogleFlow
                              ? "Completa tu registro"
                              : "Crear Cuenta",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _isGoogleFlow
                              ? "Solo falta tu teléfono para continuar"
                              : "Únete a Kapital y transforma tus finanzas",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),

                        // Badge de Google si aplica
                        if (_isGoogleFlow) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/google_icon.png',
                                  height: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Conectado con Google',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 35),

                        // Avatar / Foto opcional
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Selección de foto disponible próximamente",
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                                backgroundImage: _imageUrl != null
                                    ? NetworkImage(_imageUrl!)
                                    : null,
                                child: _imageUrl == null
                                    ? Icon(
                                        Icons.camera_alt_outlined,
                                        size: 30,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(isDark),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Foto de perfil (Opcional)",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Nombre
                        _buildTextField(
                          context: context,
                          controller: nameController,
                          hint: 'Nombre completo',
                          obscure: false,
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // Email (solo lectura si viene de Google)
                        _buildTextField(
                          context: context,
                          controller: emailController,
                          hint: 'Correo electrónico',
                          obscure: false,
                          readOnly: _isGoogleFlow,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            if (!value.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // Teléfono
                        _buildTextField(
                          context: context,
                          controller: phoneController,
                          hint: 'Número de Teléfono',
                          obscure: false,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: _isGoogleFlow
                              ? TextInputAction.done
                              : TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu teléfono';
                            }
                            if (value.length < 7) return 'Número muy corto';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "A este número recibirás información importante sobre la app cuando sea necesario.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Contraseña (oculto si es flujo Google)
                        if (!_isGoogleFlow) ...[
                          _buildTextField(
                            context: context,
                            controller: passwordController,
                            hint: 'Contraseña',
                            obscure: _obscurePassword,
                            icon: Icons.lock_outline,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa una contraseña';
                              }
                              if (value.length < 6) {
                                return 'Debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 35),
                        ] else
                          const SizedBox(height: 20),

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
                            onPressed: _isLoading ? null : signUp,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isGoogleFlow
                                        ? "Completar Registro"
                                        : "Registrarse",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "¿Ya tienes cuenta? ",
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  "Inicia sesión",
                                  style: TextStyle(
                                    color: AppColors.primary(isDark),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        Text(
                          'v1.5.0 - SaaS Edition',
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
      ),
    );
  }
}
