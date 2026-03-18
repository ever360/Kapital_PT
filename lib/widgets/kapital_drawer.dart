import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KapitalDrawer extends StatefulWidget {
  const KapitalDrawer({super.key});

  @override
  State<KapitalDrawer> createState() => _KapitalDrawerState();
}

class _KapitalDrawerState extends State<KapitalDrawer> {
  String _rol = 'Cargando...';
  String _nombre = 'Usuario Kapital';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('nombre, rol')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _rol = res['rol'] ?? 'usuario';
          _nombre = res['nombre'] ?? 'Usuario Kapital';
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _getInitials(String nombre) {
    if (nombre.isEmpty) return '??';
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getAvatarColor(String nombre) {
    final colors = [
      AppColors.verdeSupabase,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
    ];
    return colors[nombre.hashCode.abs() % colors.length].withValues(alpha: 0.8);
  }

  String _getRolLabel(String rol) {
    switch (rol.toLowerCase()) {
      case 'master':
        return '👑 MASTER';
      case 'super_admin':
        return '🏢 DUEÑO / SOCIO';
      case 'socio':
        return '📊 SOCIO';
      case 'cobrador':
        return '🚶 COBRADOR';
      case 'supervisor':
        return '🔍 SUPERVISOR';
      default:
        return rol.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = AppColors.primary(isDark);

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      child: Column(
        children: [
          // Header Modernizado con Gradiente
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.3)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                    child: CircleAvatar(
                      radius: 29,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        _getInitials(_nombre),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _getRolLabel(_rol),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Items con estilo refinado
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_rounded,
                  title: 'Panel de Control',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_rounded,
                  title: 'Mi Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perfil próximamente")));
                  },
                ),
                if (_rol == 'master' || _rol == 'super_admin')
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_rounded,
                    title: 'Reportes Globales',
                    onTap: () {
                      Navigator.pop(context);
                      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reportes próximamente")));
                    },
                  ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'Configuraciones',
                  onTap: () {
                    Navigator.pop(context);
                    // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajustes próximamente")));
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Colors.white10),
                ),

                // Theme Toggle Modernizado
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Modo Oscuro',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: isDark,
                    activeColor: primaryColor,
                    activeTrackColor: primaryColor.withValues(alpha: 0.2),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? primaryColor.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? primaryColor : Colors.amber,
                        size: 20,
                      ),
                    ),
                    onChanged: (bool value) {
                      themeProvider.toggleTheme();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Footer / Salida
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _signOut(context),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cerrar Sesión',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'KAPITAL • v1.5.0',
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? Colors.white54 : Colors.black54,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        onTap: onTap,
        hoverColor: primary.withValues(alpha: 0.1),
        dense: true,
      ),
    );
  }
}
