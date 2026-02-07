import 'package:intl/intl.dart';

DateTime dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String formatDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('yyyy-MM-dd').format(value);
}

DateTime? parseIsoDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  try {
    return dateOnly(DateTime.parse(trimmed));
  } catch (_) {
    return null;
  }
}

int daysUntil(DateTime target, {DateTime? from}) {
  final start = dateOnly(from ?? DateTime.now());
  final end = dateOnly(target);
  return end.difference(start).inDays;
}
