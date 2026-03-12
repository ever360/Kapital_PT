import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'cobrador_pagos_page.dart';

class CobradorClientesPage extends StatefulWidget {
  final Map<String, dynamic> rutaData;

  const CobradorClientesPage({super.key, required this.rutaData});

  @override
  State<CobradorClientesPage> createState() => _CobradorClientesPageState();
}

class _CobradorClientesPageState extends State<CobradorClientesPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientesAgrupados = [];
  double _totalDeudaRuta = 0;

  @override
  void initState() {
    super.initState();
    _loadClientesYPrestamos();
  }

  Future<void> _loadClientesYPrestamos() async {
    setState(() => _isLoading = true);
    try {
      final rutaId = widget.rutaData['id'];

      // 1. Traer todos los clientes activos de ESTA ruta
      final resClientes = await supabase.from('clientes').select().eq('ruta_id', rutaId).eq('is_active', true).order('nombre');

      // 2. Traer todos los prestamos activos de ESTA ruta
      final resPrestamos = await supabase.from('prestamos').select().eq('ruta_id', rutaId).eq('estado', 'ACTIVO');

      double deudaAcumulada = 0;
      final List<Map<String, dynamic>> finalData = [];

      for (var cliente in resClientes) {
        // Filtrar préstamos de este cliente localmente (más rápido que N queries)
        var prestamosDelCliente = resPrestamos.where((p) => p['cliente_id'] == cliente['id']).toList();
        
        double saldoTotalCliente = 0;
        for (var p in prestamosDelCliente) {
          saldoTotalCliente += (p['saldo_pendiente'] ?? 0) as num;
        }

        deudaAcumulada += saldoTotalCliente;

        finalData.add({
          'cliente': cliente,
          'prestamos': prestamosDelCliente,
          'deuda_total': saldoTotalCliente,
        });
      }

      if (mounted) {
        setState(() {
          _clientesAgrupados = finalData;
          _totalDeudaRuta = deudaAcumulada;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando cartera: $e')));
      }
    }
  }

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
      appBar: AppBar(
        title: Text(
          widget.rutaData['nombre']?.toUpperCase() ?? 'DETALLE DE RUTA',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Cartera Viva", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
                    Text(_formatDinero(_totalDeudaRuta), style: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Clientes", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
                    Text("${_clientesAgrupados.length}", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Lógica para crear cliente. Más adelante.
        },
        backgroundColor: primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
        label: const Text("Nuevo Cliente", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _loadClientesYPrestamos,
              color: primary,
              child: _clientesAgrupados.isEmpty
                  ? Center(
                      child: Text(
                        "No hay clientes en esta ruta",
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10).copyWith(bottom: 80),
                      itemCount: _clientesAgrupados.length,
                      itemBuilder: (context, index) {
                        final agru = _clientesAgrupados[index];
                        final cliente = agru['cliente'];
                        final prestamos = agru['prestamos'] as List;
                        final deuda = agru['deuda_total'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isDark ? 0 : 2,
                          color: isDark ? const Color(0xFF232323) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: primary,
                              collapsedIconColor: isDark ? Colors.white54 : Colors.black54,
                              title: Text(
                                cliente['nombre'],
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  text: "Deuda Total: ",
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: _formatDinero(deuda),
                                      style: TextStyle(color: deuda > 0 ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold),
                                    )
                                  ]
                                )
                              ),
                              children: [
                                const Divider(height: 1),
                                if (prestamos.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text("Sin créditos activos", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                                  )
                                else
                                  ...prestamos.map((p) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      title: Text("Crédito #${p['id'].toString().substring(0, 5)}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                                      subtitle: Text("Cuota: ${_formatDinero((p['cuota_diaria'] ?? 0) as double)} / día", style: TextStyle(color: primary)),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("Saldo", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10)),
                                          Text(_formatDinero((p['saldo_pendiente'] ?? 0) as double), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CobradorPagosPage(
                                              prestamo: p,
                                              nombreCliente: cliente['nombre'],
                                              rutaData: widget.rutaData,
                                            )
                                          )
                                        ).then((_) {
                                          _loadClientesYPrestamos(); // Refrescar al volver por si hizo pagos
                                        });
                                      },
                                    );
                                  }),
                                
                                // Botón para añadir préstamo rápido
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextButton.icon(
                                    onPressed: () {}, 
                                    icon: Icon(Icons.monetization_on, size: 16, color: primary), 
                                    label: Text("Adicionar Crédito", style: TextStyle(color: primary))
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
