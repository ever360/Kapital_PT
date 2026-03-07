import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';

class CobradorPagosPage extends StatefulWidget {
  final Map<String, dynamic> prestamo;
  final String nombreCliente;
  final Map<String, dynamic> rutaData;

  const CobradorPagosPage({
    super.key, 
    required this.prestamo, 
    required this.nombreCliente,
    required this.rutaData
  });

  @override
  State<CobradorPagosPage> createState() => _CobradorPagosPageState();
}

class _CobradorPagosPageState extends State<CobradorPagosPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pagosList = [];
  double _saldoPendienteActual = 0;

  @override
  void initState() {
    super.initState();
    _saldoPendienteActual = (widget.prestamo['saldo_pendiente'] ?? 0) as double;
    _loadHistorialPagos();
  }

  Future<void> _loadHistorialPagos() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('pagos')
          .select('*, perfiles:perfil_id(nombre, rol)')
          .eq('prestamo_id', widget.prestamo['id'])
          .order('fecha_pago', ascending: false);

      if (mounted) {
        setState(() {
          _pagosList = List<Map<String, dynamic>>.from(res);
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

  Future<void> _registrarPago() async {
    final montoCtrl = TextEditingController();
    String metodoSeleccionado = 'EFECTIVO';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = themeProvider.isDarkMode;
            final primary = AppColors.primary(isDark);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text("Registrar Pago", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cliente: ${widget.nombreCliente}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  Text("Saldo Deudor: ${_formatDinero(_saldoPendienteActual)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Monto Recibido',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.bold),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primary)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: metodoSeleccionado,
                    dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo 💵')),
                      DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia 🏦')),
                    ],
                    onChanged: (val) => setStateDialog(() => metodoSeleccionado = val!),
                    decoration: InputDecoration(
                      labelText: 'Método',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.black),
                  onPressed: () async {
                    final montoRaw = double.tryParse(montoCtrl.text.trim()) ?? 0;
                    if (montoRaw <= 0) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido')));
                       return;
                    }

                    if (montoRaw > _saldoPendienteActual) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El abono es mayor a la deuda!')));
                       return;
                    }

                    Navigator.pop(context); // Cierra popup
                    setState(() => _isLoading = true);

                    try {
                      final userId = supabase.auth.currentUser!.id;
                      final double nuevoSaldo = _saldoPendienteActual - montoRaw;
                      final String nuevoEstado = nuevoSaldo <= 0 ? 'PAGADO' : 'ACTIVO';

                      // 1. Insertar PAGO
                      await supabase.from('pagos').insert({
                        'ruta_id': widget.rutaData['id'],
                        'prestamo_id': widget.prestamo['id'],
                        'perfil_id': userId,
                        'monto': montoRaw,
                        'metodo_pago': metodoSeleccionado,
                      });

                      // 2. Actualizar SALDO del PRÉSTAMO
                      await supabase.from('prestamos').update({
                        'saldo_pendiente': nuevoSaldo,
                        'estado': nuevoEstado
                      }).eq('id', widget.prestamo['id']);

                      _saldoPendienteActual = nuevoSaldo;
                      _loadHistorialPagos();
                      
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago Registrado Exitosamente'), backgroundColor: Colors.green));

                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
                    }
                  },
                  child: const Text('Guardar Cobro'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  String _formatDinero(double valor) {
    if (valor == 0) return "\$ 0";
    return "\$ ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }
  
  String _formatFecha(String isoDate) {
    final d = DateTime.parse(isoDate).toLocal();
    return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;
    final primary = AppColors.primary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text("Cobro a ${widget.nombreCliente}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      floatingActionButton: _saldoPendienteActual > 0
          ? FloatingActionButton.extended(
              onPressed: _registrarPago,
              backgroundColor: primary,
              icon: const Icon(Icons.request_quote, color: Colors.black),
              label: const Text("Registrar Abono", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              children: [
                // Info del Préstamo
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _saldoPendienteActual > 0 ? primary.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Column(
                    children: [
                      const Text("SALDO PENDIENTE", style: TextStyle(color: Colors.grey, fontSize: 13, letterSpacing: 1.2)),
                      const SizedBox(height: 5),
                      Text(
                        _formatDinero(_saldoPendienteActual),
                        style: TextStyle(
                          fontSize: 40, 
                          fontWeight: FontWeight.bold, 
                          color: _saldoPendienteActual > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.green
                        ),
                      ),
                      if (_saldoPendienteActual <= 0)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Text("PRESTAMO PAGADO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Historial de Abonos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),

                // Lista de Pagos
                Expanded(
                  child: _pagosList.isEmpty
                      ? const Center(child: Text("No se han registrado pagos aún", style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80),
                          itemCount: _pagosList.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = _pagosList[index];
                            final monto = (p['monto'] ?? 0) as double;
                            final fecha = _formatFecha(p['fecha_pago'] ?? p['created_at']);
                            final quienCobro = p['perfiles'] != null ? p['perfiles']['nombre'] : 'Desconocido';
                            final esTransferencia = p['metodo_pago'] == 'TRANSFERENCIA';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esTransferencia ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                child: Icon(esTransferencia ? Icons.account_balance : Icons.payments, size: 18, color: esTransferencia ? Colors.deepPurple : Colors.green),
                              ),
                              title: Text(_formatDinero(monto), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: RichText(
                                text: TextSpan(
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                                  children: [
                                    TextSpan(text: "$fecha\n"),
                                    TextSpan(text: "Cobrado por: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: quienCobro),
                                  ]
                                )
                              ),
                              isThreeLine: true,
                            );
                          },
                        )
                )
              ],
            ),
    );
  }
}
