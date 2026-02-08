import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/user_settings.dart';

class UserSettingsRepository {
  UserSettingsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  Stream<UserSettings> watchSettings(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? <String, dynamic>{};
      return UserSettings(
        themeMode: _themeModeFromString(data['themeMode'] as String?),
        notificationThresholdDays:
            (data['notificationThresholdDays'] as num?)?.toInt() ?? 3,
        perishableReminderDays:
            (data['perishableReminderDays'] as num?)?.toInt() ?? 7,
      );
    });
  }

  Future<void> updateThemeMode(String uid, AppThemeMode mode) async {
    await _userDoc(uid).set(<String, dynamic>{
      'themeMode': mode.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateThreshold(String uid, int days) async {
    await _userDoc(uid).set(<String, dynamic>{
      'notificationThresholdDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePerishableReminderDays(String uid, int days) async {
    await _userDoc(uid).set(<String, dynamic>{
      'perishableReminderDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  AppThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(FirebaseFirestore.instance);
});

final userSettingsProvider = StreamProvider<UserSettings>((ref) {
  final user = ref.watch(currentUserProvider);
  final uid = user?.uid;
  if (uid == null) {
    return Stream<UserSettings>.value(UserSettings.defaults);
  }
  return ref.watch(userSettingsRepositoryProvider).watchSettings(uid);
});

final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(userSettingsProvider).valueOrNull ?? UserSettings.defaults;
  switch (settings.themeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});
