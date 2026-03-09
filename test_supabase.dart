// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://uvmlrxazutsocrfzueoc.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2bWxyeGF6dXRzb2NyZnp1ZW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDgzMDgsImV4cCI6MjA4NzI4NDMwOH0.vi59v3GKVnwpE7D1C8A0HEswLIJD0fqDXXZEfuNcXGA',
  );

  try {
    final response = await supabase.from('profiles').select();
    print('Perfiles encontrados: ${response.length}');
    for (var p in response) {
      print('ID: ${p['id']}, Rol: ${p['rol']}, Nombre: ${p['nombre']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
