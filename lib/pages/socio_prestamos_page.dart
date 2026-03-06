import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class SocioPrestamosPage extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final Map<String, dynamic> ruta;

  const SocioPrestamosPage({super.key, required this.cliente, required this.ruta});

  @override
  State<SocioPrestamosPage> createState() => _SocioPrestamosPageState();
}

class _SocioPrestamosPageState extends State<SocioPrestamosPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _prestamos = [];
  bool _tienePrestamoActivo = false;

  @override
  void initState() {
    super.initState();
    _loadPrestamos();
  }

  Future<void> _loadPrestamos() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('prestamos')
          .select()
          .eq('cliente_id', widget.cliente['id'])
          .order('created_at', ascending: false);
      
      bool hayActivo = false;
      for (var p in res) {
        if (p['estado'] == 'ACTIVO') hayActivo = true;
      }

      if (mounted) {
        setState(() {
          _prestamos = List<Map<String, dynamic>>.from(res);
          _tienePrestamoActivo = hayActivo;
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

  String _formatDinero(double valor) {
    if (valor == 0) return "\$ 0";
    return "\$ ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _crearPrestamo() async {
    if (_tienePrestamoActivo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El cliente ya tiene un préstamo activo.'), backgroundColor: Colors.orange));
      return;
    }

    final montoCtrl = TextEditingController();
    final interesCtrl = TextEditingController(text: "20");
    final plazoCtrl = TextEditingController(text: "30");

    double montoTotal = 0;
    double cuotaDiaria = 0;

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = themeProvider.isDarkMode;
        final primary = AppColors.primary(isDark);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void calcular() {
              final m = double.tryParse(montoCtrl.text) ?? 0;
              final i = double.tryParse(interesCtrl.text) ?? 0;
              final p = int.tryParse(plazoCtrl.text) ?? 1;
              
              if (m > 0 && p > 0) {
                montoTotal = m + (m * (i / 100));
                cuotaDiaria = montoTotal / p;
              } else {
                montoTotal = 0;
                cuotaDiaria = 0;
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text("Nuevo Préstamo", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: montoCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      onChanged: (_) => setStateDialog(calcular),
                      decoration: InputDecoration(
                        labelText: "Monto a Prestar *",
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: primary, fontWeight: FontWeight.bold)
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: interesCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            onChanged: (_) => setStateDialog(calcular),
                            decoration: InputDecoration(
                              labelText: "Interés (%)",
                              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: plazoCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            onChanged: (_) => setStateDialog(calcular),
                            decoration: InputDecoration(
                              labelText: "Plazo (Días)",
                              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        children: [
                          Text("Total a Pagar", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                          Text(_formatDinero(montoTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.orange)),
                          const Divider(),
                          Text("Cuota Diaria", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                          Text(_formatDinero(cuotaDiaria), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primary)),
                        ],
                      ),
                    )
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
                    if (montoTotal <= 0) return;
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    
                    try {
                      final m = double.tryParse(montoCtrl.text) ?? 0;
                      final i = double.tryParse(interesCtrl.text) ?? 0;
                      final p = int.tryParse(plazoCtrl.text) ?? 1;

                      await supabase.from('prestamos').insert({
                        'ruta_id': widget.ruta['id'],
                        'cliente_id': widget.cliente['id'],
                        'monto_prestado': m,
                        'tasa_interes': i,
                        'monto_total_a_pagar': montoTotal,
                        'saldo_pendiente': montoTotal,
                        'cuota_diaria': cuotaDiaria,
                        'dias_plazo': p,
                        'estado': 'ACTIVO',
                        'fecha_inicio': DateTime.now().toIso8601String().split('T')[0],
                        'fecha_vencimiento': DateTime.now().add(Duration(days: p)).toIso8601String().split('T')[0]
                      });
                      
                      _loadPrestamos();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Préstamo creado con éxito'), backgroundColor: Colors.green));
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Confirmar Préstamo"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text("Préstamos de ${widget.cliente['alias'] ?? widget.cliente['nombre']}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      floatingActionButton: _tienePrestamoActivo == false
          ? FloatingActionButton.extended(
              onPressed: _crearPrestamo,
              backgroundColor: primary,
              icon: const Icon(Icons.account_balance_wallet, color: Colors.black),
              label: const Text("Nuevo Préstamo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _prestamos.isEmpty
              ? const Center(child: Text("Sin historial de préstamos.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prestamos.length,
                  itemBuilder: (context, index) {
                    final p = _prestamos[index];
                    final esActivo = p['estado'] == 'ACTIVO';
                    final saldo = (p['saldo_pendiente'] ?? 0) as double;
                    
                    return Card(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: esActivo ? primary.withValues(alpha: 0.5) : Colors.transparent, width: 2)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDinero((p['monto_prestado'] ?? 0) as double),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black87),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: esActivo ? primary.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Text(
                                    p['estado'] ?? '',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: esActivo ? primary : Colors.green),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Cuota Diaria", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(_formatDinero((p['cuota_diaria'] ?? 0) as double), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("Saldo Pendiente", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(_formatDinero(saldo), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Text("Otorgado: ${p['fecha_inicio']} • Vence: ${p['fecha_vencimiento']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
