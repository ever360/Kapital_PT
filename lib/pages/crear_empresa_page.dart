import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class CrearEmpresaPage extends StatefulWidget {
  const CrearEmpresaPage({super.key});

  @override
  State<CrearEmpresaPage> createState() => _CrearEmpresaPageState();
}

class _CrearEmpresaPageState extends State<CrearEmpresaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController ciudadController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> _crearEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Insertar la empresa
      final empresaData = {
        'nombre': nombreController.text.trim(),
        'is_active': false, // Sigue requiriendo activacion del Master
        'total_rutas_contratadas': 1, // Valor inicial por defecto
        'ciudad': ciudadController.text.trim(),
        'telefono': telefonoController.text.trim(),
        'descripcion': descripcionController.text.trim(),
      };

      final List<dynamic> response = await supabase
          .from('empresas')
          .insert(empresaData)
          .select();

      if (response.isEmpty) throw Exception("Error al crear la empresa");

      final String empresaId = response[0]['id'];

      // 2. Vincular al usuario admin
      await supabase.from('profiles').update({
        'empresa_id': empresaId,
      }).eq('id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Empresa registrada. El Master debe activarla para empezar."),
          backgroundColor: Colors.green,
        ),
      );

      // Redirigir al home
      Navigator.pushReplacementNamed(context, '/super_admin_home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Configura tu Empresa"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "¡Bienvenido, Dueño!",
                style: TextStyle(
                  color: AppColors.primary(isDark),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Para comenzar, necesitamos los datos básicos de tu empresa de préstamos.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              _buildField(
                label: "Nombre de la Empresa",
                controller: nombreController,
                icon: Icons.business_outlined,
                hint: "Ej: Kapital Inversiones",
                validator: (v) => (v == null || v.isEmpty) ? "Requerido" : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                label: "Ciudad / Ubicación",
                controller: ciudadController,
                icon: Icons.location_on_outlined,
                hint: "Ej: Bogotá, Colombia",
              ),
              const SizedBox(height: 20),

              _buildField(
                label: "Teléfono de Contacto",
                controller: telefonoController,
                icon: Icons.phone_outlined,
                hint: "Ej: +57 300...",
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              _buildField(
                label: "Descripción breve",
                controller: descripcionController,
                icon: Icons.description_outlined,
                hint: "Breve descripción de tu negocio",
                maxLines: 3,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(isDark),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _crearEmpresa,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Registrar Empresa",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
            prefixIcon: Icon(icon, color: AppColors.primary(isDark), size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
