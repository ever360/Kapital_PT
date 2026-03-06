import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_screen.dart';
import 'pages/super_admin_home.dart';
import 'pages/socio_home.dart';
import 'pages/cobrador_home.dart';
import 'services/push_notification_service.dart';

// Futuro global para inicialización
Future<void>? _initFuture;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initFuture = _initializeServices();
  runApp(const KapitalApp());
}

Future<void> _initializeServices() async {
  // 1. Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAaxzlRP7giXc0WMYsrXYKDpakx-L2-JHI',
        appId: '1:903185337094:web:98058680bf7d8c6f98ec87',
        messagingSenderId: '903185337094',
        projectId: 'kapital-br',
        authDomain: 'kapital-br.firebaseapp.com',
        storageBucket: 'kapital-br.firebasestorage.app',
        measurementId: 'G-J4SN2H8BJG',
      ),
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // 2. Inicializar Supabase
  try {
    await Supabase.initialize(
      url: 'https://uvmlrxazutsocrfzueoc.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2bWxyeGF6dXRzb2NyZnp1ZW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDgzMDgsImV4cCI6MjA4NzI4NDMwOH0.vi59v3GKVnwpE7D1C8A0HEswLIJD0fqDXXZEfuNcXGA',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  // 3. Inicializar Notificaciones
  try {
    PushNotificationService.initialize();
  } catch (e) {
    debugPrint("Push init error: $e");
  }
}

class KapitalApp extends StatelessWidget {
  const KapitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
      ),
      home: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              ),
            );
          }
          return const SplashScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/super_admin_home': (context) => const SuperAdminHomePage(),
        '/socio_home': (context) => const SocioHomePage(),
        '/cobrador_home': (context) => const CobradorHomePage(),
      },
    );
  }
}
