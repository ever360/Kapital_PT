import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:kapital_app/pages/socio_prestamos_page.dart';

class SocioClientesPage extends StatefulWidget {
  final Map<String, dynamic> ruta;

  const SocioClientesPage({super.key, required this.ruta});

  @override
  State<SocioClientesPage> createState() => _SocioClientesPageState();
}

class _SocioClientesPageState extends State<SocioClientesPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientes = [];

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('clientes')
          .select('*, prestamos(*)')
          .eq('ruta_id', widget.ruta['id'])
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _clientes = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _crearCliente() async {
    final nombreCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final dirCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = themeProvider.isDarkMode;
        final primary = AppColors.primary(isDark);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text("Nuevo Cliente", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Nombre completo *",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
                TextField(
                  controller: aliasCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Alias o Apodo",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Teléfono",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
                TextField(
                  controller: dirCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Dirección",
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.black),
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await supabase.from('clientes').insert({
                    'nombre': nombreCtrl.text.trim(),
                    'alias': aliasCtrl.text.trim(),
                    'telefono': telCtrl.text.trim(),
                    'direccion': dirCtrl.text.trim(),
                    'ruta_id': widget.ruta['id'],
                  });
                  _loadClientes();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente guardado'), backgroundColor: Colors.green));
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "CLIENTES - ${widget.ruta['nombre']}",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearCliente,
        backgroundColor: primary,
        icon: const Icon(Icons.person_add, color: Colors.black),
        label: const Text("Nuevo Cliente", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _clientes.isEmpty
              ? const Center(child: Text("No hay clientes en esta ruta.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clientes.length,
                  itemBuilder: (context, index) {
                    final cliente = _clientes[index];
                    return Card(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primary.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: primary),
                        ),
                        title: Text(cliente['nombre'] ?? 'Sin Nombre', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text(cliente['telefono'] ?? 'Sin Teléfono', style: const TextStyle(color: Colors.grey)),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary.withValues(alpha: 0.1),
                            foregroundColor: primary,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.monetization_on, size: 18),
                          label: const Text("Préstamos"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SocioPrestamosPage(cliente: cliente, ruta: widget.ruta),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
