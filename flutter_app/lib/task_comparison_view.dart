import 'package:flutter/material.dart';
import 'tasklog_style.dart';

/// Admin Activity & Task Comparison page.
/// Compares each activity across staff members for the selected date,
/// featuring graphical proportional bar representations alongside exact numbers.
class TaskComparisonView extends StatefulWidget {
  const TaskComparisonView({
    super.key,
    required this.records,
    required this.refresh,
    this.staffNames = const <String>[],
    this.branch,
    this.category,
    this.employee,
    this.singleDate,
    this.period,
    this.todayOnly,
    this.onFilterChanged,
  });

  final List<dynamic> records;
  final Future<void> Function() refresh;
  final List<String> staffNames;
  final String? branch;
  final String? category;
  final String? employee;
  final DateTime? singleDate;
  final DateTimeRange? period;
  final bool? todayOnly;
  final void Function({
    String? branch,
    String? category,
    String? employee,
    DateTime? singleDate,
    DateTimeRange? period,
    bool? todayOnly,
    bool clearDates,
  })? onFilterChanged;

  @override
  State<TaskComparisonView> createState() => _TaskComparisonViewState();
}

class _StaffTaskMetric {
  final String staffName;
  final String branch;
  final String category;
  double quantity = 0.0;
  double hours = 0.0;
  int entryCount = 0;
  final List<String> emrList = [];
  final List<String> remarksList = [];

  // Dedicated fields for ledger tracking to prevent duplicate counting
  double parentLedgerQty = 0.0;
  double parentLedgerHours = 0.0;
  double emrBreakdownQty = 0.0;
  double emrBreakdownHours = 0.0;
  bool hasParentLedger = false;
  bool hasEmrBreakdown = false;

  _StaffTaskMetric({
    required this.staffName,
    required this.branch,
    required this.category,
  });
}

class _ActivityGroup {
  final String key;
  final String category;
  final String taskId;
  final String sampleBranch;
  final Map<String, _StaffTaskMetric> staffMap;

  _ActivityGroup({
    required this.key,
    required this.category,
    required this.taskId,
    required this.sampleBranch,
    required this.staffMap,
  });

  String get title =>
      TaskLogStyle.activityTitle(sampleBranch, category, taskId);

  List<_StaffTaskMetric> get staffList {
    final list = staffMap.values.toList();
    list.sort((a, b) {
      final qCmp = b.quantity.compareTo(a.quantity);
      if (qCmp != 0) return qCmp;
      return b.hours.compareTo(a.hours);
    });
    return list;
  }

  double get totalQty =>
      staffMap.values.fold(0.0, (sum, m) => sum + m.quantity);

  double get totalHours =>
      staffMap.values.fold(0.0, (sum, m) => sum + m.hours);

  double get maxQty => staffMap.values.fold(
      0.0, (max, m) => m.quantity > max ? m.quantity : max);

  double get maxHours =>
      staffMap.values.fold(0.0, (max, m) => m.hours > max ? m.hours : max);

  int get staffCount => staffMap.length;

  bool get isMultiStaff => staffCount > 1;

  bool get isCollection => taskId == 'collection';

  bool get isLedger =>
      taskId == 'ledger_updated' ||
      taskId == 'ledger_prepared' ||
      taskId == 'insurance_ledger_emr';
}

class _TaskComparisonViewState extends State<TaskComparisonView> {
  String _localBranch = 'ALL', _localCategory = 'ALL', _localEmployee = 'ALL';
  DateTime? _localSingleDate;
  DateTimeRange? _localPeriod;
  bool _localTodayOnly = true;

  // Comparison view specific options
  bool _multiStaffOnly = false;
  String _metricMode = 'quantity'; // 'quantity' or 'time'

