import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class SuperAdminHomePage extends StatefulWidget {
  const SuperAdminHomePage({super.key});

  @override
  State<SuperAdminHomePage> createState() => _SuperAdminHomePageState();
}

class _SuperAdminHomePageState extends State<SuperAdminHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _miEmpresa;
  String? _miEmpresaId;
  int _sociosActuales = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener mi perfil para sacar el empresa_id
      final profile = await supabase.from('profiles').select().eq('id', user.id).single();
      _miEmpresaId = profile['empresa_id'];

      if (_miEmpresaId != null) {
        // 2. Obtener datos de la empresa
        final empresaRes = await supabase.from('empresas').select().eq('id', _miEmpresaId!).single();
        
        // 3. Contar los socios actuales de esta empresa
        final countRes = await supabase
            .from('profiles')
            .select('id')
            .eq('empresa_id', _miEmpresaId!)
            .eq('rol', 'socio');

        if (mounted) {
          setState(() {
            _miEmpresa = empresaRes;
            _sociosActuales = countRes.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos. $e')));
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "U";
    List<String> names = name.split(" ");
    if (names.length >= 2) return "${names[0][0]}${names[1][0]}".toUpperCase();
    return names[0][0].toUpperCase();
  }

  Future<void> _updateUserStatus(String id, bool isApproved, bool isActive, String rol) async {
    try {
      await supabase.from('profiles').update({
        'isApproved': isApproved,
        'isActive': isActive,
        'rol': rol
      }).eq('id', id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario actualizado")));
      _loadDashboardData(); // Recargar cuentas
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al actualizar: $e")));
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _crearNuevoSocio() async {
    if (_miEmpresa == null) return;
    
    final int sociosMaximos = _miEmpresa!['socios_maximos'] ?? 0;
    
    if (_sociosActuales >= sociosMaximos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Has alcanzado el límite máximo de Socios permitidos en tu plan."),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Crear Nuevo Socio', 
                style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87)
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Disponibles: ${sociosMaximos - _sociosActuales}", style: TextStyle(color: AppColors.primary(themeProvider.isDarkMode), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nombreCtrl,
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Nombre y Apellido'),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Correo Electrónico'),
                        validator: (v) => v!.contains('@') ? null : 'Correo inválido',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Teléfono'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Contraseña (mín 6)'),
                        validator: (v) => (v != null && v.length >= 6) ? null : 'Mínimo 6 caracteres',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(themeProvider.isDarkMode),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isCreating ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setStateDialog(() => isCreating = true);
                      try {
                        // Usar un cliente temporal para no desloguear al Admin
                        final tempClient = SupabaseClient('https://uvmlrxazutsocrfzueoc.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2bWxyeGF6dXRzb2NyZnp1ZW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDgzMDgsImV4cCI6MjA4NzI4NDMwOH0.vi59v3GKVnwpE7D1C8A0HEswLIJD0fqDXXZEfuNcXGA');
                        final authRes = await tempClient.auth.signUp(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim()
                        );
                        
                        if (authRes.user != null) {
                          // Insertar el perfil con el cliente temporal (que ahora está logueado como el socio)
                          await tempClient.from('profiles').insert({
                            'id': authRes.user!.id,
                            'nombre': nombreCtrl.text.trim(),
                            'telefono': phoneCtrl.text.trim(),
                            'rol': 'socio',
                            'empresa_id': _miEmpresaId,
                            'isApproved': true,
                            'isActive': true,
                          });
                          
                          // Cerrar sesión del temp client para evitar basura
                          await tempClient.auth.signOut();
                          
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _loadDashboardData();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Socio creado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         setStateDialog(() => isCreating = false);
                         if (!context.mounted) return;
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isCreating ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Crear'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white54 : Colors.black54),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.white24 : Colors.black26)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(themeProvider.isDarkMode))),
    );
  }

  void _showEditRoleDialog(Map<String, dynamic> user) {
    String selectedRole = user['rol'] ?? 'cobrador';
    bool isApproved = user['isApproved'] ?? false;
    bool isActive = user['isActive'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text('Gestionar a ${user['nombre']}', style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    dropdownColor: themeProvider.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'cobrador', child: Text('Cobrador')),
                      DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                      DropdownMenuItem(value: 'socio', child: Text('Socio')),
                    ],
                    onChanged: (value) => setStateDialog(() => selectedRole = value!),
                    decoration: _inputDeco('Rol del usuario'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text('Aprobado (Entrada)', style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
                    activeTrackColor: AppColors.primary(themeProvider.isDarkMode),
                    value: isApproved,
                    onChanged: (val) => setStateDialog(() => isApproved = val),
                  ),
                  SwitchListTile(
                    title: Text('Activo (Cuenta)',  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
                    activeTrackColor: AppColors.primary(themeProvider.isDarkMode),
                    value: isActive,
                    onChanged: (val) => setStateDialog(() => isActive = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(themeProvider.isDarkMode), foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUserStatus(user['id'], isApproved, isActive, selectedRole);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Empresa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboardData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut, tooltip: "Cerrar sesión"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearNuevoSocio,
        backgroundColor: AppColors.primary(themeProvider.isDarkMode),
        icon: const Icon(Icons.add_business, color: Colors.black),
        label: const Text("Nuevo Socio", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.primary(themeProvider.isDarkMode)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppColors.primary(themeProvider.isDarkMode),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard Card
                    if (_miEmpresa != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.8), const Color(0xFFB5952A).withValues(alpha: 0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _miEmpresa!['nombre'] ?? 'Mi Empresa',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _InfoStat(title: "Rutas Máximas", value: "${_miEmpresa!['rutas_maximas'] ?? 0}"),
                                _InfoStat(title: "Socios", value: "$_sociosActuales / ${_miEmpresa!['socios_maximos'] ?? 0}"),
                              ],
                            )
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Mi Equipo",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),

                    // Lista de Empleados
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('empresa_id', _miEmpresaId ?? '').order('nombre'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        
                        final team = snapshot.data!;
                        if (team.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text("Aún no tienes equipo registrado.")),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: team.length,
                          itemBuilder: (context, index) {
                            final user = team[index];
                            final isApproved = user['isApproved'] ?? false;
                            final isActive = user['isActive'] ?? false;
                            final String rol = (user['rol'] ?? '').toUpperCase();
                            
                            // No mostrarse a sí mismo si no queremos, o mostrarlo con otro estilo.
                            // Aquí se mostrarán todos.
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: isDark ? 0 : 1,
                              color: isDark ? const Color(0xFF232323) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.2),
                                  child: Text(_getInitials(user['nombre']), style: TextStyle(color: AppColors.primary(themeProvider.isDarkMode), fontWeight: FontWeight.bold)),
                                ),
                                title: Text(user['nombre'] ?? 'Sin Nombre', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildBadge(rol, Colors.blueGrey),
                                    _buildBadge(isActive ? 'Activo' : 'Inactivo', isActive ? Colors.green : Colors.red),
                                    _buildBadge(isApproved ? 'Aprobado' : 'Pendiente', isApproved ? Colors.blue : Colors.orange),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.settings, color: Colors.grey),
                                  onPressed: () => _showEditRoleDialog(user),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 80), // Padding para el FAB
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  final String title;
  final String value;

  const _InfoStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

