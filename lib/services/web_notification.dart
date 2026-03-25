import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> showWebNotification(String title, String body) async {
  final permission = web.Notification.permission;
  if (permission != 'granted') {
    await web.Notification.requestPermission().toDart;
  }
  if (web.Notification.permission == 'granted') {
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: '/icons/kapital_192.png'),
    );
  }
}
