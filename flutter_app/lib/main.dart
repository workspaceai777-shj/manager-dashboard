import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api.dart';
import 'config.dart';
import 'tasklog_style.dart';
import 'payroll_reports.dart';
import 'report_aggregation.dart';
import 'performance_dashboard.dart';
import 'staff_detailed_report.dart';
import 'task_comparison_view.dart';
import 'admin_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: AppConfig.firebase);
  runApp(const OntarioApp());
}

class OntarioApp extends StatelessWidget {
  const OntarioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ontario Staff Tasks',
        theme: TaskLogStyle.light,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) =>
              snap.data == null ? const LoginPage() : const Portal(),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  String error = '';
  bool busy = false;
  bool saveCredentials = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      try {
        await FirebaseAuth.instance.setPersistence(
          saveCredentials ? Persistence.LOCAL : Persistence.SESSION,
        );
      } catch (_) {}
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      TextInput.finishAutofillContext(shouldSave: saveCredentials);
    } catch (e) {
      setState(() =>
          error = 'Sign-in failed. Check your credentials and account status.');
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: AutofillGroup(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const TaskLogBrandMark(size: 54),
                                    const SizedBox(height: 12),
                                    const Text('Ontario Staff Portal',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    TextField(
                                        controller: email,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                          AutofillHints.email,
                                        ],
                                        decoration: const InputDecoration(
                                            labelText: 'Email')),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: password,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => _signIn(),
                                        decoration: const InputDecoration(
                                            labelText: 'Password')),
                                    const SizedBox(height: 8),
                                    CheckboxListTile(
                                      value: saveCredentials,
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: const Text(
                                        'Save login credentials',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      onChanged: busy
                                          ? null
                                          : (v) => setState(() =>
                                              saveCredentials = v ?? true),
                                    ),
                                    if (error.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(error,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.red)),
                                    ],
                                    const SizedBox(height: 12),
                                    FilledButton(
                                        onPressed: busy ? null : _signIn,
                                        child: const Text('Sign in'))
                                  ],
                                ),
                              ))),
                    )))),
      );
}

class Portal extends StatefulWidget {
  const Portal({super.key, this.api});
  final StaffApi? api;
  @override
  State<Portal> createState() => _PortalState();
}

