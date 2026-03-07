import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? _imageUrl; // Para la foto opcional
  bool _obscurePassword = true;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authResponse = await supabase.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        if (!mounted) return;

        if (authResponse.user != null) {
          // 1. Contar cuántos usuarios hay globalmente usando nuestra función segura (bypasa el RLS)
          // Verificamos si es el primer usuario en la base de datos (obsoleto por RLS).
          // El máster ya existe, todos los nuevos deben ser admin_pendiente por defecto.
          final bool isFirstUser = false; // Removido para evitar que todos hereden Master

          // 2. Crear el perfil del usuario (Sin empresa asignada aún)
          // El Master lo aprobará y creará su empresa manualmente después
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

          if (!mounted) return;

          if (isFirstUser) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Cuenta MASTER (DIOS) creada! Ya puedes ingresar."),
                backgroundColor: Colors.green,
              ),
            );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Solicitud enviada exitosamente. El Master revisará tu cuenta pronto."),
                backgroundColor: Colors.blue,
              ),
            );
          }

          Navigator.pop(context); // Volver al login
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
              )
            ],
          )
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required BuildContext context, // Agregamos context
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
      style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54),
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
                                  color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.4),
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
                          "Crear Cuenta",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Únete a Kapital y transforma tus finanzas",
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 35),

                        // Avatar / Foto opcional
                        GestureDetector(
                          onTap: () {
                            // TODO: Implementar selección de imagen (image_picker)
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selección de foto disponible próximamente")));
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                                child: _imageUrl == null 
                                  ? Icon(Icons.camera_alt_outlined, size: 30, color: isDark ? Colors.white38 : Colors.black38) 
                                  : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: AppColors.primary(isDark), shape: BoxShape.circle),
                                  child: const Icon(Icons.add, size: 18, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text("Foto de perfil (Opcional)", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                        const SizedBox(height: 25),

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



                        _buildTextField(
                          context: context,
                          controller: emailController,
                          hint: 'Correo electrónico',
                          obscure: false,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Ingresa tu correo';
                            if (!value.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        _buildTextField(
                          context: context,
                          controller: phoneController,
                          hint: 'Número de Teléfono',
                          obscure: false,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
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
                            style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 15),

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
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                            if (value.length < 6) return 'Debe tener al menos 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary(isDark), // Botón dinámico
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
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  )
                                : const Text(
                                    "Registrarse",
                                    style: TextStyle(
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
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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

                        // Versión Abajo
                        Text(
                          'v1.4.5 - SaaS Edition',
                          style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11),
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

