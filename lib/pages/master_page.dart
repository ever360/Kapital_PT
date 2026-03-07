import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/pages/login_page.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MasterHomePage extends StatefulWidget {
  const MasterHomePage({super.key});

  @override
  State<MasterHomePage> createState() => _MasterHomePageState();
}

class _MasterHomePageState extends State<MasterHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _usuariosPendientes = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _fetchEmpresas(),
      _fetchUsuariosPendientes(),
    ]);
  }

  Future<void> _fetchEmpresas() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase.from('empresas').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _empresas = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Error empresas: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsuariosPendientes() async {
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('rol', 'admin_pendiente')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _usuariosPendientes = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Error usuarios: $e');
    }
  }

  Future<void> _aprobarYCrearEmpresa(Map<String, dynamic> usuario) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController empresaNameCtrl = TextEditingController(text: "Kapital - ${usuario['nombre']}");
    final TextEditingController rutasCtrl = TextEditingController(text: "1");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Aprobar y Crear Empresa", style: TextStyle(color: Colors.white)),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Asignar recursos a: ${usuario['nombre']}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: empresaNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Nombre Comercial de la Empresa",
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: rutasCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Cupo de Rutas (Cuota)",
                    labelStyle: TextStyle(color: Colors.amber),
                    hintText: "Eje: 5",
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                    if (int.tryParse(v) == null) return 'Debe ser un número';
                    if (int.parse(v) < 1) return 'Mínimo 1 ruta';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(themeProvider.isDarkMode)),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                
                final String name = empresaNameCtrl.text.trim();
                final int totalRutas = int.parse(rutasCtrl.text.trim());
                
                Navigator.pop(context);
                setState(() => _isLoading = true);

                try {
                  // 1. Crear Empresa
                  final empRes = await supabase.from('empresas').insert({
                    'nombre': name,
                    'total_rutas_contratadas': totalRutas,
                    'is_active': true,
                  }).select('id').single();

                  final String empId = empRes['id'];

                  // 2. Actualizar Perfil (Aprobar y vincular)
                  await supabase.from('profiles').update({
                    'empresa_id': empId,
                    'rol': 'admin',
                    'isApproved': true,
                    'isActive': true,
                    'rutas_maximas': totalRutas, // Guardamos la cuota en el perfil también
                  }).eq('id', usuario['id']);

                  _refreshData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Acceso concedido y empresa configurada"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Confirmar Aprobación", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final Color primary = AppColors.primary(isDark);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text("MASTER - Dios Supremo", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1A1A1A),
          bottom: TabBar(
            indicatorColor: primary,
            labelColor: primary,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(icon: Icon(Icons.business), text: "Empresas"),
              Tab(icon: Icon(Icons.people_outline), text: "Pendientes"),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: TabBarView(
          children: [
            _buildEmpresasTab(),
            _buildUsuariosTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresasTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_empresas.isEmpty) return const Center(child: Text("No hay empresas", style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _empresas.length,
      itemBuilder: (context, index) {
        final emp = _empresas[index];
        final bool isActive = emp['is_active'] ?? false;
        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            title: Text(emp['nombre'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("Cuota: ${emp['total_rutas_contratadas']} rutas", style: const TextStyle(color: Colors.white54)),
            trailing: Switch(
              value: isActive,
              activeColor: AppColors.primary(themeProvider.isDarkMode),
              onChanged: (v) async {
                await supabase.from('empresas').update({'is_active': v}).eq('id', emp['id']);
                _fetchEmpresas();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsuariosTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_usuariosPendientes.isEmpty) return const Center(child: Text("Sin solicitudes pendientes", style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usuariosPendientes.length,
      itemBuilder: (context, index) {
        final user = _usuariosPendientes[index];
        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
            title: Text(user['nombre'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white)),
            subtitle: Text(user['telefono'] ?? 'Sin tel', style: const TextStyle(color: Colors.white54)),
            trailing: IconButton(
              icon: Icon(Icons.how_to_reg, color: AppColors.primary(themeProvider.isDarkMode)),
              onPressed: () => _aprobarYCrearEmpresa(user),
            ),
          ),
        );
      },
    );
  }
}


