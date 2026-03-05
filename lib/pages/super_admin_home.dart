import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminHomePage extends StatefulWidget {
  const SuperAdminHomePage({super.key});

  @override
  State<SuperAdminHomePage> createState() => _SuperAdminHomePageState();
}

class _SuperAdminHomePageState extends State<SuperAdminHomePage> {
  final supabase = Supabase.instance.client;

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "U";
    List<String> names = name.split(" ");
    if (names.length >= 2) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  Future<void> _updateUserStatus(
    String id,
    bool isApproved,
    bool isActive,
    String rol,
  ) async {
    try {
      await supabase
          .from('profiles')
          .update({'isApproved': isApproved, 'isActive': isActive, 'rol': rol})
          .eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Usuario actualizado")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al actualizar: $e")));
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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
              title: Text('Gestionar a ${user['nombre']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(
                        value: 'cobrador',
                        child: Text('Cobrador'),
                      ),
                      DropdownMenuItem(value: 'socio', child: Text('Socio')),
                      DropdownMenuItem(
                        value: 'super_admin',
                        child: Text('Súper Admin'),
                      ),
                    ],
                    onChanged: (value) =>
                        setStateDialog(() => selectedRole = value!),
                    decoration: const InputDecoration(
                      labelText: 'Rol del usuario',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Aprobado (Entrada)'),
                    value: isApproved,
                    onChanged: (val) => setStateDialog(() => isApproved = val),
                  ),
                  SwitchListTile(
                    title: const Text('Activo (Cuenta)'),
                    value: isActive,
                    onChanged: (val) => setStateDialog(() => isActive = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUserStatus(
                      user['id'],
                      isApproved,
                      isActive,
                      selectedRole,
                    );
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
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Usuarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: "Cerrar sesión",
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .order('nombre'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados'));
          }

          final perfiles = snapshot.data!;

          // Agrupación por rol
          final Map<String, List<Map<String, dynamic>>> agrupadosPorRol = {};
          for (var user in perfiles) {
            final rol = user['rol'] ?? 'Sin Rol';
            agrupadosPorRol.putIfAbsent(rol, () => []).add(user);
          }

          final rolesOrden = ['super_admin', 'socio', 'cobrador', 'Sin Rol'];
          final rolesPresentes = agrupadosPorRol.keys.toList()
            ..sort((a, b) {
              final aIndex = rolesOrden.indexOf(a);
              final bIndex = rolesOrden.indexOf(b);
              return (aIndex == -1 ? 99 : aIndex).compareTo(
                bIndex == -1 ? 99 : bIndex,
              );
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 30),
            itemCount: rolesPresentes.length,
            itemBuilder: (context, index) {
              final rolCategory = rolesPresentes[index];
              final usuariosRol = agrupadosPorRol[rolCategory]!;
              final rolTitle = rolCategory.replaceAll('_', ' ').toUpperCase();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      "$rolTitle (${usuariosRol.length})",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white54 : Colors.grey[700],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...usuariosRol.map((user) {
                    final isApproved = user['isApproved'] ?? false;
                    final isActive = user['isActive'] ?? false;
                    final String? fotoUrl = user['foto'];
                    final String nombre = user['nombre'] ?? 'Sin nombre';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: isActive && isApproved
                                ? const Color(0xFFD4AF37)
                                : Colors.grey.shade400,
                            backgroundImage: fotoUrl != null
                                ? NetworkImage(fotoUrl)
                                : null,
                            child: fotoUrl == null
                                ? Text(
                                    _getInitials(nombre),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildBadge(
                                  isActive ? 'Activo' : 'Inactivo',
                                  isActive ? Colors.green : Colors.red,
                                ),
                                _buildBadge(
                                  isApproved ? 'Aprobado' : 'Pendiente',
                                  isApproved ? Colors.blue : Colors.orange,
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blueGrey,
                            ),
                            onPressed: () => _showEditRoleDialog(user),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
