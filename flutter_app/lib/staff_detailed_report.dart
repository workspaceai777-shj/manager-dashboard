import 'package:flutter/material.dart';
import 'tasklog_style.dart';

class StaffDetailedReport extends StatefulWidget {
  const StaffDetailedReport({
    super.key,
    required this.records,
    required this.refresh,
    this.staffNames = const <String>[],
  });

  final List<dynamic> records;
  final Future<void> Function() refresh;
  final List<String> staffNames;

  @override
  State<StaffDetailedReport> createState() => _StaffDetailedReportState();
}

class _StaffDetailedReportState extends State<StaffDetailedReport> {
  String branch = 'ALL', category = 'ALL', employee = 'ALL';
  DateTime? singleDate;
  DateTimeRange? period;
  bool todayOnly = true;

  static const Set<String> _yesNoTaskIds = {
    'accounts_collection_check',
    'accounts_dha_attendance',
    'accounts_petty_cash',
    'accounts_month_end',
    'accounts_reception',
    'room_chore_inspection',
    'daily_collection_billing_done',
  };

  static const List<String> _sectionOrder = [
    'FRONT DESK',
    'INSURANCE USER',
    'ACCOUNTS',
    "DOCTOR'S ZONE",
  ];

  static String activityTitle(String branch, String category, String taskId) {
    if (taskId == 'other_tasks') {
      return 'Other task carried out';
    }
    if (branch == 'ONT-BB' && category == 'FRONT DESK') {
      const bbMap = {
        'registrations': 'New patient registration and cards prepared',
        'whatsapp': 'WhatsApp messages checked and responded',
        'therapist_schedule': 'Therapist schedule arranged and posted',
        'reminders': 'Next-day WhatsApp reminders sent',
        'billing_excel': 'Billing and daily collection Excel prepared',
        'registration_excel': 'New registration Excel updated',
        'appointments': 'Appointments, arrival and reporting vouchers',
        'collection': 'Daily collection (AED)',
        'card_details': 'Card date/time, therapist and treatment entered',
        'patient_cards': 'Treatment Charts & Reporting Vouchers prepared',
        'charts':
            'Charts prepared for next day including session & rearranged all cards.',
        'cards_arranged':
            'Charts prepared for next day including session & rearranged all cards.',
        'ledger_updated': 'Next-day individual ledgers updated',
        'room_chore_inspection': 'Room Chore Inspection',
        'daily_collection_billing_done':
            'Daily Collection in Excel & Billing in software Done',
        'daily_task_updation': 'Daily Task Updation',
        'ledger_prepared': 'Individual Ledgers Prepared (EMR-wise)',
      };
      if (bbMap.containsKey(taskId)) return bbMap[taskId]!;
    }
    const generalMap = {
      // Front Desk (ONT-BR1 & general)
      'registrations':
          'Patient Registrations (including treatment chart and case sheet)',
      'appointments': 'Appointments Booked',
      'calls': 'Calls Attended',
      'whatsapp': 'WhatsApp Enquiries Replied',
      'confirmations': 'Confirmation Messages Sent',
      'consultations': 'Consultations Coordinated',
      'enquiries': 'Enquiries Handled',
      'registration_excel': 'Patient Registration Excel updated',
      'ledger_prepared': 'Individual Ledgers Prepared (EMR-wise)',
      'ledger_updated': 'Ledgers Updated (R4)',
      'patient_cards': 'Treatment Charts & Reporting Vouchers prepared',
      'charts':
          'Charts prepared for next day including session & rearranged all cards.',
      'cards_arranged':
          'Charts prepared for next day including session & rearranged all cards.',
      'patient_documents': 'Patient Documents Updated',
      'emr_updated': 'EMR Records Updated',
      'appointment_excel': 'Appointment Excel Records Updated',
      'due_checked': 'Next Day Appointment Due Checked',
      'room_chore_inspection': 'Room Chore Inspection',
      'daily_collection_billing_done':
          'Daily Collection in Excel & Billing in software Done',
      'daily_task_updation': 'Daily Task Updation',
      'collection': 'Daily Collection (AED)',
      // Insurance User
      'insurance_claims_prepared': 'Insurance Claims Prepared',
      'insurance_invoices': 'Insurance Invoices Prepared',
      'insurance_documents': 'Insurance Documents Sent',
      'insurance_datewise': 'Insurance Datewise Updated',
      'insurance_emrwise': 'Insurance EMRwise Updated',
      'insurance_ledger_emr': 'Insurance EMR-wise Entry',
      // Accounts
      'accounts_collection_check':
          'Daily Collections Checked — White Fox and Ontario',
      'accounts_dha_attendance': 'DHA Attendance Records Updated',
      'accounts_insurance_ledgers':
          'Individual Ledgers for Insurance Updated & Showed',
      'accounts_petty_cash': 'Petty Cash Filing Completed',
      'accounts_month_end':
          'Month-End Collection Closing and Bank Deposit Handover',
      'accounts_reception': 'Reception Duties and Reporting Vouchers',
      'accounts_zoho_updation': 'Zoho updation',
      'accounts_vat_excel_ontario': 'Vat excel entry Ontario',
      'accounts_vat_filing_ontario': 'Vat filing Ontario',
      'accounts_vat_excel_whitefox': 'Vat excel updation White fox',
      'accounts_vat_filing_whitefox': 'Vat filing White fox',
      'accounts_cash_in_hand_checking': 'Cash in hand checking',
      'accounts_staff_attendance': 'Staff attendance Ontario and Whitefox',
      'accounts_towel_import_invoice':
          'Towel import invoice preparation, cash collect from customer and excel update',
      'accounts_medicine_collect_whitefox':
          'Medicine collect from supplier for whitefox and invoice updated',
      'accounts_month_end_closing_deposit':
          'Month end closing and cash handover for deposit',
      'accounts_whitefox_consignment_sale':
          'White fox Consignment basis sale checking and update',
      'accounts_petty_cash_voucher_entry':
          'Petty cash voucher entry and filing',
      'accounts_petty_cash_excel': 'Petty cash excel',
      'accounts_monthly_collection_excel': 'Monthly collection excel',
      'accounts_purchase_request_month': 'Purchase request for one month',
      // Doctor's Zone
      'doctors_consultations': 'Number of Consultations',
      'doctors_follow_ups': 'Number of Follow-ups',
      'doctors_treatments_supervised': 'Number of Treatments Supervised',
    };
    return generalMap[taskId] ?? taskId.replaceAll('_', ' ');
  }

