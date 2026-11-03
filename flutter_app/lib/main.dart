import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api.dart';
import 'config.dart';
import 'tasklog_style.dart';
import 'performance_dashboard.dart';
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
  final newUserEmail = TextEditingController(),
      newUserName = TextEditingController(),
      newUserUid = TextEditingController();
  String newUserBranch = 'ONT-BB', newUserCategory = 'FRONT DESK';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
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
      entries = List.from((await api.request(
            profile['role'] == 'ADMIN' ? 'dashboard' : 'myDashboard',
            body: {
              'from': _date(DateTime.now().subtract(const Duration(days: 365))),
              'to': _date(DateTime.now()),
            },
          ))['entries'] ??
          []);
      if (profile['role'] == 'ADMIN') {
        users = List.from((await api.request('users'))['users'] ?? []);
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
      final nextTasks = List<dynamic>.from(response['tasks'] ?? [])
          .where((t) => t['id'].toString() != 'accounts_r4_ledgers')
          .map((t) {
        final item = Map<String, dynamic>.from(t as Map);
        if (item['id'] == 'accounts_insurance_ledgers') {
          item['name'] = 'Individual Ledgers for Insurance Updated & Showed';
        }
        return item;
      }).toList();
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
      if (nextCategory == 'FRONT DESK' &&
          nextTasks.any((t) =>
              t['id'].toString().startsWith('insurance_') ||
              t['id'].toString().startsWith('accounts_'))) {
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
      remark.clear();
      mins.clear();
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
          'from': _date(DateTime.now().subtract(const Duration(days: 365))),
          'to': _date(DateTime.now()),
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
    remark.clear();
    mins.clear();
    final previous = List<dynamic>.from(result['entries'] ?? []);
    for (final raw in previous) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['taskId'].toString();
      if (id == 'ledger_prepared') {
        emr.add(TextEditingController(text: row['emr'].toString()));
        remark.add(TextEditingController(text: row['remarks'].toString()));
        final time = double.tryParse(row['hours'].toString()) ?? 0;
        mins.add(TextEditingController(text: (time * 60).round().toString()));
      } else {
        qty.putIfAbsent(id, () => TextEditingController()).text =
            row['quantity'].toString();
        hours.putIfAbsent(id, () => TextEditingController()).text =
            row['hours'].toString();
      }
    }
    setState(() => savedReportExists = previous.isNotEmpty);
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

  Future<void> saveTasks() async {
    final data = <Map<String, dynamic>>[];
    for (final task in tasks) {
      final id = task['id'].toString();
      final q = double.tryParse(qty[id]?.text ?? '') ?? 0;
      final h = double.tryParse(hours[id]?.text ?? '') ?? 0;
      if (q > 0 || h > 0) {
        data.add({
          'taskId': id,
          'quantity': id == 'collection' ? q : q.round(),
          'hours': h,
        });
      }
    }
    final ledgerTask =
        tasks.where((t) => t['id'] == 'ledger_prepared').toList();
    if (ledgerTask.isNotEmpty) {
      for (int i = 0; i < emr.length; i++) {
        final m = int.tryParse(mins[i].text) ?? 0;
        if (emr[i].text.trim().isNotEmpty && m > 0) {
          data.add({
            'taskId': 'ledger_prepared',
            'emr': emr[i].text.trim(),
            'remarks': remark[i].text.trim(),
            'quantity': 1,
            'hours': m / 60
          });
        }
      }
    }
    if (data.isEmpty && !savedReportExists) {
      message('Enter at least one task');
      return;
    }
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
      const Text('Record quantities and actual time spent on each activity',
          style: TextStyle(color: TaskLogStyle.muted)),
      const SizedBox(height: 20),
      const Text('Activities',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 8),
      ...tasks
          .where((t) => t['id'] != 'ledger_prepared')
          .toList()
          .asMap()
          .entries
          .map((entry) {
        final activityNumber = entry.key + 1;
        final t = entry.value;
        final id = t['id'].toString();
        qty.putIfAbsent(id, () => TextEditingController());
        hours.putIfAbsent(id, () => TextEditingController());
        final isYesNo = _yesNoTaskIds.contains(id);
        final yesNoValue =
            (double.tryParse(qty[id]?.text ?? '') ?? 0) >= 1 ? 'Yes' : 'No';
        return ConstrainedBox(
          key: ValueKey('$branch|$category|$id'),
          constraints: const BoxConstraints(maxWidth: 940),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final Widget quantityField = isYesNo
                    ? InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Yes / No'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: ValueKey('yesno-$id-$yesNoValue'),
                            isExpanded: true,
                            isDense: true,
                            value: yesNoValue,
                            items: const [
                              DropdownMenuItem(value: 'No', child: Text('No')),
                              DropdownMenuItem(
                                  value: 'Yes', child: Text('Yes')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                qty[id]!.text = v == 'Yes' ? '1' : '0';
                              });
                            },
                          ),
                        ),
                      )
                    : TextField(
                        controller: qty[id],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: id == 'collection' ? 'AED' : 'Quantity'),
                      );
                final hoursField = TextField(
                  controller: hours[id],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Hours'),
                );
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
                      ]);
                }
                return Row(children: [
                  Expanded(flex: 3, child: numberedTitle),
                  const SizedBox(width: 16),
                  Expanded(child: quantityField),
                  const SizedBox(width: 12),
                  Expanded(child: hoursField),
                ]);
              }),
            ),
          ),
        );
      }),
      if (tasks.any((t) => t['id'] == 'ledger_prepared')) ...[
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tasks.where((t) => t['id'] != 'ledger_prepared').length + 1}. ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: TaskLogStyle.teal,
              ),
            ),
            const Expanded(
              child: Text(
                'Individual ledger preparation — EMR-wise',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        const Text(
            'One EMR per row; preparation quantity and hours are calculated automatically.'),
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
                                    }),
                                icon: const Icon(Icons.delete_outline)),
                          ]),
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
                        IconButton(
                            onPressed: () => setState(() {
                                  emr.removeAt(i).dispose();
                                  remark.removeAt(i).dispose();
                                  mins.removeAt(i).dispose();
                                }),
                            icon: const Icon(Icons.delete_outline))
                      ]);
                    })))),
        OutlinedButton.icon(
            onPressed: () => setState(() {
                  emr.add(TextEditingController());
                  remark.add(TextEditingController());
                  mins.add(TextEditingController());
                }),
            icon: const Icon(Icons.add),
            label: const Text('Add EMR')),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: saveTasks,
          icon: const Icon(Icons.save),
          label: const Text('Save daily report')),
    ]);
  }

  Widget dashboard() => PerformanceDashboard(
        records: entries,
        isAdmin: manager,
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
          items: ['FRONT DESK', 'INSURANCE USER', 'ACCOUNTS']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
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
    final pages =
        manager ? ['Dashboard', 'Settings'] : ['Daily Tasks', 'My Dashboard'];
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
            if (activePage == 'Settings' && manager) AdminSettings(api: api),
          ]),
        ),
      ),
    );
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
                if (pages[i].contains('Dashboard')) refreshDashboardData();
              },
              destinations: pages
                  .map((p) => NavigationDestination(
                        icon: Icon(p == 'Daily Tasks'
                            ? Icons.edit_note
                            : p == 'Settings'
                                ? Icons.settings
                                : Icons.bar_chart),
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
                    icon: Icon(p == 'Daily Tasks'
                        ? Icons.edit_note
                        : p == 'Settings'
                            ? Icons.settings
                            : Icons.bar_chart),
                    label: Text(p),
                  ))
              .toList(),
          onDestinationSelected: (i) {
            setState(() => page = pages[i]);
            if (pages[i].contains('Dashboard')) refreshDashboardData();
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