  String get branch => widget.branch ?? _localBranch;
  String get category => widget.category ?? _localCategory;
  String get employee => widget.employee ?? _localEmployee;
  DateTime? get singleDate =>
      widget.onFilterChanged != null ? widget.singleDate : _localSingleDate;
  DateTimeRange? get period =>
      widget.onFilterChanged != null ? widget.period : _localPeriod;
  bool get todayOnly => widget.todayOnly ?? _localTodayOnly;

  static const Set<String> _yesNoTaskIds = {
    'accounts_collection_check',
    'accounts_dha_attendance',
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
    'accounts_purchase_request_month',
    'room_chore_inspection',
    'daily_collection_billing_done',
  };

  void _setFilter({
    String? branch,
    String? category,
    String? employee,
    DateTime? singleDate,
    DateTimeRange? period,
    bool? todayOnly,
    bool clearDates = false,
  }) {
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(
        branch: branch,
        category: category,
        employee: employee,
        singleDate: singleDate,
        period: period,
        todayOnly: todayOnly,
        clearDates: clearDates,
      );
    } else {
      setState(() {
        if (branch != null) _localBranch = branch;
        if (category != null) _localCategory = category;
        if (employee != null) _localEmployee = employee;
        if (clearDates) {
          _localTodayOnly = false;
          _localSingleDate = null;
          _localPeriod = null;
        } else {
          if (todayOnly != null) {
            _localTodayOnly = todayOnly;
            if (todayOnly) {
              _localSingleDate = null;
              _localPeriod = null;
            }
          }
          if (singleDate != null) {
            _localSingleDate = singleDate;
            _localTodayOnly = false;
            _localPeriod = null;
          }
          if (period != null) {
            _localPeriod = period;
            _localTodayOnly = false;
            _localSingleDate = null;
          }
        }
      });
    }
  }

  String dateLabel(DateTime d) => TaskLogStyle.dateLabel(d);

  String formatDuration(double hoursVal) {
    final totalMins = (hoursVal * 60).round();
    if (totalMins <= 0) return '0 min';
    if (totalMins < 60) {
      return '$totalMins min';
    }
    return '${hoursVal.toStringAsFixed(2)} hrs ($totalMins min)';
  }

  String shortDuration(double hoursVal) {
    final totalMins = (hoursVal * 60).round();
    if (totalMins <= 0) return '0m';
    if (totalMins < 60) return '${totalMins}m';
    return '${hoursVal.toStringAsFixed(1)}h';
  }

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
      ...widget.records.map((e) => (e[key] ?? '').toString().trim()).where(
          (v) =>
              v.isNotEmpty &&
              (key != 'employeeName' || v.toLowerCase() != 'administrator')),
    }.toList();
  }

  List<dynamic> get filteredRows => widget.records.where((e) {
        final empName = (e['employeeName'] ?? '').toString().trim();
        if (empName.toLowerCase() == 'administrator') {
          return false;
        }
        if (branch != 'ALL' && e['branch'] != branch) {
          return false;
        }
        if (category != 'ALL' && e['category'] != category) {
          return false;
        }
        if (employee != 'ALL' && empName != employee) {
          return false;
        }
        final d = TaskLogStyle.parseEntryDate(e['Task Date'] ?? e['date']);
        if (singleDate != null) {
          return d != null &&
              d.year == singleDate!.year &&
              d.month == singleDate!.month &&
              d.day == singleDate!.day;
        }
        if (todayOnly) {
          final today = DateTime.now();
          return d != null &&
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }
        if (period != null) {
          if (d == null) return false;
          final start = DateTime(
              period!.start.year, period!.start.month, period!.start.day);
          final end = DateTime(
              period!.end.year, period!.end.month, period!.end.day, 23, 59, 59);
          return !d.isBefore(start) && !d.isAfter(end);
        }
        return true;
      }).toList();

  String get activeDateDisplay {
    if (singleDate != null) {
      return dateLabel(singleDate!);
    }
    if (todayOnly) {
      return '${dateLabel(DateTime.now())} (Today)';
    }
    if (period != null) {
      return '${dateLabel(period!.start)} — ${dateLabel(period!.end)}';
    }
    return 'All loaded dates';
  }

  Map<String, _ActivityGroup> get groupedActivities {
    final map = <String, _ActivityGroup>{};
    for (final raw in filteredRows) {
      final e = Map<String, dynamic>.from(raw as Map);
      var taskId = (e['taskId'] ?? '').toString().trim();
      if (taskId.isEmpty) continue;

      if (taskId == 'cards_arranged') {
        taskId = 'charts';
      }
      if (taskId == 'emr_updated') {
        continue;
      }

      final isLedgerRow = taskId == 'ledger_updated' ||
          taskId == 'ledger_prepared' ||
          taskId == 'insurance_ledger_emr';

      // Merge both ledger activities into a single 'ledger_updated' activity
      final normalizedTaskId = isLedgerRow ? 'ledger_updated' : taskId;

      final cat = (e['category'] ?? 'FRONT DESK').toString().trim();
      final br = (e['branch'] ?? 'ONT-BB').toString().trim();
      final emp = (e['employeeName'] ?? '').toString().trim();
      if (emp.isEmpty || emp.toLowerCase() == 'administrator') continue;

      final qtyVal = double.tryParse((e['quantity'] ?? '0').toString()) ?? 0.0;
      final hrsVal = double.tryParse((e['hours'] ?? '0').toString()) ?? 0.0;
      final emrStr = (e['emr'] ?? '').toString().trim();
      final remStr = (e['remarks'] ?? '').toString().trim();

      final groupKey = '$cat|$normalizedTaskId';
      final group = map.putIfAbsent(
        groupKey,
        () => _ActivityGroup(
          key: groupKey,
          category: cat,
          taskId: normalizedTaskId,
          sampleBranch: br,
          staffMap: {},
        ),
      );

      final stat = group.staffMap.putIfAbsent(
        emp,
        () => _StaffTaskMetric(
          staffName: emp,
          branch: br,
          category: cat,
        ),
      );

      stat.entryCount += 1;

      if (isLedgerRow) {
        if (taskId == 'ledger_updated') {
          stat.parentLedgerQty += qtyVal;
          stat.parentLedgerHours += hrsVal;
          stat.hasParentLedger = true;
        } else {
          // Individual EMR row (ledger_prepared or insurance_ledger_emr)
          stat.emrBreakdownQty += (qtyVal > 0 ? qtyVal : 1.0);
          stat.emrBreakdownHours += hrsVal;
          stat.hasEmrBreakdown = true;
          if (emrStr.isNotEmpty && !stat.emrList.contains(emrStr)) {
            stat.emrList.add(emrStr);
          }
          if (remStr.isNotEmpty && !stat.remarksList.contains(remStr)) {
            stat.remarksList.add(remStr);
          }
        }
      } else {
        stat.quantity += qtyVal;
        stat.hours += hrsVal;
      }
    }

    // Resolve merged ledger quantities and hours to prevent duplicate counting
    for (final group in map.values) {
      if (group.isLedger) {
        for (final stat in group.staffMap.values) {
          if (stat.hasParentLedger && stat.hasEmrBreakdown) {
            stat.quantity = stat.parentLedgerQty > 0
                ? stat.parentLedgerQty
                : (stat.emrList.isNotEmpty
                    ? stat.emrList.length.toDouble()
                    : stat.emrBreakdownQty);
            // Use parent entered hours if greater than 0, otherwise use sum of EMR breakdown hours
            stat.hours = stat.parentLedgerHours > 0
                ? stat.parentLedgerHours
                : stat.emrBreakdownHours;
          } else if (stat.hasParentLedger) {
            stat.quantity = stat.parentLedgerQty;
            stat.hours = stat.parentLedgerHours;
          } else if (stat.hasEmrBreakdown) {
            stat.quantity = stat.emrList.isNotEmpty
                ? stat.emrList.length.toDouble()
                : (stat.emrBreakdownQty > 0 ? stat.emrBreakdownQty : 1.0);
            stat.hours = stat.emrBreakdownHours;
          }
        }
      }
    }

    return map;
  }

  Widget _buildPicker(String label, String value, List<String> opts,
          ValueChanged<String?> onChanged) =>
      SizedBox(
        width: MediaQuery.sizeOf(context).width < 620
            ? (MediaQuery.sizeOf(context).width - 48) / 2
            : 180,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey('cmp-$label-$value'),
              isExpanded: true,
              isDense: true,
              value: opts.contains(value) ? value : 'ALL',
              items: opts
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      );

  Widget _buildFilterBar() => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildPicker('Branch', branch, options('branch'),
              (v) => _setFilter(branch: v)),
          _buildPicker('Category', category, options('category'),
              (v) => _setFilter(category: v)),
          _buildPicker('Employee', employee, options('employeeName'),
              (v) => _setFilter(employee: v)),
          FilledButton.icon(
            onPressed: () => _setFilter(todayOnly: true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  todayOnly ? TaskLogStyle.teal : TaskLogStyle.surface,
              foregroundColor:
                  todayOnly ? const Color(0xFF061425) : TaskLogStyle.ink,
              side: const BorderSide(color: TaskLogStyle.border),
            ),
            icon: const Icon(Icons.event_available, size: 18),
            label: Text('Today — ${dateLabel(DateTime.now())}'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: singleDate ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                _setFilter(singleDate: picked);
              }
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: singleDate != null
                  ? TaskLogStyle.teal.withValues(alpha: 0.15)
                  : null,
              side: BorderSide(
                color: singleDate != null
                    ? TaskLogStyle.teal
                    : TaskLogStyle.border,
              ),
            ),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(
              singleDate != null ? dateLabel(singleDate!) : 'Choose date',
              style: TextStyle(
                color:
                    singleDate != null ? TaskLogStyle.teal : TaskLogStyle.ink,
                fontWeight:
                    singleDate != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
                initialDateRange: period,
              );
              if (picked != null) {
                _setFilter(period: picked);
              }
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: period != null
                  ? TaskLogStyle.teal.withValues(alpha: 0.15)
                  : null,
              side: BorderSide(
                color: period != null ? TaskLogStyle.teal : TaskLogStyle.border,
              ),
            ),
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              period != null
                  ? '${dateLabel(period!.start)} — ${dateLabel(period!.end)}'
                  : 'Choose date range',
              style: TextStyle(
                color: period != null ? TaskLogStyle.teal : TaskLogStyle.ink,
                fontWeight: period != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _setFilter(clearDates: true),
            child: const Text('All loaded dates'),
          ),
        ],
      );

  Widget _buildExecutiveOverview(
      int totalActivities, int multiStaffCount, List<_ActivityGroup> groups) {
    final activeStaffNames = <String>{};
    double totalTasks = 0;
    double totalHours = 0;
    final staffTotalTasks = <String, double>{};
    final staffTotalHours = <String, double>{};

    for (final g in groups) {
      for (final s in g.staffList) {
        activeStaffNames.add(s.staffName);
        if (!g.isCollection) {
          totalTasks += s.quantity;
          staffTotalTasks[s.staffName] =
              (staffTotalTasks[s.staffName] ?? 0.0) + s.quantity;
        }
        totalHours += s.hours;
        staffTotalHours[s.staffName] =
            (staffTotalHours[s.staffName] ?? 0.0) + s.hours;
      }
    }

    final maxStaffTasks = staffTotalTasks.values.fold<double>(
        0.0, (max, v) => v > max ? v : max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E324E), Color(0xFF121F34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaskLogStyle.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TaskLogStyle.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: TaskLogStyle.teal.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: TaskLogStyle.teal),
                    const SizedBox(width: 6),
                    Text(
                      activeDateDisplay,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TaskLogStyle.teal,
                      ),
                    ),
                  ],
                ),
              ),
              if (branch != 'ALL')
                _badge('Branch: $branch', const Color(0xFF1976D2)),
              if (category != 'ALL')
                _badge('Category: $category', const Color(0xFF7B1FA2)),
              if (employee != 'ALL')
                _badge('Employee: $employee', const Color(0xFF388E3C)),
            ],
          ),
          const SizedBox(height: 16),
          // Metric Cards Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill(
                icon: Icons.checklist,
                title: 'Activities Logged',
                value: '$totalActivities',
                accent: TaskLogStyle.teal,
              ),
              _metricPill(
                icon: Icons.people_outline,
                title: 'Multi-Staff Shared',
                value: '$multiStaffCount',
                accent: const Color(0xFF4DD0E1),
              ),
              _metricPill(
                icon: Icons.badge_outlined,
                title: 'Active Staff',
                value: '${activeStaffNames.length}',
                accent: const Color(0xFF81C784),
              ),
              _metricPill(
                icon: Icons.task_alt,
                title: 'Total Tasks',
                value: totalTasks % 1 == 0
                    ? totalTasks.toInt().toString()
                    : totalTasks.toStringAsFixed(1),
                accent: const Color(0xFFFFB74D),
              ),
              _metricPill(
                icon: Icons.schedule,
                title: 'Total Time',
                value: formatDuration(totalHours).split(' (').first,
                accent: const Color(0xFFBA68C8),
              ),
            ],
          ),
          if (staffTotalTasks.length > 1) ...[
            const SizedBox(height: 20),
            const Divider(color: TaskLogStyle.border),
            const SizedBox(height: 10),
            const Text(
              'Staff Workload Distribution on this Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: TaskLogStyle.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Total tasks & hours accomplished by each staff member',
              style: TextStyle(fontSize: 12, color: TaskLogStyle.muted),
            ),
            const SizedBox(height: 14),
            ...staffTotalTasks.entries.map((entry) {
              final staffName = entry.key;
              final taskQty = entry.value;
              final hoursVal = staffTotalHours[staffName] ?? 0.0;
              final ratio =
                  maxStaffTasks > 0 ? (taskQty / maxStaffTasks).clamp(0.05, 1.0) : 0.05;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LayoutBuilder(builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person,
                              size: 14, color: TaskLogStyle.teal),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              staffName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${taskQty.toInt()} tasks · ${shortDuration(hoursVal)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TaskLogStyle.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 9,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF132238),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF26A69A), TaskLogStyle.teal],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: bg.withValues(alpha: 0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: bg),
        ),
      );

  Widget _metricPill({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: TaskLogStyle.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TaskLogStyle.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontSize: 10.5, color: TaskLogStyle.muted),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildActivityCard(int index, _ActivityGroup activity) {
    final isMulti = activity.isMultiStaff;
    final staffList = activity.staffList;
    final isYesNo = _yesNoTaskIds.contains(activity.taskId);

    // Compute max for visual bars according to metricMode
    final maxMetricVal = _metricMode == 'quantity'
        ? (activity.maxQty > 0 ? activity.maxQty : 1.0)
        : (activity.maxHours > 0 ? activity.maxHours : 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: TaskLogStyle.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMulti
              ? TaskLogStyle.teal.withValues(alpha: 0.5)
              : TaskLogStyle.border,
          width: isMulti ? 1.4 : 1.0,
        ),
        boxShadow: isMulti
            ? [
                BoxShadow(
                  color: TaskLogStyle.teal.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            LayoutBuilder(builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E324E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TaskLogStyle.border),
                        ),
                        child: Text(
                          '#$index',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: TaskLogStyle.teal,
                          ),
                        ),
                      ),
                      _badge(activity.category, const Color(0xFF64B5F6)),
                      if (isMulti)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: TaskLogStyle.teal.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: TaskLogStyle.teal
                                    .withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt,
                                  size: 13, color: TaskLogStyle.teal),
                              const SizedBox(width: 4),
                              Text(
                                'Compared across ${activity.staffCount} staff',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: TaskLogStyle.teal,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          '1 staff member (${staffList.first.staffName})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: TaskLogStyle.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TaskLogStyle.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Activity totals row
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A2C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          activity.isCollection
                              ? 'Total: AED ${activity.totalQty.toStringAsFixed(2)}'
                              : (isYesNo
                                  ? 'Done by: ${staffList.where((s) => s.quantity >= 1).length} staff'
                                  : 'Total: ${activity.totalQty % 1 == 0 ? activity.totalQty.toInt() : activity.totalQty.toStringAsFixed(1)} ${activity.isLedger ? "ledgers" : "units"}'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TaskLogStyle.ink,
                          ),
                        ),
                        Text(
                          'Total Time: ${formatDuration(activity.totalHours).split(" (").first}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TaskLogStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 14),
            // Staff Graphical Comparison List
            ...staffList.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final staff = entry.value;

              final metricVal =
                  _metricMode == 'quantity' ? staff.quantity : staff.hours;
              final ratio = maxMetricVal > 0
                  ? (metricVal / maxMetricVal).clamp(0.04, 1.0)
                  : 0.04;

              // Percentage of total activity volume
              final sharePct = activity.totalQty > 0
                  ? ((staff.quantity / activity.totalQty) * 100).round()
                  : (activity.totalHours > 0
                      ? ((staff.hours / activity.totalHours) * 100).round()
                      : 0);

              final qtyDisplay = activity.isCollection
                  ? 'AED ${staff.quantity.toStringAsFixed(2)}'
                  : (isYesNo
                      ? (staff.quantity >= 1 ? 'Yes' : 'No')
                      : (activity.isLedger
                          ? '${staff.quantity.toInt()} ledgers'
                          : '${staff.quantity % 1 == 0 ? staff.quantity.toInt() : staff.quantity.toStringAsFixed(1)}'));

              final timeDisplay = formatDuration(staff.hours).split(' (').first;

              // Distinct color gradient per rank
              final barColors = rank == 1
                  ? const [Color(0xFF26A69A), TaskLogStyle.teal]
                  : (rank == 2
                      ? const [Color(0xFF1E88E5), Color(0xFF4FC3F7)]
                      : const [Color(0xFF7E57C2), Color(0xFFB39DDB)]);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121F33),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rank == 1 && isMulti
                          ? TaskLogStyle.teal.withValues(alpha: 0.35)
                          : TaskLogStyle.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Staff Header Row
                      Row(
                        children: [
                          if (isMulti) ...[
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? TaskLogStyle.teal
                                    : const Color(0xFF263852),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: rank == 1
                                      ? const Color(0xFF041423)
                                      : TaskLogStyle.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Icon(Icons.person,
                              size: 15, color: TaskLogStyle.teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              staff.staffName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: TaskLogStyle.ink,
                              ),
                            ),
                          ),
                          _badge(staff.branch, const Color(0xFF90A4AE)),
                          if (isMulti && sharePct > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TaskLogStyle.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$sharePct%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: TaskLogStyle.teal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Graphical Bar Representation
                      Container(
                        height: 18,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1424),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: barColors),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: barColors.first.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Numbers Mentioned Row
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Qty: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TaskLogStyle.muted,
                                ),
                              ),
                              Text(
                                qtyDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _metricMode == 'quantity'
                                      ? TaskLogStyle.teal
                                      : TaskLogStyle.ink,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule,
                                  size: 13, color: TaskLogStyle.muted),
                              const SizedBox(width: 4),
                              Text(
                                timeDisplay,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _metricMode == 'time'
                                      ? TaskLogStyle.teal
                                      : TaskLogStyle.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (staff.emrList.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1524),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: TaskLogStyle.teal
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long,
                                      size: 13, color: TaskLogStyle.teal),
                                  const SizedBox(width: 5),
                                  Text(
                                    'EMR entries (${staff.emrList.length}):',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: TaskLogStyle.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                staff.emrList.join(', '),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: TaskLogStyle.ink,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityGroups = groupedActivities;
    var allActivities = activityGroups.values.toList();

    // Sort: multi-staff activities first, then by total quantity descending
    allActivities.sort((a, b) {
      if (a.isMultiStaff != b.isMultiStaff) {
        return a.isMultiStaff ? -1 : 1;
      }
      return b.totalQty.compareTo(a.totalQty);
    });

    final multiStaffActivities =
        allActivities.where((a) => a.isMultiStaff).toList();
    final displayedActivities =
        _multiStaffOnly ? multiStaffActivities : allActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title & Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task & activity comparison',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Compare each activity done by staff members on the selected date with graphical metrics',
                  style: TextStyle(color: TaskLogStyle.muted, fontSize: 13),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: widget.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Filter Bar with criteria mentioned in Dashboard
        _buildFilterBar(),
        const SizedBox(height: 18),

        // Executive Overview Card
        _buildExecutiveOverview(
          allActivities.length,
          multiStaffActivities.length,
          allActivities,
        ),
        const SizedBox(height: 20),

        // Controls: Multi-staff filter toggle & metric selector
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            // Filter Pills
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text('All Activities (${allActivities.length})'),
                  selected: !_multiStaffOnly,
                  onSelected: (v) => setState(() => _multiStaffOnly = false),
                  selectedColor: TaskLogStyle.teal,
                  labelStyle: TextStyle(
                    color: !_multiStaffOnly
                        ? const Color(0xFF041423)
                        : TaskLogStyle.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                ChoiceChip(
                  label: Text(
                      '⚡ Multi-Staff Shared (${multiStaffActivities.length})'),
                  selected: _multiStaffOnly,
                  onSelected: (v) => setState(() => _multiStaffOnly = true),
                  selectedColor: TaskLogStyle.teal,
                  labelStyle: TextStyle(
                    color: _multiStaffOnly
                        ? const Color(0xFF041423)
                        : TaskLogStyle.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            // Metric selector toggle
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Bar metric: ',
                  style: TextStyle(fontSize: 12, color: TaskLogStyle.muted),
                ),
                ChoiceChip(
                  label: const Text('Quantity'),
                  selected: _metricMode == 'quantity',
                  onSelected: (v) => setState(() => _metricMode = 'quantity'),
                  selectedColor: TaskLogStyle.teal,
                  labelStyle: TextStyle(
                    color: _metricMode == 'quantity'
                        ? const Color(0xFF041423)
                        : TaskLogStyle.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Time'),
                  selected: _metricMode == 'time',
                  onSelected: (v) => setState(() => _metricMode = 'time'),
                  selectedColor: TaskLogStyle.teal,
                  labelStyle: TextStyle(
                    color: _metricMode == 'time'
                        ? const Color(0xFF041423)
                        : TaskLogStyle.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Activity Cards List
        if (displayedActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: TaskLogStyle.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TaskLogStyle.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rule_folder_outlined,
                    size: 48, color: TaskLogStyle.muted),
                const SizedBox(height: 12),
                Text(
                  _multiStaffOnly
                      ? 'No multi-staff shared activities on $activeDateDisplay'
                      : 'No activity entries found for $activeDateDisplay',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TaskLogStyle.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try choosing a different date or clearing branch/category filters above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: TaskLogStyle.muted),
                ),
              ],
            ),
          )
        else
          ...displayedActivities.asMap().entries.map(
                (e) => _buildActivityCard(e.key + 1, e.value),
              ),
      ],
    );
  }
}
