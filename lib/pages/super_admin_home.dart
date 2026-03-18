import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:kapital_app/widgets/kapital_drawer.dart';

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
  List<Map<String, dynamic>> _sucursales = [];
  int _rutasAsignadasTotales = 0;
  int _usuariosActivos = 0;
  int _totalAlcanzable = 0;

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

      final profile = await supabase.from('profiles').select().eq('id', user.id).single();
      _miEmpresaId = profile['empresa_id'];

      if (_miEmpresaId != null) {
        final empresaRes = await supabase.from('empresas').select().eq('id', _miEmpresaId!).single();
        final sucursalesRes = await supabase.from('sucursales').select().eq('empresa_id', _miEmpresaId!);
        
        // 3. Contar usuarios activos de la empresa
        final profilesRes = await supabase
            .from('profiles')
            .select('id')
            .eq('empresa_id', _miEmpresaId!)
            .eq('isActive', true);
        
        int rutasContadas = 0;
        for (var s in sucursalesRes) {
          rutasContadas += (s['rutas_permitidas'] as int? ?? 0);
        }

        if (mounted) {
          setState(() {
            _miEmpresa = empresaRes;
            _sucursales = List<Map<String, dynamic>>.from(sucursalesRes);
            _rutasAsignadasTotales = rutasContadas;
            _usuariosActivos = profilesRes.length;
            _totalAlcanzable = empresaRes['total_rutas_contratadas'] ?? 0;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearSucursal() async {
    if (_miEmpresa == null) return;
    final int maxGlobal = _miEmpresa!['total_rutas_contratadas'] ?? 1;
    final int disponibles = maxGlobal - _rutasAsignadasTotales;

    if (disponibles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes rutas disponibles para asignar a una nueva sucursal.")));
      return;
    }

    final nombreCtrl = TextEditingController();
    final rutasSedeCtrl = TextEditingController(text: "1");

    await showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          title: const Text("Nueva Sucursal / Socio"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Rutas disponibles: $disponibles", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 10),
              TextField(controller: nombreCtrl, decoration: _inputDeco("Nombre (ej: Sede Norte)")),
              const SizedBox(height: 10),
              TextField(controller: rutasSedeCtrl, keyboardType: TextInputType.number, decoration: _inputDeco("Rutas para esta sede")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(themeProvider.isDarkMode)),
              onPressed: () async {
                final int r = int.tryParse(rutasSedeCtrl.text) ?? 1;
                if (r > disponibles) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excedes tu cuota disponible")));
                  return;
                }
                Navigator.pop(context);
                await supabase.from('sucursales').insert({
                  'nombre': nombreCtrl.text.trim(),
                  'empresa_id': _miEmpresaId,
                  'rutas_permitidas': r,
                });
                _loadDashboardData();
              },
              child: const Text("Crear", style: TextStyle(color: Colors.black)),
            )
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    if (_isLoading) return Scaffold(backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5), body: Center(child: CircularProgressIndicator(color: AppColors.primary(isDark))));
    if (_miEmpresaId == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
        extendBodyBehindAppBar: true,
        extendBody: true,
        drawer: const KapitalDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black87,
        ),
        body: Stack(
          children: [
            // Elementos decorativos de fondo
            if (isDark) ...[
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary(true).withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary(true).withValues(alpha: 0.03),
                  ),
                ),
              ),
            ],
            
            // Contenido Central
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icono con efecto de elevación
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary(isDark).withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.business_center_rounded,
                          size: 64,
                          color: AppColors.primary(isDark),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Textos con tipografía mejorada
                      Text(
                        "¡Bienvenido a la Familia!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Tu cuenta ha sido aprobada con éxito. El siguiente paso es configurar tu empresa para empezar a gestionar tus rutas y equipo.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Botón de Acción Principal (Premium)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/crear_empresa'),
                          icon: const Icon(Icons.add_business_rounded, color: Colors.black, size: 24),
                          label: const Text(
                            "Configurar mi Empresa",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(isDark),
                            elevation: 8,
                            shadowColor: AppColors.primary(isDark).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Botón Secundario
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                        label: const Text(
                          "Cerrar Sesión",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      drawer: const KapitalDrawer(),
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          _miEmpresa?['nombre'] ?? 'DASHBOARD',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isDark 
            ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) 
            : Colors.white.withValues(alpha: 0.7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearSucursal,
        elevation: 4,
        backgroundColor: AppColors.primary(themeProvider.isDarkMode),
        label: const Text("Nueva Sucursal", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_business_rounded, color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary(isDark),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuotaCard(),
              const SizedBox(height: 16),
              _buildTeamCard(),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Mis Sucursales / Sedes",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_sucursales.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.store_outlined, size: 48, color: isDark ? Colors.white10 : Colors.black12),
                        const SizedBox(height: 10),
                        Text(
                          "No tienes sucursales creadas.",
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sucursales.length,
                  itemBuilder: (context, index) {
                    final s = _sucursales[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.store_rounded, color: Colors.amber, size: 24),
                        ),
                        title: Text(
                          s['nombre'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "Cupo: ${s['rutas_permitidas']} rutas",
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
                        onTap: () {
                          // Navegar a gestión de la sucursal (próximamente)
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaCard() {
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    final primary = AppColors.primary(isDark);
    final int maxGlobal = _miEmpresa?['total_rutas_contratadas'] ?? 0;
    final double progreso = maxGlobal > 0 ? _rutasAsignadasTotales / maxGlobal : 0;
    final bool isAtLimit = _rutasAsignadasTotales >= maxGlobal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: (isAtLimit ? Colors.orange : primary).withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Balance de Rutas",
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
                        "$_rutasAsignadasTotales",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        " / $maxGlobal",
                        style: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isAtLimit ? Colors.orange : primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  color: isAtLimit ? Colors.orange : primary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                height: 10,
                width: MediaQuery.of(context).size.width * 0.8 * progreso,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAtLimit
                        ? [Colors.orange, Colors.orangeAccent]
                        : [primary, primary.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: (isAtLimit ? Colors.orange : primary).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAtLimit 
              ? "⚠️ Has alcanzado el límite de rutas contratadas."
              : "Has distribuido el ${(progreso * 100).toInt()}% de tu cupo total.",
            style: TextStyle(
              color: isAtLimit ? Colors.orange : (isDark ? Colors.white38 : Colors.black38),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;
    final primary = AppColors.primary(isDark);
    final double progreso = _totalAlcanzable > 0 ? _usuariosActivos / _totalAlcanzable : 0;
    final bool isAtLimit = _usuariosActivos >= _totalAlcanzable && _totalAlcanzable > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.pushNamed(context, '/gestion_equipo');
            _loadDashboardData();
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MI EQUIPO",
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
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              " / $_totalAlcanzable",
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black26,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isAtLimit ? Colors.redAccent : primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isAtLimit ? Icons.warning_rounded : Icons.people_alt_rounded,
                        color: isAtLimit ? Colors.redAccent : primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      height: 8,
                      width: MediaQuery.of(context).size.width * 0.8 * progreso,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAtLimit
                              ? [Colors.redAccent, Colors.red]
                              : [primary, Colors.greenAccent],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAtLimit 
                        ? "⚠️ Cupo de personal agotado" 
                        : "Tienes ${_totalAlcanzable - _usuariosActivos} espacios disponibles",
                      style: TextStyle(
                        color: isAtLimit ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



