import 'dart:ui';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final tp = Provider.of<ThemeProvider>(context);
        final isDark = tp.isDarkMode;
        final primary = AppColors.primary(isDark);

        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              top: 32,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Añadir Personal",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Vincula a un nuevo miembro a tu equipo mediante su correo electrónico.",
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    hintText: "ejemplo@correo.com",
                    prefixIcon: Icon(Icons.email_outlined, color: primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Rol del Personal",
                    prefixIcon: Icon(Icons.badge_outlined, color: primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cobrador', child: Text("Cobrador")),
                    DropdownMenuItem(value: 'socio', child: Text("Socio")),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (emailController.text.isNotEmpty) {
                        Navigator.pop(context);
                        _addUser(emailController.text, selectedRole);
                      }
                    },
                    child: const Text("Vincular al Equipo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: const Text(
          "Gestión de Equipo",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark 
            ? const Color(0xFF1A1A1A).withOpacity(0.7) 
            : Colors.white.withOpacity(0.7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        elevation: 4,
        backgroundColor: primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("Añadir Personal", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primary))
        : Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
              // Resumen de Cupos
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isAtLimit 
                      ? dangerColor.withOpacity(0.4) 
                      : (_isNearLimit ? warningColor.withOpacity(0.4) : primary.withOpacity(0.1)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isAtLimit ? dangerColor : primary).withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MI CUPO DISPONIBLE", 
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38, 
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          )
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "$_usuariosActivos",
                              style: TextStyle(
                                fontSize: 32, 
                                fontWeight: FontWeight.w900, 
                                color: _isAtLimit ? dangerColor : (_isNearLimit ? warningColor : isDark ? Colors.white : Colors.black87),
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              " / $_cupoTotal",
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_isAtLimit ? dangerColor : primary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _isAtLimit ? Icons.warning_rounded : Icons.group_rounded, 
                        color: _isAtLimit ? dangerColor : primary, 
                        size: 32
                      ),
                    ),
                  ],
                ),
              ),

              // Título lista
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      "PERSONAL REGISTRADO",
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${_empleados.length} Total",
                      style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Lista de Empleados
              Expanded(
                child: _empleados.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black12),
                          const SizedBox(height: 16),
                          Text(
                            "No hay empleados registrados.",
                            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _empleados.length,
                      itemBuilder: (context, index) {
                        final emp = _empleados[index];
                        final bool isActive = emp['isActive'] ?? false;
                        final String rol = emp['rol'] ?? 'cobrador';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primary.withOpacity(0.3), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: primary.withOpacity(0.1),
                                child: Text(
                                  emp['nombre']?[0].toUpperCase() ?? '?',
                                  style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                            title: Text(
                              emp['nombre'] ?? 'Sin nombre',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (rol == 'socio' ? Colors.blue : Colors.purple).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      rol.toUpperCase(),
                                      style: TextStyle(
                                        color: rol == 'socio' ? Colors.blue : Colors.purple,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isActive ? "Activo" : "Inactivo",
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.redAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Switch(
                              value: isActive,
                              activeColor: primary,
                              activeTrackColor: primary.withOpacity(0.2),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withOpacity(0.2),
                              trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
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
