import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'api.dart';
import 'report_aggregation.dart';
import 'staff_detailed_report.dart' show formatRowTime;
import 'tasklog_style.dart';

enum PdfReportType { detailed, staffSummary, activitySummary }

extension on PdfReportType {
  String get label => switch (this) {
        PdfReportType.detailed => 'Detailed report',
        PdfReportType.staffSummary => 'Staff summary (accounts / salary)',
        PdfReportType.activitySummary => 'Activity summary',
      };
  String get title => switch (this) {
        PdfReportType.detailed => 'Detailed Staff Activity Report',
        PdfReportType.staffSummary => 'Staff Working Hours Summary',
        PdfReportType.activitySummary => 'Activity Summary Report',
      };
  String get fileName => switch (this) {
        PdfReportType.detailed => 'detailed_report',
        PdfReportType.staffSummary => 'staff_summary',
        PdfReportType.activitySummary => 'activity_summary',
      };
}

const String _company = 'Ontario Ayurvedic Medical Centre - TaskLog';

/// Built-in PDF fonts are Latin-1 only; replace common punctuation and any
/// other unsupported character so text never renders as blanks.
String pdfSafe(String v) => v
    .replaceAll(RegExp('[\u2013\u2014]'), '-')
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp('[\u201C\u201D]'), '"')
    .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

String _capCell(String s, [int maxLen = 350]) =>
    s.length <= maxLen ? s : '${s.substring(0, maxLen)}...';

