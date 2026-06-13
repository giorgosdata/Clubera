import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // No-op: system tray handles display when app is killed.
}

class NotificationsService {
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'clubera_default',
    'Clubera Notifications',
    description: 'All app notifications',
    importance: Importance.high,
  );

  static Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied');
        return;
      }

      FirebaseMessaging.onMessage.listen(_showLocal);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);

      // Subscribe to global topic for app-wide announcements
      await FirebaseMessaging.instance.subscribeToTopic('global');
    } catch (e) {
      debugPrint('NotificationsService init error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    // Filter by notification preferences stored in SharedPreferences
    final type = message.data['type'] as String? ?? '';
    const prefKeys = {
      'goal': 'notif_goals',
      'match_start': 'notif_match_start',
      'match_end': 'notif_match_end',
      'announcement': 'notif_announcements',
      'prediction': 'notif_predictions',
    };
    final prefKey = prefKeys[type];
    if (prefKey != null) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(prefKey) ?? true)) return;
    }

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String?,
    );
  }

  /// Subscribe a user to a topic (e.g. "club_abc123" to follow a club).
  static Future<void> subscribe(String topic) =>
      FirebaseMessaging.instance.subscribeToTopic(topic);

  static Future<void> unsubscribe(String topic) =>
      FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}
