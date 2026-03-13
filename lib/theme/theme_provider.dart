import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.system;

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
    await _storage.write(key: 'theme_mode', value: saveVal);
    // Actualizar el color de la barra en PWA (solo web)
    if (kIsWeb) {
      _updateWebThemeColor(isDarkMode);
    }
  }

  Future<void> toggleTheme() async {
    final mode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setTheme(mode);
  }

  void _updateWebThemeColor(bool isDark) {
    // This code only runs on web
    if (!kIsWeb) return;
    // Web theme color update intentionally simplified
    // Full implementation would require dart:js which breaks Android builds
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
