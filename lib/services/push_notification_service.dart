import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'kapital_push_channel',
        'Notificaciones Kapital',
        description: 'Canal de alertas de solicitudes pendientes',
        importance: Importance.high,
      );
  static final supabase = Supabase.instance.client;
  static bool _initialized = false;
  static bool _localNotificationsReady = false;
  static String? _lastKnownUserId;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Solicitar permisos (fundamental en iOS y Web)
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permisos de notificaciones concedidos.');
        await _initializeLocalNotifications();

        // En iOS permite mostrar notificacion visual aun con la app abierta.
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // 2. Obtener y sincronizar token del dispositivo
        await syncTokenForCurrentUser();

        // Escuchar si el token se refresca
        _firebaseMessaging.onTokenRefresh.listen((token) async {
          debugPrint('FCM Token refrescado.');
          await _saveTokenToSupabase(token);
        });

        // Reintentar sincronizacion cuando cambie la sesion de Supabase
        supabase.auth.onAuthStateChange.listen((data) async {
          if (data.event == AuthChangeEvent.signedIn) {
            await syncTokenForCurrentUser();
          }
          if (data.event == AuthChangeEvent.signedOut) {
            final userId = _lastKnownUserId;
            if (userId != null) {
              await _clearTokenInSupabase(userId);
              _lastKnownUserId = null;
            }
          }
        });

        // 3. Configurar recepción de mensajes en Foreground (App abierta)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          debugPrint(
            'Mensaje recibido en primer plano: ${message.notification?.title}',
          );
          await _showForegroundNotification(message);
        });

        _initialized = true;
      } else {
        debugPrint('El usuario denegó los permisos de notificación.');
      }
    } catch (e) {
      debugPrint("Error al inicializar notificaciones: $e");
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (kIsWeb || _localNotificationsReady) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    _localNotificationsReady = true;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    await _initializeLocalNotifications();

    final String title =
        message.notification?.title ?? 'Nueva notificacion de Kapital';
    final String body =
        message.notification?.body ?? 'Tienes una solicitud pendiente.';

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'Kapital',
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('notification_logo'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  static Future<void> syncTokenForCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      _lastKnownUserId = user.id;

      final String rawVapidKey = const String.fromEnvironment(
        'FCM_WEB_VAPID_KEY',
      );
      final String vapidKey = rawVapidKey
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll(RegExp(r'\s+'), '');

      if (kIsWeb && vapidKey.isEmpty) {
        debugPrint(
          'FCM Web no puede generar token porque falta --dart-define=FCM_WEB_VAPID_KEY=TU_VAPID_KEY',
        );
        return;
      }

      final String? token = await _firebaseMessaging.getToken(
        vapidKey: kIsWeb && vapidKey.isNotEmpty ? vapidKey : null,
      );

      if (token == null || token.isEmpty) {
        debugPrint('No se pudo obtener FCM token.');
        return;
      }

      debugPrint('FCM Token: $token');
      await _saveTokenToSupabase(token);
    } catch (e) {
      debugPrint('Error al sincronizar FCM token: $e');
      if (kIsWeb) {
        debugPrint(
          'Revisa que FCM_WEB_VAPID_KEY no tenga comillas, espacios ni saltos de linea.',
        );
      }
    }
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        _lastKnownUserId = user.id;
        // Guardar en device_tokens (multi-dispositivo)
        await supabase.from('device_tokens').upsert({
          'user_id': user.id,
          'fcm_token': token,
          'platform': _platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,fcm_token');
        // Mantener compatibilidad con profiles.fcm_token
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('FCM Token guardado en Supabase exitosamente.');
      }
    } catch (e) {
      debugPrint('Error al guardar FCM Token: $e');
    }
  }

  static Future<void> _clearTokenInSupabase(String userId) async {
    try {
      // Obtener el token actual para borrarlo de device_tokens
      final String? currentToken = await _firebaseMessaging.getToken();
      if (currentToken != null) {
        await supabase
            .from('device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('fcm_token', currentToken);
      }
      // Limpiar profiles.fcm_token solo si no quedan otros dispositivos
      final remaining = await supabase
          .from('device_tokens')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      if ((remaining as List).isEmpty) {
        await supabase
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', userId);
      }
      debugPrint('FCM Token limpiado en Supabase al cerrar sesion.');
    } catch (e) {
      debugPrint('Error al limpiar FCM Token: $e');
    }
  }
}
