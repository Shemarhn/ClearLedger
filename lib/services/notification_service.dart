import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/supabase_client.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await _fcm.getToken();
    if (token != null) {
      await saveFcmToken(token);
    }

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'ClearLedger';
      final body = message.notification?.body ?? 'New notification';
      showLocalNotification(title: title, body: body);
    });
  }

  Future<void> saveFcmToken(String token) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('fcm_tokens').upsert({
      'user_id': user.id,
      'token': token,
    });
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget overspending',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _localNotifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
