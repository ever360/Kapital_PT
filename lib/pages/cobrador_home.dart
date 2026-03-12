import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:kapital_app/widgets/kapital_drawer.dart';
import 'cobrador_clientes_page.dart'; // Crearemos esta pantalla luego

class CobradorHomePage extends StatefulWidget {
  const CobradorHomePage({super.key});

  @override
  State<CobradorHomePage> createState() => _CobradorHomePageState();
}

class _CobradorHomePageState extends State<CobradorHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _misRutas = [];
  double _totalCobradoHoy = 0.0;
  double _metaCobroHoy = 0.0;
  int _clientesPendientes = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener las Rutas que el socio me asignó
      final asignacionesRes = await supabase
          .from('cobrador_rutas')
          .select('rutas(id, nombre, is_active)')
          .eq('perfil_id', user.id);

      final rutasList = (asignacionesRes as List)
          .map((item) => item['rutas'] as Map<String, dynamic>)
          .where((r) => r['is_active'] == true) // Solo operativas
          .toList();

      if (rutasList.isNotEmpty) {
        final List<String> idsRutas = rutasList.map((r) => r['id'].toString()).toList();
        
        // 2. Calcular Clientes Totales Activos en mis rutas
        final clientesRes = await supabase
            .from('clientes')
            .select('id')
            .inFilter('ruta_id', idsRutas)
            .eq('is_active', true);
            
        // 3. Mapear Préstamos activos para calcular "Meta del Día" (Cuota Diaria de Préstamos Activos)
        final prestamosRes = await supabase
            .from('prestamos')
            .select('cuota_diaria')
            .inFilter('ruta_id', idsRutas)
            .eq('estado', 'ACTIVO');
            
        double metaCalculada = 0;
        for(var p in prestamosRes) {
          metaCalculada += (p['cuota_diaria'] ?? 0) as num;
        }

        // 4. Calcular "Cobrado Hoy"
        final tzToday = DateTime.now();
        final startOfDay = DateTime(tzToday.year, tzToday.month, tzToday.day).toIso8601String();
        
        final pagosHoyRes = await supabase
            .from('pagos')
            .select('monto')
            .inFilter('ruta_id', idsRutas)
            .eq('perfil_id', user.id) // Solo LO QUE YO HE COBRADO HOY
            .gte('fecha_pago', startOfDay);
            
        double cobradoHoyCalculado = 0;
        for(var p in pagosHoyRes) {
          cobradoHoyCalculado += (p['monto'] ?? 0) as num;
        }

        if (mounted) {
          setState(() {
            _misRutas = rutasList;
            _clientesPendientes = clientesRes.length; // Idealmente sería: Totales - Los que ya pagaron hoy.
            _metaCobroHoy = metaCalculada;
            _totalCobradoHoy = cobradoHoyCalculado;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _misRutas = [];
            _isLoading = false;
          });
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando operaciones: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Utilidad para formatear divisas simple
  String _formatDinero(double valor) {
    if (valor == 0) return "\$ 0";
    return "\$ ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      drawer: const KapitalDrawer(),
      appBar: AppBar(
        title: Text(
          'MI ASIGNACIÓN',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              color: primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // CONTENEDOR SUPERIOR - DASHBOARD DEL COBRADOR
                    // ==========================================
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                              ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                              : [primary.withValues(alpha: 0.9), primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: primary.withValues(alpha: isDark ? 0.1 : 0.3), blurRadius: 20, offset: const Offset(0, 8))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recaudo del Día",
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatDinero(_totalCobradoHoy),
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? primary : Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _KpiItem(
                                title: "Meta Cuotas", 
                                value: _formatDinero(_metaCobroHoy), 
                                isDark: isDark
                              ),
                              _KpiItem(
                                title: "Clientes Asignados", 
                                value: "$_clientesPendientes", 
                                isDark: isDark
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // ==========================================
                    // LISTADO DE RUTAS
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Text(
                        "Mis Rutas a Cubrir",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),

                    if (_misRutas.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(Icons.directions_walk, size: 60, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 15),
                              Text(
                                "No tienes rutas asignadas.\nHabla con tu Gerente (Socio).",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _misRutas.length,
                        itemBuilder: (context, index) {
                          final ruta = _misRutas[index];
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF232323) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isDark ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              boxShadow: isDark ? [] : [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // Navegar a la pantalla de clientes de la ruta
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (context) => CobradorClientesPage(rutaData: ruta))
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.maps_home_work, color: primary, size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ruta['nombre'] ?? 'Sin Nombre', 
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Toca para ver los clientes", 
                                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.black26),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String title;
  final String value;
  final bool isDark;

  const _KpiItem({required this.title, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
