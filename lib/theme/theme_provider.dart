import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'web_theme_utils_stub.dart'
    if (dart.library.js) 'web_theme_utils_web.dart';

class ThemeProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.system;

  // --- Estado para el Selector de Roles Master ---
  String _masterView = 'master'; // 'master' o 'super_admin'
  String? _targetEmpresaId;
  Map<String, dynamic>? _targetEmpresa;

  String get masterView => _masterView;
  String? get targetEmpresaId => _targetEmpresaId;
  Map<String, dynamic>? get targetEmpresa => _targetEmpresa;

  void setMasterView(String view, {String? empresaId, Map<String, dynamic>? empresa}) {
    _masterView = view;
    _targetEmpresaId = empresaId;
    _targetEmpresa = empresa;
    notifyListeners();
  }

  ThemeProvider() {
    init();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> init() async {
    final savedTheme = await _storage.read(key: 'theme_mode');
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    String saveVal = 'system';
    if (mode == ThemeMode.light) saveVal = 'light';
    if (mode == ThemeMode.dark) saveVal = 'dark';
    
    // Guardar en secure storage para la app
    await _storage.write(key: 'theme_mode', value: saveVal);

    // Actualizar el color de la barra en PWA (solo web)
    if (kIsWeb) {
      saveThemeToWebStorage(saveVal);
      updateWebPWATheme(isDarkMode);
    }
  }

  Future<void> toggleTheme() async {
    final mode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setTheme(mode);
  }

  // Helper para obtener el estilo del sistema consistente
  static SystemUiOverlayStyle getSystemUIOverlayStyle(bool isDark) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent, // Intentar quitar línea en algunos Android
    );
  }
}

// Singleton global
final themeProvider = ThemeProvider();

class AppColors {
  static const Color doradoKapital = Color(0xFFD4AF37);
  static const Color verdeSupabase = Color(0xFF3ECF8E);

  // Retorna el color de acento principal dependiendo del modo
  static Color primary(bool isDark) {
    return isDark ? verdeSupabase : doradoKapital;
  }
}
