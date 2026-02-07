import 'package:app/src/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseIsoDate parses valid yyyy-MM-dd', () {
    final parsed = parseIsoDate('2026-02-15');
    expect(parsed, isNotNull);
    expect(formatDate(parsed), '2026-02-15');
  });

  test('parseIsoDate returns null on invalid input', () {
    expect(parseIsoDate('invalid-date'), isNull);
  });
}
