import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_screen.dart';
import 'pages/super_admin_home.dart';
import 'pages/master_page.dart'; // El panel global que creamos
import 'pages/socio_home.dart';
import 'pages/cobrador_home.dart';
import 'services/push_notification_service.dart';
import 'package:kapital_app/theme/theme_provider.dart'; // Controlador de Temas
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

// Futuro global para inicialización
Future<void>? _initFuture;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar pantalla completa (Edge-to-Edge)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  _initFuture = _initializeServices();
  runApp(const KapitalApp());
}

Future<void> _initializeServices() async {
  // 0. Inicializar Tema Visual
  await themeProvider.init();
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
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2bWxyeGF6dXRzb2NyZnp1ZW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDgzMDgsImV4cCI6MjA4NzI4NDMwOH0.vi59v3GKVnwpE7D1C8A0HEswLIJD0fqDXXZEfuNcXGA',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }
  // 2. Orientación y Estilo Full Screen
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
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
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: ListenableBuilder(
        listenable: themeProvider,
        builder: (context, _) {
          final bool isDark = themeProvider.isDarkMode;
          final Color primaryColor = AppColors.primary(isDark);

          // Actualizar el estilo del sistema en cada cambio de tema
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              // Mismo color que el fondo del Scaffold para que se vea continuo
              statusBarColor: isDark
                  ? const Color(0xFF0D0D0D)
                  : const Color(0xFFF5F5F5),
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: isDark
                  ? const Color(0xFF0D0D0D)
                  : const Color(0xFFF5F5F5),
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'Kapital',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            // ============== TEMA CLARO (DORADO) ==============
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: AppColors.doradoKapital,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.doradoKapital,
                brightness: Brightness.light,
                primary: AppColors.doradoKapital,
                surface: Colors.white,
                onPrimary: Colors.black,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFFF5F5F5),
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Color(0xFFF5F5F5),
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
              ),
              tabBarTheme: TabBarThemeData(
                indicatorColor: AppColors.doradoKapital,
                labelColor: AppColors.doradoKapital,
                unselectedLabelColor: Colors.black38,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.doradoKapital,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: AppColors.doradoKapital,
                foregroundColor: Colors.black,
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppColors.doradoKapital : Colors.grey),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppColors.doradoKapital.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: AppColors.doradoKapital,
              ),
              iconTheme: const IconThemeData(color: Colors.black54),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.black87),
                bodyLarge: TextStyle(color: Colors.black87),
              ),
            ),
            // ============== TEMA OSCURO (VERDE MENTA) ==============
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: AppColors.verdeSupabase,
              scaffoldBackgroundColor: const Color(0xFF0D0D0D),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.verdeSupabase,
                brightness: Brightness.dark,
                primary: AppColors.verdeSupabase,
                surface: const Color(0xFF1A1A1A),
                onPrimary: Colors.black,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFF0D0D0D),
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Color(0xFF0D0D0D),
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
              ),
              tabBarTheme: TabBarThemeData(
                indicatorColor: AppColors.verdeSupabase,
                labelColor: AppColors.verdeSupabase,
                unselectedLabelColor: Colors.white38,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeSupabase,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: AppColors.verdeSupabase,
                foregroundColor: Colors.black,
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppColors.verdeSupabase : Colors.grey),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? AppColors.verdeSupabase.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF1A1A1A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: AppColors.verdeSupabase,
              ),
              iconTheme: const IconThemeData(color: Colors.white54),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white),
                bodyLarge: TextStyle(color: Colors.white),
              ),
            ),
            home: FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    // El fondo ya lo toma automático del tema
                    body: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary(themeProvider.isDarkMode),
                      ),
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
              '/master_home': (context) => const MasterHomePage(),
              '/socio_home': (context) => const SocioHomePage(),
              '/cobrador_home': (context) => const CobradorHomePage(),
            },
          );
        },
      ),
    );
  }
}
