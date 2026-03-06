import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          // Verificar la cantidad de perfiles actuales
          final res = await supabase.from('profiles').select('id');
          final totalProfiles = res.length;

          final isFirstUser = totalProfiles == 0;
          final String rolAsignado = isFirstUser ? 'super_admin' : 'cobrador';
          final bool statusAsignado = isFirstUser ? true : false; // Si es el primero, entra directo (Aprobado y Activo)

          await supabase.from('profiles').insert({
            'id': authResponse.user!.id,
            'nombre': nameController.text.trim(),
            'telefono': phoneController.text.trim(),
            'foto': null,
            'rol': rolAsignado,
            'isApproved': statusAsignado,
            'isActive': statusAsignado,
          });

          if (!mounted) return;

          if (isFirstUser) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Cuenta Súper Admin creada! Ya puedes ingresar."),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Registro exitoso. Espera aprobación de un administrador."),
                backgroundColor: Colors.blue,
              ),
            );
          }

          Navigator.pop(context); // Volver al login
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo oscuro emparejado con Login
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
                                  color: Colors.amber.withValues(alpha: 0.15),
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
                        const Text(
                          "Crear Cuenta",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Únete a Kapital y transforma tus finanzas",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 35),

                        _buildTextField(
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
                          controller: phoneController,
                          hint: 'Teléfono',
                          obscure: false,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu teléfono';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        _buildTextField(
                          controller: passwordController,
                          hint: 'Contraseña',
                          obscure: _obscurePassword,
                          icon: Icons.lock_outline,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.white54,
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
                              backgroundColor: const Color(0xFFD4AF37), // Botón dorado
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
                            const Text(
                              "¿Ya tienes cuenta? ",
                              style: TextStyle(color: Colors.white70),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "Inicia sesión",
                                  style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
