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
  String? _miEmpresaId;
  List<Map<String, dynamic>> _empresas = [];
  Map<String, Map<String, int>> _empresaStats = {};
  int _solicitudesPendientes = 0;
  int _empresasConAlertaVencimiento = 0;

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
          .select('nombre, rol, empresa_id')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _rol = res['rol'] ?? 'usuario';
          _nombre = res['nombre'] ?? 'Usuario Kapital';
          _miEmpresaId = res['empresa_id'];
        });

        if ((res['rol'] ?? '').toString().toLowerCase() == 'master') {
          await _loadMasterDashboardData();
        }
      }
    }
  }

  int _diasParaVencer(String? isoDate) {
    if (isoDate == null) return 9999;
    final vencDate = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();
    return vencDate.difference(now).inDays;
  }

  Future<void> _loadMasterDashboardData() async {
    try {
      final empresasRes = await Supabase.instance.client
          .from('empresas')
          .select(
            'id, nombre, is_active, fecha_vencimiento, total_rutas_contratadas',
          )
          .order('nombre');

      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('empresa_id, isActive, isApproved, rol');

      final rutasRes = await Supabase.instance.client
          .from('rutas')
          .select('empresa_id');

      final empresas = List<Map<String, dynamic>>.from(empresasRes);
      final profiles = List<Map<String, dynamic>>.from(profilesRes);
      final rutas = List<Map<String, dynamic>>.from(rutasRes);

      final stats = <String, Map<String, int>>{};
      int alertasVencimiento = 0;

      for (final emp in empresas) {
        final id = emp['id']?.toString();
        if (id == null) continue;

        final usuariosEmpresa = profiles
            .where((p) => p['empresa_id']?.toString() == id)
            .toList();
        final rutasEmpresa = rutas.where(
          (r) => r['empresa_id']?.toString() == id,
        );

        final usuariosActivos = usuariosEmpresa
            .where((p) => p['isActive'] == true)
            .length;
        final pendientes = usuariosEmpresa
            .where((p) => p['isApproved'] != true || p['isActive'] != true)
            .length;

        stats[id] = {
          'usuariosActivos': usuariosActivos,
          'usuariosTotal': usuariosEmpresa.length,
          'rutasTotal': rutasEmpresa.length,
          'pendientes': pendientes,
        };

        final dias = _diasParaVencer(emp['fecha_vencimiento'] as String?);
        if (dias <= 7) {
          alertasVencimiento += 1;
        }
      }

      final pendientesGlobales = profiles
          .where((p) => p['rol'] == 'admin_pendiente')
          .length;

      if (!mounted) return;
      setState(() {
        _empresas = empresas;
        _empresaStats = stats;
        _solicitudesPendientes = pendientesGlobales;
        _empresasConAlertaVencimiento = alertasVencimiento;
      });
    } catch (e) {
      debugPrint('Error cargando dashboard master en drawer: $e');
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

  String _getRolLabel(String rol, ThemeProvider tp) {
    if (rol.toLowerCase() == 'master') {
      return tp.masterView == 'master' ? '👑 MASTER' : '🏢 M / DUEÑO';
    }
    switch (rol.toLowerCase()) {
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

  Widget _buildMasterViewSelector(
    ThemeProvider tp,
    bool isDark,
    Color primary,
  ) {
    final isMasterView = tp.masterView == 'master';
    final inMyCompanyView =
        tp.masterView == 'super_admin' && tp.targetEmpresaId == _miEmpresaId;
    final linkedEmpresa = _empresas
        .where((e) => e['id']?.toString() == _miEmpresaId)
        .cast<Map<String, dynamic>>()
        .toList();
    final empresaLabel = linkedEmpresa.isNotEmpty
        ? (linkedEmpresa.first['nombre'] ?? 'Mi Empresa').toString()
        : 'Mi Empresa';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                tp.setMasterView('master');
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/master_home');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isMasterView ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '👑 Master',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isMasterView
                        ? Colors.black
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: _miEmpresaId == null
                  ? null
                  : () {
                      final miEmpresa = _empresas
                          .where((e) => e['id']?.toString() == _miEmpresaId)
                          .cast<Map<String, dynamic>>()
                          .toList();
                      if (miEmpresa.isNotEmpty) {
                        tp.setMasterView(
                          'super_admin',
                          empresaId: _miEmpresaId,
                          empresa: miEmpresa.first,
                        );
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/master_home');
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: inMyCompanyView
                      ? Colors.blueAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🏢 $empresaLabel',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: inMyCompanyView
                        ? Colors.white
                        : (_miEmpresaId == null
                              ? (isDark ? Colors.white30 : Colors.black26)
                              : (isDark ? Colors.white70 : Colors.black87)),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterEmpresaTile(
    Map<String, dynamic> emp,
    ThemeProvider tp,
    bool isDark,
    Color primary,
  ) {
    final id = emp['id']?.toString() ?? '';
    final stats = _empresaStats[id] ?? const {};
    final usuariosActivos = stats['usuariosActivos'] ?? 0;
    final usuariosTotal = stats['usuariosTotal'] ?? 0;
    final rutasTotal = stats['rutasTotal'] ?? 0;
    final pendientes = stats['pendientes'] ?? 0;
    final dias = _diasParaVencer(emp['fecha_vencimiento'] as String?);
    final isSelected =
        tp.masterView == 'super_admin' && tp.targetEmpresaId == id;

    final Color vencColor = dias < 0
        ? Colors.redAccent
        : (dias <= 7 ? Colors.orange : Colors.green);
    final String vencLabel = dias < 0
        ? 'Vencida'
        : (dias <= 7 ? 'Vence en $dias d' : 'Al día');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? primary.withValues(alpha: 0.45)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          tp.setMasterView('super_admin', empresaId: id, empresa: emp);
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/master_home');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      emp['nombre'] ?? 'Empresa',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pendientes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'Pend: $pendientes',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniMetric('👥', '$usuariosActivos/$usuariosTotal'),
                  const SizedBox(width: 10),
                  _miniMetric('🛣', '$rutasTotal'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vencLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: vencColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$icon $value',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = AppColors.primary(isDark);
    final avatarColor = _getAvatarColor(_nombre);
    final secondaryGlow = isDark ? Colors.cyanAccent : Colors.blueAccent;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF07111A),
                          Color(0xFF0D0D0D),
                          Color(0xFF111D1B),
                        ]
                      : const [
                          Color(0xFFFBF7EF),
                          Color(0xFFF6FBF8),
                          Color(0xFFFFFFFF),
                        ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 24,
                      bottom: 24,
                      left: 20,
                      right: 20,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.18),
                            blurRadius: 34,
                            spreadRadius: -12,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      avatarColor,
                                      secondaryGlow.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 33,
                                  backgroundColor: isDark
                                      ? const Color(0xFF0D0D0D)
                                      : Colors.white,
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: avatarColor.withValues(
                                      alpha: 0.14,
                                    ),
                                    child: Text(
                                      _getInitials(_nombre),
                                      style: TextStyle(
                                        color: avatarColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nombre,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Panel conectado y listo para operar',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _getRolLabel(_rol, themeProvider),
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_rol.toLowerCase() == 'master') ...[
                            const SizedBox(height: 12),
                            _buildMasterViewSelector(
                              themeProvider,
                              isDark,
                              primaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 12,
                      ),
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
                        if (_rol == 'master' || _rol == 'super_admin') ...[
                          if (_rol == 'master') ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.025)
                                    : Colors.black.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Pendientes: $_solicitudesPendientes',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Por vencer: $_empresasConAlertaVencimiento',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_empresas.isNotEmpty)
                              ..._empresas.map(
                                (emp) => _buildMasterEmpresaTile(
                                  emp,
                                  themeProvider,
                                  isDark,
                                  primaryColor,
                                ),
                              ),
                          ],
                          _buildDrawerItem(
                            context,
                            icon: Icons.analytics_rounded,
                            title: 'Reportes Globales',
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          if (_rol == 'super_admin' ||
                              themeProvider.masterView == 'super_admin')
                            _buildDrawerItem(
                              context,
                              icon: Icons.group_rounded,
                              title: 'Gestión de Equipo',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/gestion_equipo');
                              },
                            ),
                        ],
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Divider(color: Colors.white10),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _signOut(context),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.redAccent.withValues(alpha: 0.12),
                                  Colors.redAccent.withValues(alpha: 0.04),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(18),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: isDark
            ? Colors.white.withValues(alpha: 0.025)
            : Colors.white.withValues(alpha: 0.78),
        leading: Icon(icon, color: isDark ? Colors.white70 : primary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
        hoverColor: primary.withValues(alpha: 0.1),
        dense: true,
      ),
    );
  }
}
