import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'tasklog_style.dart';

class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({
    super.key,
    required this.records,
    required this.refresh,
    required this.isAdmin,
    this.staffNames = const <String>[],
  });
  final List<dynamic> records;
  final Future<void> Function() refresh;
  final bool isAdmin;
  final List<String> staffNames;
  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard> {
  String branch = 'ALL', category = 'ALL', employee = 'ALL';
  DateTime? singleDate;
  DateTimeRange? period;
  bool todayOnly = true;

  String dateLabel(DateTime d) => [
        d.day.toString().padLeft(2, '0'),
        d.month.toString().padLeft(2, '0'),
        d.year.toString()
      ].join('/');

  double num(dynamic x) => double.tryParse(x.toString()) ?? 0;

  List<String> options(String key) {
    final defaults = key == 'branch'
        ? const ['ONT-BB', 'ONT-BR1']
        : key == 'category'
            ? const [
                'FRONT DESK',
                'INSURANCE USER',
                'ACCOUNTS',
                "DOCTOR'S ZONE",
              ]
            : key == 'employeeName'
                ? widget.staffNames
                : const <String>[];
    return <String>{
      'ALL',
      ...defaults.where((v) => v.trim().toLowerCase() != 'administrator'),
      ...widget.records
          .map((e) => (e[key] ?? '').toString().trim())
          .where((v) =>
              v.isNotEmpty &&
              (key != 'employeeName' ||
                  v.toLowerCase() != 'administrator')),
    }.toList();
  }

  List<dynamic> get rows => widget.records.where((e) {
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
      }).toList();

  Widget picker(String name, String selected, List<String> opts,
          ValueChanged<String?> change) =>
      SizedBox(
        width: MediaQuery.sizeOf(context).width < 620
            ? (MediaQuery.sizeOf(context).width - 48) / 2
            : 180,
        child: InputDecorator(
          decoration: InputDecoration(labelText: name, isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey(name + selected),
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

  Widget tile(String title, String val, IconData icon, Color color) =>
      Container(
        width: MediaQuery.sizeOf(context).width < 620
            ? (MediaQuery.sizeOf(context).width - 48) / 2
            : 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF20334F), Color(0xFF132138)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TaskLogStyle.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color)),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(val,
                style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: TaskLogStyle.ink)),
          ),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: TaskLogStyle.muted)),
        ]),
      );

  Widget panel(String title, Widget child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF20334F), Color(0xFF132138)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TaskLogStyle.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{},
        hours = <String, double>{},
        byEmployee = <String, double>{};
    for (final e in rows) {
      final task = e['taskId'].toString();
      final name = e['employeeName'].toString();
      totals[task] = (totals[task] ?? 0) + num(e['quantity']);
      hours[task] = (hours[task] ?? 0) + num(e['hours']);
      if (task != 'collection') {
        byEmployee[name] = (byEmployee[name] ?? 0) + num(e['quantity']);
      }
    }
    final quantityTasks = totals.entries
        .where((e) => e.key != 'collection')
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hourTasks = hours.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalHours = hours.values.fold(0.0, (a, b) => a + b);
    final max = quantityTasks.isEmpty ? 1.0 : quantityTasks.first.value + 1;
    const chartColors = [
      Color(0xFF34D5C0),
      Color(0xFF579FE8),
      Color(0xFFB18AF1),
      Color(0xFFE6A34C),
      Color(0xFFE67988),
      Color(0xFF52B9AA)
    ];
    final chart1 = panel(
      'Task quantities',
      quantityTasks.isEmpty
          ? const SizedBox(
              height: 220,
              child: Center(child: Text('No records for selected filters')),
            )
          : LayoutBuilder(builder: (context, c) {
              final compact = c.maxWidth < 460;
              final visible = quantityTasks;
              final chartMaxY = max * 1.18;
              final leftReserved = compact ? 32.0 : 40.0;
              const bottomReserved = 76.0;
              final rodWidth = compact ? 20.0 : 24.0;
              final minChartWidth =
                  leftReserved + visible.length * (compact ? 68.0 : 78.0);
              final chartWidth = math.max(c.maxWidth, minChartWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 310,
                      child: Stack(
                        children: [
                          BarChart(BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: chartMaxY,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: leftReserved,
                                  maxIncluded: false,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: bottomReserved,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (value != index.toDouble() ||
                                        index < 0 ||
                                        index >= visible.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final label =
                                        visible[index].key.replaceAll('_', ' ');
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 10,
                                      child: SizedBox(
                                        width: compact ? 62 : 72,
                                        child: Text(label,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: TaskLogStyle.muted,
                                                height: 1.15)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: visible
                                .asMap()
                                .entries
                                .map((e) => BarChartGroupData(x: e.key, barRods: [
                                      BarChartRodData(
                                          toY: e.value.value,
                                          color: TaskLogStyle.teal,
                                          width: rodWidth,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(7)))
                                    ]))
                                .toList(),
                          )),
                          Positioned(
                            left: leftReserved,
                            right: 0,
                            top: 0,
                            bottom: bottomReserved,
                            child: IgnorePointer(
                              child: LayoutBuilder(
                                builder: (context, plot) {
                                  final slotWidth =
                                      plot.maxWidth / visible.length;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children:
                                        visible.asMap().entries.map((item) {
                                      final i = item.key;
                                      final value = item.value.value;
                                      final barHeight = ((value / chartMaxY) *
                                              plot.maxHeight)
                                          .clamp(0.0, plot.maxHeight);
                                      final qtyText = value % 1 == 0
                                          ? value.toInt().toString()
                                          : value.toStringAsFixed(1);
                                      final insideBar = barHeight >= 14;
                                      final barLeft =
                                          (i + 0.5) * slotWidth - rodWidth / 2;
                                      return Positioned(
                                        left: barLeft,
                                        width: rodWidth,
                                        bottom: insideBar ? 0 : barHeight + 4,
                                        height: insideBar ? barHeight : 24,
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: insideBar &&
                                                      barHeight > 20
                                                  ? 3
                                                  : 1,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: RotatedBox(
                                                quarterTurns: 3,
                                                child: Text(
                                                  qtyText,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize:
                                                        compact ? 10.5 : 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.2,
                                                    color: insideBar
                                                        ? const Color(
                                                            0xFF041421)
                                                        : TaskLogStyle.ink,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20, color: TaskLogStyle.border),
                  ...visible.map((e) {
                    final qtyText = e.value % 1 == 0
                        ? e.value.toInt().toString()
                        : e.value.toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              e.key.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: TaskLogStyle.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            qtyText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: TaskLogStyle.teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),
    );
    final chart2 = panel(
      'Time spent by activity',
      hourTasks.isEmpty
          ? const SizedBox(
              height: 220,
              child: Center(child: Text('No hours recorded')),
            )
          : LayoutBuilder(builder: (context, c) {
              final stackVertically = c.maxWidth < 500;
              final pieWidget = SizedBox(
                height: stackVertically ? 190 : 240,
                child: PieChart(PieChartData(
                  centerSpaceRadius: stackVertically ? 36 : 45,
                  sections: hourTasks
                      .asMap()
                      .entries
                      .map((e) => PieChartSectionData(
                          value: e.value.value,
                          color: chartColors[e.key % chartColors.length],
                          radius: stackVertically ? 38 : 44,
                          showTitle: false))
                      .toList(),
                )),
              );
              final breakdownWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${totalHours.toStringAsFixed(2)} hours',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...hourTasks.asMap().entries.map((entry) {
                    final e = entry.value;
                    final color =
                        chartColors[entry.key % chartColors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 8),
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e.key.replaceAll('_', ' ')} — ${e.value.toStringAsFixed(1)}h',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: TaskLogStyle.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${e.value.toStringAsFixed(2)}h',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: TaskLogStyle.teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
              if (stackVertically) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pieWidget,
                    const SizedBox(height: 16),
                    breakdownWidget,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 220, child: pieWidget),
                  const SizedBox(width: 16),
                  Expanded(child: breakdownWidget),
                ],
              );
            }),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.isAdmin ? 'Performance dashboard' : 'My performance',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: TaskLogStyle.ink)),
            const SizedBox(height: 5),
            const Text('A clear view of daily activity, hours and ledger work',
                style: TextStyle(color: TaskLogStyle.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: widget.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'))
      ]),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [
        picker('Branch', branch, options('branch'),
            (v) => setState(() => branch = v ?? 'ALL')),
        picker('Category', category, options('category'),
            (v) => setState(() => category = v ?? 'ALL')),
        if (widget.isAdmin)
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
                label: Text('Today — ${dateLabel(DateTime.now())}'))
            : OutlinedButton.icon(
                icon: const Icon(Icons.today),
                onPressed: () => setState(() {
                      todayOnly = true;
                      singleDate = null;
                      period = null;
                    }),
                label: Text('Today — ${dateLabel(DateTime.now())}')),
        singleDate != null
            ? FilledButton.tonalIcon(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final v = await showDatePicker(
                      context: context,
                      initialDate: singleDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2036));
                  if (v != null) {
                    setState(() {
                      todayOnly = false;
                      singleDate = DateTime(v.year, v.month, v.day);
                      period = null;
                    });
                  }
                },
                label: Text('Date — ${dateLabel(singleDate!)}'))
            : OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final v = await showDatePicker(
                      context: context,
                      initialDate: singleDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2036));
                  if (v != null) {
                    setState(() {
                      todayOnly = false;
                      singleDate = DateTime(v.year, v.month, v.day);
                      period = null;
                    });
                  }
                },
                label: const Text('Choose date')),
        period != null
            ? FilledButton.tonalIcon(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final v = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2036),
                      initialDateRange: period);
                  if (v != null) {
                    setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = v;
                    });
                  }
                },
                label: Text(
                    '${dateLabel(period!.start)} – ${dateLabel(period!.end)}'))
            : OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final v = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2036),
                      initialDateRange: period);
                  if (v != null) {
                    setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = v;
                    });
                  }
                },
                label: const Text('Choose date range')),
        (!todayOnly && singleDate == null && period == null)
            ? FilledButton.tonalIcon(
                icon: const Icon(Icons.all_inclusive),
                onPressed: () => setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = null;
                    }),
                label: const Text('All loaded dates'))
            : TextButton(
                onPressed: () => setState(() {
                      todayOnly = false;
                      singleDate = null;
                      period = null;
                    }),
                child: const Text('All loaded dates')),
      ]),
      const SizedBox(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: [
        tile(
            'Ledgers prepared',
            (totals['ledger_prepared'] ?? 0).toStringAsFixed(0),
            Icons.menu_book_outlined,
            chartColors[1]),
        tile(
            'Ledgers updated',
            (totals['ledger_updated'] ?? 0).toStringAsFixed(0),
            Icons.edit_document,
            chartColors[0]),
        tile('Total task hours', totalHours.toStringAsFixed(2), Icons.schedule,
            chartColors[3]),
        tile('Collection (AED)', (totals['collection'] ?? 0).toStringAsFixed(2),
            Icons.account_balance_wallet_outlined, chartColors[2]),
      ]),
      const SizedBox(height: 20),
      LayoutBuilder(
          builder: (context, c) => c.maxWidth > 850
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: chart1),
                  const SizedBox(width: 16),
                  Expanded(child: chart2)
                ])
              : Column(children: [chart1, const SizedBox(height: 16), chart2])),
      const SizedBox(height: 20),
      panel(
          'Task activity by employee',
          byEmployee.isEmpty
              ? const Text('No activity records')
              : Column(
                  children: byEmployee.entries
                      .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            SizedBox(
                                width: MediaQuery.sizeOf(context).width < 420
                                    ? 100
                                    : 140,
                                child: Text(e.key,
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: LinearProgressIndicator(
                                    value: (e.value / 25).clamp(0.0, 1.0),
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(12))),
                            const SizedBox(width: 14),
                            Text(e.value.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ])))
                      .toList())),
      const SizedBox(height: 12),
      const Text(
          'Activity bars show recorded task quantities, not target achievement.',
          style: TextStyle(color: TaskLogStyle.muted, fontSize: 12)),
    ]);
  }
}
