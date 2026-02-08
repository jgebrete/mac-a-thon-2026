enum AppThemeMode { system, light, dark }

class UserSettings {
  const UserSettings({
    required this.themeMode,
    required this.notificationThresholdDays,
    required this.perishableReminderDays,
  });

  final AppThemeMode themeMode;
  final int notificationThresholdDays;
  final int perishableReminderDays;

  UserSettings copyWith({
    AppThemeMode? themeMode,
    int? notificationThresholdDays,
    int? perishableReminderDays,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationThresholdDays:
          notificationThresholdDays ?? this.notificationThresholdDays,
      perishableReminderDays: perishableReminderDays ?? this.perishableReminderDays,
    );
  }

  static const UserSettings defaults = UserSettings(
    themeMode: AppThemeMode.system,
    notificationThresholdDays: 3,
    perishableReminderDays: 7,
  );
}
