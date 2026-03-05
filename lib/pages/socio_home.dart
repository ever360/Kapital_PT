import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocioHomePage extends StatelessWidget {
  const SocioHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Socio'),
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
        child: Text('Bienvenido Socio'),
      ),
    );
  }
}
