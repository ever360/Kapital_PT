import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/pages/login_page.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

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
    // Temporalmente comentado para debug
    /*
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
    */
  }

  @override
  void dispose() {
    // _profilesChannel.unsubscribe();
    // _empresasChannel.unsubscribe();
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
                        'rutas_maximas': int.parse(rutasMaxCtrl.text.trim()),
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
      text: '${emp['rutas_maximas'] ?? 1}',
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
                          'rutas_maximas':
                              int.tryParse(rutasCtrl.text) ??
                              emp['rutas_maximas'],
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
                      'rutas_maximas':
                          int.tryParse(rutasCtrl.text) ?? emp['rutas_maximas'],
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
      appBar: AppBar(
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
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          tabs: [
            const Tab(icon: Icon(Icons.business), text: 'Empresas'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions),
                  const SizedBox(width: 4),
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.people), text: 'Usuarios'),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEmpresasTab(isDark, primary),
                _buildPendientesTab(isDark, primary),
                _buildUsuariosTab(isDark, primary),
              ],
            ),
    );
  }

  Widget _buildAlertasSection(bool isDark, Color primary) {
    final alertas = _getAlertas();
    if (alertas.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Alertas de Vencimiento',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alertas.map(
            (alerta) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alerta['color'].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: alerta['color'].withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    alerta['tipo'] == 'vencimiento'
                        ? Icons.error
                        : Icons.warning,
                    color: alerta['color'],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${alerta['empresa']}: ${alerta['tipo'] == 'vencimiento' ? 'Vencida hace ${alerta['dias']} días' : 'Vence en ${alerta['dias']} días'}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
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
        padding: const EdgeInsets.all(16),
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activa
                    ? primary.withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emp['nombre'] ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Switch(
                        value: activa,
                        activeThumbColor: primary,
                        onChanged: (_) => _toggleEmpresaActiva(emp),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Admin: $ownerName',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        activa ? '🟢 Activa' : '🔴 Inactiva',
                        activa ? Colors.green : Colors.redAccent,
                        isDark,
                      ),
                      _chip(
                        '📍 ${emp['rutas_maximas'] ?? 0} rutas',
                        primary,
                        isDark,
                      ),
                      if (fechaVenc != null) ...[
                        () {
                          final icon = status['status'] == 'vencido'
                              ? '🔴'
                              : status['status'] == 'proximo'
                              ? '🟠'
                              : '🟢';
                          final text = status['status'] == 'vencido'
                              ? 'Vencida'
                              : status['status'] == 'proximo'
                              ? 'Vence en ${status['days']}d'
                              : 'Activa';
                          return _chip('$icon $text', status['color'], isDark);
                        }(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(Icons.edit, size: 16, color: primary),
                      label: Text(
                        'Editar',
                        style: TextStyle(color: primary, fontSize: 13),
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
                        color: _getRolColor(rol).withValues(alpha: 0.15),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
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
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['nombre'] ?? 'Sin nombre',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (user['telefono'] != null)
                    Text(
                      '📞 ${user['telefono']}',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  if (empresaNombre != null)
                    Text(
                      '🏢 $empresaNombre',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (!isPending)
                        _chip(
                          activo ? '🟢 Activo' : '🔴 Inactivo',
                          activo ? Colors.green : Colors.redAccent,
                          isDark,
                        ),
                      _chip(_getRolLabel(rol), _getRolColor(rol), isDark),
                    ],
                  ),
                ],
              ),
            ),
            // Acciones
            if (isPending)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(
                  Icons.how_to_reg,
                  size: 18,
                  color: Colors.black,
                ),
                label: const Text(
                  'Aprobar',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _aprobarUsuario(user),
              )
            else
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
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
                          activo ? Icons.block : Icons.check_circle,
                          color: activo ? Colors.redAccent : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activo ? 'Desactivar' : 'Activar',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rol',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Cambiar Rol',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