class _PortalState extends State<Portal> {
  static const _yesNoTaskIds = <String>{
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

  late final StaffApi api = widget.api ?? StaffApi();
  Map<String, dynamic> profile = {};
  List<dynamic> assignments = [], tasks = [], entries = [], users = [];
  String branch = '', category = '', page = 'Daily Tasks', error = '';
  DateTime reportDate = DateTime.now();
  bool branchSelected = false;
  bool loading = true;
  bool savedReportExists = false;
  final qty = <String, TextEditingController>{},
      hours = <String, TextEditingController>{};
  final emr = <TextEditingController>[],
      remark = <TextEditingController>[],
      mins = <TextEditingController>[];
  // Per-call details for activity "Enquiries Handled". Reference only: they never
  // feed the activity's quantity/minutes or the total hours worked.
  static const enquiryStatuses = <String>[
    'Resolved',
    'Appointment booked',
    'Follow-up required',
    'Call back later',
    'Not interested',
    'No answer',
  ];
  final enqNo = <TextEditingController>[],
      enqName = <TextEditingController>[],
      enqPhone = <TextEditingController>[],
      enqRemark = <TextEditingController>[],
      enqMins = <TextEditingController>[];
  final enqStatus = <String>[];
  // Actual first-start / last-end per row, parallel to enqMins / mins.
  final enqStart = <DateTime?>[], enqEnd = <DateTime?>[];
  final emrStart = <DateTime?>[], emrEnd = <DateTime?>[];

  /// Five slots are allocated; only [otherTaskSlots] are shown/saved
  /// (5 for ACCOUNTS, 1 for every other category).
  static const int accountsOtherTaskSlots = 5;
  final otherTaskDesc = List<TextEditingController>.generate(
      accountsOtherTaskSlots, (_) => TextEditingController());
  final otherTaskMins = List<TextEditingController>.generate(
      accountsOtherTaskSlots, (_) => TextEditingController());
  int get otherTaskSlots => category == 'ACCOUNTS' ? accountsOtherTaskSlots : 1;

  void _clearOtherTasks() {
    for (final c in otherTaskDesc) {
      c.clear();
    }
    for (final c in otherTaskMins) {
      c.clear();
    }
  }

  final newUserEmail = TextEditingController(),
      newUserName = TextEditingController(),
      newUserUid = TextEditingController();
  String newUserBranch = 'ONT-BB', newUserCategory = 'FRONT DESK';
  String adminBranch = 'ALL';
  String adminCategory = 'ALL';
  String adminEmployee = 'ALL';
  DateTime? adminSingleDate;
  DateTimeRange? adminPeriod;
  bool adminTodayOnly = false;

  void _onAdminFilterChanged({
    String? branch,
    String? category,
    String? employee,
    DateTime? singleDate,
    DateTimeRange? period,
    bool? todayOnly,
    bool clearDates = false,
  }) {
    setState(() {
      if (branch != null) adminBranch = branch;
      if (category != null) adminCategory = category;
      if (employee != null) adminEmployee = employee;
      if (clearDates) {
        adminTodayOnly = false;
        adminSingleDate = null;
        adminPeriod = null;
      } else {
        if (todayOnly != null) {
          adminTodayOnly = todayOnly;
          if (todayOnly) {
            adminSingleDate = null;
            adminPeriod = null;
          }
        }
        if (singleDate != null) {
          adminSingleDate = singleDate;
          adminTodayOnly = false;
          adminPeriod = null;
        }
        if (period != null) {
          adminPeriod = period;
          adminTodayOnly = false;
          adminSingleDate = null;
        }
      }
    });
  }

  // In-memory running timers. Keys: '<taskId>', 'enq-<row>', 'emr-<row>'.
  final Map<String, DateTime> _running = {};

  // One shared 1s ticker; elapsed labels listen to it (no page rebuilds).
  final ValueNotifier<DateTime> _tick = ValueNotifier(DateTime.now());
  Timer? _ticker;

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _running.isEmpty) {
        t.cancel();
        _ticker = null;
        return;
      }
      _tick.value = DateTime.now();
    });
  }

  Map<String, String> _timeFields(List<DateTime?> s, List<DateTime?> e, int i) {
    final st = i < s.length ? s[i] : null;
    final en = i < e.length ? e[i] : null;
    return {
      if (st != null) 'startTime': st.toUtc().toIso8601String(),
      if (en != null) 'endTime': en.toUtc().toIso8601String(),
    };
  }

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  void _shiftRunning(String prefix, int removed) {
    final next = <String, DateTime>{};
    _running.forEach((k, v) {
      if (k.startsWith(prefix)) {
        final i = int.tryParse(k.substring(prefix.length));
        if (i == null) {
          next[k] = v;
        } else if (i < removed) {
          next[k] = v;
        } else if (i > removed) {
          next['$prefix${i - 1}'] = v;
        }
      } else {
        next[k] = v;
      }
    });
    _running
      ..clear()
      ..addAll(next);
  }

  void _syncTimes(List<DateTime?> l, int n) {
    while (l.length < n) {
      l.add(null);
    }
  }

  void _recordTime(String key, {required bool start}) {
    final isEnq = key.startsWith('enq-');
    final isEmr = key.startsWith('emr-');
    if (!isEnq && !isEmr) return;
    final i = int.tryParse(key.substring(4));
    if (i == null) return;
    final s = isEnq ? enqStart : emrStart;
    final e = isEnq ? enqEnd : emrEnd;
    _syncTimes(s, i + 1);
    _syncTimes(e, i + 1);
    final now = DateTime.now();
    if (start) {
      s[i] ??= now;
    } else {
      e[i] = now;
    }
  }

  void _startTimer(String key) {
    setState(() {
      _running[key] = DateTime.now();
      _recordTime(key, start: true);
    });
    _tick.value = DateTime.now();
    _ensureTicker();
  }

  void _endTimer(String key, TextEditingController ctrl) {
    final start = _running[key];
    if (start == null) return;
    final ms = DateTime.now().difference(start).inMilliseconds;
    var add = (ms / 60000).ceil();
    if (ms > 0 && add < 1) add = 1;
    final existing = double.tryParse(ctrl.text.trim()) ?? 0;
    final total = existing + add;
    setState(() {
      _running.remove(key);
      _recordTime(key, start: false);
      ctrl.text = total == total.roundToDouble()
          ? total.toInt().toString()
          : total.toStringAsFixed(2);
    });
    if (_running.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _timerControls(String key, TextEditingController ctrl,
      {required String startKey, required String endKey}) {
    final start = _running[key];
    final running = start != null;
    const pad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: 'Start timer',
          child: FilledButton.icon(
            key: ValueKey(startKey),
            style: FilledButton.styleFrom(
                padding: pad,
                minimumSize: const Size(0, 34),
                backgroundColor: TaskLogStyle.teal),
            onPressed: running ? null : () => _startTimer(key),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start'),
          ),
        ),
        Tooltip(
          message: 'End timer and add elapsed minutes',
          child: OutlinedButton.icon(
            key: ValueKey(endKey),
            style: OutlinedButton.styleFrom(
                padding: pad, minimumSize: const Size(0, 34)),
            onPressed: running ? () => _endTimer(key, ctrl) : null,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('End'),
          ),
        ),
        if (running)
          ValueListenableBuilder<DateTime>(
            valueListenable: _tick,
            builder: (_, now, __) => Text(
                'Started ${_hhmm(start)} · Elapsed ${formatElapsed(now.difference(start))}',
                style:
                    const TextStyle(color: TaskLogStyle.muted, fontSize: 12)),
          ),
      ],
    );
  }

  void _addEnquiryRow(
      {String? no,
      String name = '',
      String phone = '',
      String remark = '',
      String mins = '',
      String status = '',
      DateTime? start,
      DateTime? end}) {
    enqNo.add(TextEditingController(text: no ?? '${enqNo.length + 1}'));
    enqName.add(TextEditingController(text: name));
    enqPhone.add(TextEditingController(text: phone));
    enqRemark.add(TextEditingController(text: remark));
    enqMins.add(TextEditingController(text: mins));
    enqStatus.add(status);
    enqStart.add(start);
    enqEnd.add(end);
  }

  void _removeEnquiryRow(int i) {
    enqNo.removeAt(i).dispose();
    enqName.removeAt(i).dispose();
    enqPhone.removeAt(i).dispose();
    enqRemark.removeAt(i).dispose();
    enqMins.removeAt(i).dispose();
    enqStatus.removeAt(i);
    if (i < enqStart.length) {
      enqStart.removeAt(i);
    }
    if (i < enqEnd.length) {
      enqEnd.removeAt(i);
    }
    _shiftRunning('enq-', i);
  }

  void _clearEnquiryRows() {
    for (final c in [
      ...enqNo,
      ...enqName,
      ...enqPhone,
      ...enqRemark,
      ...enqMins
    ]) {
      c.dispose();
    }
    enqNo.clear();
    enqName.clear();
    enqPhone.clear();
    enqRemark.clear();
    enqMins.clear();
    enqStatus.clear();
    enqStart.clear();
    enqEnd.clear();
    _running.removeWhere((k, _) => k.startsWith('enq-'));
  }

  String? get emrTaskId {
    if (tasks.any((t) => t['id'] == 'ledger_prepared')) {
      return 'ledger_prepared';
    }
    if (tasks.any((t) => t['id'] == 'insurance_ledger_emr')) {
      return 'insurance_ledger_emr';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _tick.dispose();
    for (final c in qty.values) {
      c.dispose();
    }
    for (final c in hours.values) {
      c.dispose();
    }
    for (final c in emr) {
      c.dispose();
    }
    for (final c in remark) {
      c.dispose();
    }
    for (final c in mins) {
      c.dispose();
    }
    _clearEnquiryRows();
    for (final c in otherTaskDesc) {
      c.dispose();
    }
    for (final c in otherTaskMins) {
      c.dispose();
    }
    newUserEmail.dispose();
    newUserName.dispose();
    newUserUid.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final b = Map<String, dynamic>.from(await api.request('bootstrap'));
      profile = Map<String, dynamic>.from(b['profile'] ?? {});
      assignments = List.from(b['assignments'] ?? []);
      // A branch/category must be explicitly chosen by normal staff members.
      // Admins skip branch selection and open directly on the Dashboard.
      if (profile['role'] == 'ADMIN') {
        branchSelected = true;
        if (page != 'Settings') {
          page = 'Dashboard';
        }
      } else if (!branchSelected) {
        branch = '';
        category = '';
        tasks = [];
      }
      final isAdmin = profile['role'] == 'ADMIN';
      final results = await Future.wait<dynamic>([
        api.request(
          isAdmin ? 'dashboard' : 'myDashboard',
          body: {
            'from': _date(DateTime.now().subtract(const Duration(days: 360))),
            'to': _date(DateTime.now().add(const Duration(days: 1))),
          },
        ),
        if (isAdmin) api.request('users'),
      ]);
      entries = List.from((results[0] as Map)['entries'] ?? []);
      if (isAdmin && results.length > 1) {
        users = List.from((results[1] as Map)['users'] ?? []);
      }
      error = '';
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> selectAssignment(String nextBranch, String nextCategory) async {
    if (!assignments.any(
        (a) => a['branch'] == nextBranch && a['category'] == nextCategory)) {
      message('This branch/category is not assigned to your account');
      return;
    }
    setState(() => loading = true);
    try {
      final response = await api.request('tasks', body: {
        'branch': nextBranch,
        'category': nextCategory,
      });
      var nextTasks = List<dynamic>.from(response['tasks'] ?? [])
          .where((t) => t['id'].toString() != 'accounts_r4_ledgers')
          .map((t) {
        final item = Map<String, dynamic>.from(t as Map);
        if (item['id'] == 'accounts_insurance_ledgers') {
          item['name'] = 'Individual ledgers for insurance showed';
        }
        return item;
      }).toList();
      if (nextCategory == 'INSURANCE USER' &&
          !nextTasks.any((t) => t['id'] == 'insurance_claims_prepared')) {
        nextTasks = [
          {
            'id': 'insurance_claims_prepared',
            'name': 'Insurance Claims Prepared',
          },
          ...nextTasks,
        ];
      }
      if (nextCategory == 'INSURANCE USER' &&
          !nextTasks.any((t) => t['id'] == 'insurance_ledger_emr')) {
        nextTasks = [
          ...nextTasks,
          {
            'id': 'insurance_ledger_emr',
            'name': 'Insurance EMR-wise Entry',
          },
        ];
      }
      // Fail closed if a stale or mismatched task catalog is received.
      // INSURANCE USER and ACCOUNTS have distinct task ID namespaces.
      if (nextCategory == 'INSURANCE USER' &&
          (nextTasks.isEmpty ||
              nextTasks
                  .any((t) => !t['id'].toString().startsWith('insurance_')))) {
        throw StateError(
            'Incorrect Insurance task list returned. Please retry.');
      }
      if (nextCategory == 'ACCOUNTS' &&
          (nextTasks.isEmpty ||
              nextTasks
                  .any((t) => !t['id'].toString().startsWith('accounts_')))) {
        throw StateError(
            'Incorrect Accounts task list returned. Please retry.');
      }
      if (nextCategory.toUpperCase() == "DOCTOR'S ZONE" &&
          (nextTasks.isEmpty ||
              nextTasks
                  .any((t) => !t['id'].toString().startsWith('doctors_')))) {
        throw StateError(
            "Incorrect Doctor's Zone task list returned. Please retry.");
      }
      if (nextCategory == 'FRONT DESK' &&
          nextTasks.any((t) =>
              t['id'].toString().startsWith('insurance_') ||
              t['id'].toString().startsWith('accounts_') ||
              t['id'].toString().startsWith('doctors_'))) {
        throw StateError(
            'Incorrect Front Desk task list returned. Please retry.');
      }
      if (!mounted) return;
      for (final controller in qty.values) {
        controller.dispose();
      }
      for (final controller in hours.values) {
        controller.dispose();
      }
      qty.clear();
      hours.clear();
      for (final controller in emr) {
        controller.dispose();
      }
      for (final controller in remark) {
        controller.dispose();
      }
      for (final controller in mins) {
        controller.dispose();
      }
      emr.clear();
      emrStart.clear();
      emrEnd.clear();
      remark.clear();
      mins.clear();
      _clearEnquiryRows();
      _clearOtherTasks();
      setState(() {
        branch = nextBranch;
        category = nextCategory;
        tasks = nextTasks;
        savedReportExists = false;
        branchSelected = true;
        page = 'Daily Tasks';
        error = '';
      });
      await restoreReport(nextBranch, nextCategory, reportDate);
    } catch (e) {
      message('Unable to load tasks: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> refreshDashboardData() async {
    try {
      final response = await api.request(
        manager ? 'dashboard' : 'myDashboard',
        body: {
          'from': _date(DateTime.now().subtract(const Duration(days: 360))),
          'to': _date(DateTime.now().add(const Duration(days: 1))),
        },
      );
      if (mounted) {
        setState(() => entries = List.from(response['entries'] ?? []));
      }
    } catch (e) {
      message('Unable to refresh dashboard: $e');
    }
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
  bool get manager => profile['role'] == 'ADMIN';
  String get staffDisplayName {
    final name = (profile['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return (profile['email'] ?? '').toString().trim();
  }

  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> restoreReport(String selectedBranch, String selectedCategory,
      DateTime selectedDate) async {
    final result = await api.request('report', body: {
      'branch': selectedBranch,
      'category': selectedCategory,
      'date': _date(selectedDate),
    });
    if (!mounted) return;
    for (final c in qty.values) {
      c.clear();
    }
    for (final c in hours.values) {
      c.clear();
    }
    for (final c in emr) {
      c.dispose();
    }
    for (final c in remark) {
      c.dispose();
    }
    for (final c in mins) {
      c.dispose();
    }
    emr.clear();
    emrStart.clear();
    emrEnd.clear();
    remark.clear();
    mins.clear();
    _running.clear();
    _clearEnquiryRows();
    _clearOtherTasks();
    final otherRows = <Map<String, dynamic>>[];
    final previous = List<dynamic>.from(result['entries'] ?? []);
    for (final raw in previous) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['taskId'].toString();
      if (id == 'ledger_prepared' || id == 'insurance_ledger_emr') {
        emr.add(TextEditingController(text: row['emr'].toString()));
        remark.add(TextEditingController(text: row['remarks'].toString()));
        final time = double.tryParse(row['hours'].toString()) ?? 0;
        mins.add(TextEditingController(text: (time * 60).round().toString()));
        emrStart.add(_parseTs(row['startTime']));
        emrEnd.add(_parseTs(row['endTime']));
      } else if (id == 'enquiry_detail') {
        final time = double.tryParse(row['hours'].toString()) ?? 0;
        _addEnquiryRow(
          no: (row['emr'] ?? '').toString(),
          name: (row['callerName'] ?? '').toString(),
          phone: (row['callerPhone'] ?? '').toString(),
          remark: (row['remarks'] ?? '').toString(),
          mins: time > 0 ? (time * 60).round().toString() : '',
          status: (row['callStatus'] ?? '').toString(),
          start: _parseTs(row['startTime']),
          end: _parseTs(row['endTime']),
        );
      } else if (id == 'other_tasks') {
        otherRows.add(row);
      } else {
        qty.putIfAbsent(id, () => TextEditingController()).text =
            row['quantity'].toString();
        final time = double.tryParse(row['hours'].toString()) ?? 0;
        hours.putIfAbsent(id, () => TextEditingController()).text =
            (time * 60).round().toString();
      }
    }
    _restoreOtherTasks(otherRows, otherTaskSlots);
    setState(() => savedReportExists = previous.isNotEmpty);
  }

  /// Maps saved 'other_tasks' rows to slots by their emr value ('1'..'N';
  /// legacy '' maps to slot 1). Rows with a missing/duplicate/out-of-range
  /// slot fall to the next free slot; rows beyond capacity are dropped.
  void _restoreOtherTasks(List<Map<String, dynamic>> rows, int slots) {
    final taken = <int>{};
    final pending = <Map<String, dynamic>>[];
    void put(int i, Map<String, dynamic> row) {
      taken.add(i);
      otherTaskDesc[i].text = (row['remarks'] ?? '').toString();
      final time = double.tryParse((row['hours'] ?? '').toString()) ?? 0;
      otherTaskMins[i].text = time > 0 ? (time * 60).round().toString() : '';
    }

    for (final row in rows) {
      final raw = (row['emr'] ?? '').toString().trim();
      final n = raw.isEmpty ? 1 : int.tryParse(raw);
      if (n != null && n >= 1 && n <= slots && !taken.contains(n - 1)) {
        put(n - 1, row);
      } else {
        pending.add(row);
      }
    }
    for (final row in pending) {
      final free =
          List.generate(slots, (i) => i).where((i) => !taken.contains(i));
      if (free.isEmpty) break;
      put(free.first, row);
    }
  }

  Future<void> selectReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: reportDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      reportDate = picked;
      loading = true;
    });
    try {
      await restoreReport(branch, category, picked);
    } catch (e) {
      message('Unable to load saved report: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reloadSelectedReport() async {
    setState(() => loading = true);
    try {
      await restoreReport(branch, category, reportDate);
      message('Saved task entries loaded for ${_date(reportDate)}');
    } catch (e) {
      message('Unable to load saved report: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The summary card (activity "Ledger Updated") is derived from EMR rows.
  bool _isLedgerSummary(String id) =>
      id == ledgerSummaryTaskId && emrTaskId != null;

  LedgerTotals _ledgerTotals() => computeLedgerTotals(
      [for (final c in emr) c.text], [for (final c in mins) c.text]);

  /// The "Enquiries Handled" card is derived from the enquiry call rows.
  bool _isEnquirySummary(String id) =>
      id == enquirySummaryTaskId && tasks.any((t) => t['id'] == id);

  LedgerTotals _enquiryTotals() => computeEnquiryTotals([
        for (int i = 0; i < enqNo.length; i++)
          (
            name: enqName[i].text,
            phone: enqPhone[i].text,
            remarks: enqRemark[i].text,
            status: i < enqStatus.length ? enqStatus[i] : '',
            minutes: enqMins[i].text,
          )
      ]);

  Future<void> saveTasks() async {
    final data = <Map<String, dynamic>>[];
    for (final task in tasks) {
      final id = task['id'].toString();
      if (_isEnquirySummary(id)) {
        final et = _enquiryTotals();
        if (et.count > 0 || et.minutes > 0) {
          data.add({
            'taskId': id,
            'quantity': et.count,
            'hours': et.minutes / 60.0,
          });
        }
        continue;
      }
      if (_isLedgerSummary(id)) {
        final lt = _ledgerTotals();
        if (lt.count > 0 || lt.minutes > 0) {
          data.add({
            'taskId': id,
            'quantity': lt.count,
            'hours': lt.minutes / 60.0,
          });
        }
        continue;
      }
      final qText = (qty[id]?.text ?? '').trim();
      final mText = (hours[id]?.text ?? '').trim();
      final parsedQ = qText.isEmpty ? 0.0 : (double.tryParse(qText) ?? 0.0);
      final parsedM = mText.isEmpty ? 0.0 : (double.tryParse(mText) ?? 0.0);
      final q = parsedQ < 0 ? 0.0 : parsedQ;
      final m = parsedM < 0 ? 0.0 : parsedM;
      if (q > 0 || m > 0) {
        data.add({
          'taskId': id,
          'quantity': id == 'collection' ? q : q.round(),
          'hours': m / 60.0,
        });
      }
    }
    final activeEmrTask = emrTaskId;
    if (activeEmrTask != null) {
      for (int i = 0; i < emr.length; i++) {
        final mText = mins[i].text.trim();
        final parsedM = mText.isEmpty ? 0 : (int.tryParse(mText) ?? 0);
        final m = parsedM < 0 ? 0 : parsedM;
        if (emr[i].text.trim().isNotEmpty) {
          data.add({
            'taskId': activeEmrTask,
            'emr': emr[i].text.trim(),
            'remarks': remark[i].text.trim(),
            'quantity': 1,
            'hours': m > 0 ? m / 60 : 0,
            ..._timeFields(emrStart, emrEnd, i),
          });
        }
      }
    }
    if (tasks.any((t) => t['id'] == 'enquiries')) {
      for (int i = 0; i < enqNo.length; i++) {
        final no = enqNo[i].text.trim();
        final name = enqName[i].text.trim();
        final phone = enqPhone[i].text.trim();
        final rem = enqRemark[i].text.trim();
        final status = enqStatus[i];
        final m = _parseMinutes(enqMins[i].text);
        // The auto-filled number alone does not make a row worth saving.
        if (!isEnquiryRowWorthSaving(
            name: name,
            phone: phone,
            remarks: rem,
            status: status,
            minutes: enqMins[i].text)) {
          continue;
        }
        data.add({
          'taskId': 'enquiry_detail',
          'emr': no,
          'callerName': name,
          'callerPhone': phone,
          'callStatus': status,
          'remarks': rem,
          'quantity': 1,
          'hours': m / 60.0,
          ..._timeFields(enqStart, enqEnd, i),
        });
      }
    }
    for (var i = 0; i < otherTaskSlots; i++) {
      final otherDesc = otherTaskDesc[i].text.trim();
      final otherMText = otherTaskMins[i].text.trim();
      final parsedOtherM =
          otherMText.isEmpty ? 0.0 : (double.tryParse(otherMText) ?? 0.0);
      final otherM = parsedOtherM < 0 ? 0.0 : parsedOtherM;
      if (otherDesc.isNotEmpty || otherM > 0) {
        data.add({
          'taskId': 'other_tasks',
          'emr': '${i + 1}',
          'remarks': otherDesc,
          'quantity': 1,
          'hours': otherM / 60.0,
        });
      }
    }
    final formattedDate = [
      reportDate.day.toString().padLeft(2, '0'),
      reportDate.month.toString().padLeft(2, '0'),
      reportDate.year.toString(),
    ].join('/');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_available, color: TaskLogStyle.teal),
            SizedBox(width: 10),
            Expanded(child: Text('Confirm report date')),
          ],
        ),
        content: Text(
          'Please confirm the date for which you are saving this daily task report:\n\n'
          'Date: $formattedDate (${_date(reportDate)})\n'
          'Section: $branch — $category',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Change date'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.request('saveReport', body: {
        'branch': branch,
        'category': category,
        'date': _date(reportDate),
        'entries': data
      });
      await restoreReport(branch, category, reportDate);
      await refreshDashboardData();
      message('Daily report saved for ${_date(reportDate)}');
    } catch (e) {
      message(e.toString());
    }
  }

  /// Optional per-call breakdown shown under "Enquiries Handled". Entirely
  /// separate from that activity's own quantity/minutes.
  Widget enquiryDetailsPanel(int activityNumber) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, isDense: true);
    Widget statusField(int i) => InputDecorator(
          decoration: deco('Call status'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey('enq-status-$i-${enqStatus[i]}'),
              isExpanded: true,
              isDense: true,
              hint: const Text('Select'),
              value:
                  enquiryStatuses.contains(enqStatus[i]) ? enqStatus[i] : null,
              items: [
                for (final v in enquiryStatuses)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) => setState(() => enqStatus[i] = v ?? ''),
            ),
          ),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 940),
      child: Card(
        key: const ValueKey('enquiry-details'),
        margin: const EdgeInsets.only(left: 18, bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enquiry details — activity $activityNumber',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 4),
              const Text(
                  'List each enquiry call here. The Quantity and Minutes above '
                  'are calculated from these calls and counted once in total '
                  'hours worked.',
                  style: TextStyle(color: TaskLogStyle.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              for (int i = 0; i < enqNo.length; i++)
                Container(
                  key: ValueKey('enq-row-$i'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: TaskLogStyle.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: LayoutBuilder(builder: (context, c) {
                    final compact = c.maxWidth < 600;
                    final number = TextField(
                        controller: enqNo[i], decoration: deco('No.'));
                    final name = TextField(
                        controller: enqName[i],
                        textCapitalization: TextCapitalization.words,
                        decoration: deco('Caller name'));
                    final phone = TextField(
                        controller: enqPhone[i],
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-() ]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: deco('Phone number'));
                    final mins = TextField(
                        controller: enqMins[i],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: deco('Minutes'));
                    final remarks = TextField(
                        controller: enqRemark[i],
                        minLines: 1,
                        maxLines: 3,
                        decoration: deco('Remarks'));
                    final delete = IconButton(
                        tooltip: 'Remove this enquiry',
                        onPressed: () => setState(() => _removeEnquiryRow(i)),
                        icon: const Icon(Icons.delete_outline));
                    final timer = _timerControls('enq-$i', enqMins[i],
                        startKey: 'enq-start-$i', endKey: 'enq-end-$i');
                    if (compact) {
                      return Column(children: [
                        Row(children: [
                          SizedBox(width: 70, child: number),
                          const SizedBox(width: 8),
                          Expanded(child: name),
                          delete,
                        ]),
                        const SizedBox(height: 10),
                        phone,
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(flex: 3, child: statusField(i)),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: mins),
                        ]),
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: timer),
                        const SizedBox(height: 10),
                        remarks,
                      ]);
                    }
                    return Column(children: [
                      Row(children: [
                        SizedBox(width: 80, child: number),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: name),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: phone),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: statusField(i)),
                        const SizedBox(width: 10),
                        SizedBox(width: 110, child: mins),
                        delete,
                      ]),
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: timer),
                      const SizedBox(height: 10),
                      remarks,
                    ]);
                  }),
                ),
              OutlinedButton.icon(
                key: const ValueKey('add-enquiry'),
                onPressed: () => setState(_addEnquiryRow),
                icon: const Icon(Icons.add),
                label: const Text('Add enquiry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget entryPage() {
    if (assignments.isEmpty) {
      return const Text(
          'No branch/category assignment. Contact your administrator.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, children: [
        SizedBox(
            width: MediaQuery.sizeOf(context).width < 720
                ? MediaQuery.sizeOf(context).width - 32
                : 340,
            child: DropdownButton<String>(
                isExpanded: true,
                value: assignments.any((a) =>
                        '${a['branch']}|${a['category']}' ==
                        '$branch|$category')
                    ? '$branch|$category'
                    : null,
                items: assignments.map<DropdownMenuItem<String>>((a) {
                  final v = '${a['branch']}|${a['category']}';
                  return DropdownMenuItem(
                      value: v,
                      child: Text('${a['branch']} — ${a['category']}',
                          overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  final selection = v.split('|');
                  await selectAssignment(selection[0], selection[1]);
                })),
        OutlinedButton.icon(
            onPressed: selectReportDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_date(reportDate))),
        OutlinedButton.icon(
            onPressed: reloadSelectedReport,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Load / edit saved report')),
      ]),
      if (savedReportExists)
        const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
                'Saved report loaded — edit the values and save again to replace this date’s entries.',
                style: TextStyle(color: TaskLogStyle.teal))),
      const SizedBox(height: 24),
      const Text('Daily task report',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 27,
              color: TaskLogStyle.ink)),
      const SizedBox(height: 5),
      const Text('Record quantities and total minutes spent on each activity',
          style: TextStyle(color: TaskLogStyle.muted)),
      const SizedBox(height: 20),
      const Text('Activities',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 8),
      ...tasks
          .where((t) =>
              t['id'] != 'ledger_prepared' &&
              t['id'] != 'insurance_ledger_emr' &&
              t['id'] != 'other_tasks')
          .toList()
          .asMap()
          .entries
          .map((entry) {
        final activityNumber = entry.key + 1;
        final t = entry.value;
        final id = t['id'].toString();
        qty.putIfAbsent(id, () => TextEditingController());
        hours.putIfAbsent(id, () => TextEditingController());
        final isLedgerSummary = _isLedgerSummary(id);
        final isEnqSummary = _isEnquirySummary(id);
        final isSummary = isLedgerSummary || isEnqSummary;
        final isYesNo = _yesNoTaskIds.contains(id);
        final yesNoValue =
            (double.tryParse(qty[id]?.text ?? '') ?? 0) >= 1 ? 'Yes' : 'No';
        Widget readOnlyField(String label, String value) => InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(value,
                key: ValueKey(isEnqSummary
                    ? 'enquiry-summary-$label'
                    : 'ledger-summary-$label')));
        final activityCard = ConstrainedBox(
          key: ValueKey('$branch|$category|$id'),
          constraints: const BoxConstraints(maxWidth: 940),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                  listenable: isLedgerSummary
                      ? Listenable.merge([...emr, ...mins])
                      : isEnqSummary
                          ? Listenable.merge([
                              ...enqName,
                              ...enqPhone,
                              ...enqRemark,
                              ...enqMins
                            ])
                          : const _NeverListenable(),
                  builder: (context, _) =>
                      LayoutBuilder(builder: (context, constraints) {
                        final compact = constraints.maxWidth < 650;
                        final lt = isLedgerSummary
                            ? _ledgerTotals()
                            : isEnqSummary
                                ? _enquiryTotals()
                                : null;
                        final Widget quantityField = isSummary
                            ? readOnlyField('Quantity', '${lt!.count}')
                            : isYesNo
                                ? InputDecorator(
                                    decoration: const InputDecoration(
                                        labelText: 'Yes / No'),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        key: ValueKey('yesno-$id-$yesNoValue'),
                                        isExpanded: true,
                                        isDense: true,
                                        value: yesNoValue,
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'No', child: Text('No')),
                                          DropdownMenuItem(
                                              value: 'Yes', child: Text('Yes')),
                                        ],
                                        onChanged: (v) {
                                          setState(() {
                                            qty[id]!.text =
                                                v == 'Yes' ? '1' : '0';
                                          });
                                        },
                                      ),
                                    ),
                                  )
                                : TextField(
                                    controller: qty[id],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                        labelText: id == 'collection'
                                            ? 'AED'
                                            : 'Quantity'),
                                  );
                        final Widget hoursField = isSummary
                            ? readOnlyField(
                                'Minutes', formatLedgerMinutes(lt!.minutes))
                            : TextField(
                                controller: hours[id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    const InputDecoration(labelText: 'Minutes'),
                              );
                        final Widget? helper = isSummary
                            ? Text(
                                isEnqSummary
                                    ? 'Auto-calculated from enquiry calls below'
                                    : 'Auto-calculated from EMR-wise ledgers below',
                                style: TextStyle(
                                    color: TaskLogStyle.muted, fontSize: 12.5))
                            : null;
                        final numberedTitle = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$activityNumber. ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 15 : 14,
                                color: TaskLogStyle.teal,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                t['name'].toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: compact ? 15 : 14,
                                ),
                              ),
                            ),
                          ],
                        );
                        final showTimer =
                            id != 'enquiries' && !isYesNo && !isSummary;
                        final timer = showTimer
                            ? _timerControls(id, hours[id]!,
                                startKey: 'start-$id', endKey: 'end-$id')
                            : null;
                        if (compact) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                numberedTitle,
                                const SizedBox(height: 14),
                                Row(children: [
                                  Expanded(child: quantityField),
                                  const SizedBox(width: 10),
                                  Expanded(child: hoursField),
                                ]),
                                if (helper != null) ...[
                                  const SizedBox(height: 6),
                                  helper
                                ],
                                if (timer != null) ...[
                                  const SizedBox(height: 10),
                                  timer,
                                ],
                              ]);
                        }
                        final row = Row(children: [
                          Expanded(flex: 3, child: numberedTitle),
                          const SizedBox(width: 16),
                          Expanded(child: quantityField),
                          const SizedBox(width: 12),
                          Expanded(child: hoursField),
                        ]);
                        if (helper != null) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                row,
                                const SizedBox(height: 6),
                                helper
                              ]);
                        }
                        if (timer == null) return row;
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              row,
                              const SizedBox(height: 10),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: timer),
                            ]);
                      })),
            ),
          ),
        );
        if (id == 'enquiries') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [activityCard, enquiryDetailsPanel(activityNumber)],
          );
        }
        return activityCard;
      }),
      if (emrTaskId != null) ...[
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tasks.where((t) => t['id'] != 'ledger_prepared' && t['id'] != 'insurance_ledger_emr' && t['id'] != 'other_tasks').length + 1}. ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: TaskLogStyle.teal,
              ),
            ),
            Expanded(
              child: Text(
                emrTaskId == 'insurance_ledger_emr'
                    ? 'Insurance EMR-wise — EMR number and time taken'
                    : 'Individual ledger preparation — EMR-wise',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        const Text(
            'One EMR per row; preparation quantity and time are calculated automatically.'),
        ...List.generate(
            emr.length,
            (i) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      if (compact) {
                        return Column(children: [
                          Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: emr[i],
                                    decoration: const InputDecoration(
                                        labelText: 'EMR No.'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: TextField(
                                    controller: mins[i],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Minutes'))),
                            IconButton(
                                onPressed: () => setState(() {
                                      emr.removeAt(i).dispose();
                                      remark.removeAt(i).dispose();
                                      mins.removeAt(i).dispose();
                                      if (i < emrStart.length) {
                                        emrStart.removeAt(i);
                                      }
                                      if (i < emrEnd.length) {
                                        emrEnd.removeAt(i);
                                      }
                                      _shiftRunning('emr-', i);
                                    }),
                                icon: const Icon(Icons.delete_outline)),
                          ]),
                          const SizedBox(height: 8),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: _timerControls('emr-$i', mins[i],
                                  startKey: 'emr-start-$i',
                                  endKey: 'emr-end-$i')),
                          const SizedBox(height: 8),
                          TextField(
                              controller: remark[i],
                              decoration:
                                  const InputDecoration(labelText: 'Remarks')),
                        ]);
                      }
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        SizedBox(
                            width: 150,
                            child: TextField(
                                controller: emr[i],
                                decoration: const InputDecoration(
                                    labelText: 'EMR No.'))),
                        SizedBox(
                            width: 260,
                            child: TextField(
                                controller: remark[i],
                                decoration: const InputDecoration(
                                    labelText: 'Remarks'))),
                        SizedBox(
                            width: 145,
                            child: TextField(
                                controller: mins[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Minutes'))),
                        _timerControls('emr-$i', mins[i],
                            startKey: 'emr-start-$i', endKey: 'emr-end-$i'),
                        IconButton(
                            onPressed: () => setState(() {
                                  emr.removeAt(i).dispose();
                                  remark.removeAt(i).dispose();
                                  mins.removeAt(i).dispose();
                                  if (i < emrStart.length) {
                                    emrStart.removeAt(i);
                                  }
                                  if (i < emrEnd.length) {
                                    emrEnd.removeAt(i);
                                  }
                                  _shiftRunning('emr-', i);
                                }),
                            icon: const Icon(Icons.delete_outline))
                      ]);
                    })))),
        OutlinedButton.icon(
            onPressed: () => setState(() {
                  emr.add(TextEditingController());
                  remark.add(TextEditingController());
                  mins.add(TextEditingController());
                  emrStart.add(null);
                  emrEnd.add(null);
                }),
            icon: const Icon(Icons.add),
            label: const Text('Add EMR')),
      ],
      const SizedBox(height: 20),
      const Text(
        'Other task carried out',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      const SizedBox(height: 4),
      const Text(
        'Enter any other tasks not included in the list above and the time taken.',
        style: TextStyle(color: TaskLogStyle.muted, fontSize: 13),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < otherTaskSlots; i++) ...[
        if (i > 0) const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final multi = otherTaskSlots > 1;
                final descField = TextField(
                  controller: otherTaskDesc[i],
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: multi
                        ? 'Other task ${i + 1}'
                        : 'Other task carried out',
                  ),
                );
                final minsField = TextField(
                  controller: otherTaskMins[i],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      descField,
                      const SizedBox(height: 12),
                      minsField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: descField),
                    const SizedBox(width: 16),
                    Expanded(child: minsField),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: saveTasks,
          icon: const Icon(Icons.save),
          label: const Text('Save daily report')),
    ]);
  }

  List<String> get _staffNameList => users
      .where(
          (u) => (u['role'] ?? '').toString().trim().toUpperCase() != 'ADMIN')
      .map((u) => (u['name'] ?? '').toString().trim())
      .where((s) => s.isNotEmpty && s.toLowerCase() != 'administrator')
      .toSet()
      .toList();

  Widget dashboard() {
    final currentUid = (profile['uid'] ?? '').toString().trim();
    final filteredEntries = entries.where((e) {
      final empName = (e['employeeName'] ?? '').toString().trim();
      if (empName.toLowerCase() == 'administrator') return false;
      if (!manager) {
        final rowUid = (e['uid'] ?? '').toString().trim();
        if (currentUid.isNotEmpty &&
            rowUid.isNotEmpty &&
            rowUid != currentUid) {
          return false;
        }
      }
      return true;
    }).toList();
    return PerformanceDashboard(
      records: filteredEntries,
      staffNames: _staffNameList,
      isAdmin: manager,
      currentStaffUid: currentUid,
      currentStaffName: staffDisplayName,
      initialDate: reportDate,
      branch: manager ? adminBranch : null,
      category: manager ? adminCategory : null,
      employee: manager ? adminEmployee : null,
      singleDate: manager ? adminSingleDate : null,
      period: manager ? adminPeriod : null,
      todayOnly: manager ? adminTodayOnly : null,
      onFilterChanged: manager ? _onAdminFilterChanged : null,
      refresh: () async {
        setState(() => loading = true);
        await load();
      },
    );
  }

  ReportCriteria get _adminCriteria => ReportCriteria(
        branch: adminBranch,
        category: adminCategory,
        employee: adminEmployee,
        singleDate: adminSingleDate,
        period: adminPeriod == null
            ? null
            : (start: adminPeriod!.start, end: adminPeriod!.end),
        todayOnly: adminTodayOnly,
      );

  Widget detailedReports() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const ValueKey('export-pdf'),
            onPressed: () => showPayrollReportsDialog(
                context, _adminCriteria, staffDisplayName),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
          ),
        ),
        const SizedBox(height: 12),
        _detailedReportsBody(),
      ]);

  Widget _detailedReportsBody() => StaffDetailedReport(
        records: entries
            .where((e) =>
                (e['employeeName'] ?? '').toString().trim().toLowerCase() !=
                'administrator')
            .toList(),
        staffNames: _staffNameList,
        branch: adminBranch,
        category: adminCategory,
        employee: adminEmployee,
        singleDate: adminSingleDate,
        period: adminPeriod,
        todayOnly: adminTodayOnly,
        onFilterChanged: _onAdminFilterChanged,
        refresh: () async {
          setState(() => loading = true);
          await load();
        },
      );

  Widget taskComparison() => TaskComparisonView(
        records: entries
            .where((e) =>
                (e['employeeName'] ?? '').toString().trim().toLowerCase() !=
                'administrator')
            .toList(),
        staffNames: _staffNameList,
        branch: adminBranch,
        category: adminCategory,
        employee: adminEmployee,
        singleDate: adminSingleDate,
        period: adminPeriod,
        todayOnly: adminTodayOnly,
        onFilterChanged: _onAdminFilterChanged,
        refresh: () async {
          setState(() => loading = true);
          await load();
        },
      );

  Widget branchSelector() => SafeArea(
          child: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.business_outlined,
                        size: 40, color: TaskLogStyle.teal),
                    if (staffDisplayName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Logged in as $staffDisplayName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TaskLogStyle.teal,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Select branch and category',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Choose the task report you want to open.'),
                    const SizedBox(height: 16),
                    if (assignments.isEmpty)
                      Text(error.isEmpty
                          ? 'No branch/category assignment. Contact your administrator.'
                          : error),
                    ...assignments.map((a) => ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: Text(a['branch'].toString()),
                          subtitle: Text(a['category'].toString()),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => selectAssignment(
                              a['branch'].toString(), a['category'].toString()),
                        )),
                  ]),
                ),
              ),
            )),
      ));

  Widget settings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Admin — staff assignments',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Text(
          'Create staff authentication accounts in Firebase Authentication first, then register the UID here.'),
      TextField(
          controller: newUserUid,
          decoration: const InputDecoration(labelText: 'Firebase User UID')),
      TextField(
          controller: newUserName,
          decoration: const InputDecoration(labelText: 'Staff name')),
      TextField(
          controller: newUserEmail,
          decoration: const InputDecoration(labelText: 'Email')),
      DropdownButton<String>(
          value: newUserBranch,
          items: ['ONT-BB', 'ONT-BR1']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => newUserBranch = v!)),
      DropdownButton<String>(
          value: newUserCategory,
          items: [
            'FRONT DESK',
            'INSURANCE USER',
            'ACCOUNTS',
            "DOCTOR'S ZONE",
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => newUserCategory = v!)),
      FilledButton(
          onPressed: () async {
            try {
              await api.request('upsertUser', body: {
                'uid': newUserUid.text,
                'name': newUserName.text,
                'email': newUserEmail.text,
                'role': 'STAFF',
                'branch': newUserBranch,
                'category': newUserCategory
              });
              message('Assignment saved');
              await load();
            } catch (e) {
              message(e.toString());
            }
          },
          child: const Text('Add user / assignment')),
      const SizedBox(height: 15),
      ...users.map((u) => ListTile(
          title: Text('${u['name']} — ${u['role']}'),
          subtitle: Text('${u['email']} | ${u['branch']} / ${u['category']}'))),
    ]);
  }

  Widget responsivePortal(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final pages = manager
        ? ['Dashboard', 'Detailed Reports', 'Task Comparison', 'Settings']
        : ['Daily Tasks', 'My Dashboard'];
    final activePage = pages.contains(page) ? page : pages.first;
    final index = pages.indexOf(activePage);
    final content = Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: narrow ? 12 : 32, vertical: narrow ? 16 : 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
            if (activePage == 'Daily Tasks' && !manager) entryPage(),
            if (activePage == 'Dashboard' || activePage == 'My Dashboard')
              dashboard(),
            if (activePage == 'Detailed Reports' && manager) detailedReports(),
            if (activePage == 'Task Comparison' && manager) taskComparison(),
            if (activePage == 'Settings' && manager) AdminSettings(api: api),
          ]),
        ),
      ),
    );
    IconData navIcon(String p) {
      if (p == 'Daily Tasks') return Icons.edit_note;
      if (p == 'Detailed Reports') return Icons.assignment_outlined;
      if (p == 'Task Comparison') return Icons.compare_arrows;
      if (p == 'Settings') return Icons.settings;
      return Icons.bar_chart;
    }

    if (narrow) {
      return Scaffold(
        appBar: AppBar(
            title: const Row(mainAxisSize: MainAxisSize.min, children: [
              TaskLogBrandMark(size: 32),
              SizedBox(width: 10),
              Flexible(
                  child: Text('Ontario | TaskLog',
                      overflow: TextOverflow.ellipsis))
            ]),
            actions: [
              if (staffDisplayName.isNotEmpty)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline,
                            size: 16, color: TaskLogStyle.teal),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            staffDisplayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: TaskLogStyle.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out'),
            ]),
        body: content,
        bottomNavigationBar: SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                setState(() => page = pages[i]);
                if (pages[i].contains('Dashboard') ||
                    pages[i] == 'Detailed Reports' ||
                    pages[i] == 'Task Comparison') {
                  refreshDashboardData();
                }
              },
              destinations: pages
                  .map((p) => NavigationDestination(
                        icon: Icon(navIcon(p)),
                        label: p,
                      ))
                  .toList(),
            )),
      );
    }
    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 72,
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            TaskLogBrandMark(size: 34),
            SizedBox(width: 12),
            Flexible(
                child: Text('Ontario  |  TaskLog',
                    overflow: TextOverflow.ellipsis))
          ]),
          actions: [
            if (staffDisplayName.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TaskLogStyle.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TaskLogStyle.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline,
                            size: 16, color: TaskLogStyle.teal),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            staffDisplayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TaskLogStyle.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sign out')),
          ]),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NavigationRail(
          minWidth: 90,
          minExtendedWidth: 205,
          extended: MediaQuery.sizeOf(context).width > 1100,
          labelType: MediaQuery.sizeOf(context).width > 1100
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          selectedIndex: index,
          leading: const Padding(
              padding: EdgeInsets.only(top: 22, bottom: 30),
              child: TaskLogBrandMark(size: 48)),
          destinations: pages
              .map((p) => NavigationRailDestination(
                    icon: Icon(navIcon(p)),
                    label: Text(p),
                  ))
              .toList(),
          onDestinationSelected: (i) {
            setState(() => page = pages[i]);
            if (pages[i].contains('Dashboard') ||
                pages[i] == 'Detailed Reports' ||
                pages[i] == 'Task Comparison') {
              refreshDashboardData();
            }
          },
        ),
        Expanded(child: content),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : (!branchSelected && !manager)
          ? Scaffold(body: branchSelector())
          : responsivePortal(context);
}

