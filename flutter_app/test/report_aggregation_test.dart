import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/payroll_reports.dart';
import 'package:ontario_staff_tasks/report_aggregation.dart';

Map<String, dynamic> row(String uid, String name, String date, String task,
        {num q = 1, num h = 0, Map<String, dynamic> extra = const {}}) =>
    {
      'uid': uid,
      'employeeName': name,
      'Task Date': date,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': task,
      'quantity': '$q',
      'hours': '$h',
      ...extra,
    };

void main() {
  final rows = [
    row('a', 'Asha', '2026-01-05', 'registrations', q: 4, h: 1),
    row('a', 'Asha', '2026-01-05', 'enquiries', q: 2, h: 0.5),
    row('a', 'Asha', '2026-01-05', 'enquiry_detail', h: 0.25),
    row('a', 'Asha', '2026-01-05', 'ledger_prepared', h: 0.5),
    row('a', 'Asha', '2026-01-06', 'registrations', q: 2, h: 2),
    row('b', 'Ben', '2026-01-05', 'registrations', q: 1, h: 0.5),
  ];

  test('countedMinutes excludes breakdown rows', () {
    expect(countedMinutes(rows[0]), 60);
    expect(countedMinutes(rows[2]), 0);
    expect(countedMinutes(rows[3]), 0);
  });

  test('staff summary totals, days and average', () {
    final s = buildStaffSummary(rows);
    expect(s.map((e) => e.name), ['Asha', 'Ben']);
    final a = s.first;
    expect(a.daysWorked, 2);
    expect(a.days.first.minutes, 90);
    expect(a.totalMinutes, 90 + 120);
    expect(a.avgMinutesPerDay, 105);
  });

  test('activity summary totals, staff count, and per-user cross-tab details', () {
    final t = buildActivitySummary(rows);
    final reg = t.firstWhere((x) => x.taskId == 'registrations');
    expect(reg.quantity, 7);
    expect(reg.minutes, 210);
    expect(reg.staffCount, 2);
    expect(reg.avgMinutesPerStaff, 105);
    expect(reg.byUser['Asha']?.quantity, 6);
    expect(reg.byUser['Asha']?.minutes, 180);
    expect(reg.byUser['Ben']?.quantity, 1);
    expect(reg.byUser['Ben']?.minutes, 30);
    expect(t.any((x) => x.taskId == 'enquiry_detail'), isFalse);
  });

  test('detailed groups by staff/date with enquiry and ledger rows', () {
    final d = buildDetailed(rows);
    final day = d.first.days.first;
    expect(day.enquiries.length, 1);
    expect(day.ledger.length, 1);
    expect(day.totalMinutes, 90);
  });

  test('multiple other_tasks rows per day sum minutes and list descriptions',
      () {
    final r = [
      row('z', 'Zed', '2026-02-01', 'other_tasks',
          h: 0.5, extra: {'emr': '1', 'remarks': 'Bank run'}),
      row('z', 'Zed', '2026-02-01', 'other_tasks',
          h: 0.25, extra: {'emr': '2', 'remarks': 'Audit'}),
    ];
    final line = buildDetailed(r).single.days.single.activities['other_tasks']!;
    expect(line.minutes, 45);
    expect(line.rows, 2);
    expect(line.descriptions, ['Bank run', 'Audit']);
    expect(buildActivitySummary(r).single.minutes, 45);
    expect(buildStaffSummary(r).single.totalMinutes, 45);
  });

  test('filterEntries drops administrator and applies employee', () {
    final r = filterEntries([
      ...rows,
      row('x', 'Administrator', '2026-01-05', 'registrations'),
    ], const ReportCriteria(employee: 'Ben'));
    expect(r.length, 1);
  });

  test('criteria range and error mapping', () {
    final now = DateTime(2026, 3, 10);
    expect(
        const ReportCriteria(todayOnly: true).periodLabel(now), '10/03/2026');
    final r = const ReportCriteria().range(now);
    expect(r.to.difference(r.from).inDays + 1, maxRangeDays);
    expect(
        friendlyReportError(Exception('Date range too large (max 366 days)')),
        contains('shorter'));
  });

  test('pdf builds for each type, including empty and large multi-page datasets', () async {
    final largeRows = <Map<String, dynamic>>[
      for (var day = 0; day < 90; day++)
        for (final staff in ['Asha', 'Ben', 'Chitra']) ...[
          row(
            staff.toLowerCase(),
            staff,
            isoDate(DateTime(2026, 1, 1).add(Duration(days: day))),
            'registrations',
            q: 5,
            h: 1.5,
          ),
          row(
            staff.toLowerCase(),
            staff,
            isoDate(DateTime(2026, 1, 1).add(Duration(days: day))),
            'ledger_prepared',
            q: 1,
            h: 0.25,
            extra: {'emr': 'E$day'},
          ),
        ],
    ];
    for (final t in PdfReportType.values) {
      for (final data in [rows, <Map<String, dynamic>>[], largeRows]) {
        final bytes = await buildReportPdf(
            type: t,
            rows: data,
            criteria: const ReportCriteria(),
            generatedBy: 'Admin');
        expect(bytes.length, greaterThan(500));
      }
    }
  });

  test('pdfSafe replaces unsupported characters', () {
    expect(pdfSafe('A \u2014 B'), 'A - B');
    expect(pdfSafe('\u0627'), '?');
  });
}
