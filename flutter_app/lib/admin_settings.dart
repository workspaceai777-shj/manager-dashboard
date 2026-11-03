import 'package:flutter/material.dart';
import 'api.dart';
import 'tasklog_style.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});
  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final api = StaffApi();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String role = 'STAFF';
  final selected = <String>{};
  List<dynamic> users = [];
  bool busy = false;
  String? editingUid;

  static const branches = ['ONT-BB', 'ONT-BR1'];
  static const categories = ['FRONT DESK', 'INSURANCE USER', 'ACCOUNTS'];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void notice(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> refresh() async {
    try {
      final result = await api.request('users');
      if (mounted) setState(() => users = List.from(result['users'] ?? []));
    } catch (e) {
      notice('Unable to load staff: $e');
    }
  }

  List<Map<String, String>> assignments() => selected.map((key) {
    final parts = key.split('|');
    return {'branch': parts[0], 'category': parts[1]};
  }).toList();

  void editUser(Map<String, dynamic> user) {
    final uid = user['uid'].toString();
    selected.clear();
    for (final u in users.where((u) => u['uid'].toString() == uid)) {
      if ('${u['active']}'.toLowerCase() == 'false') continue;
      selected.add('${u['branch']}|${u['category']}');
    }
    setState(() {
      editingUid = uid;
      name.text = user['name'].toString();
      email.text = user['email'].toString();
      role = user['role'].toString();
      password.clear();
    });
  }

  void resetForm() {
    setState(() {
      editingUid = null;
      name.clear();
      email.clear();
      password.clear();
      role = 'STAFF';
      selected.clear();
    });
  }

  Future<void> save() async {
    if (selected.isEmpty) {
      notice('Select at least one branch and category');
      return;
    }
    if (editingUid == null &&
        (name.text.trim().length < 2 ||
            !email.text.contains('@') ||
            password.text.length < 12)) {
      notice('Enter name, email and a password of at least 12 characters');
      return;
    }
    setState(() => busy = true);
    try {
      if (editingUid == null) {
        await api.request('createStaff', body: {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
          'role': role,
          'assignments': assignments(),
        });
      } else {
        await api.request('replaceAssignments', body: {
          'uid': editingUid,
          'assignments': assignments(),
        });
      }
      notice(editingUid == null ? 'Staff account created' : 'Assignments updated');
      resetForm();
      await refresh();
    } catch (e) {
      notice('Unable to save: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget section(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final unique = <String, Map<String, dynamic>>{};
    for (final entry in users) {
      final user = Map<String, dynamic>.from(entry as Map);
      unique.putIfAbsent(user['uid'].toString(), () => user);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Staff management',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: TaskLogStyle.ink)),
        const SizedBox(height: 5),
        const Text('Manage staff accounts, branch access and user categories.',
            style: TextStyle(color: TaskLogStyle.muted)),
        const SizedBox(height: 16),
        section(editingUid == null ? 'Add new staff' : 'Edit branch and category access',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, enabled: editingUid == null,
              decoration: const InputDecoration(labelText: 'Staff name')),
            const SizedBox(height: 12),
            TextField(controller: email, enabled: editingUid == null,
              decoration: const InputDecoration(labelText: 'Login email')),
            if (editingUid == null) ...[
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Initial password (12+ characters)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'User role'),
                items: ['STAFF', 'MANAGER', 'ADMIN']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => role = v ?? 'STAFF'),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Branch and category access',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Select multiple categories across both branches.'),
            const SizedBox(height: 12),
            ...branches.map((branch) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(branch, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
                  ...categories.map((category) {
                    final key = '$branch|$category';
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(category),
                      value: selected.contains(key),
                      onChanged: busy ? null : (value) => setState(() {
                        if (value == true) {
                          selected.add(key);
                        } else {
                          selected.remove(key);
                        }
                      }),
                    );
                  }),
                ]),
              ),
            )),
            const SizedBox(height: 16),
            Wrap(spacing: 10, children: [
              FilledButton.icon(
                onPressed: busy ? null : save,
                icon: const Icon(Icons.save),
                label: Text(editingUid == null ? 'Create staff user' : 'Update assignments'),
              ),
              if (editingUid != null) OutlinedButton(
                onPressed: busy ? null : resetForm,
                child: const Text('Cancel editing'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        section('Registered staff', Column(children: [
          Row(children: [
            Text('${unique.length} users'),
            const Spacer(),
            TextButton.icon(onPressed: refresh,
              icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ]),
          ...unique.values.map((u) => LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 440;
              if (compact) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${u['email']} · ${u['role']}',
                        softWrap: true, style: const TextStyle(color: TaskLogStyle.muted)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => editUser(u),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit access'),
                    ),
                    const Divider(),
                  ]),
                );
              }
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(u['name'].toString()),
                subtitle: Text('${u['email']} · ${u['role']}'),
                trailing: OutlinedButton(
                  onPressed: () => editUser(u), child: const Text('Edit access')),
              );
            },
          )),
        ])),
      ],
    );
  }
}
