import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void updateWebPWATheme(bool isDark) {
  try {
    final metaTag =
        web.document.querySelector('meta[name="theme-color"]')
            as web.HTMLMetaElement?;
    if (metaTag != null) {
      metaTag.content = isDark ? '#0D0D0D' : '#F5F5F5';
    }
  } catch (e) {
    debugPrint('Error updating PWA theme: $e');
  }
}

void saveThemeToWebStorage(String theme) {
  try {
    web.window.localStorage.setItem('app_theme', theme);
  } catch (e) {
    debugPrint('Error saving theme to localStorage: $e');
  }
}
