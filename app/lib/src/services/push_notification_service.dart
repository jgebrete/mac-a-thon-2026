import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushNotificationService {
  PushNotificationService(this._messaging, this._db, this._localNotifications);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _foregroundHandlersInitialized = false;

  static const String _channelId = 'pantry_alerts';
  static const String _channelName = 'Pantry Alerts';
  static const String _channelDescription = 'Expiry and pantry reminder alerts';

  Future<void> initializeAndSyncToken(String uid) async {
    await _initializeForegroundNotifications();
    await _messaging.requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _db
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .set(<String, dynamic>{
      'token': token,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _initializeForegroundNotifications() async {
    if (_foregroundHandlersInitialized) {
      return;
    }
    _foregroundHandlersInitialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Pantry reminder';
    final body = message.notification?.body ?? '';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final id = Random().nextInt(1 << 30);
    await _localNotifications.show(id, title, body, details);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
    FlutterLocalNotificationsPlugin(),
  );
});
