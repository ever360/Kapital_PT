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
  List<Map<String, dynamic>> _invitacionesPendientes = [];
  int _usuariosActivos = 0;
  int _cupoTotal = 0;
  String? _empresaId;
  String _empresaNombre = 'Mi Empresa';

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

      final profile = await supabase
          .from('profiles')
          .select('empresa_id')
          .eq('id', user.id)
          .single();
      _empresaId = profile['empresa_id'];

      if (_empresaId != null) {
        // 1. Datos de la empresa — nombre y cupo de usuarios
        final empresa = await supabase
            .from('empresas')
            .select('nombre, max_usuarios, total_rutas_contratadas')
            .eq('id', _empresaId!)
            .single();
        _cupoTotal =
            empresa['max_usuarios'] ?? empresa['total_rutas_contratadas'] ?? 0;
        _empresaNombre = (empresa['nombre'] ?? 'Mi Empresa').toString();

        // 2. Lista de empleados activos/inactivos
        final empleadosRes = await supabase
            .from('profiles')
            .select()
            .eq('empresa_id', _empresaId!)
            .order('nombre');

        final allProfiles = List<Map<String, dynamic>>.from(empleadosRes);

        // 3. Invitaciones pendientes (correos invitados que aún no se registran)
        final invRes = await supabase
            .from('invitaciones')
            .select()
            .eq('empresa_id', _empresaId!)
            .eq('used', false)
            .order('created_at', ascending: false);

        setState(() {
          _empleados = allProfiles;
          _invitacionesPendientes = List<Map<String, dynamic>>.from(invRes);
          _usuariosActivos = allProfiles
              .where((u) => u['isActive'] == true)
              .length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleStatus(
    Map<String, dynamic> empleado,
    bool newValue,
  ) async {
    if (newValue && _usuariosActivos >= _cupoTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Sin cupos disponibles. Aumenta tu plan o desactiva otro usuario.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirmar si se está desactivando (despidiendo)
    if (!newValue) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar usuario'),
          content: Text(
            '¿Desactivar a ${empleado['nombre']}? '
            'No podrá ingresar a la app hasta que lo reactives.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    try {
      await supabase
          .from('profiles')
          .update({'isActive': newValue})
          .eq('id', empleado['id']);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Agrega personal de forma inteligente:
  /// - Si ya existe en profiles y no tiene empresa → lo vincula directamente.
  /// - Si no existe aún → crea una invitación para cuando se registre.
  Future<void> _addUser(String email, String role) async {
    setState(() => _isLoading = true);
    try {
      final emailLower = email.trim().toLowerCase();

      // 1. ¿Ya está registrado?
      final existing = await supabase
          .from('profiles')
          .select()
          .eq('email', emailLower)
          .maybeSingle();

      if (existing != null) {
        // Ya existe en la plataforma
        if (existing['empresa_id'] != null &&
            existing['empresa_id'] != _empresaId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este usuario ya pertenece a otra empresa.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else if (existing['empresa_id'] == _empresaId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este usuario ya es miembro de tu equipo.'),
              ),
            );
          }
        } else {
          // Sin empresa → vincular directamente
          await supabase
              .from('profiles')
              .update({
                'empresa_id': _empresaId,
                'rol': role,
                'isActive': false,
                'isApproved': true,
              })
              .eq('id', existing['id']);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ ${existing['nombre']} vinculado como $role. Actívalo cuando esté listo.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // No existe aún → crear invitación para cuando se registre
        final existingInvite = await supabase
            .from('invitaciones')
            .select('id')
            .eq('email', emailLower)
            .eq('empresa_id', _empresaId!)
            .eq('used', false)
            .maybeSingle();

        if (existingInvite != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ya existe una invitación pendiente para ese correo.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          final currentUser = supabase.auth.currentUser!;
          await supabase.from('invitaciones').insert({
            'email': emailLower,
            'rol': role,
            'empresa_id': _empresaId,
            'created_by': currentUser.id,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '📩 Invitación creada. Cuando $emailLower se registre, '
                  'quedará vinculado automáticamente como $role.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelarInvitacion(String invitacionId) async {
    try {
      await supabase.from('invitaciones').delete().eq('id', invitacionId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitación cancelada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
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
                  "Ingresa el correo. Si ya está registrado lo vinculamos ahora; si no, le enviamos una invitación automática.",
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    hintText: "ejemplo@correo.com",
                    prefixIcon: Icon(Icons.email_outlined, color: primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: isDark
                      ? const Color(0xFF252525)
                      : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "Rol del Personal",
                    prefixIcon: Icon(Icons.badge_outlined, color: primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cobrador',
                      child: Text("Cobrador"),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (emailController.text.isNotEmpty) {
                        Navigator.pop(context);
                        _addUser(emailController.text, selectedRole);
                      }
                    },
                    child: const Text(
                      "Agregar / Invitar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
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
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: const Text(
          "Panel Empresa • Gestión de Equipo",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _empresaNombre,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.7),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        elevation: 4,
        backgroundColor: primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          "Añadir Personal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                ),
                // Resumen de Cupos
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isAtLimit
                          ? dangerColor.withValues(alpha: 0.4)
                          : (_isNearLimit
                                ? warningColor.withValues(alpha: 0.4)
                                : primary.withValues(alpha: 0.1)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isAtLimit ? dangerColor : primary).withValues(
                          alpha: isDark ? 0.3 : 0.05,
                        ),
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
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "$_usuariosActivos",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: _isAtLimit
                                      ? dangerColor
                                      : (_isNearLimit
                                            ? warningColor
                                            : isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  letterSpacing: -1.5,
                                ),
                              ),
                              Text(
                                " / $_cupoTotal",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isAtLimit ? dangerColor : primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isAtLimit
                              ? Icons.warning_rounded
                              : Icons.group_rounded,
                          color: _isAtLimit ? dangerColor : primary,
                          size: 32,
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
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Invitaciones pendientes
                if (_invitacionesPendientes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "INVITACIONES PENDIENTES",
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${_invitacionesPendientes.length}",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_invitacionesPendientes.map((inv) {
                    final rol = inv['rol'] ?? 'cobrador';
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.amber.withValues(alpha: 0.05)
                            : Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv['email'] ?? '',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${rol.toUpperCase()} · Esperando registro',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Cancelar invitación',
                            onPressed: () =>
                                _cancelarInvitacion(inv['id'].toString()),
                          ),
                        ],
                      ),
                    );
                  })),
                  const SizedBox(height: 16),
                ],

                // Lista de Empleados
                Expanded(
                  child: _empleados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No hay empleados registrados.",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
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
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.3 : 0.03,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Text(
                                      emp['nombre']?[0].toUpperCase() ?? '?',
                                      style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  emp['nombre'] ?? 'Sin nombre',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (rol == 'socio'
                                                      ? Colors.blue
                                                      : Colors.purple)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          rol.toUpperCase(),
                                          style: TextStyle(
                                            color: rol == 'socio'
                                                ? Colors.blue
                                                : Colors.purple,
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
                                          color: isActive
                                              ? Colors.green
                                              : Colors.redAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Switch(
                                  value: isActive,
                                  activeThumbColor: primary,
                                  activeTrackColor: primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Colors.grey.withValues(
                                    alpha: 0.2,
                                  ),
                                  trackOutlineColor:
                                      WidgetStateProperty.resolveWith(
                                        (_) => Colors.transparent,
                                      ),
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
