import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kapital_app/pages/super_admin_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/widgets/kapital_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String _formatMiles(dynamic value) {
    final num n = value is String ? (num.tryParse(value) ?? 0) : (value ?? 0);
    return n
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
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

    // Obtener historial de pagos de suscripción de la empresa
    List<Map<String, dynamic>> pagos = [];
    try {
      final resp = await supabase
          .from('pagos_empresa')
          .select('*')
          .eq('empresa_id', emp['id'])
          .order('created_at', ascending: false)
          .limit(50);
      pagos = List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      debugPrint('Error cargando pagos empresa: $e');
    }

    // Obtener fecha de creación
    final fechaCreacion = emp['fecha_pago'] ?? emp['created_at'] ?? 'N/A';

    if (!mounted) return;

    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;
    final primary = AppColors.primary(isDark);

    final vencStatus = _getVencimientoStatus(emp);
    final totalPagado = pagos.fold<double>(
      0,
      (sum, p) =>
          sum +
          ((p['monto'] ?? 0) is int
              ? (p['monto'] as int).toDouble()
              : (p['monto'] ?? 0.0) as double),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header futurista con gradiente
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withValues(alpha: 0.15),
                      primary.withValues(alpha: 0.05),
                      isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            color: primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp['nombre'] ?? 'Sin nombre',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: (emp['is_active'] ?? false)
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              ((emp['is_active'] ?? false)
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent)
                                                  .withValues(alpha: 0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (emp['is_active'] ?? false)
                                        ? 'Activa'
                                        : 'Inactiva',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${emp['total_rutas_contratadas'] ?? 0} rutas',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Mini stats row
                    Row(
                      children: [
                        _buildMiniStat(
                          'Dueño',
                          ownerName,
                          Icons.person_rounded,
                          isDark,
                          primary,
                        ),
                        const SizedBox(width: 8),
                        _buildMiniStat(
                          'Vence',
                          emp['fecha_vencimiento'] != null
                              ? _formatDate(emp['fecha_vencimiento'])
                              : 'N/A',
                          Icons.timer_outlined,
                          isDark,
                          vencStatus['color'] as Color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Info cards row
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            Icons.email_outlined,
                            ownerEmail,
                            isDark,
                            primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            Icons.calendar_today_outlined,
                            'Creada: ${_formatDate(fechaCreacion)}',
                            isDark,
                            primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoChip(
                            Icons.payments_outlined,
                            'Total: \$${totalPagado.toStringAsFixed(0)}',
                            isDark,
                            Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Historial de Pagos header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Historial de Pagos',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pagos.length}',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pagos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sin pagos registrados',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...pagos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pago = entry.value;
                        final montoRaw = (pago['monto'] ?? 0);
                        final monto = montoRaw is int
                            ? montoRaw.toDouble()
                            : (montoRaw as double);
                        final isLatest = idx == 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isLatest
                                  ? [
                                      primary.withValues(alpha: 0.08),
                                      isDark
                                          ? const Color(0xFF1A1A2E)
                                          : Colors.white,
                                    ]
                                  : [
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.03)
                                          : Colors.white,
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.01)
                                          : const Color(0xFFF8F9FA),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLatest
                                  ? primary.withValues(alpha: 0.3)
                                  : isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            boxShadow: isLatest
                                ? [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Icono con glow
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isLatest
                                            ? primary.withValues(alpha: 0.15)
                                            : isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.paid_rounded,
                                        color: isLatest
                                            ? primary
                                            : isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Monto y fecha
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '\$ ${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDate(
                                              pago['fecha_pago'] ??
                                                  pago['created_at'] ??
                                                  'N/A',
                                            ),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rutas badge
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.location_on_rounded,
                                                size: 11,
                                                color: primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${pago['rutas_contratadas'] ?? 0}',
                                                style: TextStyle(
                                                  color: primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (pago['fecha_vencimiento'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Vence ${_formatDate(pago['fecha_vencimiento'])}',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white30
                                                    : Colors.black26,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (pago['notas'] != null &&
                                    (pago['notas'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.03)
                                          : Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      pago['notas'],
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black45,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
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

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    bool isDark,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
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
          content: Text('No hay solicitudes pendientes '),
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
    final rutasMaxCtrl = TextEditingController(text: '0');
    final montoCtrl = TextEditingController(); // Valor por ruta
    double _totalPagar = 0;

    void _recalcularTotal(void Function(void Function()) setDialogState) {
      final rutas = int.tryParse(rutasMaxCtrl.text.trim()) ?? 0;
      final valorRaw = montoCtrl.text.replaceAll('.', '').replaceAll(',', '');
      final valor = double.tryParse(valorRaw) ?? 0;
      setDialogState(() {
        _totalPagar = rutas * valor;
      });
    }

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
                child: SingleChildScrollView(
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
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                          labelText: 'Rutas contratadas',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on_rounded,
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
                        onChanged: (_) => _recalcularTotal(setDialogState),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Obligatorio';
                          if (int.tryParse(v) == null || int.parse(v) < 1) {
                            return 'Mínimo 1';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ThousandSeparatorFormatter()],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor por ruta',
                          hintText: '0',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: AppColors.primary(isDark),
                          ),
                          prefixText: '\$ ',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => _recalcularTotal(setDialogState),
                        validator: (v) {
                          final raw =
                              v?.replaceAll('.', '').replaceAll(',', '') ?? '';
                          final n = double.tryParse(raw) ?? 0;
                          if (n <= 0) return 'Ingresa un valor mayor a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Total a pagar (calculado)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary(
                            isDark,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary(
                              isDark,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total a pagar',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '\$ ${_formatMiles(_totalPagar)}',
                              style: TextStyle(
                                color: AppColors.primary(isDark),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
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
                      final rutasContratadas = int.parse(
                        rutasMaxCtrl.text.trim(),
                      );
                      final valorRaw = montoCtrl.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim();
                      final valorRuta = double.tryParse(valorRaw) ?? 0;
                      final montoVal = valorRuta * rutasContratadas;
                      final empRes = await supabase
                          .from('empresas')
                          .insert({
                            'nombre': empresaCtrl.text.trim(),
                            'total_rutas_contratadas': rutasContratadas,
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
                      // Registrar pago inicial de la empresa
                      await supabase.from('pagos_empresa').insert({
                        'empresa_id': empRes['id'],
                        'monto': montoVal,
                        'rutas_contratadas': rutasContratadas,
                        'fecha_pago': fechaPagoSel.toUtc().toIso8601String(),
                        'fecha_vencimiento': fechaVencSel
                            .toUtc()
                            .toIso8601String(),
                        'notas': 'Pago inicial - Empresa creada',
                        'registrado_por': supabase.auth.currentUser?.id,
                      });
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
                      // Ofrecer enviar comprobante por WhatsApp
                      _ofrecerWhatsApp(
                        telefono: user['telefono'],
                        empresa: empresaCtrl.text.trim(),
                        monto: montoVal,
                        rutas: rutasContratadas,
                        fechaPago: fechaPagoSel,
                        fechaVenc: fechaVencSel,
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
    final montoEditCtrl = TextEditingController(text: '0');
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
              content: SingleChildScrollView(
                child: Column(
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
                          Icons.location_on_rounded,
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
                    TextFormField(
                      controller: montoEditCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ThousandSeparatorFormatter()],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor a Pagar',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        prefixIcon: Icon(
                          Icons.attach_money,
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
                    final rutasNuevas =
                        int.tryParse(rutasCtrl.text) ??
                        emp['total_rutas_contratadas'];
                    await supabase
                        .from('empresas')
                        .update({
                          'fecha_pago': fechaPagoSel.toUtc().toIso8601String(),
                          'fecha_vencimiento': fechaVencSel
                              .toUtc()
                              .toIso8601String(),
                          'total_rutas_contratadas': rutasNuevas,
                          'notas_master': notasCtrl.text.trim(),
                        })
                        .eq('id', emp['id']);
                    // Registrar pago en historial
                    final montoVal =
                        double.tryParse(montoEditCtrl.text.trim()) ?? 0;
                    if (montoVal > 0) {
                      await supabase.from('pagos_empresa').insert({
                        'empresa_id': emp['id'],
                        'monto': montoVal,
                        'rutas_contratadas': rutasNuevas,
                        'fecha_pago': fechaPagoSel.toUtc().toIso8601String(),
                        'fecha_vencimiento': fechaVencSel
                            .toUtc()
                            .toIso8601String(),
                        'notas': notasCtrl.text.trim(),
                        'registrado_por': supabase.auth.currentUser?.id,
                      });
                    }
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

  // ============== WHATSAPP COMPROBANTE ==============

  Future<void> _ofrecerWhatsApp({
    required String? telefono,
    required String empresa,
    required double monto,
    required int rutas,
    required DateTime fechaPago,
    required DateTime fechaVenc,
  }) async {
    if (!mounted) return;
    final enviar = await showDialog<bool>(
      context: this.context,
      builder: (ctx) {
        final isDark = Provider.of<ThemeProvider>(ctx).isDarkMode;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.send_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              const Text('Enviar Comprobante'),
            ],
          ),
          content: Text(
            '¿Enviar comprobante de pago por WhatsApp a $empresa?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text(
                'Enviar WhatsApp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    if (enviar != true) return;

    final tel = (telefono ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (tel.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('El usuario no tiene teléfono registrado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final fechaPagoStr = _formatDate(fechaPago.toIso8601String());
    final fechaVencStr = _formatDate(fechaVenc.toIso8601String());
    final montoStr = _formatMiles(monto);

    final mensaje = Uri.encodeComponent(
      '✅ *COMPROBANTE DE PAGO - KAPITAL*\n\n'
      '🏢 Empresa: *$empresa*\n'
      '💰 Monto pagado: *\$$montoStr*\n'
      '🗓️ Fecha de pago: *$fechaPagoStr*\n'
      '📅 Vence: *$fechaVencStr*\n'
      '📍 Rutas contratadas: *$rutas*\n\n'
      '¡Gracias por tu pago! Tu cuenta está activa.',
    );

    final url = Uri.parse('https://wa.me/$tel?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ============== REGISTRAR PAGO EMPRESA ==============

  Future<void> _registrarPagoEmpresa(Map<String, dynamic> emp) async {
    final montoCtrl = TextEditingController();
    final rutasCtrl = TextEditingController(
      text: '${emp['total_rutas_contratadas'] ?? 1}',
    );
    final notasCtrl = TextEditingController();
    DateTime fechaPagoSel = DateTime.now();
    DateTime fechaVencSel = emp['fecha_vencimiento'] != null
        ? (DateTime.tryParse(emp['fecha_vencimiento'])?.toLocal() ??
                  DateTime.now())
              .add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 30));

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx);
        final isDark = tp.isDarkMode;
        final primary = AppColors.primary(isDark);
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
              title: Row(
                children: [
                  Icon(Icons.payments_rounded, color: primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pago: ${emp['nombre']}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ThousandSeparatorFormatter()],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor a pagar ',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(Icons.attach_money, color: primary),
                          prefixText: '\$ ',
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
                          final raw =
                              v?.replaceAll('.', '').replaceAll(',', '') ?? '';
                          final n = double.tryParse(raw) ?? 0;
                          if (n <= 0) return 'Ingresa un monto mayor a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rutasCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Rutas Contratadas',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on_rounded,
                            color: primary,
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
                          if (v == null || v.trim().isEmpty)
                            return 'Obligatorio';
                          if (int.tryParse(v) == null || int.parse(v) < 1)
                            return 'Mínimo 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notasCtrl,
                        maxLines: 2,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Notas (opcional)',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(Icons.note_outlined, color: primary),
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
                              icon: Icon(Icons.event_available, color: primary),
                              label: Text(
                                'Pago: ${_formatDate(fechaPagoSel.toIso8601String())}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
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
                              icon: Icon(Icons.event_busy, color: primary),
                              label: Text(
                                'Vence: ${_formatDate(fechaVencSel.toIso8601String())}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
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
                    'Registrar Pago',
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
                      final montoRaw = montoCtrl.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim();
                      final montoVal = double.tryParse(montoRaw) ?? 0;
                      final rutasNuevas =
                          int.tryParse(rutasCtrl.text.trim()) ??
                          emp['total_rutas_contratadas'];

                      // Actualizar empresa
                      await supabase
                          .from('empresas')
                          .update({
                            'fecha_pago': fechaPagoSel
                                .toUtc()
                                .toIso8601String(),
                            'fecha_vencimiento': fechaVencSel
                                .toUtc()
                                .toIso8601String(),
                            'total_rutas_contratadas': rutasNuevas,
                          })
                          .eq('id', emp['id']);

                      // Registrar pago
                      await supabase.from('pagos_empresa').insert({
                        'empresa_id': emp['id'],
                        'monto': montoVal,
                        'rutas_contratadas': rutasNuevas,
                        'fecha_pago': fechaPagoSel.toUtc().toIso8601String(),
                        'fecha_vencimiento': fechaVencSel
                            .toUtc()
                            .toIso8601String(),
                        'notas': notasCtrl.text.trim(),
                        'registrado_por': supabase.auth.currentUser?.id,
                      });

                      _refreshData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Pago de \$${_formatMiles(montoVal)} registrado',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Buscar teléfono del dueño de la empresa
                      final owner = _todosUsuarios.firstWhere(
                        (p) =>
                            p['empresa_id'] == emp['id'] &&
                            (p['rol'] == 'super_admin' || p['rol'] == 'admin'),
                        orElse: () => <String, dynamic>{},
                      );
                      _ofrecerWhatsApp(
                        telefono: owner['telefono'],
                        empresa: emp['nombre'] ?? '',
                        monto: montoVal,
                        rutas: rutasNuevas,
                        fechaPago: fechaPagoSel,
                        fechaVenc: fechaVencSel,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
              OutlinedButton.icon(
                onPressed: () => _editarEmpresa(emp),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar plan'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showEmpresaDetalles(emp),
                icon: const Icon(Icons.info_outline),
                label: const Text('Detalles'),
              ),
              OutlinedButton.icon(
                onPressed: () => _registrarPagoEmpresa(emp),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Registrar Pago'),
              ),
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
          ? const Color(0xFF050816)
          : const Color(0xFFF9F6ED),
      extendBodyBehindAppBar: true,
      extendBody: true,
      drawer: const KapitalDrawer(),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark
              ? const Color(0xFF050816)
              : const Color(0xFFF9F6ED),
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
            ? const Color(0xFF050816)
            : const Color(0xFFF9F6ED),
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

// ============== THOUSAND SEPARATOR FORMATTER ==============

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('.', '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (int.tryParse(text) == null) return oldValue;

    final formatted = _format(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String s) {
    final buf = StringBuffer();
    final len = s.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
