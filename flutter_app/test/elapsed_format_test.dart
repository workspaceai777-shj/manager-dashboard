import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/main.dart';

void main() {
  test('formatElapsed formats MM:SS and H:MM:SS', () {
    expect(formatElapsed(const Duration(seconds: 5)), '00:05');
    expect(formatElapsed(const Duration(minutes: 12, seconds: 41)), '12:41');
    expect(formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03');
    expect(formatElapsed(const Duration(seconds: -4)), '00:00');
  });
}
