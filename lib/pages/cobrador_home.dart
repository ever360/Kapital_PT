import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CobradorHomePage extends StatelessWidget {
  const CobradorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta de Cobro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Bienvenido Cobrador'),
      ),
    );
  }
}
