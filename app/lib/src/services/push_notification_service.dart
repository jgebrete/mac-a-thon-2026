import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushNotificationService {
  PushNotificationService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  Future<void> initializeAndSyncToken(String uid) async {
    await _messaging.requestPermission();
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
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance, FirebaseFirestore.instance);
});
