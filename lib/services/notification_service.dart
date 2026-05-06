import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/supabase_client.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _localInitialized = false;
  bool _pushEnabled = false;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  Future<void> initialize({bool enablePush = true}) async {
    if (!_localInitialized) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(settings: initSettings);
      _localInitialized = true;
    }

    if (!enablePush) return;

    try {
      _pushEnabled = true;
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await syncPushToken();

      await _messageSubscription?.cancel();
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? 'ClearLedger';
        final body = message.notification?.body ?? 'New notification';
        showLocalNotification(title: title, body: body);
      });
    } catch (error) {
      _pushEnabled = false;
      debugPrint('ClearLedger push notifications disabled: $error');
    }
  }

  Future<void> syncPushToken() async {
    if (!_pushEnabled) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await saveFcmToken(token);
      }
    } catch (error) {
      debugPrint('ClearLedger FCM token sync failed: $error');
    }
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
    try {
      if (!_localInitialized) {
        await initialize(enablePush: false);
      }

      const androidDetails = AndroidNotificationDetails(
        'budget_alerts',
        'Budget Alerts',
        channelDescription: 'Notifications for budget overspending',
        importance: Importance.max,
        priority: Priority.high,
      );

      await _localNotifications.show(
        id: 0,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (error) {
      debugPrint('ClearLedger local notification failed: $error');
    }
  }
}
