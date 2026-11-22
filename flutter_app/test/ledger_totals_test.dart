import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/main.dart';

void main() {
  enquiryTotalsTests();
  test('counts non-empty EMR rows and sums all minutes', () {
    final t = computeLedgerTotals(['1', ' ', '3'], ['10', '5', 'x']);
    expect(t.count, 2);
    expect(t.minutes, 15);
  });
  test('empty and negative values', () {
    final t = computeLedgerTotals([], []);
    expect(t.count, 0);
    expect(t.minutes, 0);
    expect(computeLedgerTotals(['a'], ['-4']).minutes, 0);
  });
  test('formatLedgerMinutes', () {
    expect(formatLedgerMinutes(15), '15');
    expect(formatLedgerMinutes(2.5), '2.5');
  });
}

void enquiryTotalsTests() {
  EnquiryRowInput row(
          {String name = '',
          String phone = '',
          String remarks = '',
          String status = '',
          String minutes = ''}) =>
      (
        name: name,
        phone: phone,
        remarks: remarks,
        status: status,
        minutes: minutes
      );
  group('computeEnquiryTotals', () {
    test('empty', () {
      final t = computeEnquiryTotals([]);
      expect(t.count, 0);
      expect(t.minutes, 0);
    });
    test('blank rows (auto number only) do not count', () {
      expect(computeEnquiryTotals([row(), row()]).count, 0);
    });
    test('counts worthwhile rows and sums minutes; invalid/negative = 0', () {
      final t = computeEnquiryTotals([
        row(name: 'A', minutes: '5'),
        row(minutes: '2.5'),
        row(status: 'Booked', minutes: '-3'),
        row(phone: '1', minutes: 'x'),
        row(),
      ]);
      expect(t.count, 4);
      expect(t.minutes, 7.5);
    });
  });
}