/// Formats a duration as H:MM:SS, or MM:SS under an hour.
String formatElapsed(Duration d) {
  final secs = d.isNegative ? 0 : d.inSeconds;
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Activity card whose totals come from the enquiry call rows.
const String enquirySummaryTaskId = 'enquiries';

double _parseMinutes(String s) {
  final v = double.tryParse(s.trim()) ?? 0;
  return v > 0 ? v : 0;
}

/// Same rule saveTasks uses to keep an enquiry_detail row: the auto-filled
/// call number alone does not count.
bool isEnquiryRowWorthSaving({
  required String name,
  required String phone,
  required String remarks,
  required String status,
  required String minutes,
}) =>
    name.trim().isNotEmpty ||
    phone.trim().isNotEmpty ||
    remarks.trim().isNotEmpty ||
    status.trim().isNotEmpty ||
    _parseMinutes(minutes) > 0;

typedef EnquiryRowInput = ({
  String name,
  String phone,
  String remarks,
  String status,
  String minutes
});

/// Count of worthwhile enquiry rows and the sum of all rows' minutes.
LedgerTotals computeEnquiryTotals(List<EnquiryRowInput> rows) {
  var count = 0;
  var total = 0.0;
  for (final r in rows) {
    if (isEnquiryRowWorthSaving(
        name: r.name,
        phone: r.phone,
        remarks: r.remarks,
        status: r.status,
        minutes: r.minutes)) {
      count++;
    }
    total += _parseMinutes(r.minutes);
  }
  return LedgerTotals(count, total);
}

/// Activity card whose totals come from the EMR-wise ledger rows.
const String ledgerSummaryTaskId = 'ledger_updated';

class LedgerTotals {
  const LedgerTotals(this.count, this.minutes);
  final int count;
  final double minutes;
}

/// Count of rows with a non-empty EMR No. and the sum of all rows' minutes
/// (negative/invalid values count as 0).
LedgerTotals computeLedgerTotals(List<String> emrNos, List<String> minutes) {
  final count = emrNos.where((e) => e.trim().isNotEmpty).length;
  var total = 0.0;
  for (final m in minutes) {
    final v = double.tryParse(m.trim()) ?? 0;
    if (v > 0) total += v;
  }
  return LedgerTotals(count, total);
}

String formatLedgerMinutes(double m) =>
    m == m.roundToDouble() ? m.toInt().toString() : m.toStringAsFixed(1);

class _NeverListenable extends Listenable {
  const _NeverListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
