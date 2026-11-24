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
        {
          'id': 'insurance_claims_prepared',
          'name': 'Insurance Claims Prepared'
        },
        {'id': 'insurance_invoices', 'name': 'Insurance Invoices Prepared'},
        {'id': 'insurance_documents', 'name': 'Insurance Documents Sent'},
        {'id': 'insurance_datewise', 'name': 'Insurance Datewise Updated'},
        {'id': 'insurance_emrwise', 'name': 'Insurance EMRwise Updated'},
        {'id': 'insurance_ledger_emr', 'name': 'Insurance EMR-wise Entry'},
      ];
    }
    if (category == 'ACCOUNTS') {
      return const [
        {
          'id': 'accounts_collection_check',
          'name': 'Daily Collections Checked — White Fox and Ontario'
        },
        {
          'id': 'accounts_dha_attendance',
          'name': 'DHA Attendance Records Updated'
        },
        {
          'id': 'accounts_insurance_ledgers',
          'name': 'Individual ledgers for insurance showed'
        },
        {
          'id': 'accounts_month_end',
          'name': 'Month-End Collection Closing and Bank Deposit Handover'
        },
        {
          'id': 'accounts_reception',
          'name': 'Reception Duties and Reporting Vouchers'
        },
        {'id': 'accounts_zoho_updation', 'name': 'Zoho updation'},
        {'id': 'accounts_vat_excel_ontario', 'name': 'Vat excel entry Ontario'},
        {'id': 'accounts_vat_filing_ontario', 'name': 'Vat filing Ontario'},
        {
          'id': 'accounts_vat_excel_whitefox',
          'name': 'Vat excel updation White fox'
        },
        {'id': 'accounts_vat_filing_whitefox', 'name': 'Vat filing White fox'},
        {
          'id': 'accounts_cash_in_hand_checking',
          'name': 'Cash in hand checking'
        },
        {
          'id': 'accounts_staff_attendance',
          'name': 'Staff attendance Ontario and Whitefox'
        },
        {
          'id': 'accounts_towel_import_invoice',
          'name':
              'Towel import invoice preparation, cash collect from customer and excel update'
        },
        {
          'id': 'accounts_medicine_collect_whitefox',
          'name':
              'Medicine collect from supplier for whitefox and invoice updated'
        },
        {
          'id': 'accounts_month_end_closing_deposit',
          'name': 'Travel collection closing and cash handover for deposit'
        },
        {
          'id': 'accounts_whitefox_consignment_sale',
          'name': 'White fox Consignment basis sale checking and update'
        },
        {
          'id': 'accounts_petty_cash_voucher_entry',
          'name': 'Petty cash voucher entry and filing'
        },
        {'id': 'accounts_petty_cash_excel', 'name': 'Petty cash excel'},
        {
          'id': 'accounts_purchase_request_month',
          'name': 'Purchase request for one month'
        },
      ];
    }
    if (category.toUpperCase() == "DOCTOR'S ZONE") {
      return const [
        {'id': 'doctors_consultations', 'name': 'Number of Consultations'},
        {'id': 'doctors_follow_ups', 'name': 'Number of Follow-ups'},
        {
          'id': 'doctors_treatments_supervised',
          'name': 'Number of Treatments Supervised'
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
        {
          'id': 'ledger_updated',
          'name': 'Individual Ledger Updated (R4) (including for insurance)'
        },
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
      {'id': 'enquiries', 'name': 'Enquiries Handled'},
      {
        'id': 'ledger_prepared',
        'name': 'Individual Ledgers Prepared (EMR-wise)'
      },
      {
        'id': 'ledger_updated',
        'name': 'Individual Ledger Updated (R4) (including for insurance)'
      },
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
            {'branch': 'ONT-BB', 'category': "DOCTOR'S ZONE"},
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
        // Exact v2.js validation check
        final allowed =
            catalogFor(b, c).map((t) => t['id'].toString()).toSet()
              ..add('other_tasks')
              ..add('cards_arranged');
        if (c == 'ACCOUNTS') {
          allowed.add('accounts_monthly_collection_excel');
        }
        if (allowed.contains('enquiries')) {
          allowed.add('enquiry_detail');
        }
        final isAccounts = c == 'ACCOUNTS';
        final maxOther = isAccounts ? 5 : 1;
        final otherSlots = <String>{};
        final seenLedger = <String>{};
        for (final row in incoming) {
          final task = (row['taskId'] ?? '').toString();
          if (!allowed.contains(task)) {
            throw Exception(
                'Invalid task quantity or hours (task: $task, not allowed for this category)');
          }
          final emr = (row['emr'] ?? '').toString().trim();
          final remarks = (row['remarks'] ?? '').toString().trim();
          if (task == 'enquiry_detail') {
            final phone = (row['callerPhone'] ?? '').toString().trim();
            if (phone.length > 30 ||
                !RegExp(r'^[0-9+\-() ]*$').hasMatch(phone)) {
              throw Exception('Invalid caller phone');
            }
            continue;
          }
          if (task == 'other_tasks') {
            if (remarks.length > 500) {
              throw Exception('Other task description too long (max 500)');
            }
            if (otherSlots.length >= maxOther) {
              throw Exception('Too many other tasks');
            }
            var slot = '';
            if (isAccounts) {
              slot = emr.isEmpty ? '1' : emr;
              if (!RegExp(r'^[1-5]$').hasMatch(slot)) {
                throw Exception('Invalid other task slot (1-5)');
              }
            } else if (emr.isNotEmpty && emr != '1') {
              throw Exception('EMR is only accepted for EMR-wise preparation');
            }
            if (otherSlots.contains(slot)) {
              throw Exception('Duplicate other task slot');
            }
            otherSlots.add(slot);
            continue;
          }
          if (task == 'ledger_prepared' || task == 'insurance_ledger_emr') {
            if (emr.isEmpty) continue;
            final key = '$task:$emr';
            if (seenLedger.contains(key)) {
              throw Exception('Duplicate EMR in submission');
            }
            seenLedger.add(key);
          } else if (emr.isNotEmpty) {
            throw Exception('EMR is only accepted for EMR-wise preparation');
          }
        }
        // Replace previous entries for (uid, date, branch, category) without duplicating
        allEntries.removeWhere((e) =>
            e['uid'] == uid &&
            e['branch'] == b &&
            e['category'] == c &&
            e['date'] == d);
        final savedRows = <Map<String, dynamic>>[];
        for (final row in incoming) {
          final task = (row['taskId'] ?? '').toString();
          final rawEmr = (row['emr'] ?? '').toString().trim();
          final emrVal = task == 'other_tasks'
              ? (isAccounts ? (rawEmr.isEmpty ? '1' : rawEmr) : '')
              : rawEmr;
          final saved = {
            'uid': uid,
            'employeeName': name,
            'date': d,
            'Task Date': d,
            'branch': b,
            'category': c,
            'taskId': task,
            'emr': emrVal,
            'remarks': row['remarks'] ?? '',
            'quantity': row['quantity'],
            'hours': row['hours'],
            'callerName': row['callerName'] ?? '',
            'callerPhone': row['callerPhone'] ?? '',
            'callStatus': row['callStatus'] ?? '',
            if (row['startTime'] != null) 'startTime': row['startTime'],
            if (row['endTime'] != null) 'endTime': row['endTime'],
          };
          allEntries.add(saved);
          savedRows.add(saved);
        }
        return {'saved': savedRows.length, 'entries': savedRows};
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
      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(find.text('Save login credentials'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
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
      expect(find.byType(RotatedBox), findsWidgets);
      expect(find.text('14'), findsWidgets);
      expect(find.text('12'), findsWidgets);
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

    // Branch selector screen appears first and shows logged-in staff name
    expect(find.text('Select branch and category'), findsOneWidget);
    expect(find.text('Logged in as Prince'), findsOneWidget);

    // Select ONT-BB FRONT DESK
    await tester.tap(find.text('ONT-BB').first);
    await tester.pumpAndSettle();

    // Verify logged-in staff name is visible in the top bar
    expect(find.text('Prince'), findsOneWidget);

    // Verify ONT-BB FRONT DESK specific task appears and is numbered
    expect(find.text('1. '), findsOneWidget);
    expect(find.text('New patient registration and cards prepared'),
        findsOneWidget);
    // Staff navigation has Daily Tasks and My Dashboard only, never Settings
    expect(find.text('My Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);

    // Switch to ONT-BR1 ACCOUNTS and verify 19 activities
    await tester.tap(find.text('ONT-BB — FRONT DESK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BR1 — ACCOUNTS').last);
    await tester.pumpAndSettle();
    expect(find.text('R4 Individual Ledgers Created'), findsNothing);
    expect(
        find.text('Individual ledgers for insurance showed'), findsOneWidget);
    expect(find.text('Petty Cash Filing Completed'), findsNothing);
    expect(find.text('Monthly collection excel'), findsNothing);
    expect(find.text('Zoho updation'), findsOneWidget);
    expect(
        find.text('Travel collection closing and cash handover for deposit'),
        findsOneWidget);
    expect(find.text('Purchase request for one month'), findsOneWidget);
    expect(find.text('Other task carried out'), findsWidgets);
    for (int i = 1; i <= 19; i++) {
      expect(find.text('$i. '), findsOneWidget);
    }
    expect(find.widgetWithText(InputDecorator, 'Yes / No'), findsNWidgets(16));
    expect(find.widgetWithText(TextField, 'Quantity'), findsNWidgets(3));

    // Switch to ONT-BB DOCTOR'S ZONE and verify the 3 Doctor's Zone activities
    await tester.tap(find.text('ONT-BR1 — ACCOUNTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("ONT-BB — DOCTOR'S ZONE").last);
    await tester.pumpAndSettle();
    expect(find.text('Number of Consultations'), findsOneWidget);
    expect(find.text('Number of Follow-ups'), findsOneWidget);
    expect(find.text('Number of Treatments Supervised'), findsOneWidget);
    for (int i = 1; i <= 3; i++) {
      expect(find.text('$i. '), findsOneWidget);
    }

    // Switch to ONT-BR1 FRONT DESK and verify branch-specific task
    await tester.tap(find.text("ONT-BB — DOCTOR'S ZONE"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BR1 — FRONT DESK').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Patient Registrations (including treatment chart and case sheet)'),
        findsOneWidget);

    // Verify Start/End timer increments Quantity on each Start and adds Minutes on each End
    final regCard = find.ancestor(
      of: find.text(
          'Patient Registrations (including treatment chart and case sheet)'),
      matching: find.byType(Card),
    );
    await tester.tap(find.byKey(const ValueKey('start-registrations')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.descendant(
              of: regCard, matching: find.widgetWithText(TextField, 'Quantity')))
          .controller!
          .text,
      '1',
    );
    await tester.tap(find.byKey(const ValueKey('end-registrations')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-registrations')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.descendant(
              of: regCard, matching: find.widgetWithText(TextField, 'Quantity')))
          .controller!
          .text,
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('end-registrations')));
    await tester.pump();

    // Enter Ledger Updated (R4) (including for insurance) = 5, Hours = 1.5 and save
    final ledgerCard = find.ancestor(
      of: find.text('Individual Ledger Updated (R4) (including for insurance)'),
      matching: find.byType(Card),
    );
    Future<void> addEmrRows(int from, int to) async {
      for (var i = from; i < to; i++) {
        await tester.ensureVisible(find.text('Add EMR'));
        await tester.tap(find.text('Add EMR'));
        await tester.pumpAndSettle();
        final emrField = find.widgetWithText(TextField, 'EMR No.').at(i);
        await tester.ensureVisible(emrField);
        await tester.enterText(emrField, 'E$i');
        if (i == 0) {
          await tester.enterText(
              find.descendant(
                  of: find
                      .ancestor(of: emrField, matching: find.byType(Card))
                      .first,
                  matching: find.widgetWithText(TextField, 'Minutes')),
              '90');
        }
        await tester.pumpAndSettle();
      }
    }

    // Activity card is read-only and derived from the EMR-wise rows
    expect(find.descendant(of: ledgerCard, matching: find.byType(TextField)),
        findsNothing);
    await addEmrRows(0, 5);
    final qtyField = find.descendant(
        of: ledgerCard,
        matching: find.byKey(const ValueKey('ledger-summary-Quantity')));
    expect(tester.widget<Text>(qtyField).data, '5');
    expect(
        tester
            .widget<Text>(find.descendant(
                of: ledgerCard,
                matching: find.byKey(const ValueKey('ledger-summary-Minutes'))))
            .data,
        '90');
    await tester.ensureVisible(find.text('Save daily report'));
    await tester.tap(find.text('Save daily report'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm report date'), findsOneWidget);
    await tester.tap(find.text('Confirm & Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Saved report loaded — edit the values and save again to replace this date’s entries.'),
      findsOneWidget,
    );

    // Edit the saved report from 5 to 8 and resave
    await addEmrRows(5, 8);
    expect(tester.widget<Text>(qtyField).data, '8');
    await tester.ensureVisible(find.text('Save daily report'));
    await tester.tap(find.text('Save daily report'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm report date'), findsOneWidget);
    await tester.tap(find.text('Confirm & Save'));
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
      'Admin Portal opens directly to full Dashboard, Detailed Reports, and Settings (without Daily Tasks) across all target widths',
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
        home: Portal(key: ValueKey('admin-$width'), api: adminApi),
      ));
      await tester.pumpAndSettle();

      // Admin skips branch selection and lands directly on the Performance dashboard
      expect(find.text('Select branch and category'), findsNothing);
      expect(find.text('Daily Tasks'), findsNothing);
      expect(find.text('Daily task report'), findsNothing);
      expect(find.text('Performance dashboard'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.assignment_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Staff detailed activity reports'), findsOneWidget);
      expect(find.text('SECTION: FRONT DESK'), findsOneWidget);
      expect(find.text('Individual Ledger Updated (R4) (including for insurance)'),
          findsWidgets);

      expect(find.text('Settings'), findsWidgets);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Staff management'), findsOneWidget);
      expect(find.text("DOCTOR'S ZONE"), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'Admin filter state is shared between Dashboard and Detailed Reports and strictly filters by date',
      (tester) async {
    final adminApi = FakeStaffApi(
      role: 'ADMIN',
      uid: 'admin-1',
      name: 'Clinic Admin',
    );
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year.toString().padLeft(4, "0")}-${yesterday.month.toString().padLeft(2, "0")}-${yesterday.day.toString().padLeft(2, "0")}';
    adminApi.allEntries.add({
      'uid': 'staff-1',
      'employeeName': 'Prince',
      'date': yesterdayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'ledger_updated',
      'emr': '',
      'remarks': '',
      'quantity': 12,
      'hours': 2.0,
      'Task Date': yesterdayStr,
    });

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(MaterialApp(
      theme: TaskLogStyle.dark,
      home: Portal(key: const ValueKey('admin-filter-test'), api: adminApi),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Performance dashboard'), findsOneWidget);

    // Switch Branch to ONT-BR1 on Dashboard
    await tester.tap(find.byKey(const ValueKey('BranchALL')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BR1').last);
    await tester.pumpAndSettle();

    // Switch to Detailed Reports
    await tester.tap(find.byIcon(Icons.assignment_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Staff detailed activity reports'), findsOneWidget);

    // Verify Detailed Reports has inherited ONT-BR1!
    expect(find.byKey(const ValueKey('detail-Branch-ONT-BR1')), findsOneWidget);

    // Change Section in Detailed Reports to FRONT DESK
    await tester.tap(find.byKey(const ValueKey('detail-Section-ALL')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FRONT DESK').last);
    await tester.pumpAndSettle();

    // Switch back to Dashboard and verify Section is now FRONT DESK
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('CategoryFRONT DESK')), findsOneWidget);

    // Verify Yesterday filter button is displayed with correct date and activates filter
    final yesterdayDateLabel =
        '${yesterday.day.toString().padLeft(2, "0")}/${yesterday.month.toString().padLeft(2, "0")}/${yesterday.year}';
    expect(find.text('Yesterday — $yesterdayDateLabel'), findsWidgets);
    await tester.tap(find.text('Yesterday — $yesterdayDateLabel').first);
    await tester.pumpAndSettle();

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'Admin Task Comparison page compares activities across staff with graphical bars and numbers across all widths',
      (tester) async {
    final adminApi = FakeStaffApi(
      role: 'ADMIN',
      uid: 'admin-1',
      name: 'Clinic Admin',
    );
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, "0")}-${today.month.toString().padLeft(2, "0")}-${today.day.toString().padLeft(2, "0")}';

    // Farzana did 15 appointments
    adminApi.allEntries.add({
      'uid': 'staff-1',
      'employeeName': 'Farzana',
      'date': todayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'appointments',
      'quantity': 15,
      'hours': 1.5,
      'Task Date': todayStr,
    });

    // Prince also did 10 appointments on the same date! (Multi-staff activity)
    adminApi.allEntries.add({
      'uid': 'staff-2',
      'employeeName': 'Prince',
      'date': todayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'appointments',
      'quantity': 10,
      'hours': 1.0,
      'Task Date': todayStr,
    });

    // Farzana did 25 ledgers updated
    adminApi.allEntries.add({
      'uid': 'staff-1',
      'employeeName': 'Farzana',
      'date': todayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'ledger_updated',
      'quantity': 25,
      'hours': 7.75,
      'Task Date': todayStr,
    });

    // Farzana also had EMR breakdown rows (which must merge with ledger_updated without double counting)
    adminApi.allEntries.add({
      'uid': 'staff-1',
      'employeeName': 'Farzana',
      'date': todayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'ledger_prepared',
      'emr': '1684',
      'quantity': 1,
      'hours': 0.31,
      'Task Date': todayStr,
    });
    adminApi.allEntries.add({
      'uid': 'staff-1',
      'employeeName': 'Farzana',
      'date': todayStr,
      'branch': 'ONT-BR1',
      'category': 'FRONT DESK',
      'taskId': 'ledger_prepared',
      'emr': '1685',
      'quantity': 1,
      'hours': 0.31,
      'Task Date': todayStr,
    });

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(Size(width, 900));

      await tester.pumpWidget(MaterialApp(
        theme: TaskLogStyle.dark,
        home: Portal(key: ValueKey('admin-cmp-$width'), api: adminApi),
      ));
      await tester.pumpAndSettle();

      // Tap Task Comparison navigation tab
      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();

      expect(find.text('Task & activity comparison'), findsOneWidget);
      expect(find.text('Appointments Booked'), findsWidgets);
      expect(find.text('Compared across 2 staff'), findsWidgets);
      expect(find.text('Farzana'), findsWidgets);
      expect(find.text('Prince'), findsWidgets);

      // Verify ledger activities are merged as one, showing EMR entries and no duplicate activity
      expect(find.text('Individual Ledger Updated (R4) (including for insurance)'),
          findsWidgets);
      expect(find.text('Individual Ledgers Prepared (EMR-wise)'), findsNothing);
      expect(find.text('EMR entries (2):'), findsWidgets);
      expect(find.text('1684, 1685'), findsWidgets);

      // Verify Farzana's workload distribution: 15 appt + 25 ledger = 40 tasks (not 42!), 1.5h + 7.75h = 9.3h (not 9.9h!)
      expect(find.text('40 tasks · 9.3h'), findsWidgets);

      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'Enquiries Handled: per-call details are saved and drive the read-only quantity and minutes',
      (tester) async {
    addTearDown(tester.view.reset);
    for (final width in const <double>[360, 390, 1280]) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 1400);
      final staffApi = FakeStaffApi(
        role: 'STAFF',
        uid: 'staff-farzana',
        name: 'Farzana',
      );
      // Fresh app (and ScaffoldMessenger) per width so a previous run's snackbar
      // cannot cover the Save button.
      await tester.pumpWidget(MaterialApp(
        key: ValueKey('enq-app-$width'),
        theme: TaskLogStyle.dark,
        home: Portal(key: ValueKey('enq-$width'), api: staffApi),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ONT-BR1').first);
      await tester.pumpAndSettle();
      expect(find.text('Enquiries Handled'), findsOneWidget);
      // Activities: 1 Registrations, 2 Enquiries Handled, 3 Ledger Updated, 4 Collection
      expect(find.text('Enquiry details — activity 2'), findsOneWidget);

      // Activity 2's quantity / minutes are read-only and start at 0.
      expect(find.text('Auto-calculated from enquiry calls below'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('enquiry-summary-Quantity')),
          findsOneWidget);

      // Two enquiry rows are numbered 1 and 2 automatically; row 2 stays blank.
      await tester.ensureVisible(find.byKey(const ValueKey('add-enquiry')));
      await tester.tap(find.byKey(const ValueKey('add-enquiry')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('add-enquiry')));
      await tester.tap(find.byKey(const ValueKey('add-enquiry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('enq-row-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('enq-row-1')), findsOneWidget);
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Caller name').first, 'Mrs Sharma');
      await tester.enterText(find.widgetWithText(TextField, 'Remarks').first,
          'Asked about braces');
      // Minutes fields: [0] registrations, [1] enquiry row 1
      await tester.enterText(
          find.widgetWithText(TextField, 'Minutes').at(1), '10');
      await tester.pump();
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('enquiry-summary-Quantity')))
              .data,
          '1');
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('enquiry-summary-Minutes')))
              .data,
          '10');
      await tester.ensureVisible(find.byKey(const ValueKey('enq-status-0-')));
      await tester.tap(find.byKey(const ValueKey('enq-status-0-')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appointment booked').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save daily report'));
      await tester.tap(find.text('Save daily report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Save'));
      await tester.pumpAndSettle();

      final saved = staffApi.allEntries
          .where((e) => e['uid'] == 'staff-farzana')
          .toList();
      final activity = saved.singleWhere((e) => e['taskId'] == 'enquiries');
      expect(activity['quantity'], 1,
          reason: 'quantity = number of worthwhile call rows');
      expect(activity['hours'], closeTo(10 / 60, 1e-9),
          reason: 'minutes = sum of the call minutes');
      final details =
          saved.where((e) => e['taskId'] == 'enquiry_detail').toList();
      expect(details, hasLength(1), reason: 'the blank row is not saved');
      expect(details.single['emr'], '1');
      expect(details.single['callerName'], 'Mrs Sharma');
      expect(details.single['callStatus'], 'Appointment booked');
      expect(details.single['remarks'], 'Asked about braces');
      expect(details.single['hours'], closeTo(10 / 60, 1e-9));

      // Reloaded from the saved report: the call is restored, blank row is gone.
      expect(find.byKey(const ValueKey('enq-row-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('enq-row-1')), findsNothing);
      expect(find.text('Mrs Sharma'), findsOneWidget);
      expect(find.text('Appointment booked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Enquiry call details appear under activity 7 in the Detailed Report but never count toward totals',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 1600);
    final adminApi = FakeStaffApi(
      role: 'ADMIN',
      uid: 'admin-1',
      name: 'Clinic Admin',
    );
    final today = FakeStaffApi._todayStr();
    Map<String, dynamic> row(String task, num qty, double hrs,
            {String emr = '',
            String remarks = '',
            String caller = '',
            String phone = '',
            String status = ''}) =>
        {
          'uid': 'staff-farzana',
          'employeeName': 'Farzana',
          'date': today,
          'Task Date': today,
          'branch': 'ONT-BR1',
          'category': 'FRONT DESK',
          'taskId': task,
          'emr': emr,
          'remarks': remarks,
          'quantity': qty,
          'hours': hrs,
          'callerName': caller,
          'callerPhone': phone,
          'callStatus': status,
        };
    adminApi.allEntries
      ..add(row('registrations', 2, 30 / 60))
      ..add(row('enquiries', 3, 25 / 60))
      ..add(row('enquiry_detail', 1, 20 / 60,
          emr: '1',
          caller: 'Mrs Sharma',
          phone: '+971 50 471 3459',
          status: 'Appointment booked',
          remarks: 'Asked about braces'))
      ..add(row('enquiry_detail', 1, 40 / 60,
          emr: '2', caller: 'Mr Khan', status: 'Follow-up required'));

    await tester.pumpWidget(MaterialApp(
      theme: TaskLogStyle.dark,
      home: Portal(key: const ValueKey('enq-report'), api: adminApi),
    ));
    await tester.pumpAndSettle();

    // Dashboard: Farzana's time is 30 + 25 = 55 min (the 60 min of calls is ignored).
    expect(find.text('Farzana — Time worked'), findsOneWidget);
    expect(find.text('55 min'), findsWidgets);
    expect(find.text('1 hrs'), findsNothing);

    await tester.tap(find.byIcon(Icons.assignment_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Staff detailed activity reports'), findsOneWidget);

    // Detailed report: details are listed beneath activity "Enquiries Handled".
    expect(find.text('Enquiry details (2)'), findsOneWidget);
    expect(find.text('Mrs Sharma'), findsNWidgets(2));
    expect(find.text('+971 50 471 3459'), findsNWidgets(2));
    expect(find.text('Appointment booked'), findsOneWidget);
    expect(find.text('Remarks: Asked about braces'), findsOneWidget);
    expect(find.text('Mr Khan'), findsNWidgets(2));
    expect(find.text('Follow-up required'), findsOneWidget);
    // Totals use only the activity-level minutes (30 + 25), not the call minutes.
    expect(find.text('Total Time: 55 min'), findsOneWidget);
    // If the 60 call-minutes were counted this would read 1.92 hrs (115 min).
    expect(find.text('Total Time: 1.92 hrs (115 min)'), findsNothing);
    // The activity keeps its own typed quantity.
    expect(find.text('Qty: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'All categories (FRONT DESK, INSURANCE USER, ACCOUNTS, DOCTOR\'S ZONE) save all activities, other_tasks, EMR rows, and auto-stop timers properly',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 1600);
    final staffApi = FakeStaffApi(
      role: 'STAFF',
      uid: 'staff-all-test',
      name: 'Prince',
    );
    await tester.pumpWidget(MaterialApp(
      theme: TaskLogStyle.dark,
      home: Portal(key: const ValueKey('all-cat-save'), api: staffApi),
    ));
    await tester.pumpAndSettle();

    Future<void> clickSaveAndConfirm() async {
      final saveBtn = find.text('Save daily report');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('Confirm report date'), findsOneWidget);
      await tester.tap(find.text('Confirm & Save'));
      await tester.pumpAndSettle();
    }

    // 1. ONT-BB FRONT DESK (standard tasks + collection + EMR rows + other_tasks + running timer auto-stop)
    await tester.tap(find.text('ONT-BB').first);
    await tester.pumpAndSettle();

    // Start timer on 'registrations' and leave it running when clicking Save
    await tester.tap(find.byKey(const ValueKey('start-registrations')));
    await tester.pump(const Duration(milliseconds: 50));

    // Enter Daily collection (AED)
    final collCard = find.byKey(const ValueKey('ONT-BB|FRONT DESK|collection'));
    await tester.enterText(
        find.descendant(
            of: collCard, matching: find.widgetWithText(TextField, 'AED')),
        '1525.50');
    await tester.enterText(
        find.descendant(
            of: collCard, matching: find.widgetWithText(TextField, 'Minutes')),
        '20');

    // Add an EMR row
    await tester.ensureVisible(find.text('Add EMR'));
    await tester.tap(find.text('Add EMR'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'EMR No.').first, 'BB-101');
    await tester.enterText(
        find.widgetWithText(TextField, 'Remarks').first, 'Consultation');
    await tester.tap(find.byKey(const ValueKey('emr-start-0')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('emr-end-0')));
    await tester.pumpAndSettle();

    // Fill Other task carried out (non-ACCOUNTS category!)
    final otherField = find.widgetWithText(TextField, 'Other task carried out');
    await tester.ensureVisible(otherField);
    await tester.enterText(otherField, 'Organized reception brochures');
    final otherCard =
        find.ancestor(of: otherField, matching: find.byType(Card)).first;
    await tester.enterText(
        find.descendant(
            of: otherCard,
            matching: find.widgetWithText(TextField, 'Minutes')),
        '15');

    await clickSaveAndConfirm();

    final bbSaved = staffApi.allEntries
        .where((e) =>
            e['uid'] == 'staff-all-test' &&
            e['branch'] == 'ONT-BB' &&
            e['category'] == 'FRONT DESK')
        .toList();
    expect(bbSaved.any((e) => e['taskId'] == 'registrations'), isTrue);
    final regEntry = bbSaved.firstWhere((e) => e['taskId'] == 'registrations');
    expect(regEntry['quantity'], 1);
    expect(regEntry['startTime'], isNotNull);
    expect(regEntry['endTime'], isNotNull,
        reason: 'Running timer was auto-stopped on save');
    final collEntry = bbSaved.firstWhere((e) => e['taskId'] == 'collection');
    expect(collEntry['quantity'], 1525.50);
    final ledgerSummary =
        bbSaved.firstWhere((e) => e['taskId'] == 'ledger_updated');
    expect(ledgerSummary['quantity'], 1);
    final ledgerEmr =
        bbSaved.firstWhere((e) => e['taskId'] == 'ledger_prepared');
    expect(ledgerEmr['emr'], 'BB-101');
    expect(ledgerEmr['startTime'], isNotNull);
    expect(ledgerEmr['endTime'], isNotNull);
    final bbOther = bbSaved.firstWhere((e) => e['taskId'] == 'other_tasks');
    expect(bbOther['remarks'], 'Organized reception brochures');
    expect(bbOther['hours'], closeTo(15 / 60, 1e-6));

    // Verify restored on entry screen
    expect(find.text('Organized reception brochures'), findsOneWidget);

    // 2. ONT-BB INSURANCE USER (standard insurance tasks + insurance_ledger_emr -> insurance_emrwise + other_tasks)
    await tester.ensureVisible(find.text('ONT-BB — FRONT DESK'));
    await tester.tap(find.text('ONT-BB — FRONT DESK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BB — INSURANCE USER').last);
    await tester.pumpAndSettle();

    final claimsCard = find.byKey(
        const ValueKey('ONT-BB|INSURANCE USER|insurance_claims_prepared'));
    await tester.enterText(
        find.descendant(
            of: claimsCard,
            matching: find.widgetWithText(TextField, 'Quantity')),
        '6');
    await tester.enterText(
        find.descendant(
            of: claimsCard,
            matching: find.widgetWithText(TextField, 'Minutes')),
        '45');

    // Add 2 Insurance EMR rows and verify insurance_emrwise is auto-calculated
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Add EMR'));
      await tester.tap(find.text('Add EMR'));
      await tester.pumpAndSettle();
      final emrField = find.widgetWithText(TextField, 'EMR No.').at(i);
      await tester.enterText(emrField, 'INS-${200 + i}');
      final emrCard =
          find.ancestor(of: emrField, matching: find.byType(Card)).first;
      await tester.enterText(
          find.descendant(
              of: emrCard,
              matching: find.widgetWithText(TextField, 'Minutes')),
          '15');
      await tester.pumpAndSettle();
    }
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('ledger-summary-Quantity')))
            .data,
        '2');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('ledger-summary-Minutes')))
            .data,
        '30');

    final insOtherField =
        find.widgetWithText(TextField, 'Other task carried out');
    await tester.ensureVisible(insOtherField);
    await tester.enterText(insOtherField, 'Followed up pre-approvals');

    await clickSaveAndConfirm();

    final insSaved = staffApi.allEntries
        .where((e) =>
            e['uid'] == 'staff-all-test' &&
            e['branch'] == 'ONT-BB' &&
            e['category'] == 'INSURANCE USER')
        .toList();
    expect(
        insSaved.firstWhere(
            (e) => e['taskId'] == 'insurance_claims_prepared')['quantity'],
        6);
    final insEmrSummary =
        insSaved.firstWhere((e) => e['taskId'] == 'insurance_emrwise');
    expect(insEmrSummary['quantity'], 2);
    expect(insEmrSummary['hours'], closeTo(30 / 60, 1e-6));
    expect(
        insSaved.where((e) => e['taskId'] == 'insurance_ledger_emr').length, 2);
    expect(insSaved.firstWhere((e) => e['taskId'] == 'other_tasks')['remarks'],
        'Followed up pre-approvals');

    // 3. ONT-BR1 ACCOUNTS (Yes/No tasks + quantity tasks + 5 other_tasks slots)
    await tester.ensureVisible(find.text('ONT-BB — INSURANCE USER'));
    await tester.tap(find.text('ONT-BB — INSURANCE USER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ONT-BR1 — ACCOUNTS').last);
    await tester.pumpAndSettle();

    // Toggle Yes on Activity 15 (accounts_month_end_closing_deposit)
    final act15Card = find.byKey(
        const ValueKey('ONT-BR1|ACCOUNTS|accounts_month_end_closing_deposit'));
    await tester.ensureVisible(act15Card);
    await tester.tap(find.byKey(
        const ValueKey('yesno-accounts_month_end_closing_deposit-No')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: act15Card,
            matching: find.widgetWithText(TextField, 'Minutes')),
        '35');

    // Enter Quantity task in ACCOUNTS: Petty cash voucher entry and filing
    final pettyCard = find.byKey(
        const ValueKey('ONT-BR1|ACCOUNTS|accounts_petty_cash_voucher_entry'));
    await tester.ensureVisible(pettyCard);
    await tester.enterText(
        find.descendant(
            of: pettyCard,
            matching: find.widgetWithText(TextField, 'Quantity')),
        '12');
    await tester.enterText(
        find.descendant(
            of: pettyCard,
            matching: find.widgetWithText(TextField, 'Minutes')),
        '40');

    // Fill 2 of the 5 Other task slots in ACCOUNTS
    final accOther1 = find.widgetWithText(TextField, 'Other task 1');
    await tester.ensureVisible(accOther1);
    await tester.enterText(accOther1, 'Bank reconciliation');
    final accOther3 = find.widgetWithText(TextField, 'Other task 3');
    await tester.ensureVisible(accOther3);
    await tester.enterText(accOther3, 'Supplier statement check');

    await clickSaveAndConfirm();

    final accSaved = staffApi.allEntries
        .where((e) =>
            e['uid'] == 'staff-all-test' &&
            e['branch'] == 'ONT-BR1' &&
            e['category'] == 'ACCOUNTS')
        .toList();
    final act15Saved = accSaved.firstWhere(
        (e) => e['taskId'] == 'accounts_month_end_closing_deposit');
    expect(act15Saved['quantity'], 1);
    expect(act15Saved['hours'], closeTo(35 / 60, 1e-6));
    final pettySaved = accSaved.firstWhere(
        (e) => e['taskId'] == 'accounts_petty_cash_voucher_entry');
    expect(pettySaved['quantity'], 12);
    final accOthers =
        accSaved.where((e) => e['taskId'] == 'other_tasks').toList();
    expect(accOthers.length, 2);
    expect(accOthers[0]['emr'], '1');
    expect(accOthers[0]['remarks'], 'Bank reconciliation');
    expect(accOthers[1]['emr'], '3');
    expect(accOthers[1]['remarks'], 'Supplier statement check');

    // 4. ONT-BB DOCTOR'S ZONE (all 3 doctor tasks + other_tasks)
    await tester.ensureVisible(find.text('ONT-BR1 — ACCOUNTS'));
    await tester.tap(find.text('ONT-BR1 — ACCOUNTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("ONT-BB — DOCTOR'S ZONE").last);
    await tester.pumpAndSettle();

    for (final taskId in const [
      'doctors_consultations',
      'doctors_follow_ups',
      'doctors_treatments_supervised'
    ]) {
      final card = find.byKey(ValueKey("ONT-BB|DOCTOR'S ZONE|$taskId"));
      await tester.ensureVisible(card);
      await tester.enterText(
          find.descendant(
              of: card, matching: find.widgetWithText(TextField, 'Quantity')),
          '4');
      await tester.enterText(
          find.descendant(
              of: card, matching: find.widgetWithText(TextField, 'Minutes')),
          '30');
    }
    final docOther = find.widgetWithText(TextField, 'Other task carried out');
    await tester.ensureVisible(docOther);
    await tester.enterText(docOther, 'Reviewed clinical case notes');

    await clickSaveAndConfirm();

    final docSaved = staffApi.allEntries
        .where((e) =>
            e['uid'] == 'staff-all-test' &&
            e['branch'] == 'ONT-BB' &&
            e['category'] == "DOCTOR'S ZONE")
        .toList();
    expect(docSaved.length, 4);
    expect(docSaved.firstWhere((e) => e['taskId'] == 'other_tasks')['remarks'],
        'Reviewed clinical case notes');
    expect(tester.takeException(), isNull);
  });
}
