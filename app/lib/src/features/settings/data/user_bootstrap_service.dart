import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserBootstrapService {
  UserBootstrapService(this._db);

  final FirebaseFirestore _db;

  Future<void> ensureUserDoc(String uid) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'notificationThresholdDays': 3,
    }, SetOptions(merge: true));
  }
}

final userBootstrapServiceProvider = Provider<UserBootstrapService>((ref) {
  return UserBootstrapService(FirebaseFirestore.instance);
});
