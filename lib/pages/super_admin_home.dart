import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';

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
        
        int rutasContadas = 0;
        for (var s in sucursalesRes) {
          rutasContadas += (s['rutas_permitidas'] as int? ?? 0);
        }

        if (mounted) {
          setState(() {
            _miEmpresa = empresaRes;
            _sucursales = List<Map<String, dynamic>>.from(sucursalesRes);
            _rutasAsignadasTotales = rutasContadas;
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Nueva Sucursal / Socio", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Rutas disponibles: $disponibles", style: const TextStyle(color: Colors.amber)),
            const SizedBox(height: 10),
            TextField(controller: nombreCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco("Nombre (ej: Sede Norte)")),
            const SizedBox(height: 10),
            TextField(controller: rutasSedeCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco("Rutas para esta sede")),
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
      ),
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
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator()));
    if (_miEmpresaId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("Esperando aprobación del Master", style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              const Text("Tu cuenta está registrada pero no tiene empresa asignada.", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _signOut, child: const Text("Cerrar Sesión")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_miEmpresa?['nombre'] ?? 'Dashboard', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadDashboardData),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _signOut),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearSucursal,
        backgroundColor: AppColors.primary(themeProvider.isDarkMode),
        label: const Text("Nueva Sucursal", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_business, color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuotaCard(),
            const SizedBox(height: 25),
            const Text("Mis Sucursales / Sedes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (_sucursales.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No tienes sucursales creadas.", style: TextStyle(color: Colors.white54))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sucursales.length,
                itemBuilder: (context, index) {
                  final s = _sucursales[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.store, color: Colors.amber),
                      title: Text(s['nombre'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("Rutas Permitidas: ${s['rutas_permitidas']}", style: const TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
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
    );
  }

  Widget _buildQuotaCard() {
    final int maxGlobal = _miEmpresa?['total_rutas_contratadas'] ?? 0;
    final double progreso = maxGlobal > 0 ? _rutasAsignadasTotales / maxGlobal : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Cuota de Rutas", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text("$_rutasAsignadasTotales / $maxGlobal", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: progreso,
            backgroundColor: Colors.white10,
            color: Colors.amber,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
          Text(
            "Has distribuido el ${(progreso * 100).toInt()}% de tus rutas contratadas.",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

}

class _InfoStat extends StatelessWidget {
  final String title;
  final String value;

  const _InfoStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

