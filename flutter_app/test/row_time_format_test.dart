import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/staff_detailed_report.dart';

void main() {
  test('formatRowTime handles absent and valid values', () {
    expect(formatRowTime(null), '—');
    expect(formatRowTime('bad'), '—');
    final s = formatRowTime('2026-01-05T09:05:00');
    expect(s, '05 Jan, 09:05 AM');
  });
}
