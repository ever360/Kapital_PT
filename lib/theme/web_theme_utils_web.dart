import 'dart:js' as js;

void updateWebPWATheme(bool isDark) {
  try {
    js.context.callMethod('updatePWATheme', [isDark]);
  } catch (e) {
    print('Error calling updatePWATheme: $e');
  }
}

void saveThemeToWebStorage(String theme) {
  try {
    js.context['localStorage'].callMethod('setItem', ['app_theme', theme]);
  } catch (e) {
    print('Error saving theme to localStorage: $e');
  }
}
