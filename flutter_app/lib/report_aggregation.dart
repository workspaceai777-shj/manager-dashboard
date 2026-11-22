import 'tasklog_style.dart';

/// Pure aggregation logic for the admin PDF reports (no Flutter/PDF imports).

const Set<String> ledgerTaskIds = {'ledger_prepared', 'insurance_ledger_emr'};
const String enquiryDetailId = 'enquiry_detail';
const int maxRangeDays = 366;

double _num(dynamic x) => double.tryParse(x?.toString() ?? '') ?? 0;
int _mins(dynamic hours) => (_num(hours) * 60).round();
String _s(dynamic x) => (x ?? '').toString().trim();

/// Minutes that count toward a working-time total. EMR-wise ledger rows and
/// enquiry call details are breakdowns of an activity, never added.
int countedMinutes(Map<String, dynamic> r) {
  final id = _s(r['taskId']);
  if (ledgerTaskIds.contains(id) || id == enquiryDetailId) return 0;
  return _mins(r['hours']);
}

class ReportCriteria {
  const ReportCriteria({
    this.branch = 'ALL',
    this.category = 'ALL',
    this.employee = 'ALL',
    this.singleDate,
    this.period,
    this.todayOnly = false,
  });
  final String branch, category, employee;
  final DateTime? singleDate;
  final ({DateTime start, DateTime end})? period;
  final bool todayOnly;

  /// Inclusive date range sent to the API. With no date filter the last
  /// [maxRangeDays] days ending [now] are used.
  ({DateTime from, DateTime to}) range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (singleDate != null) {
      final d = DateTime(singleDate!.year, singleDate!.month, singleDate!.day);
      return (from: d, to: d);
    }
    if (period != null) {
      return (
        from: DateTime(
            period!.start.year, period!.start.month, period!.start.day),
        to: DateTime(period!.end.year, period!.end.month, period!.end.day),
      );
    }
    if (todayOnly) return (from: today, to: today);
    return (
      from: today.subtract(const Duration(days: maxRangeDays - 1)),
      to: today
    );
  }

  String periodLabel(DateTime now) {
    final r = range(now);
    final a = TaskLogStyle.dateLabel(r.from), b = TaskLogStyle.dateLabel(r.to);
    return a == b ? a : '$a to $b';
  }

  List<String> describe() => [
        'Branch: ${branch == 'ALL' ? 'All' : branch}',
        'Category: ${category == 'ALL' ? 'All' : category}',
        'Employee: ${employee == 'ALL' ? 'All' : employee}',
      ];
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Client-side clean-up of the API rows: drops administrator rows and
/// emr_updated, applies employee/branch/category filters (defensive).
List<Map<String, dynamic>> filterEntries(List<dynamic> raw, ReportCriteria c) {
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    final m = Map<String, dynamic>.from(e as Map);
    final name = _s(m['employeeName']);
    if (name.toLowerCase() == 'administrator') continue;
    if (_s(m['taskId']) == 'emr_updated') continue;
    if (c.branch != 'ALL' && _s(m['branch']) != c.branch) continue;
    if (c.category != 'ALL' && _s(m['category']) != c.category) continue;
    if (c.employee != 'ALL' && name != c.employee) continue;
    out.add(m);
  }
  return out;
}

DateTime _dateOf(Map<String, dynamic> r) =>
    TaskLogStyle.parseEntryDate(r['Task Date'] ?? r['date']) ?? DateTime(1970);

String _staffKey(Map<String, dynamic> r) {
  final uid = _s(r['uid']);
  return uid.isNotEmpty ? uid : _s(r['employeeName']).toLowerCase();
}

String fmtMinutes(int m) {
  if (m <= 0) return '0 min';
  final h = m ~/ 60, r = m % 60;
  return h == 0 ? '$m min' : '${h}h ${r.toString().padLeft(2, '0')}m';
}

String fmtHours(num minutes) => (minutes / 60).toStringAsFixed(2);

// ---------------------------------------------------------------- detailed

class ActivityLine {
  ActivityLine(this.taskId, this.title);
  final String taskId, title;
  double quantity = 0;
  int minutes = 0;
  int rows = 0;

  /// Non-empty remarks, one per row (e.g. each 'other_tasks' description).
  final List<String> descriptions = [];
  bool get isLedger => ledgerTaskIds.contains(taskId);
}

class DayDetail {
  DayDetail(this.date);
  final DateTime date;
  final Map<String, ActivityLine> activities = {};
  final List<Map<String, dynamic>> enquiries = [];
  final List<Map<String, dynamic>> ledger = [];
  int get totalMinutes =>
      activities.values.fold(0, (a, l) => a + (l.isLedger ? 0 : l.minutes));
}

