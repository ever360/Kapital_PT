import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/pages/login_page.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/widgets/kapital_drawer.dart';

// Se ignoran advertencias de miembros obsoletos usados en este archivo, especialmente
// RadioListTile.groupValue/onChanged y Switch.activeColor.
// ignore_for_file: deprecated_member_use

class MasterHomePage extends StatefulWidget {
  const MasterHomePage({super.key});

  @override
  State<MasterHomePage> createState() => _MasterHomePageState();
}

class _MasterHomePageState extends State<MasterHomePage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _todosUsuarios = [];
  List<Map<String, dynamic>> _pendientes = [];
  late TabController _tabController;
  late final RealtimeChannel _profilesChannel;
  late final RealtimeChannel _empresasChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupRealtime();
    _refreshData();
  }

  void _setupRealtime() {
    _profilesChannel = supabase.channel('profiles_changes');
    _profilesChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) => _refreshData(),
        )
        .subscribe();

    _empresasChannel = supabase.channel('empresas_changes');
    _empresasChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'empresas',
          callback: (payload) => _refreshData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _profilesChannel.unsubscribe();
    _empresasChannel.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchEmpresas(), _fetchUsuarios()]);
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchEmpresas() async {
    try {
      final res = await supabase.from('empresas').select();
      if (!mounted) return;
      setState(() => _empresas = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error empresas: $e');
      if (!mounted) return;
      setState(() => _empresas = []);
    }
  }

  Future<void> _fetchUsuarios() async {
    try {
      final res = await supabase.from('profiles').select();
      if (!mounted) return;
      final all = List<Map<String, dynamic>>.from(res);
      setState(() {
        _todosUsuarios = all
            .where((u) => u['rol'] != 'admin_pendiente')
            .toList();
        _pendientes = all.where((u) => u['rol'] == 'admin_pendiente').toList();
      });
    } catch (e) {
      debugPrint('Error usuarios: $e');
      if (!mounted) return;
      setState(() {
        _todosUsuarios = [];
        _pendientes = [];
      });
    }
  }

  // ============== HELPERS ==============

  String _getInitials(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return '??';
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getAvatarColor(String? nombre) {
    if (nombre == null) return Colors.blueGrey;
    final colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFFE17055),
      const Color(0xFF0984E3),
      const Color(0xFFFDAA5D),
      const Color(0xFFE84393),
      const Color(0xFF00CEC9),
      const Color(0xFFFF7675),
    ];
    return colors[nombre.hashCode.abs() % colors.length];
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'master':
        return const Color(0xFFFFD700);
      case 'super_admin':
        return const Color(0xFF6C5CE7);
      case 'admin':
        return const Color(0xFF0984E3);
      case 'socio':
        return const Color(0xFF00B894);
      case 'cobrador':
        return const Color(0xFFE17055);
      case 'supervisor':
        return const Color(0xFF00CEC9);
      default:
        return Colors.grey;
    }
  }

  String _getRolLabel(String rol) {
    switch (rol) {
      case 'master':
        return '👑 Master';
      case 'super_admin':
        return '🏢 Dueño';
      case 'admin':
        return '👔 Admin';
      case 'socio':
        return '📊 Socio';
      case 'cobrador':
        return '🚶 Cobrador';
      case 'supervisor':
        return '🔍 Supervisor';
      case 'admin_pendiente':
        return '⏳ Pendiente';
      default:
        return rol;
    }
  }

  String? _getEmpresaNombre(String? empresaId) {
    if (empresaId == null) return null;
    final emp = _empresas.where((e) => e['id'] == empresaId).toList();
    return emp.isNotEmpty ? emp.first['nombre'] : null;
  }

  // ============== VENCIMIENTOS Y ALERTAS ==============

  Map<String, dynamic> _getVencimientoStatus(Map<String, dynamic> empresa) {
    final fechaVenc = empresa['fecha_vencimiento'];
    if (fechaVenc == null) {
      return {'status': 'unknown', 'days': 0, 'color': Colors.grey};
    }

    final vencDate = DateTime.parse(fechaVenc).toLocal();
    final now = DateTime.now();
    final diff = vencDate.difference(now).inDays;

    if (diff < 0) {
      return {'status': 'vencido', 'days': diff.abs(), 'color': Colors.red};
    } else if (diff <= 7) {
      return {'status': 'proximo', 'days': diff, 'color': Colors.orange};
    } else {
      return {'status': 'activo', 'days': diff, 'color': Colors.green};
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    final date = DateTime.parse(isoDate).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<Map<String, dynamic>> _getAlertas() {
    final alertas = <Map<String, dynamic>>[];
    for (final emp in _empresas) {
      final status = _getVencimientoStatus(emp);
      if (status['status'] == 'vencido' || status['status'] == 'proximo') {
        alertas.add({
          'tipo': status['status'] == 'vencido' ? 'vencimiento' : 'aviso',
          'empresa': emp['nombre'],
          'dias': status['days'],
          'color': status['color'],
        });
      }
    }
    return alertas;
  }

  // ============== ACCIONES ==============

  Future<void> _toggleUsuarioActivo(Map<String, dynamic> user) async {
    final bool nuevoEstado = !(user['isActive'] ?? false);
    try {
      await supabase
          .from('profiles')
          .update({'isActive': nuevoEstado})
          .eq('id', user['id']);
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleEmpresaActiva(Map<String, dynamic> emp) async {
    final bool nuevoEstado = !(emp['is_active'] ?? false);
    try {
      await supabase
          .from('empresas')
          .update({'is_active': nuevoEstado})
          .eq('id', emp['id']);
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cambiarRol(Map<String, dynamic> user) async {
    final roles = ['admin', 'super_admin', 'socio', 'cobrador', 'supervisor'];
    String? selected = user['rol'];

    await showDialog(
      context: context,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final _ = tp.isDarkMode;
        return AlertDialog(
          title: const Text('Cambiar Rol'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((r) {
              return RadioListTile<String>(
                title: Text(_getRolLabel(r)),
                value: r,
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) {
                    selected = val;
                    (ctx as Element).markNeedsBuild();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await supabase
                    .from('profiles')
                    .update({'rol': selected})
                    .eq('id', user['id']);
                _refreshData();
              },
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _aprobarUsuario(Map<String, dynamic> user) async {
    final formKey = GlobalKey<FormState>();
    final empresaCtrl = TextEditingController(
      text: 'Kapital - ${user['nombre']}',
    );
    final rutasMaxCtrl = TextEditingController(
      text: '5',
    ); // Rutas pagadas por defecto

    // Calcular fechas
    final now = DateTime.now().toUtc();
    final fechaPago = now.toIso8601String();
    final fechaVenc = now.add(const Duration(days: 30)).toIso8601String();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final isDark = tp.isDarkMode;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.how_to_reg),
              const SizedBox(width: 10),
              const Text('Aprobar Dueño'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del usuario
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _getAvatarColor(user['nombre']),
                        backgroundImage: user['foto'] != null
                            ? NetworkImage(user['foto'])
                            : null,
                        child: user['foto'] == null
                            ? Text(
                                _getInitials(user['nombre']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user['telefono'] ?? '',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: empresaCtrl,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Empresa',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    prefixIcon: Icon(
                      Icons.business,
                      color: AppColors.primary(isDark),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rutasMaxCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Rutas Máximas Pagadas',
                    labelStyle: TextStyle(color: AppColors.primary(isDark)),
                    prefixIcon: Icon(
                      Icons.route,
                      color: AppColors.primary(isDark),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obligatorio';
                    if (int.tryParse(v) == null || int.parse(v) < 1) {
                      return 'Mínimo 1';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Mostrar fechas calculadas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fechas de Membresía:',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pago: ${_formatDate(fechaPago)}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Vence: ${_formatDate(fechaVenc)}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.check_circle, color: Colors.black),
              label: const Text(
                'Aprobar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  // Crear empresa con rutas máximas y fechas
                  final empRes = await supabase
                      .from('empresas')
                      .insert({
                        'nombre': empresaCtrl.text.trim(),
                        'total_rutas_contratadas': int.parse(rutasMaxCtrl.text.trim()),
                        'is_active': true,
                        'fecha_pago': fechaPago,
                        'fecha_vencimiento': fechaVenc,
                      })
                      .select('id')
                      .single();
                  // Actualizar perfil
                  await supabase
                      .from('profiles')
                      .update({
                        'empresa_id': empRes['id'],
                        'rol': 'super_admin',
                        'isApproved': true,
                        'isActive': true,
                      })
                      .eq('id', user['id']);
                  _refreshData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Dueño aprobado y empresa creada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editarEmpresa(Map<String, dynamic> emp) async {
    final rutasCtrl = TextEditingController(
      text: '${emp['total_rutas_contratadas'] ?? 1}',
    );
    final notasCtrl = TextEditingController(text: emp['notas_master'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final isDark = tp.isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Editar: ${emp['nombre']}',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rutasCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Cupo de Rutas',
                  prefixIcon: Icon(
                    Icons.route,
                    color: AppColors.primary(isDark),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Notas del Master',
                  prefixIcon: Icon(
                    Icons.note,
                    color: AppColors.primary(isDark),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.payment, color: AppColors.primary(isDark)),
                  label: Text(
                    'Registrar Pago Hoy',
                    style: TextStyle(color: AppColors.primary(isDark)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary(isDark)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final now = DateTime.now().toUtc().toIso8601String();
                    final vencimiento = DateTime.now()
                        .add(const Duration(days: 30))
                        .toUtc()
                        .toIso8601String();
                    await supabase
                        .from('empresas')
                        .update({
                          'fecha_pago': now,
                          'fecha_vencimiento': vencimiento,
                          'total_rutas_contratadas':
                              int.tryParse(rutasCtrl.text) ??
                              emp['total_rutas_contratadas'],
                          'notas_master': notasCtrl.text.trim(),
                        })
                        .eq('id', emp['id']);
                    _refreshData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💳 Pago registrado. Vence en 30 días.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(isDark),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await supabase
                    .from('empresas')
                    .update({
                      'total_rutas_contratadas':
                          int.tryParse(rutasCtrl.text) ?? emp['total_rutas_contratadas'],
                      'notas_master': notasCtrl.text.trim(),
                    })
                    .eq('id', emp['id']);
                _refreshData();
              },
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      extendBody: true,
      drawer: const KapitalDrawer(),
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'MASTER',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        backgroundColor: isDark 
            ? const Color(0xFF1A1A1A).withOpacity(0.7) 
            : Colors.white.withOpacity(0.7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(text: 'Empresas'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendientes'),
                  if (_pendientes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendientes.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Usuarios'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              children: [
                // Padding para el extendBodyBehindAppBar
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 48),
                // Sección de alertas
                if (_getAlertas().isNotEmpty)
                  _buildAlertasSection(isDark, primary),
                // Tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmpresasTab(isDark, primary),
                      _buildPendientesTab(isDark, primary),
                      _buildUsuariosTab(isDark, primary),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAlertasSection(bool isDark, Color primary) {
    final alertas = _getAlertas();
    if (alertas.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Alertas de Vencimiento',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...alertas.map(
            (alerta) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: alerta['color'].withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    alerta['tipo'] == 'vencimiento'
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: alerta['color'],
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${alerta['empresa']}: ${alerta['tipo'] == 'vencimiento' ? 'Vencida hace ${alerta['dias']} días' : 'Vence en ${alerta['dias']} días'}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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

  // ============== TAB: EMPRESAS ==============

  Widget _buildEmpresasTab(bool isDark, Color primary) {
    if (_empresas.isEmpty) {
      return Center(
        child: Text(
          'No hay empresas registradas',
          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _empresas.length,
        itemBuilder: (context, index) {
          final emp = _empresas[index];
          final bool activa = emp['is_active'] ?? false;
          final String? fechaVenc = emp['fecha_vencimiento'];
          final ownerList = _todosUsuarios
              .where(
                (u) =>
                    u['empresa_id'] == emp['id'] && u['rol'] == 'super_admin',
              )
              .toList();
          final ownerName = ownerList.isNotEmpty
              ? ownerList.first['nombre']
              : 'Sin asignar';
          final status = _getVencimientoStatus(emp);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.business_rounded, color: primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emp['nombre'] ?? 'Sin Nombre',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Dueño: $ownerName',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: activa,
                                activeColor: primary,
                                activeTrackColor: primary.withOpacity(0.2),
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.withOpacity(0.2),
                                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                onChanged: (_) => _toggleEmpresaActiva(emp),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _chip(
                              activa ? 'Activa' : 'Inactiva',
                              activa ? Colors.green : Colors.redAccent,
                              isDark,
                            ),
                            _chip(
                              '${emp['total_rutas_contratadas'] ?? 0} Rutas',
                              primary,
                              isDark,
                            ),
                            if (fechaVenc != null) ...[
                              () {
                                final text = status['status'] == 'vencido'
                                    ? 'Vencida'
                                    : status['status'] == 'proximo'
                                    ? 'Vence en ${status['days']}d'
                                    : 'Al día';
                                return _chip(text, status['color'], isDark);
                              }(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                      border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                    ),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      icon: Icon(Icons.settings_suggest_rounded, size: 18, color: primary),
                      label: Text(
                        'Administrar suscripción',
                        style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _editarEmpresa(emp),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============== TAB: PENDIENTES ==============

  Widget _buildPendientesTab(bool isDark, Color primary) {
    if (_pendientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 60,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin solicitudes pendientes',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendientes.length,
        itemBuilder: (context, index) {
          final user = _pendientes[index];
          return _buildUserCard(user, isDark, primary, isPending: true);
        },
      ),
    );
  }

  // ============== TAB: USUARIOS ==============

  Widget _buildUsuariosTab(bool isDark, Color primary) {
    if (_todosUsuarios.isEmpty) {
      return Center(
        child: Text(
          'No hay usuarios',
          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }

    // Agrupar por rol
    final roleOrder = [
      'master',
      'super_admin',
      'admin',
      'socio',
      'supervisor',
      'cobrador',
    ];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var u in _todosUsuarios) {
      final rol = u['rol'] ?? 'cobrador';
      grouped.putIfAbsent(rol, () => []).add(u);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var rol in roleOrder)
            if (grouped.containsKey(rol)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getRolColor(rol).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRolLabel(rol),
                        style: TextStyle(
                          color: _getRolColor(rol),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${grouped[rol]!.length})',
                      style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ...grouped[rol]!.map((u) => _buildUserCard(u, isDark, primary)),
            ],
        ],
      ),
    );
  }

  // ============== WIDGETS REUTILIZABLES ==============

  Widget _buildUserCard(
    Map<String, dynamic> user,
    bool isDark,
    Color primary, {
    bool isPending = false,
  }) {
    final bool activo = user['isActive'] ?? false;
    final String rol = user['rol'] ?? '';
    final String? empresaNombre = _getEmpresaNombre(user['empresa_id']);

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
            radius: 26,
            backgroundColor: _getAvatarColor(user['nombre']).withOpacity(0.1),
            backgroundImage: user['foto'] != null
                ? NetworkImage(user['foto'])
                : null,
            child: user['foto'] == null
                ? Text(
                    _getInitials(user['nombre']),
                    style: TextStyle(
                      color: _getAvatarColor(user['nombre']),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
        ),
        title: Text(
          user['nombre'] ?? 'Sin nombre',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (empresaNombre != null)
              Row(
                children: [
                  Icon(Icons.business_rounded, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Text(
                    empresaNombre,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (!isPending)
                  _chip(
                    activo ? 'Activo' : 'Inactivo',
                    activo ? Colors.green : Colors.redAccent,
                    isDark,
                  ),
                _chip(_getRolLabel(rol), _getRolColor(rol), isDark),
              ],
            ),
          ],
        ),
        trailing: isPending
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(80, 40),
                ),
                child: const Text('Aprobar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _aprobarUsuario(user),
              )
            : PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isDark ? const Color(0xFF252525) : Colors.white,
                onSelected: (action) {
                  if (action == 'toggle') _toggleUsuarioActivo(user);
                  if (action == 'rol') _cambiarRol(user);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          activo ? Icons.block_flipped : Icons.check_circle_outline,
                          color: activo ? Colors.redAccent : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(activo ? 'Desactivar' : 'Activar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rol',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts_outlined, color: primary, size: 18),
                        const SizedBox(width: 10),
                        const Text('Cambiar Rol'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
