import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapital_app/theme/theme_provider.dart';
import 'package:kapital_app/pages/socio_clientes_page.dart';

class SocioHomePage extends StatefulWidget {
  const SocioHomePage({super.key});

  @override
  State<SocioHomePage> createState() => _SocioHomePageState();
}

class _SocioHomePageState extends State<SocioHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _miSocioId;
  String? _miEmpresaId;
  Map<String, dynamic>? _miEmpresa;
  
  List<Map<String, dynamic>> _misRutas = [];
  int _rutasHermanasTotales = 0; // Rutas de toda la empresa

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
      _miSocioId = user.id;

      // 1. Obtener mi perfil y mi empresa_id
      final profile = await supabase.from('profiles').select().eq('id', _miSocioId!).single();
      _miEmpresaId = profile['empresa_id'];

      if (_miEmpresaId != null) {
        // 2. Obtener datos de la empresa para ver el límite de rutas
        final empresaRes = await supabase.from('empresas').select().eq('id', _miEmpresaId!).single();
        _miEmpresa = empresaRes;

        // 3. Contar TODAS las rutas de la empresa para saber si podemos crear más
        final todasRutas = await supabase.from('rutas').select('id').eq('empresa_id', _miEmpresaId!);
        _rutasHermanasTotales = todasRutas.length;

        // 4. Obtener las rutas que ME pertenecen a mí (como socio)
        final misRutasRes = await supabase
            .from('rutas')
            .select()
            .eq('socio_id', _miSocioId!)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _misRutas = List<Map<String, dynamic>>.from(misRutasRes);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos. $e')));
      }
    }
  }

  Future<void> _crearRuta() async {
    if (_miEmpresa == null || _miEmpresaId == null || _miSocioId == null) return;
    
    final int rutasMaximas = _miEmpresa!['rutas_maximas'] ?? 0;
    
    // Validar el límite GLOBAL de la empresa, no solo las del socio
    if (_rutasHermanasTotales >= rutasMaximas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Límite de Rutas alcanzado para tu empresa. Contacta a tu Administrador."),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    final nombreCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Crear Nueva Ruta', 
            style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Rutas Disponibles en Planta: ${rutasMaximas - _rutasHermanasTotales}", 
                style: TextStyle(color: AppColors.primary(themeProvider.isDarkMode), fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nombreCtrl,
                style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Nombre o Ciudad de la Ruta',
                  labelStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white54 : Colors.black54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.white24 : Colors.black26)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(themeProvider.isDarkMode))),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(themeProvider.isDarkMode),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final nombreRuta = nombreCtrl.text.trim();
                if (nombreRuta.isEmpty) return;
                
                Navigator.pop(context); // Cierra popup
                setState(() => _isLoading = true);
                
                try {
                  await supabase.from('rutas').insert({
                    'empresa_id': _miEmpresaId,
                    'socio_id': _miSocioId,
                    'nombre': nombreRuta,
                    'is_active': true,
                  });
                  _loadData();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta creada'), backgroundColor: Colors.green));
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Crear Ruta'),
            ),
          ],
        );
      }
    );
  }

  Future<void> _verOperariosDeLaRuta(Map<String, dynamic> ruta) async {
    // 1. Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.primary(themeProvider.isDarkMode)))
    );

    try {
      // 2. Obtener a quiénes hemos asignado a esta ruta específica
      final asignaciones = await supabase
          .from('cobrador_rutas')
          .select('perfil_id, profiles(nombre, rol)')
          .eq('ruta_id', ruta['id']);

      final operariosAsignados = List<Map<String, dynamic>>.from(asignaciones);

      // 3. Obtener el catálogo de trabajadores "Cobradores" o "Supervisores" de mi Empresa que estén activos
      final todosEmpleados = await supabase
          .from('profiles')
          .select('id, nombre, rol')
          .eq('empresa_id', _miEmpresaId!)
          .inFilter('rol', ['cobrador', 'supervisor'])
          .eq('isActive', true)
          .eq('isApproved', true);

      final catalogo = List<Map<String, dynamic>>.from(todosEmpleados);

      if (!mounted) return;
      Navigator.pop(context); // Quitar loader

      // 4. Mostrar panel de gestión
      _mostrarPanelGestionRuta(ruta, operariosAsignados, catalogo);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar operarios: $e')));
    }
  }

  void _mostrarPanelGestionRuta(Map<String, dynamic> ruta, List<Map<String, dynamic>> asignados, List<Map<String, dynamic>> catalogo) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = themeProvider.isDarkMode;
            
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text('Gestión: ${ruta['nombre']}', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asignados actualmente:', style: TextStyle(color: AppColors.primary(themeProvider.isDarkMode), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (asignados.isEmpty)
                      Text('Nadie ha sido asignado.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontStyle: FontStyle.italic)),
                     ...asignados.map((a) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person, color: Colors.blueGrey),
                          title: Text(a['profiles']['nombre'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text(a['profiles']['rol'].toString().toUpperCase(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                            onPressed: () async {
                              await supabase.from('cobrador_rutas').delete().match({'perfil_id': a['perfil_id'], 'ruta_id': ruta['id']});
                              setStateDialog(() => asignados.remove(a));
                            },
                          ),
                        );
                     }),
                     const Divider(),
                     Text('Añadir al equipo:', style: TextStyle(color: AppColors.primary(themeProvider.isDarkMode), fontWeight: FontWeight.bold)),
                     const SizedBox(height: 10),
                     if (catalogo.isEmpty)
                        Text('No hay cobradores activos en la empresa.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                     Expanded(
                       child: ListView.builder(
                         shrinkWrap: true,
                         itemCount: catalogo.length,
                         itemBuilder: (ctx, idx) {
                           final candidato = catalogo[idx];
                           // Verificar si ya está asignado visualmente
                           final yaAsignado = asignados.any((asig) => asig['perfil_id'] == candidato['id']);
                           
                           return ListTile(
                             contentPadding: EdgeInsets.zero,
                             title: Text(candidato['nombre'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                             subtitle: Text(candidato['rol'].toString().toUpperCase(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10)),
                             trailing: yaAsignado 
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary(themeProvider.isDarkMode), 
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      minimumSize: const Size(60, 30),
                                    ),
                                    onPressed: () async {
                                      try {
                                        await supabase.from('cobrador_rutas').insert({
                                          'perfil_id': candidato['id'],
                                          'ruta_id': ruta['id']
                                        });
                                        setStateDialog(() {
                                          asignados.add({
                                            'perfil_id': candidato['id'],
                                            'profiles': {
                                              'nombre': candidato['nombre'],
                                              'rol': candidato['rol']
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    },
                                    child: const Text('Añadir', style: TextStyle(fontSize: 12)),
                                  )
                           );
                         },
                       ),
                     )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar Planilla', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Oficina - SOCIO', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut, tooltip: "Cerrar sesión"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearRuta,
        backgroundColor: AppColors.primary(themeProvider.isDarkMode),
        icon: const Icon(Icons.add_location_alt, color: Colors.black),
        label: const Text("Nueva Ruta", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.primary(themeProvider.isDarkMode)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary(themeProvider.isDarkMode),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_miEmpresa != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Tus Rutas", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text(
                                  "${_misRutas.length}",
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Límite Global", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text(
                                  "$_rutasHermanasTotales / ${_miEmpresa!['rutas_maximas'] ?? 0}",
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Rutas Asignadas a Mí",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),

                    if (_misRutas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text("Aún no tienes rutas. ¡Crea una para empezar!")),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _misRutas.length,
                        itemBuilder: (context, index) {
                          final ruta = _misRutas[index];
                          final bool activa = ruta['is_active'] ?? false;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: isDark ? 0 : 1,
                            color: isDark ? const Color(0xFF232323) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: activa ? AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1),
                                child: Icon(Icons.map, color: activa ? AppColors.primary(themeProvider.isDarkMode) : Colors.redAccent),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SocioClientesPage(ruta: ruta),
                                  ),
                                );
                              },
                              title: Text(ruta['nombre'] ?? 'Sin Nombre', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              subtitle: Text(activa ? 'Operativa' : 'Suspendida', style: TextStyle(color: activa ? Colors.green : Colors.redAccent, fontSize: 12)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary(themeProvider.isDarkMode).withValues(alpha: 0.1),
                                  foregroundColor: AppColors.primary(themeProvider.isDarkMode),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.group_add, size: 18),
                                label: const Text("Equipo"),
                                onPressed: () => _verOperariosDeLaRuta(ruta),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 80), // Padding FAB
                  ],
                ),
              ),
            ),
    );
  }
}

