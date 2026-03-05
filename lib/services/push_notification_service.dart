import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    // 1. Solicitar permisos (fundamental en iOS y Web)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permisos de notificaciones concedidos.');
      // 2. Obtener el token único del dispositivo
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveTokenToSupabase(token);
      }

      // Escuchar si el token se refresca
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // 3. Configurar recepción de mensajes en Foreground (App abierta)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Mensaje recibido en primer plano: ${message.notification?.title}');
        // Aquí se podría mostrar un SnackBar local de aviso
      });
    } else {
      debugPrint('El usuario denegó los permisos de notificación.');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Guarda el token en el perfil del usuario logueado
        await supabase.from('profiles').update({'fcm_token': token}).eq('id', user.id);
        debugPrint('FCM Token guardado en Supabase exitosamente.');
      }
    } catch (e) {
      debugPrint('Error al guardar FCM Token: $e');
    }
  }
}
