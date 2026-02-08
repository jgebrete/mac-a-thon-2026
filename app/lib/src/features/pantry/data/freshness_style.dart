import 'package:flutter/material.dart';

import '../../settings/domain/user_settings.dart';

class FreshnessStyle {
  const FreshnessStyle({
    required this.background,
    required this.border,
    required this.badge,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color badge;
  final String label;
}

FreshnessStyle freshnessStyleForDays(
  int? daysUntilExpiry,
  UserSettings settings,
  Brightness brightness,
  {required bool isPerishableNoExpiry}
) {
  if (isPerishableNoExpiry) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF5E4B1A)
        : const Color(0xFFFFF1CC);
    final border = Color.lerp(base, Colors.amber.shade700, 0.55)!;
    return FreshnessStyle(
      background: base,
      border: border,
      badge: Colors.amber.shade700,
      label: 'Perishable',
    );
  }

  if (daysUntilExpiry == null) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFEAEAEA);
    return FreshnessStyle(
      background: base,
      border: Color.lerp(base, Colors.grey.shade700, 0.4)!,
      badge: Colors.grey.shade700,
      label: 'Unknown',
    );
  }

  if (daysUntilExpiry <= 0) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF7A2E2E)
        : const Color(0xFFFFD8D8);
    final border = Color.lerp(base, Colors.red.shade700, 0.55)!;
    return FreshnessStyle(
      background: base,
      border: border,
      badge: Colors.red.shade600,
      label: 'Expired',
    );
  }

  final threshold = settings.notificationThresholdDays.clamp(1, 14);
  final ratio = (daysUntilExpiry / threshold).clamp(0.0, 2.0);

  final start = brightness == Brightness.dark
      ? const Color(0xFF533B1D)
      : const Color(0xFFFFECCC);
  final end = brightness == Brightness.dark
      ? const Color(0xFF1D4E3B)
      : const Color(0xFFDFF5E9);

  final t = ratio >= 1 ? 1.0 : ratio;
  final background = Color.lerp(start, end, t)!;
  final border = Color.lerp(Colors.orange.shade700, Colors.green.shade700, t)!;
  final badge = Color.lerp(Colors.orange.shade600, Colors.green.shade600, t)!;

  return FreshnessStyle(
    background: background,
    border: border,
    badge: badge,
    label: ratio >= 1 ? 'Fresh' : 'Soon',
  );
}
