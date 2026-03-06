import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/pages/login_page.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class MasterHomePage extends StatefulWidget {
  const MasterHomePage({super.key});

  @override
  State<MasterHomePage> createState() => _MasterHomePageState();
}

class _MasterHomePageState extends State<MasterHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _empresas = [];

  @override
  void initState() {
    super.initState();
    _fetchEmpresas();
  }

  Future<void> _fetchEmpresas() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase.from('empresas').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _empresas = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar empresas: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleEmpresaStatus(String id, bool currentStatus) async {
    try {
      await supabase.from('empresas').update({'is_active': !currentStatus}).eq('id', id);
      _fetchEmpresas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStatus ? "Empresa Activada" : "Empresa Desactivada"),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _editLimites(Map<String, dynamic> empresa) async {
    final TextEditingController rutasCtrl = TextEditingController(text: empresa['rutas_maximas'].toString());
    final TextEditingController sociosCtrl = TextEditingController(text: empresa['socios_maximos'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text("Límites: ${empresa['nombre']}", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rutasCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Máximo de Rutas",
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(themeProvider.isDarkMode))),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sociosCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Máximo de Socios (Ciudades)",
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(themeProvider.isDarkMode))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(themeProvider.isDarkMode),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final int nuevasRutas = int.tryParse(rutasCtrl.text) ?? 1;
                final int nuevosSocios = int.tryParse(sociosCtrl.text) ?? 1;
                Navigator.pop(context);
                try {
                  await supabase.from('empresas').update({
                    'rutas_maximas': nuevasRutas,
                    'socios_maximos': nuevosSocios,
                  }).eq('id', empresa['id']);
                  _fetchEmpresas();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Límites actualizados"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text("Guardar"),
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
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Panel Global - MASTER",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmpresas,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary(themeProvider.isDarkMode)))
          : _empresas.isEmpty
              ? const Center(
                  child: Text(
                    "No hay empresas registradas",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _empresas.length,
                  itemBuilder: (context, index) {
                    final empresa = _empresas[index];
                    final bool isActive = empresa['is_active'] ?? false;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    empresa['nombre'] ?? 'Sin Nombre',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeColor: AppColors.primary(themeProvider.isDarkMode),
                                  onChanged: (val) => _toggleEmpresaStatus(empresa['id'], isActive),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Email Contacto: ${empresa['email_contacto'] ?? 'N/A'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildBadge("Socios Máx: ${empresa['socios_maximos']}"),
                                const SizedBox(width: 8),
                                _buildBadge("Rutas Máx: ${empresa['rutas_maximas']}"),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.edit, color: AppColors.primary(themeProvider.isDarkMode)),
                                  onPressed: () => _editLimites(empresa),
                                  tooltip: "Editar Límites",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

