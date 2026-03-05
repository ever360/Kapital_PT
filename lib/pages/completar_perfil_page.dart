import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompletarPerfilPage extends StatefulWidget {
  final User user;

  const CompletarPerfilPage({super.key, required this.user});

  @override
  State<CompletarPerfilPage> createState() => _CompletarPerfilPageState();
}

class _CompletarPerfilPageState extends State<CompletarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<void> completar() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Revisar si es el primer usuario de toda la app
        final perfiles = await supabase.from('profiles').select('id').limit(1);
        final bool isFirstUser = perfiles.isEmpty;

        await supabase.from('profiles').insert({
          'id': widget.user.id,
          'nombre': nameController.text.trim(),
          'telefono': phoneController.text.trim(),
          'foto': null,
          'isApproved': isFirstUser, // Si es el primero, lo aprobamos
          'isActive': isFirstUser,
          'rol': isFirstUser ? 'super_admin' : 'cobrador',
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFirstUser
                  ? "Registro exitoso. ¡Eres el Súper Administrador!"
                  : "Registro exitoso. Espera a que te aprueben para iniciar.",
            ),
          ),
        );

        if (isFirstUser) {
          // Va a su panel
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/super_admin_home',
            (route) => false,
          );
        } else {
          // Si no es el primero, lo deslogueamos y mandamos al login
          final nav = Navigator.of(context);
          await supabase.auth.signOut();
          nav.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () async {
            final nav = Navigator.of(context);
            await supabase.auth.signOut();
            nav.pushReplacementNamed('/login');
          },
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logoKapital.png',
                          height: size.height * 0.15,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Completa tu perfil",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Para continuar con Google, ingresa los siguientes datos.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 30),

                        // Nombre
                        _buildTextField(
                          controller: nameController,
                          hint: 'Nombre Completo',
                          icon: Icons.person,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Teléfono
                        _buildTextField(
                          controller: phoneController,
                          hint: 'Teléfono',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu número de teléfono';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),

                        // Botón Finalizar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: completar,
                            child: const Text("Finalizar Registro"),
                          ),
                        ),
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