String _two(int n) => n.toString().padLeft(2, '0');
String _stamp(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
String _t(dynamic v) => formatRowTime(v).replaceAll('—', '-');
String _q(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// True when there is nothing to put in the chosen report.
bool hasNoData(List<Map<String, dynamic>> rows) => rows.isEmpty;

Future<Uint8List> buildReportPdf({
  required PdfReportType type,
  required List<Map<String, dynamic>> rows,
  required ReportCriteria criteria,
  required String generatedBy,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final doc = pw.Document(title: type.title, author: generatedBy);
  final period = criteria.periodLabel(at);
  final format = PdfPageFormat.a4.landscape;
  final base = pw.TextStyle(fontSize: 9);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  pw.Widget header() =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(_company,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(type.title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text('Period: $period    ${criteria.describe().join('    ')}',
            style: base),
        pw.Text('Generated: ${_stamp(at)} by $generatedBy', style: base),
        pw.Divider(),
      ]);

  pw.Widget table(List<String> head, List<List<String>> data,
      {Map<int, pw.Alignment>? align,
      Map<int, pw.TableColumnWidth>? widths,
      Set<int>? highlightNegativeCols}) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: [
          for (var c = 0; c < head.length; c++)
            pw.Container(
              alignment: align?[c] ?? pw.Alignment.centerLeft,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(
                pdfSafe(head[c]),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
        ],
      ),
      for (final r in data)
        pw.TableRow(
          children: [
            for (var c = 0; c < r.length; c++)
              () {
                final text = pdfSafe(_capCell(r[c]));
                final isNegative =
                    (highlightNegativeCols?.contains(c) ?? false) &&
                        text.trim().startsWith('-');
                return pw.Container(
                  alignment: align?[c] ?? pw.Alignment.centerLeft,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: isNegative ? PdfColors.red700 : PdfColors.black,
                      fontWeight: isNegative
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                );
              }(),
          ],
        ),
    ];
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      children: tableRows,
    );
  }

  pw.Widget reportFooter(pw.Context c) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              for (final l in ['Prepared by', 'Verified by', 'Approved by'])
                pw.SizedBox(
                  width: 170,
                  child: pw.Column(children: [
                    pw.Divider(thickness: 0.6),
                    pw.Text(l, style: bold),
                    pw.Text('Name / Date',
                        style: const pw.TextStyle(fontSize: 7.5)),
                  ]),
                ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${c.pageNumber} of ${c.pagesCount}',
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      );

  if (rows.isEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      maxPages: 2000,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => header(),
      footer: reportFooter,
      build: (_) => [
        pw.Padding(
            padding: const pw.EdgeInsets.only(top: 30),
            child: pw.Text(
                'No records found for the selected filters and period.',
                style: const pw.TextStyle(fontSize: 12))),
      ],
    ));
    return doc.save();
  }

  if (type == PdfReportType.detailed) {
    for (final s in buildDetailed(rows)) {
      final userBody = <pw.Widget>[
        pw.SizedBox(height: 6),
        pw.Text(pdfSafe('Staff: ${s.name}'),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ];
      for (final d in s.days) {
        userBody.add(pw.SizedBox(height: 4));
        userBody.add(pw.Text(
            'Date: ${TaskLogStyle.dateLabel(d.date)}   Total working time: ${fmtMinutes(d.totalMinutes)}',
            style: bold));
        userBody.add(table([
          'Activity',
          'Quantity',
          'Minutes'
        ], [
          for (final a in d.activities.values)
            [
              a.isLedger
                  ? '${a.title} (EMR-wise breakdown)'
                  : a.descriptions.isNotEmpty
                      ? '${a.title}: ${a.descriptions.join('; ')}'
                      : a.title,
              a.taskId == 'collection'
                  ? 'AED ${_q(a.quantity)}'
                  : _q(a.quantity),
              '${a.minutes}',
            ]
        ], align: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight
        }, widths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
        }));
        if (d.enquiries.isNotEmpty) {
          userBody.add(pw.SizedBox(height: 3));
          userBody.add(pw.Text('Enquiry calls (activity 7)', style: bold));
          userBody.add(table([
            'Call no.',
            'Caller',
            'Phone',
            'Status',
            'Remarks',
            'Start',
            'End',
            'Min'
          ], [
            for (final e in d.enquiries)
              [
                '${e['emr'] ?? ''}',
                '${e['callerName'] ?? ''}',
                '${e['callerPhone'] ?? ''}',
                '${e['callStatus'] ?? ''}',
                '${e['remarks'] ?? ''}',
                _t(e['startTime']),
                _t(e['endTime']),
                '${((double.tryParse('${e['hours']}') ?? 0) * 60).round()}',
              ]
          ], widths: {
            4: const pw.FlexColumnWidth(2.5),
          }));
        }
        if (d.ledger.isNotEmpty) {
          userBody.add(pw.SizedBox(height: 3));
          userBody.add(pw.Text('Individual ledger - EMR-wise', style: bold));
          userBody.add(table([
            'EMR no.',
            'Remarks',
            'Start',
            'End',
            'Min'
          ], [
            for (final e in d.ledger)
              [
                '${e['emr'] ?? ''}',
                '${e['remarks'] ?? ''}',
                _t(e['startTime']),
                _t(e['endTime']),
                '${((double.tryParse('${e['hours']}') ?? 0) * 60).round()}',
              ]
          ], widths: {
            1: const pw.FlexColumnWidth(3)
          }));
        }
      }
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        maxPages: 2000,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => header(),
        footer: reportFooter,
        build: (_) => userBody,
      ));
    }
    return doc.save();
  }

  final body = <pw.Widget>[];
  if (type == PdfReportType.staffSummary) {
    final list = buildStaffSummary(rows);
    final totalDays = list.fold<int>(0, (sum, s) => sum + s.daysWorked);
    final totalStdMins = list.fold<int>(0, (sum, s) => sum + s.standardMinutes);
    final totalActMins = list.fold<int>(0, (sum, s) => sum + s.totalMinutes);
    final totalVarMins = list.fold<int>(0, (sum, s) => sum + s.varianceMinutes);
    final overallAvgMins = totalDays == 0 ? 0.0 : totalActMins / totalDays;

    body.add(pw.SizedBox(height: 6));
    body.add(table([
      'Staff',
      'Days worked',
      'Standard min',
      'Standard hrs',
      'Actual min',
      'Actual hrs',
      'Variance (min)',
      'Variance (hrs)',
      'Avg hrs / day'
    ], [
      for (final s in list)
        [
          s.name,
          '${s.daysWorked}',
          '${s.standardMinutes}',
          fmtHours(s.standardMinutes),
          '${s.totalMinutes}',
          fmtHours(s.totalMinutes),
          '${s.varianceMinutes}',
          fmtHours(s.varianceMinutes),
          fmtHours(s.avgMinutesPerDay),
        ],
      if (list.isNotEmpty)
        [
          'Total',
          '$totalDays',
          '$totalStdMins',
          fmtHours(totalStdMins),
          '$totalActMins',
          fmtHours(totalActMins),
          '$totalVarMins',
          fmtHours(totalVarMins),
          fmtHours(overallAvgMins),
        ],
    ], align: {
      for (var i = 1; i < 9; i++) i: pw.Alignment.centerRight
    }, highlightNegativeCols: const {6, 7}));
    body.add(pw.SizedBox(height: 4));
    body.add(pw.Text(
        'Standard working hours = 10.00 hrs (600 min) per day. Variance = Actual hours worked - Standard working hours (negative in red when worked less than standard hours). Daily total = sum of activity minutes (enquiry call and EMR-wise ledger minutes are breakdowns and are not added).',
        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)));
    for (final s in list) {
      body.add(pw.SizedBox(height: 10));
      body.add(pw.Text(pdfSafe('${s.name} - per day'), style: bold));
      body.add(table([
        'Date',
        'Standard min',
        'Standard hrs',
        'Actual min',
        'Actual hrs',
        'Variance (min)',
        'Variance (hrs)'
      ], [
        for (final d in s.days)
          [
            TaskLogStyle.dateLabel(d.date),
            '${d.standardMinutes}',
            fmtHours(d.standardMinutes),
            '${d.minutes}',
            fmtHours(d.minutes),
            '${d.varianceMinutes}',
            fmtHours(d.varianceMinutes),
          ],
        [
          'Total (${s.daysWorked} ${s.daysWorked == 1 ? 'day' : 'days'})',
          '${s.standardMinutes}',
          fmtHours(s.standardMinutes),
          '${s.totalMinutes}',
          fmtHours(s.totalMinutes),
          '${s.varianceMinutes}',
          fmtHours(s.varianceMinutes),
        ],
      ], align: {
        for (var i = 1; i < 7; i++) i: pw.Alignment.centerRight
      }, highlightNegativeCols: const {5, 6}));
    }
  } else {
    final list = buildActivitySummary(rows);
    final staffSet = <String>{
      for (final a in list) ...a.byUser.keys,
    };
    final staffWorkingMins = <String, int>{};
    for (final r in rows) {
      final rawName = (r['employeeName'] ?? '').toString().trim();
      final name = rawName.isNotEmpty
          ? rawName
          : (r['uid'] ?? '').toString().trim().toLowerCase();
      if (name.isNotEmpty) {
        staffSet.add(name);
        staffWorkingMins[name] =
            (staffWorkingMins[name] ?? 0) + countedMinutes(r);
      }
    }
    final staffNames = staffSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String formatCell(ActivityTotal a, UserActivityDetail? c) {
      if (c == null || (c.quantity == 0 && c.minutes == 0)) {
        return '-';
      }
      final qPart =
          a.isCollection ? 'AED ${_q(c.quantity)}' : 'Qty: ${_q(c.quantity)}';
      final mPart = '${c.minutes} min';
      return '$qPart ($mPart)';
    }

    String formatTotalCell(ActivityTotal a) {
      final qPart =
          a.isCollection ? 'AED ${_q(a.quantity)}' : 'Qty: ${_q(a.quantity)}';
      return '$qPart (${a.minutes} min)';
    }

    final grandTotalMins =
        staffWorkingMins.values.fold<int>(0, (sum, m) => sum + m);

    final headers = <String>[
      'Activity',
      ...staffNames,
      'Total',
    ];

    final tableRows = <List<String>>[
      for (final a in list)
        [
          a.isLedger ? '${a.title} *' : a.title,
          for (final u in staffNames) formatCell(a, a.byUser[u]),
          formatTotalCell(a),
        ],
      if (staffNames.isNotEmpty)
        [
          'Total Working Time',
          for (final u in staffNames)
            '${staffWorkingMins[u] ?? 0} min (${fmtHours(staffWorkingMins[u] ?? 0)} hrs)',
          '$grandTotalMins min (${fmtHours(grandTotalMins)} hrs)',
        ],
    ];

    body.add(pw.SizedBox(height: 6));
    body.add(table(
      headers,
      tableRows,
      align: {
        0: pw.Alignment.centerLeft,
        for (var i = 1; i <= staffNames.length + 1; i++) i: pw.Alignment.center,
      },
      widths: {
        0: const pw.FlexColumnWidth(2.6),
        for (var i = 1; i <= staffNames.length; i++)
          i: const pw.FlexColumnWidth(1.2),
        staffNames.length + 1: const pw.FlexColumnWidth(1.3),
      },
    ));
    body.add(pw.SizedBox(height: 4));
    body.add(pw.Text(
        '* EMR-wise ledger minutes are a breakdown and are excluded from working-time totals.',
        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)));
  }

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    maxPages: 2000,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => header(),
    footer: reportFooter,
    build: (_) => body,
  ));
  return doc.save();
}

