import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontario_staff_tasks/api.dart';
import 'package:ontario_staff_tasks/main.dart';
import 'package:ontario_staff_tasks/performance_dashboard.dart';
import 'package:ontario_staff_tasks/tasklog_style.dart';

class FakeStaffApi extends StaffApi {
  FakeStaffApi({required this.role, required this.uid, required this.name});

  final String role;
  final String uid;
  final String name;

  final List<Map<String, dynamic>> allEntries = [
    {
      'uid': 'other-staff-uid',
      'employeeName': 'Other Staff',
      'date': _todayStr(),
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'ledger_updated',
      'emr': '',
      'remarks': '',
      'quantity': 99,
      'hours': 4.0,
    },
  ];

  static String _todayStr() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
  }

  static List<Map<String, String>> catalogFor(String branch, String category) {
    if (category == 'INSURANCE USER') {
      return const [
        {'id': 'insurance_invoices', 'name': 'Insurance Invoices Prepared'},
        {'id': 'insurance_documents', 'name': 'Insurance Documents Sent'},
        {'id': 'insurance_datewise', 'name': 'Insurance Datewise Updated'},
        {'id': 'insurance_emrwise', 'name': 'Insurance EMRwise Updated'},
      ];
    }
    if (category == 'ACCOUNTS') {
      return const [
        {'id': 'accounts_r4_ledgers', 'name': 'R4 Individual Ledgers Created'},
        {
          'id': 'accounts_collection_check',
          'name': 'Daily Collections Checked — White Fox and Ontario'
        },
        {
          'id': 'accounts_dha_attendance',
          'name': 'DHA Attendance Records Updated'
        },
      ];
    }
    if (branch == 'ONT-BB') {
      return const [
        {
          'id': 'registrations',
          'name': 'New patient registration and cards prepared'
        },
        {'id': 'collection', 'name': 'Daily collection (AED)'},
        {'id': 'ledger_updated', 'name': 'Next-day individual ledgers updated'},
        {
          'id': 'ledger_prepared',
          'name': 'Individual Ledgers Prepared (EMR-wise)'
        },
      ];
    }
    return const [
      {
        'id': 'registrations',
        'name':
            'Patient Registrations (including treatment chart and case sheet)'
      },
      {
        'id': 'ledger_prepared',
        'name': 'Individual Ledgers Prepared (EMR-wise)'
      },
      {'id': 'ledger_updated', 'name': 'Ledgers Updated (R4)'},
      {'id': 'collection', 'name': 'Daily Collection (AED)'},
    ];
  }

  @override
  Future<dynamic> request(String action, {Map<String, dynamic>? body}) async {
    final payload = body ?? const <String, dynamic>{};
    switch (action) {
      case 'bootstrap':
        return {
          'profile': {
            'uid': uid,
            'name': name,
            'email': '$uid@ontario.test',
            'role': role,
            'active': true,
          },
          'assignments': const [
            {'branch': 'ONT-BB', 'category': 'FRONT DESK'},
            {'branch': 'ONT-BR1', 'category': 'FRONT DESK'},
            {'branch': 'ONT-BB', 'category': 'INSURANCE USER'},
            {'branch': 'ONT-BR1', 'category': 'ACCOUNTS'},
          ],
        };
      case 'tasks':
        return {
          'tasks': catalogFor(
            payload['branch'].toString(),
            payload['category'].toString(),
          ),
        };
      case 'report':
        final b = payload['branch'].toString();
        final c = payload['category'].toString();
        final d = payload['date'].toString();
        return {
          'entries': allEntries
              .where((e) =>
                  e['uid'] == uid &&
                  e['branch'] == b &&
                  e['category'] == c &&
                  e['date'] == d)
              .toList(),
        };
      case 'saveReport':
        final b = payload['branch'].toString();
        final c = payload['category'].toString();
        final d = payload['date'].toString();
        final incoming = List<Map<String, dynamic>>.from(
            (payload['entries'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)));
        // Replace previous entries for (uid, date, branch, category) without duplicating
        allEntries.removeWhere((e) =>
            e['uid'] == uid &&
            e['branch'] == b &&
            e['category'] == c &&
            e['date'] == d);
        for (final row in incoming) {
          allEntries.add({
            'uid': uid,
            'employeeName': name,
            'date': d,
            'branch': b,
            'category': c,
            'taskId': row['taskId'],
            'emr': row['emr'] ?? '',
            'remarks': row['remarks'] ?? '',
            'quantity': row['quantity'],
            'hours': row['hours'],
          });
        }
        return {'saved': incoming.length};
      case 'dashboard':
        if (role != 'ADMIN') {
          throw Exception('Administrator access required');
        }
        return {'entries': List<Map<String, dynamic>>.from(allEntries)};
      case 'myDashboard':
        return {
          'entries': allEntries.where((e) => e['uid'] == uid).toList(),
        };
      case 'users':
        if (role != 'ADMIN') {
          throw Exception('Admin access required');
        }
        return {
          'users': [
            {
              'uid': uid,
              'name': name,
              'email': '$uid@ontario.test',
              'role': role,
              'branch': 'ONT-BB',
              'category': 'FRONT DESK',
              'active': true,
            },
            {
              'uid': 'staff-1',
              'name': 'Prince',
              'email': 'prince@ontario.test',
              'role': 'STAFF',
              'branch': 'ONT-BR1',
              'category': 'FRONT DESK',
              'active': true,
            },
          ],
        };
      default:
        return {};
    }
  }
}

