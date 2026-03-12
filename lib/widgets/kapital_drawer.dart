import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KapitalDrawer extends StatelessWidget {
  const KapitalDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'usuario@kapital.com';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            accountName: Text(
              "Kapital",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              email,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.1),
              child: const Icon(Icons.person_outline, color: Colors.amber, size: 40),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Mi Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    // Proximamente: Navegar a perfil
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Configuraciones',
                  onTap: () {
                    Navigator.pop(context);
                    // Proximamente: Navegar a ajustes
                  },
                ),
                const Divider(color: Colors.white10),
                
                // Theme Toggle
                SwitchListTile(
                  title: Text(
                    isDark ? 'Modo Oscuro' : 'Modo Claro',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  value: isDark,
                  activeColor: Colors.amber,
                  secondary: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onChanged: (bool value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ],
            ),
          ),

          // Footer / Logout
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListTile(
              onTap: () => _signOut(context),
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent, width: 0.5),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'v1.2.0 - Foundation',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 10,
                ),
              ),
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}
