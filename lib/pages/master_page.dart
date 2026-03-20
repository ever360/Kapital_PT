import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kapital_app/pages/super_admin_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _MasterHomePageState extends State<MasterHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _todosUsuarios = [];
  List<Map<String, dynamic>> _pendientes = [];
  late final RealtimeChannel _profilesChannel;
  late final RealtimeChannel _empresasChannel;

  @override
  void initState() {
    super.initState();
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

    final parts = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '??';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }

    final one = parts.first;
    if (one.length == 1) return one.toUpperCase();
    return one.substring(0, 2).toUpperCase();
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

  int _daysUntilVencimiento(Map<String, dynamic> empresa) {
    final fechaVenc = empresa['fecha_vencimiento'];
    if (fechaVenc == null) return 99999;
    final vencDate = DateTime.parse(fechaVenc).toLocal();
    return vencDate.difference(DateTime.now()).inDays;
  }

  List<Map<String, dynamic>> _empresasOrdenadasPorVencimiento() {
    final empresas = List<Map<String, dynamic>>.from(_empresas);
    empresas.sort(
      (a, b) => _daysUntilVencimiento(a).compareTo(_daysUntilVencimiento(b)),
    );
    return empresas;
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

  // ============== NOTIFICACIONES Y DETALLES ==============

  Future<void> _showEmpresaDetalles(Map<String, dynamic> emp) async {
    // Obtener owner (super_admin)
    final ownerList = _todosUsuarios
        .where((u) => u['empresa_id'] == emp['id'] && u['rol'] == 'super_admin')
        .toList();
    final ownerEmail = ownerList.isNotEmpty ? ownerList.first['email'] : 'N/A';
    final ownerName = ownerList.isNotEmpty ? ownerList.first['nombre'] : 'N/A';

    // Obtener historial de pagos de esta empresa
    List<Map<String, dynamic>> pagos = [];
    try {
      final resp = await supabase
          .from('pagos')
          .select('*, prestamos!inner(id)')
          .order('created_at', ascending: false)
          .limit(50);
      // Filtrar solo pagos relacionados a prestamos de esta empresa
      pagos = List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      debugPrint('Error cargando pagos: $e');
    }

    // Obtener fecha de creación
    final fechaCreacion = emp['fecha_pago'] ?? emp['created_at'] ?? 'N/A';

    if (!mounted) return;

    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;
    final primary = AppColors.primary(isDark);

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business_rounded, color: primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp['nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Detalles de Empresa',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info General
                    _buildDetailSection('Información General', isDark, primary),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Dueño',
                      ownerName,
                      Icons.person_outline,
                      isDark,
                    ),
                    _buildDetailRow(
                      'Email Dueño',
                      ownerEmail,
                      Icons.email_outlined,
                      isDark,
                    ),
                    _buildDetailRow(
                      'Fecha Creación',
                      _formatDate(fechaCreacion),
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                    _buildDetailRow(
                      'Rutas Contratadas',
                      '${emp['total_rutas_contratadas'] ?? 0}',
                      Icons.route_outlined,
                      isDark,
                    ),
                    _buildDetailRow(
                      'Estado',
                      (emp['is_active'] ?? false) ? 'Activa' : 'Inactiva',
                      Icons.verified_outlined,
                      isDark,
                      valueColor: (emp['is_active'] ?? false)
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                    const SizedBox(height: 24),
                    // Historial de Pagos
                    _buildDetailSection('Historial de Pagos', isDark, primary),
                    if (pagos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Text(
                            'Sin pagos registrados',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...pagos.map(
                        (pago) => Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Monto: \$ ${(pago['monto'] ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (Match m) => '${m[1]}.')}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Método: ${pago['metodo_pago'] ?? 'N/A'}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatDate(
                                          pago['fecha_pago'] ??
                                              pago['created_at'] ??
                                              'N/A',
                                        ),
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rutas: ${(pago['rutas_contratadas'] ?? 0)}',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, bool isDark, Color primary) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color:
                        valueColor ?? (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Future<void> _showPendientesQuickApprove() async {
    if (_pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay solicitudes pendientes v1'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Solicitudes Pendientes (${_pendientes.length})',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _pendientes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = _pendientes[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _getAvatarColor(
                                user['nombre'],
                              ).withValues(alpha: 0.1),
                              backgroundImage: user['foto'] != null
                                  ? NetworkImage(user['foto'])
                                  : null,
                              child: user['foto'] == null
                                  ? Text(
                                      _getInitials(user['nombre']),
                                      style: TextStyle(
                                        color: _getAvatarColor(user['nombre']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['nombre'] ?? 'Sin nombre',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user['email'] ?? 'Sin email',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _aprobarUsuario(user);
                                },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Aprobar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  // Opcional: implementar rechazar
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Función no implementada'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.block),
                                label: const Text('Rechazar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

    DateTime fechaPagoSel = DateTime.now();
    DateTime fechaVencSel = fechaPagoSel.add(const Duration(days: 30));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final isDark = tp.isDarkMode;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate(bool isPago) async {
              final initial = isPago ? fechaPagoSel : fechaVencSel;
              final selected = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected == null) return;
              setDialogState(() {
                if (isPago) {
                  fechaPagoSel = selected;
                  if (fechaVencSel.isBefore(fechaPagoSel)) {
                    fechaVencSel = fechaPagoSel.add(const Duration(days: 30));
                  }
                } else {
                  fechaVencSel = selected;
                }
              });
            }

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
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatorio'
                          : null,
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
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
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
                            'Fechas de Membresía',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickDate(true),
                                  icon: const Icon(Icons.event_available),
                                  label: Text(
                                    'Pago: ${_formatDate(fechaPagoSel.toIso8601String())}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickDate(false),
                                  icon: const Icon(Icons.event_busy),
                                  label: Text(
                                    'Vence: ${_formatDate(fechaVencSel.toIso8601String())}',
                                  ),
                                ),
                              ),
                            ],
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
                      final empRes = await supabase
                          .from('empresas')
                          .insert({
                            'nombre': empresaCtrl.text.trim(),
                            'total_rutas_contratadas': int.parse(
                              rutasMaxCtrl.text.trim(),
                            ),
                            'is_active': true,
                            'fecha_pago': fechaPagoSel
                                .toUtc()
                                .toIso8601String(),
                            'fecha_vencimiento': fechaVencSel
                                .toUtc()
                                .toIso8601String(),
                          })
                          .select('id')
                          .single();
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
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Dueño aprobado y empresa creada'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
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
      },
    );
  }

  Future<void> _editarEmpresa(Map<String, dynamic> emp) async {
    final rutasCtrl = TextEditingController(
      text: '${emp['total_rutas_contratadas'] ?? 1}',
    );
    final notasCtrl = TextEditingController(text: emp['notas_master'] ?? '');
    DateTime fechaPagoSel = emp['fecha_pago'] != null
        ? DateTime.tryParse(emp['fecha_pago'])?.toLocal() ?? DateTime.now()
        : DateTime.now();
    DateTime fechaVencSel = emp['fecha_vencimiento'] != null
        ? DateTime.tryParse(emp['fecha_vencimiento'])?.toLocal() ??
              fechaPagoSel.add(const Duration(days: 30))
        : fechaPagoSel.add(const Duration(days: 30));

    await showDialog(
      context: context,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final isDark = tp.isDarkMode;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate(bool isPago) async {
              final initial = isPago ? fechaPagoSel : fechaVencSel;
              final selected = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected == null) return;
              setDialogState(() {
                if (isPago) {
                  fechaPagoSel = selected;
                  if (fechaVencSel.isBefore(fechaPagoSel)) {
                    fechaVencSel = fechaPagoSel.add(const Duration(days: 30));
                  }
                } else {
                  fechaVencSel = selected;
                }
              });
            }

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
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cupo de Rutas',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
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
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Notas del Master',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(true),
                          icon: Icon(
                            Icons.event_available,
                            color: AppColors.primary(isDark),
                          ),
                          label: Text(
                            'Pago: ${_formatDate(fechaPagoSel.toIso8601String())}',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(false),
                          icon: Icon(
                            Icons.event_busy,
                            color: AppColors.primary(isDark),
                          ),
                          label: Text(
                            'Vence: ${_formatDate(fechaVencSel.toIso8601String())}',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                          'fecha_pago': fechaPagoSel.toUtc().toIso8601String(),
                          'fecha_vencimiento': fechaVencSel
                              .toUtc()
                              .toIso8601String(),
                          'total_rutas_contratadas':
                              int.tryParse(rutasCtrl.text) ??
                              emp['total_rutas_contratadas'],
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
      },
    );
  }

  String _currentPageTitle(ThemeProvider tp) {
    if (tp.masterView == 'super_admin') {
      final empresa = tp.targetEmpresa?['nombre'] ?? 'Mi Empresa';
      return 'Panel Empresa • $empresa';
    }
    return 'Panel Master';
  }

  Widget _buildGlobalStats() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.primary(isDark);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF181C20), primary.withValues(alpha: 0.08)]
              : [Colors.white, primary.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Resumen Maestro',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Visibilidad global de empresas, usuarios activos y solicitudes por resolver.',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildStatItem(
                "Empresas",
                "${_empresas.length}",
                Icons.business_rounded,
                primary,
                isDark,
              ),
              _buildStatItem(
                "Usuarios",
                "${_todosUsuarios.length}",
                Icons.people_rounded,
                Colors.blue,
                isDark,
              ),
              _buildStatItem(
                "Pendientes",
                "${_pendientes.length}",
                Icons.pending_actions_rounded,
                Colors.orange,
                isDark,
                onTap: _showPendientesQuickApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tocar para gestionar',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresasSliver(bool isDark, Color primary) {
    final empresasOrdenadas = _empresasOrdenadasPorVencimiento();
    if (empresasOrdenadas.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Text("No hay empresas")),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final emp = empresasOrdenadas[index];
          return _buildEmpresaCard(emp, isDark, primary);
        }, childCount: empresasOrdenadas.length),
      ),
    );
  }

  Widget _buildEmpresaCard(
    Map<String, dynamic> emp,
    bool isDark,
    Color primary,
  ) {
    final bool activa = emp['is_active'] ?? false;
    final ownerList = _todosUsuarios
        .where((u) => u['empresa_id'] == emp['id'] && u['rol'] == 'super_admin')
        .toList();
    final ownerName = ownerList.isNotEmpty
        ? ownerList.first['nombre']
        : 'Sin asignar';
    final status = _getVencimientoStatus(emp);
    final statusColor = status['color'] as Color? ?? Colors.grey;
    final statusLabel = switch (status['status']) {
      'vencido' => 'Vencida hace ${status['days']} d',
      'proximo' => 'Vence en ${status['days']} d',
      'activo' => 'Vence en ${status['days']} d',
      _ => 'Sin fecha',
    };
    final int rutasContratadas = emp['total_rutas_contratadas'] ?? 0;
    final String fechaVenc = _formatDate(emp['fecha_vencimiento']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.business_rounded, color: primary),
        ),
        title: Text(
          emp['nombre'] ?? 'Sin Nombre',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dueño: $ownerName',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    activa ? 'Activa' : 'Inactiva',
                    activa ? Colors.green : Colors.redAccent,
                    isDark,
                  ),
                  _chip(statusLabel, statusColor, isDark),
                ],
              ),
            ],
          ),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Rutas contratadas: $rutasContratadas', primary, isDark),
              _chip('Vence: $fechaVenc', statusColor, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _toggleEmpresaActiva(emp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activa ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: Icon(
                  activa
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(activa ? 'Poner Inactiva' : 'Poner Activa'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _editarEmpresa(emp),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar plan'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showEmpresaDetalles(emp),
                icon: const Icon(Icons.info_outline),
                label: const Text('Detalles'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).setMasterView(
                    'super_admin',
                    empresaId: emp['id'],
                    empresa: emp,
                  );
                },
                child: const Text('Entrar'),
              ),
            ],
          ),
        ],
      ),
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
        title: Text(
          _currentPageTitle(tp),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.7),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: isDark ? 'Modo Claro' : 'Modo Oscuro',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => tp.toggleTheme(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color:
                            (isDark
                                    ? AppColors.verdeSupabase
                                    : AppColors.doradoKapital)
                                .withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppColors.verdeSupabase
                                      : AppColors.doradoKapital)
                                  .withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 21,
                      color: isDark
                          ? AppColors.verdeSupabase
                          : AppColors.doradoKapital,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              children: [
                // Padding para el extendBodyBehindAppBar
                SizedBox(
                  height:
                      MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                ),

                Expanded(
                  child:
                      tp.masterView == 'super_admin' &&
                          tp.targetEmpresaId != null
                      ? SuperAdminHomePage(
                          key: ValueKey(tp.targetEmpresaId),
                          empresaIdOverride: tp.targetEmpresaId,
                          isSubView: true,
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  if (_getAlertas().isNotEmpty)
                                    _buildAlertasSection(isDark, primary),
                                  _buildGlobalStats(),
                                ],
                              ),
                            ),
                            _buildSectionHeader(
                              "EMPRESAS REGISTRADAS",
                              isDark,
                              primary,
                            ),
                            _buildEmpresasSliver(isDark, primary),

                            if (_pendientes.isNotEmpty) ...[
                              _buildSectionHeader(
                                "SOLICITUDES PENDIENTES",
                                isDark,
                                Colors.orange,
                              ),
                              _buildPendientesSliver(isDark, primary),
                            ],

                            const SliverToBoxAdapter(
                              child: SizedBox(height: 80),
                            ),
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
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: isDark ? 0.05 : 0.02),
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
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
                color: alerta['color'].withValues(alpha: 0.05),
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

  Widget _buildSectionHeader(String title, bool isDark, Color color) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 32, bottom: 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendientesSliver(bool isDark, Color primary) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildUserCard(
            _pendientes[index],
            isDark,
            primary,
            isPending: true,
          ),
          childCount: _pendientes.length,
        ),
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
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
            border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: _getAvatarColor(
              user['nombre'],
            ).withValues(alpha: 0.1),
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
                  Icon(
                    Icons.business_rounded,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(80, 40),
                ),
                child: const Text(
                  'Aprobar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _aprobarUsuario(user),
              )
            : PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                          activo
                              ? Icons.block_flipped
                              : Icons.check_circle_outline,
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
                        Icon(
                          Icons.manage_accounts_outlined,
                          color: primary,
                          size: 18,
                        ),
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
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