/// Admin dialog: choose a report, fetch the range from the API using the
/// current filters, then preview/print or share the PDF.
class PayrollReportsDialog extends StatefulWidget {
  const PayrollReportsDialog({
    super.key,
    required this.criteria,
    required this.generatedBy,
    this.api,
    this.preloadedEntries,
  });
  final ReportCriteria criteria;
  final String generatedBy;
  final StaffApi? api;
  final List<dynamic>? preloadedEntries;

  @override
  State<PayrollReportsDialog> createState() => _PayrollReportsDialogState();
}

class _PayrollReportsDialogState extends State<PayrollReportsDialog> {
  late final StaffApi api = widget.api ?? StaffApi();
  PdfReportType type = PdfReportType.detailed;
  bool busy = false;
  String? error;

  Future<void> _run(bool share) async {
    if (busy) return;
    final now = DateTime.now();
    final r = widget.criteria.range(now);
    if (r.to.difference(r.from).inDays + 1 > maxRangeDays) {
      setState(() => error = friendlyReportError('Date range too large'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = widget.criteria;
      final fromIso = isoDate(r.from);
      final toIso = isoDate(r.to);
      final cutoffIso = isoDate(
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 355)));
      List<dynamic> rawEntries;
      if (widget.preloadedEntries != null &&
          widget.preloadedEntries!.isNotEmpty &&
          fromIso.compareTo(cutoffIso) >= 0) {
        rawEntries = widget.preloadedEntries!.where((e) {
          if (e is! Map) return false;
          final d = TaskLogStyle.parseEntryDate(e['Task Date'] ?? e['date']);
          if (d == null) return false;
          final dIso = isoDate(d);
          return dIso.compareTo(fromIso) >= 0 && dIso.compareTo(toIso) <= 0;
        }).toList();
      } else {
        final res = await api.request('report', body: {
          'from': fromIso,
          'to': toIso,
          if (c.branch != 'ALL') 'branch': c.branch,
          if (c.category != 'ALL') 'category': c.category,
        }).timeout(const Duration(seconds: 60));
        rawEntries = List.from(res['entries'] ?? []);
      }
      final rows = filterEntries(rawEntries, c);
      final bytes = await buildReportPdf(
          type: type,
          rows: rows,
          criteria: c,
          generatedBy: widget.generatedBy,
          now: now);
      final name = '${type.fileName}_${isoDate(r.from)}_${isoDate(r.to)}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(
            name: name,
            format: PdfPageFormat.a4.landscape,
            onLayout: (_) async => bytes);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyReportError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criteria;
    return MouseRegion(
      cursor: busy ? SystemMouseCursors.wait : MouseCursor.defer,
      child: AlertDialog(
        title: const Text('Export PDF report'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period: ${c.periodLabel(DateTime.now())}'),
            for (final l in c.describe()) Text(l),
            const SizedBox(height: 8),
            for (final t in PdfReportType.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  type == t
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: type == t ? TaskLogStyle.teal : TaskLogStyle.muted,
                ),
                title: Text(t.label),
                onTap: busy ? null : () => setState(() => type = t),
              ),
            if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close')),
          OutlinedButton.icon(
              onPressed: busy ? null : () => _run(true),
              icon: const Icon(Icons.download),
              label: const Text('Download / share')),
          FilledButton.icon(
              onPressed: busy ? null : () => _run(false),
              icon: const Icon(Icons.print),
              label: const Text('Preview / print')),
        ],
      ),
    );
  }
}

Future<void> showPayrollReportsDialog(
        BuildContext context, ReportCriteria c, String by,
        {List<dynamic>? preloadedEntries}) =>
    showDialog(
        context: context,
        builder: (_) => PayrollReportsDialog(
              criteria: c,
              generatedBy: by,
              preloadedEntries: preloadedEntries,
            ));