  String dateLabel(DateTime d) => [
        d.day.toString().padLeft(2, '0'),
        d.month.toString().padLeft(2, '0'),
        d.year.toString()
      ].join('/');

  String formatDateString(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return dateLabel(d);
  }

  double numVal(dynamic x) => double.tryParse(x.toString()) ?? 0;

  String formatDuration(double hoursVal) {
    final totalMins = (hoursVal * 60).round();
    if (totalMins <= 0) return '0 min';
    if (totalMins < 60) {
      return '$totalMins min';
    }
    return '${hoursVal.toStringAsFixed(2)} hrs ($totalMins min)';
  }

  List<String> options(String key) {
    final defaults = key == 'branch'
        ? const ['ONT-BB', 'ONT-BR1']
        : key == 'category'
            ? _sectionOrder
            : key == 'employeeName'
                ? widget.staffNames
                : const <String>[];
    return <String>{
      'ALL',
      ...defaults.where((v) => v.trim().toLowerCase() != 'administrator'),
      ...widget.records.map((e) => (e[key] ?? '').toString().trim()).where(
          (v) =>
              v.isNotEmpty &&
              (key != 'employeeName' || v.toLowerCase() != 'administrator')),
    }.toList();
  }

  List<Map<String, dynamic>> get filteredRows => widget.records
      .where((e) {
        if ((e['employeeName'] ?? '').toString().trim().toLowerCase() ==
            'administrator') {
          return false;
        }
        if (branch != 'ALL' && e['branch'] != branch) {
          return false;
        }
        if (category != 'ALL' && e['category'] != category) {
          return false;
        }
        if (employee != 'ALL' && e['employeeName'] != employee) {
          return false;
        }
        if (todayOnly || singleDate != null || period != null) {
          final d = DateTime.tryParse(e['date'].toString());
          if (todayOnly) {
            final today = DateTime.now();
            return d != null &&
                d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
          }
          if (singleDate != null) {
            return d != null &&
                d.year == singleDate!.year &&
                d.month == singleDate!.month &&
                d.day == singleDate!.day;
          }
          if (d == null ||
              d.isBefore(period!.start) ||
              d.isAfter(period!.end)) {
            return false;
          }
        }
        return true;
      })
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Widget picker(String name, String selected, List<String> opts,
          ValueChanged<String?> change) =>
      SizedBox(
        width: MediaQuery.sizeOf(context).width < 620
            ? (MediaQuery.sizeOf(context).width - 48) / 2
            : 185,
        child: InputDecorator(
          decoration: InputDecoration(labelText: name, isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey('detail-$name-$selected'),
              isExpanded: true,
              isDense: true,
              value: opts.contains(selected) ? selected : 'ALL',
              items: opts
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: change,
            ),
          ),
        ),
      );

  String describeRowTextWise(Map<String, dynamic> row) {
    final b = (row['branch'] ?? '').toString();
    final c = (row['category'] ?? '').toString();
    final taskId = (row['taskId'] ?? '').toString();
    final title = activityTitle(b, c, taskId);
    final q = numVal(row['quantity']);
    final h = numVal(row['hours']);
    final emr = (row['emr'] ?? '').toString().trim();
    final remarks = (row['remarks'] ?? '').toString().trim();
    final timeStr = formatDuration(h);

    if (taskId == 'other_tasks') {
      final desc = remarks.isNotEmpty ? remarks : 'Unspecified task';
      return 'Other task carried out: "$desc" (Time: $timeStr)';
    }
    if (taskId == 'ledger_prepared' || taskId == 'insurance_ledger_emr') {
      final remarkPart = remarks.isNotEmpty ? ', Remarks: "$remarks"' : '';
      return '$title — EMR: $emr$remarkPart (Time: $timeStr)';
    }
    if (taskId == 'collection') {
      return '$title: AED ${q.toStringAsFixed(2)}${h > 0 ? " (Time: $timeStr)" : ""}';
    }
    if (_yesNoTaskIds.contains(taskId)) {
      final yn = q >= 1 ? 'Yes' : 'No';
      return '$title: $yn (Time: $timeStr)';
    }
    final remarkPart = remarks.isNotEmpty ? ' — "$remarks"' : '';
    return '$title$remarkPart (Qty: ${q.toStringAsFixed(0)}, Time: $timeStr)';
  }

  String formatQuantityOrStatus(Map<String, dynamic> row) {
    final taskId = (row['taskId'] ?? '').toString();
    final q = numVal(row['quantity']);
    if (taskId == 'collection') {
      return 'AED ${q.toStringAsFixed(2)}';
    }
    if (_yesNoTaskIds.contains(taskId)) {
      return q >= 1 ? 'Yes' : 'No';
    }
    if (taskId == 'other_tasks') {
      return 'Completed';
    }
    if (taskId == 'ledger_prepared' || taskId == 'insurance_ledger_emr') {
      final emr = (row['emr'] ?? '').toString().trim();
      return emr.isNotEmpty ? 'EMR: $emr' : '1';
    }
    return 'Qty: ${q.toStringAsFixed(0)}';
  }

  static List<String> catalogIds(String branch, String category) {
    switch (category.toUpperCase()) {
      case "DOCTOR'S ZONE":
        return const [
          'doctors_consultations',
          'doctors_follow_ups',
          'doctors_treatments_supervised',
        ];
      case 'INSURANCE USER':
        return const [
          'insurance_claims_prepared',
          'insurance_invoices',
          'insurance_documents',
          'insurance_datewise',
          'insurance_emrwise',
          'insurance_ledger_emr',
        ];
      case 'ACCOUNTS':
        return const [
          'accounts_collection_check',
          'accounts_dha_attendance',
          'accounts_insurance_ledgers',
          'accounts_petty_cash',
          'accounts_month_end',
          'accounts_reception',
          'accounts_zoho_updation',
          'accounts_vat_excel_ontario',
          'accounts_vat_filing_ontario',
          'accounts_vat_excel_whitefox',
          'accounts_vat_filing_whitefox',
          'accounts_cash_in_hand_checking',
          'accounts_staff_attendance',
          'accounts_towel_import_invoice',
          'accounts_medicine_collect_whitefox',
          'accounts_month_end_closing_deposit',
          'accounts_whitefox_consignment_sale',
          'accounts_petty_cash_voucher_entry',
          'accounts_petty_cash_excel',
          'accounts_monthly_collection_excel',
          'accounts_purchase_request_month',
        ];
    }
    if (branch == 'ONT-BB') {
      return const [
        'registrations',
        'whatsapp',
        'therapist_schedule',
        'reminders',
        'billing_excel',
        'registration_excel',
        'appointments',
        'collection',
        'card_details',
        'patient_cards',
        'charts',
        'ledger_updated',
        'room_chore_inspection',
        'daily_collection_billing_done',
        'daily_task_updation',
        'ledger_prepared',
      ];
    }
    return const [
      'registrations',
      'appointments',
      'calls',
      'whatsapp',
      'confirmations',
      'consultations',
      'enquiries',
      'registration_excel',
      'ledger_prepared',
      'ledger_updated',
      'patient_cards',
      'charts',
      'patient_documents',
      'emr_updated',
      'appointment_excel',
      'due_checked',
      'room_chore_inspection',
      'daily_collection_billing_done',
      'daily_task_updation',
      'collection',
    ];
  }

  /// Every activity of the section in catalog order; activities the staff member
  /// did not record are shown as "Not entered" so nothing appears to be missing.
  List<Map<String, dynamic>> buildDisplayRows(
      String branch, String category, List<Map<String, dynamic>> recorded) {
    final out = <Map<String, dynamic>>[];
    final used = <int>{};
    for (final id in catalogIds(branch, category)) {
      var found = false;
      for (var i = 0; i < recorded.length; i++) {
        if ((recorded[i]['taskId'] ?? '').toString() == id) {
          out.add(recorded[i]);
          used.add(i);
          found = true;
        }
      }
      if (!found) {
        out.add({
          'taskId': id,
          'branch': branch,
          'category': category,
          'quantity': 0,
          'hours': 0,
          '_missing': true
        });
      }
    }
    for (var i = 0; i < recorded.length; i++) {
      if (!used.contains(i)) out.add(recorded[i]);
    }
    return out;
  }

  /// Task quantity counted for comparison: excludes collection amounts,
  /// yes/no checks and free-text "other task" entries.
  double countedQuantity(Map<String, dynamic> r) {
    final id = (r['taskId'] ?? '').toString();
    if (id == 'collection' ||
        id == 'other_tasks' ||
        _yesNoTaskIds.contains(id)) {
      return 0;
    }
    return numVal(r['quantity']);
  }

  Widget threeDayComparison() {
    final today = DateTime.now();
    final days = [
      for (var i = 0; i < 3; i++)
        DateTime(today.year, today.month, today.day).subtract(Duration(days: i))
    ];
    bool sameDay(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;
    final scoped = widget.records.where((e) {
      final name = (e['employeeName'] ?? '').toString().trim();
      if (name.toLowerCase() == 'administrator') return false;
      if (branch != 'ALL' && e['branch'] != branch) return false;
      if (category != 'ALL' && e['category'] != category) return false;
      if (employee != 'ALL' && name != employee) return false;
      return true;
    });
    final byStaff = <String, List<dynamic>>{};
    for (final e in scoped) {
      byStaff
          .putIfAbsent((e['employeeName'] ?? '').toString().trim(), () => [])
          .add(e);
    }
    final names = byStaff.keys.toList()..sort();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF20334F), Color(0xFF132138)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaskLogStyle.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 3 days comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Task quantity and time consumed per staff member',
              style: TextStyle(color: TaskLogStyle.muted, fontSize: 13)),
          const SizedBox(height: 14),
          if (names.isEmpty)
            const Text('No activity records',
                style: TextStyle(color: TaskLogStyle.muted))
          else
            ...names.map((name) {
              final perDay = days.map((d) {
                final rs = byStaff[name]!.where(
                    (e) => sameDay(DateTime.tryParse(e['date'].toString()), d));
                final q = rs.fold<double>(
                    0,
                    (a, r) =>
                        a +
                        countedQuantity(Map<String, dynamic>.from(r as Map)));
                final h = rs.fold<double>(0, (a, r) => a + numVal(r['hours']));
                return (d, q, h);
              }).toList();
              final maxH =
                  perDay.fold<double>(0, (a, e) => e.$3 > a ? e.$3 : a);
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TaskLogStyle.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TaskLogStyle.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person,
                          size: 16, color: TaskLogStyle.teal),
                      const SizedBox(width: 6),
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                    const SizedBox(height: 10),
                    ...perDay.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(width: 74, child: Text(dateLabel(e.$1),
                                    style: const TextStyle(fontSize: 12.5))),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: maxH <= 0
                                    ? 0
                                    : (e.$3 / maxH).clamp(0.0, 1.0),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 58,
                              child: Text('Qty: ${e.$2.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            SizedBox(
                              width: 84,
                              child: Text(
                                  formatDuration(e.$3).split(' (').first,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: TaskLogStyle.teal)),
                            ),
                          ]),
                        )),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = filteredRows;

    // Group rows by Section (category) -> Staff + Date + Branch
    final sections = <String, List<Map<String, dynamic>>>{};
    for (final s in _sectionOrder) {
      sections[s] = [];
    }
    for (final r in rows) {
      final sec = (r['category'] ?? 'OTHER').toString().trim();
      sections.putIfAbsent(sec, () => []).add(r);
    }

    final activeSections = sections.entries
        .where((e) =>
            e.value.isNotEmpty && (category == 'ALL' || e.key == category))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff detailed activity reports',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: TaskLogStyle.ink,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Section-wise activities and time taken by each staff member, with a 3-day comparison',
                    style: TextStyle(color: TaskLogStyle.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            picker('Branch', branch, options('branch'),
                (v) => setState(() => branch = v ?? 'ALL')),
            picker('Section', category, options('category'),
                (v) => setState(() => category = v ?? 'ALL')),
            picker('Employee', employee, options('employeeName'),
                (v) => setState(() => employee = v ?? 'ALL')),
            todayOnly
                ? FilledButton.tonalIcon(
                    icon: const Icon(Icons.today),
                    onPressed: () => setState(() {
                      todayOnly = true;
                      singleDate = null;
                      period = null;
                    }),
                    label: Text('Today — ${dateLabel(DateTime.now())}'),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.today),
                    onPressed: () => setState(() {
                      todayOnly = true;
                      singleDate = null;
                      period = null;
                    }),
                    label: Text('Today — ${dateLabel(DateTime.now())}'),
                  ),
            singleDate != null
                ? FilledButton.tonalIcon(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final v = await showDatePicker(
                        context: context,
                        initialDate: singleDate ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2036),
                      );
                      if (v != null) {
                        setState(() {
                          todayOnly = false;
                          singleDate = DateTime(v.year, v.month, v.day);
                          period = null;
                        });
                      }
                    },
                    label: Text('Date — ${dateLabel(singleDate!)}'),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final v = await showDatePicker(
                        context: context,
                        initialDate: singleDate ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2036),
                      );
                      if (v != null) {
                        setState(() {
                          todayOnly = false;
                          singleDate = DateTime(v.year, v.month, v.day);
                          period = null;
                        });
                      }
                    },
                    label: const Text('Choose date'),
                  ),
            period != null
                ? FilledButton.tonalIcon(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final v = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2036),
                        initialDateRange: period,
                      );
                      if (v != null) {
                        setState(() {
                          todayOnly = false;
                          singleDate = null;
                          period = v;
                        });
                      }
                    },
                    label: Text(
                        '${dateLabel(period!.start)} – ${dateLabel(period!.end)}'),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final v = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2036),
                        initialDateRange: period,
                      );
                      if (v != null) {
                        setState(() {
                          todayOnly = false;
                          singleDate = null;
                          period = v;
                        });
                      }
                    },
                    label: const Text('Choose date range'),
                  ),
            (!todayOnly && singleDate == null && period == null)
                ? FilledButton.tonalIcon(
                    icon: const Icon(Icons.all_inclusive),
                    onPressed: () => setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = null;
                    }),
                    label: const Text('All loaded dates'),
                  )
                : TextButton(
                    onPressed: () => setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = null;
                    }),
                    child: const Text('All loaded dates'),
                  ),
          ],
        ),
        const SizedBox(height: 24),
        threeDayComparison(),
        if (activeSections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF20334F), Color(0xFF132138)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TaskLogStyle.border),
            ),
            child: const Center(
              child: Text(
                'No detailed staff activity records found for the selected filter and date.',
                style: TextStyle(color: TaskLogStyle.muted, fontSize: 15),
              ),
            ),
          )
        else
          ...activeSections.map((sectionEntry) {
            final sectionName = sectionEntry.key;
            final sectionRows = sectionEntry.value;

            // Group within section by (employeeName, date, branch)
            final staffGroups = <String, List<Map<String, dynamic>>>{};
            for (final r in sectionRows) {
              final emp = (r['employeeName'] ?? 'Unknown').toString().trim();
              final dt = (r['date'] ?? '').toString().trim();
              final br = (r['branch'] ?? '').toString().trim();
              final key = '$emp|$dt|$br';
              staffGroups.putIfAbsent(key, () => []).add(r);
            }

            final sortedGroupKeys = staffGroups.keys.toList()
              ..sort((a, b) {
                final partsA = a.split('|');
                final partsB = b.split('|');
                // Sort by date descending, then employee name ascending
                final dateCmp = partsB[1].compareTo(partsA[1]);
                if (dateCmp != 0) return dateCmp;
                return partsA[0].compareTo(partsB[0]);
              });

            final sectionTotalHours = sectionRows.fold<double>(
                0.0, (sum, r) => sum + numVal(r['hours']));

            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF20334F), Color(0xFF132138)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TaskLogStyle.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: TaskLogStyle.teal.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    TaskLogStyle.teal.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_copy_outlined,
                                  size: 16, color: TaskLogStyle.teal),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'SECTION: $sectionName',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: TaskLogStyle.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${sortedGroupKeys.length} staff report(s)  •  Section total time: ${formatDuration(sectionTotalHours)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: TaskLogStyle.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...sortedGroupKeys.map((groupKey) {
                      final groupRows = staffGroups[groupKey]!;
                      final first = groupRows.first;
                      final empName =
                          (first['employeeName'] ?? 'Unknown').toString();
                      final rawDate = (first['date'] ?? '').toString();
                      final formattedDate = formatDateString(rawDate);
                      final brName = (first['branch'] ?? '').toString();
                      final empHours = groupRows.fold<double>(
                          0.0, (sum, r) => sum + numVal(r['hours']));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TaskLogStyle.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TaskLogStyle.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(Icons.person,
                                    size: 18, color: TaskLogStyle.teal),
                                Text(
                                  empName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: TaskLogStyle.ink,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF20334F),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: TaskLogStyle.border),
                                  ),
                                  child: Text(
                                    brName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: TaskLogStyle.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF20334F),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: TaskLogStyle.border),
                                  ),
                                  child: Text(
                                    'Date: $formattedDate',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: TaskLogStyle.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TaskLogStyle.teal
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: TaskLogStyle.teal
                                            .withValues(alpha: 0.45)),
                                  ),
                                  child: Text(
                                    'Total Time: ${formatDuration(empHours)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: TaskLogStyle.teal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Activity-wise Breakdown',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TaskLogStyle.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...buildDisplayRows(brName, sectionName, groupRows)
                                .asMap()
                                .entries
                                .map((entry) {
                              final idx = entry.key + 1;
                              final r = entry.value;
                              final taskId = (r['taskId'] ?? '').toString();
                              final title =
                                  activityTitle(brName, sectionName, taskId);
                              final emr = (r['emr'] ?? '').toString().trim();
                              final remarks =
                                  (r['remarks'] ?? '').toString().trim();
                              final missing = r['_missing'] == true;
                              final qtyStatus = missing
                                  ? 'Not entered'
                                  : formatQuantityOrStatus(r);
                              final timeTaken = missing
                                  ? '—'
                                  : formatDuration(numVal(r['hours']));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2942),
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: TaskLogStyle.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LayoutBuilder(builder: (context, itemC) {
                                      final narrowItem = itemC.maxWidth < 460;
                                      if (narrowItem) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$idx. ',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: TaskLogStyle.teal,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13.5,
                                                      color: TaskLogStyle.ink,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 20),
                                              child: Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    qtyStatus,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12.5,
                                                      color: TaskLogStyle.ink,
                                                    ),
                                                  ),
                                                  Text(
                                                    timeTaken,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12.5,
                                                      color: TaskLogStyle.teal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$idx. ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: TaskLogStyle.teal,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                                color: TaskLogStyle.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            qtyStatus,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                              color: TaskLogStyle.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            timeTaken,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                              color: TaskLogStyle.teal,
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    if (emr.isNotEmpty ||
                                        remarks.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 20),
                                        child: Text(
                                          [
                                            if (emr.isNotEmpty) 'EMR No: $emr',
                                            if (remarks.isNotEmpty)
                                              taskId == 'other_tasks'
                                                  ? 'Description: $remarks'
                                                  : 'Remarks: $remarks',
                                          ].join('   |   '),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: TaskLogStyle.muted,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
