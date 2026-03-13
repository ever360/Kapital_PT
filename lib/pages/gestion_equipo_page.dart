import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class GestionEquipoPage extends StatefulWidget {
  const GestionEquipoPage({super.key});

  @override
  State<GestionEquipoPage> createState() => _GestionEquipoPageState();
}

class _GestionEquipoPageState extends State<GestionEquipoPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _empleados = [];
  int _usuariosActivos = 0;
  int _cupoTotal = 0;
  String? _empresaId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase.from('profiles').select('empresa_id').eq('id', user.id).single();
      _empresaId = profile['empresa_id'];

      if (_empresaId != null) {
        // 1. Datos de la empresa (Cupo)
        final empresa = await supabase.from('empresas').select('total_rutas_contratadas').eq('id', _empresaId!).single();
        _cupoTotal = empresa['total_rutas_contratadas'] ?? 0;

        // 2. Lista de empleados
        final empleadosRes = await supabase
            .from('profiles')
            .select()
            .eq('empresa_id', _empresaId!)
            .order('nombre');
        
        final allProfiles = List<Map<String, dynamic>>.from(empleadosRes);
        
        setState(() {
          _empleados = allProfiles;
          _usuariosActivos = allProfiles.where((u) => u['isActive'] == true).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> empleado, bool newValue) async {
    if (newValue && _usuariosActivos >= _cupoTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ No tienes cupos disponibles. Aumenta tu plan o desactiva otro usuario."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await supabase.from('profiles').update({'isActive': newValue}).eq('id', empleado['id']);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Gestión de Equipo"),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primary))
        : Column(
            children: [
              // Resumen de Cupos
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                      : [primary.withValues(alpha: 0.1), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Cupo de Usuarios Activos", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          "$_usuariosActivos / $_cupoTotal",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
                        ),
                      ],
                    ),
                    Icon(Icons.group_rounded, color: primary, size: 40),
                  ],
                ),
              ),

              // Lista de Empleados
              Expanded(
                child: _empleados.isEmpty 
                  ? const Center(child: Text("No hay empleados registrados."))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _empleados.length,
                      itemBuilder: (context, index) {
                        final emp = _empleados[index];
                        final bool isActive = emp['isActive'] ?? false;
                        final String rol = emp['rol'] ?? 'Sin rol';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primary.withValues(alpha: 0.1),
                              child: Text(
                                emp['nombre']?[0].toUpperCase() ?? '?',
                                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              emp['nombre'] ?? 'Sin nombre',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              rol.toUpperCase(),
                              style: const TextStyle(fontSize: 10, letterSpacing: 0.5),
                            ),
                            trailing: Switch(
                              value: isActive,
                              activeThumbColor: primary,
                              onChanged: (val) => _toggleStatus(emp, val),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}
