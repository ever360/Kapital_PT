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
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addUser(String email, String role) async {
    setState(() => _isLoading = true);
    try {
      // 1. Buscar si el usuario existe
      final res = await supabase.from('profiles').select().eq('email', email.trim().toLowerCase()).maybeSingle();

      if (res == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("El usuario no está registrado en la plataforma. Debe registrarse primero.")),
          );
        }
      } else {
        if (res['empresa_id'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Este usuario ya pertenece a otra empresa.")),
            );
          }
        } else {
          // Vincular a esta empresa y asignar rol
          await supabase.from('profiles').update({
            'empresa_id': _empresaId,
            'rol': role,
            'isActive': false, // Se crea inactivo por defecto para control de cupo
            'isApproved': true, // Al ser invitado por el admin, ya está aprobado
          }).eq('id', res['id']);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ ${res['nombre']} vinculado correctamente como $role.")),
            );
          }
        }
      }
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'cobrador';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Añadir Personal"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email del usuario",
                  hintText: "ejemplo@correo.com",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Rol asignado"),
                items: const [
                  DropdownMenuItem(value: 'cobrador', child: Text("Cobrador")),
                  DropdownMenuItem(value: 'socio', child: Text("Socio")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (emailController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _addUser(emailController.text, selectedRole);
                }
              },
              child: const Text("Vincular"),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isNearLimit => _usuariosActivos >= _cupoTotal;
  bool get _isAtLimit => _usuariosActivos > 0 && _usuariosActivos == _cupoTotal;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);
    final warningColor = Colors.orange;
    final dangerColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Gestión de Equipo"),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("Añadir Personal"),
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
                      : [
                          _isAtLimit 
                            ? dangerColor.withValues(alpha: 0.1) 
                            : (_isNearLimit ? warningColor.withValues(alpha: 0.1) : primary.withValues(alpha: 0.1)),
                          Colors.white
                        ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAtLimit 
                      ? dangerColor.withValues(alpha: 0.4) 
                      : (_isNearLimit ? warningColor.withValues(alpha: 0.4) : primary.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cupo de Usuarios Activos", 
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54, 
                            fontSize: 13
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$_usuariosActivos / $_cupoTotal",
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold, 
                            color: _isAtLimit ? dangerColor : (_isNearLimit ? warningColor : primary)
                          ),
                        ),
                        if (_isAtLimit)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "⚠️ Cupo lleno", 
                              style: TextStyle(color: dangerColor, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                          ),
                      ],
                    ),
                    Icon(
                      _isAtLimit ? Icons.warning_amber_rounded : Icons.group_rounded, 
                      color: _isAtLimit ? dangerColor : (_isNearLimit ? warningColor : primary), 
                      size: 40
                    ),
                  ],
                ),
              ),

              // Lista de Empleados
              Expanded(
                child: _empleados.isEmpty 
                  ? const Center(child: Text("No hay empleados registrados."))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(height: 80), // Espacio para el FAB extendido
            ],
          ),
    );
  }
}