void main() {
  const widths = <double>[360, 390, 430, 768, 1280];

  testWidgets(
      'LoginPage is responsive at 360, 390, 430, 768 and desktop widths',
      (tester) async {
    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(MaterialApp(
        theme: TaskLogStyle.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: const LoginPage(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ontario Staff Portal'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'PerformanceDashboard enforces admin vs staff view and is responsive at all target widths',
      (tester) async {
    final dateStr = FakeStaffApi._todayStr();
    final sampleRecords = [
      {
        'date': dateStr,
        'branch': 'ONT-BB',
        'category': 'FRONT DESK',
        'employeeName': 'Prince',
        'taskId': 'ledger_prepared',
        'quantity': 6,
        'hours': 1.5,
      },
      {
        'date': dateStr,
        'branch': 'ONT-BR1',
        'category': 'FRONT DESK',
        'employeeName': 'Stanly',
        'taskId': 'ledger_updated',
        'quantity': 14,
        'hours': 2.0,
      },
      {
        'date': dateStr,
        'branch': 'ONT-BB',
        'category': 'FRONT DESK',
        'employeeName': 'Prince',
        'taskId': 'collection',
        'quantity': 4250.50,
        'hours': 0.5,
      },
      {
        'date': dateStr,
        'branch': 'ONT-BR1',
        'category': 'INSURANCE USER',
        'employeeName': 'Farsana',
        'taskId': 'insurance_invoices',
        'quantity': 12,
        'hours': 1.25,
      },
    ];

    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 900));

      // Staff view: personal dashboard only, no Employee filter
      await tester.pumpWidget(MaterialApp(
        theme: TaskLogStyle.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PerformanceDashboard(
              records: sampleRecords
                  .where((r) => r['employeeName'] == 'Prince')
                  .toList(),
              isAdmin: false,
              refresh: () async {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('My performance'), findsOneWidget);
      expect(find.text('Employee'), findsNothing);
      expect(tester.takeException(), isNull);

      // Admin view: full Performance dashboard + Employee filter
      await tester.pumpWidget(MaterialApp(
        theme: TaskLogStyle.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PerformanceDashboard(
              records: sampleRecords,
              isAdmin: true,
              refresh: () async {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Performance dashboard'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'Staff Portal verifies branch/category tasks, report edit/resave without duplicate totals, and blocks other employee data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final staffApi = FakeStaffApi(
      role: 'STAFF',
      uid: 'staff-prince',
      name: 'Prince',
    );

    await tester.pumpWidget(MaterialApp(
      theme: TaskLogStyle.dark,
      home: Portal(api: staffApi),
    ));
    await tester.pumpAndSettle();

    // Branch selector screen appears first
    expect(find.text('Select branch and category'), findsOneWidget);

    // Select ONT-BB FRONT DESK
    await tester.tap(find.text('ONT-BB').first);
    await tester.pumpAndSettle();

    // Verify ONT-BB FRONT DESK specific task appears
    expect(find.text('New patient registration and cards prepared'),
        findsOneWidget);
    // Staff navigation has Daily Tasks and My Dashboard only, never Settings
    expect(find.text('My Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);

    // Switch to ONT-BR1 FRONT DESK and verify branch-specific task
    await tester.tap(find.text('ONT-BB — FRONT DESK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BR1 — FRONT DESK').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Patient Registrations (including treatment chart and case sheet)'),
        findsOneWidget);

    // Enter Ledgers Updated (R4) = 5, Hours = 1.5 and save
    final ledgerCard = find.ancestor(
      of: find.text('Ledgers Updated (R4)'),
      matching: find.byType(Card),
    );
    final qtyField = find.descendant(
      of: ledgerCard,
      matching: find.widgetWithText(TextField, 'Quantity'),
    );
    final hoursField = find.descendant(
      of: ledgerCard,
      matching: find.widgetWithText(TextField, 'Hours'),
    );
    await tester.enterText(qtyField, '5');
    await tester.enterText(hoursField, '1.5');
    await tester.tap(find.text('Save daily report'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Saved report loaded — edit the values and save again to replace this date’s entries.'),
      findsOneWidget,
    );

    // Edit the saved report from 5 to 8 and resave
    await tester.enterText(qtyField, '8');
    await tester.tap(find.text('Save daily report'));
    await tester.pumpAndSettle();

    // Open My Dashboard and verify total is 8 (not 5 + 8 = 13, and excludes Other Staff's 99)
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(find.text('My performance'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('13'), findsNothing);
    expect(find.text('Other Staff'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'Admin Portal shows Daily Tasks, full Dashboard, and Settings across all target widths',
      (tester) async {
    final adminApi = FakeStaffApi(
      role: 'ADMIN',
      uid: 'admin-1',
      name: 'Clinic Admin',
    );

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(MaterialApp(
        theme: TaskLogStyle.dark,
        home: Portal(api: adminApi),
      ));
      await tester.pumpAndSettle();

      if (find.text('Select branch and category').evaluate().isNotEmpty) {
        await tester.tap(find.text('ONT-BB').first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Settings'), findsWidgets);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Staff management'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}