class StaffDetail {
  StaffDetail(this.name);
  final String name;
  final List<DayDetail> days = [];
}

List<StaffDetail> buildDetailed(List<Map<String, dynamic>> rows) {
  final staff = <String, StaffDetail>{};
  final days = <String, DayDetail>{};
  for (final r in rows) {
    final sk = _staffKey(r);
    final s = staff.putIfAbsent(sk, () => StaffDetail(_s(r['employeeName'])));
    final d = _dateOf(r);
    final dk = '$sk|${isoDate(d)}';
    var day = days[dk];
    if (day == null) {
      day = DayDetail(d);
      days[dk] = day;
      s.days.add(day);
    }
    final id = _s(r['taskId']);
    if (id == enquiryDetailId) {
      day.enquiries.add(r);
      continue;
    }
    if (ledgerTaskIds.contains(id)) day.ledger.add(r);
    final title =
        TaskLogStyle.activityTitle(_s(r['branch']), _s(r['category']), id);
    final line = day.activities.putIfAbsent(id, () => ActivityLine(id, title));
    line.quantity += _num(r['quantity']);
    line.minutes += _mins(r['hours']);
    line.rows++;
    if (id == 'other_tasks') {
      final d = _s(r['remarks']);
      if (d.isNotEmpty) line.descriptions.add(d);
    }
  }
  final list = staff.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final s in list) {
    s.days.sort((a, b) => a.date.compareTo(b.date));
    for (final d in s.days) {
      d.enquiries
          .sort((a, b) => _s(a['startTime']).compareTo(_s(b['startTime'])));
      d.ledger.sort((a, b) => _s(a['startTime']).compareTo(_s(b['startTime'])));
    }
  }
  return list;
}

// ----------------------------------------------------------- staff summary

class DayTotal {
  DayTotal(this.date, this.minutes);
  final DateTime date;
  final int minutes;
}

class StaffSummary {
  StaffSummary(this.name, this.days);
  final String name;
  final List<DayTotal> days;

  /// Distinct dates on which the staff member recorded at least one entry.
  int get daysWorked => days.length;
  int get totalMinutes => days.fold(0, (a, d) => a + d.minutes);
  double get avgMinutesPerDay =>
      daysWorked == 0 ? 0 : totalMinutes / daysWorked;
}

List<StaffSummary> buildStaffSummary(List<Map<String, dynamic>> rows) {
  final names = <String, String>{};
  final perDay = <String, Map<String, ({DateTime date, int mins})>>{};
  for (final r in rows) {
    final sk = _staffKey(r);
    names.putIfAbsent(sk, () => _s(r['employeeName']));
    final d = _dateOf(r);
    final dk = isoDate(d);
    final m = perDay.putIfAbsent(sk, () => {});
    final prev = m[dk];
    m[dk] = (date: d, mins: (prev?.mins ?? 0) + countedMinutes(r));
  }
  final out = <StaffSummary>[
    for (final e in perDay.entries)
      StaffSummary(
          names[e.key]!,
          e.value.values.map((v) => DayTotal(v.date, v.mins)).toList()
            ..sort((a, b) => a.date.compareTo(b.date)))
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

// -------------------------------------------------------- activity summary

class ActivityTotal {
  ActivityTotal(this.taskId, this.title);
  final String taskId, title;
  double quantity = 0;
  int minutes = 0;
  final Set<String> staff = {};
  bool get isLedger => ledgerTaskIds.contains(taskId);
  bool get isCollection => taskId == 'collection';
  int get staffCount => staff.length;
  double get avgMinutesPerStaff => staffCount == 0 ? 0 : minutes / staffCount;
}

List<ActivityTotal> buildActivitySummary(List<Map<String, dynamic>> rows) {
  final map = <String, ActivityTotal>{};
  for (final r in rows) {
    final id = _s(r['taskId']);
    if (id == enquiryDetailId) continue;
    final t = map.putIfAbsent(
        id,
        () => ActivityTotal(
            id,
            TaskLogStyle.activityTitle(
                _s(r['branch']), _s(r['category']), id)));
    t.quantity += _num(r['quantity']);
    t.minutes += _mins(r['hours']);
    t.staff.add(_staffKey(r));
  }
  return map.values.toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
}

/// Friendly text for the documented API failures.
String friendlyReportError(Object e) {
  final t = e.toString().replaceFirst('Exception: ', '');
  if (t.contains('Date range too large')) {
    return 'The selected period is longer than $maxRangeDays days. Choose a shorter period.';
  }
  if (t.contains('Invalid date range')) {
    return 'The selected date range is invalid.';
  }
  if (t.contains('Invalid branch or category')) {
    return 'The selected branch or category is not valid.';
  }
  return 'Unable to load report data: $t';
}
