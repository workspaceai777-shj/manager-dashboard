import 'package:flutter/material.dart';
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
      builder: (context, snap) => snap.data == null ? const LoginPage() : const Portal(),
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
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_hospital, size: 54),
          const SizedBox(height: 12),
          const Text('Ontario Staff Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : () async {
            setState(() { busy = true; error = ''; });
            try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text); }
            catch (e) { setState(() => error = 'Sign-in failed. Check your credentials and account status.'); }
            if (mounted) setState(() => busy = false);
          }, child: const Text('Sign in'))
        ],
      ))),
    )),
  );
}

class Portal extends StatefulWidget {
  const Portal({super.key});
  @override State<Portal> createState() => _PortalState();
}
class _PortalState extends State<Portal> {
  final api = StaffApi();
  Map<String, dynamic> profile = {};
  List<dynamic> assignments = [], tasks = [], entries = [], users = [];
  String branch = '', category = '', page = 'Daily Tasks', error = '';
  DateTime reportDate = DateTime.now();
  bool branchSelected = false;
  bool loading = true;
  final qty = <String, TextEditingController>{}, hours = <String, TextEditingController>{};
  final emr = <TextEditingController>[], remark = <TextEditingController>[], mins = <TextEditingController>[];
  final newUserEmail = TextEditingController(), newUserName = TextEditingController(), newUserUid = TextEditingController();
  String newUserBranch = 'ONT-BB', newUserCategory = 'FRONT DESK';

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final b = Map<String, dynamic>.from(await api.request('bootstrap'));
      profile = Map<String,dynamic>.from(b['profile'] ?? {});
      assignments = List.from(b['assignments'] ?? []);
      // A branch/category must be explicitly chosen by the staff member.
      // Do not pre-load the first assignment: its asynchronous response can
      // overwrite a different category selected on the login chooser.
      if (!branchSelected) {
        branch = '';
        category = '';
        tasks = [];
      }
      if (profile['role'] == 'ADMIN' || profile['role'] == 'MANAGER') {
        entries = List.from((await api.request('dashboard', body: {'from': _date(DateTime.now().subtract(const Duration(days:365))), 'to': _date(DateTime.now())}))['entries'] ?? []);
      }
      if (profile['role'] == 'ADMIN') users = List.from((await api.request('users'))['users'] ?? []);
      error = '';
    } catch (e) { error = e.toString(); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> selectAssignment(String nextBranch, String nextCategory) async {
    if (!assignments.any((a) =>
        a['branch'] == nextBranch && a['category'] == nextCategory)) {
      message('This branch/category is not assigned to your account');
      return;
    }
    setState(() => loading = true);
    try {
      final response = await api.request('tasks', body: {
        'branch': nextBranch,
        'category': nextCategory,
      });
      final nextTasks = List<dynamic>.from(response['tasks'] ?? []);
      // Fail closed if a stale or mismatched task catalog is received.
      // INSURANCE USER and ACCOUNTS have distinct task ID namespaces.
      if (nextCategory == 'INSURANCE USER' &&
          (nextTasks.isEmpty ||
           nextTasks.any((t) => !t['id'].toString().startsWith('insurance_')))) {
        throw StateError('Incorrect Insurance task list returned. Please retry.');
      }
      if (nextCategory == 'ACCOUNTS' &&
          (nextTasks.isEmpty ||
           nextTasks.any((t) => !t['id'].toString().startsWith('accounts_')))) {
        throw StateError('Incorrect Accounts task list returned. Please retry.');
      }
      if (nextCategory == 'FRONT DESK' &&
          nextTasks.any((t) =>
              t['id'].toString().startsWith('insurance_') ||
              t['id'].toString().startsWith('accounts_'))) {
        throw StateError('Incorrect Front Desk task list returned. Please retry.');
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
        branchSelected = true;
        page = 'Daily Tasks';
        error = '';
      });
    } catch (e) {
      message('Unable to load tasks: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _date(DateTime d) => '${d.year.toString().padLeft(4,"0")}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
  bool get manager => profile['role'] == 'ADMIN' || profile['role'] == 'MANAGER';
  void message(String s) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> saveTasks() async {
    final data = <Map<String,dynamic>>[];
    for (final task in tasks) {
      final id = task['id'].toString();
      final q = double.tryParse(qty[id]?.text ?? '') ?? 0;
      final h = double.tryParse(hours[id]?.text ?? '') ?? 0;
      if(q > 0 || h > 0) data.add({'taskId': id, 'quantity': q, 'hours': h});
    }
    final ledgerTask = tasks.where((t)=> t['id'] == 'ledger_prepared').toList();
    if(ledgerTask.isNotEmpty) {
      for (int i=0;i<emr.length;i++) {
        final m = int.tryParse(mins[i].text) ?? 0;
        if (emr[i].text.trim().isNotEmpty && m>0) {
          data.add({'taskId':'ledger_prepared','emr':emr[i].text.trim(),
            'remarks':remark[i].text.trim(),'quantity':1,'hours':m/60});
        }
      }
    }
    if(data.isEmpty){message('Enter at least one task');return;}
    try {
      await api.request('save',body:{'branch':branch,'category':category,'date':_date(reportDate),'entries':data});
      for(final c in qty.values){c.clear();}
      for(final c in hours.values){c.clear();}
      emr.clear();remark.clear();mins.clear();setState((){});
      message('Tasks saved');
    } catch (e) {message(e.toString());}
  }

  Widget entryPage() {
    if(assignments.isEmpty) return const Text('No branch/category assignment. Contact your administrator.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing:12,runSpacing:8,children: [
        DropdownButton<String>(value:'$branch|$category',items:assignments.map<DropdownMenuItem<String>>((a){
          final v='${a['branch']}|${a['category']}';return DropdownMenuItem(value:v,child:Text('${a['branch']} — ${a['category']}'));
        }).toList(),onChanged:(v) async {
          if (v == null) return;
          final selection = v.split('|');
          await selectAssignment(selection[0], selection[1]);
        }),
        OutlinedButton.icon(onPressed:() async {final x=await showDatePicker(context:context,initialDate:reportDate,firstDate:DateTime(2024),lastDate:DateTime(2035));if(x!=null)setState(()=>reportDate=x);}, icon:const Icon(Icons.calendar_month),label:Text(_date(reportDate))),
      ]),
      const SizedBox(height:24), const Text('Daily task report',style:TextStyle(fontWeight:FontWeight.w800,fontSize:27,color:TaskLogStyle.ink)),
      const SizedBox(height:5),const Text('Record quantities and actual time spent on each activity',style:TextStyle(color:TaskLogStyle.muted)),
      const SizedBox(height:20), const Text('Activities',style:TextStyle(fontWeight:FontWeight.w700,fontSize:18)),
      const SizedBox(height:8),
      ...tasks.where((t)=>t['id']!='ledger_prepared').map((t){
        final id=t['id'].toString();
        qty.putIfAbsent(id,()=>TextEditingController());
        hours.putIfAbsent(id,()=>TextEditingController());
        return ConstrainedBox(key:ValueKey('$branch|$category|$id'),constraints:const BoxConstraints(maxWidth:940),child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(
          crossAxisAlignment:WrapCrossAlignment.center,spacing:12,runSpacing:8,children:[
            SizedBox(width:360,child:Text(t['name'],style:const TextStyle(fontWeight:FontWeight.w500))),
            SizedBox(width:115,child:TextField(controller:qty[id],keyboardType:TextInputType.number,decoration:InputDecoration(labelText:id=='collection'?'AED':'Quantity',isDense:true,border:const OutlineInputBorder()))),
            SizedBox(width:115,child:TextField(controller:hours[id],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Hours',isDense:true,border:OutlineInputBorder()))),
          ],
        ))));
      }),
      if(tasks.any((t)=>t['id']=='ledger_prepared')) ...[
        const SizedBox(height:16),
        const Text('Individual ledger preparation — EMR-wise',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
        const Text('One EMR per row; preparation quantity and hours are calculated automatically.'),
        ...List.generate(emr.length,(i)=>Card(child:Padding(padding:const EdgeInsets.all(10),
          child:Wrap(spacing:10,runSpacing:10,children:[
            SizedBox(width:150,child:TextField(controller:emr[i],decoration:const InputDecoration(labelText:'EMR No.'))),
            SizedBox(width:260,child:TextField(controller:remark[i],decoration:const InputDecoration(labelText:'Remarks'))),
            SizedBox(width:145,child:TextField(controller:mins[i],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Minutes'))),
            IconButton(onPressed:()=>setState((){emr.removeAt(i);remark.removeAt(i);mins.removeAt(i);}),icon:const Icon(Icons.delete_outline))
          ])))),
        OutlinedButton.icon(onPressed:()=>setState((){emr.add(TextEditingController());remark.add(TextEditingController());mins.add(TextEditingController());}),icon:const Icon(Icons.add),label:const Text('Add EMR')),
      ],
      const SizedBox(height:20),
      FilledButton.icon(onPressed:saveTasks,icon:const Icon(Icons.save),label:const Text('Save daily report')),
    ]);
  }

  Widget dashboard()=>PerformanceDashboard(
    records: entries,
    refresh: () async {setState(()=>loading=true);await load();},
  );

  Widget branchSelector() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.business_outlined, size: 40, color: TaskLogStyle.teal),
            const SizedBox(height: 12),
            const Text('Select branch and category',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
    ),
  );

  Widget settings() {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Admin — staff assignments',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const Text('Create staff authentication accounts in Firebase Authentication first, then register the UID here.'),
      TextField(controller:newUserUid,decoration:const InputDecoration(labelText:'Firebase User UID')),
      TextField(controller:newUserName,decoration:const InputDecoration(labelText:'Staff name')),
      TextField(controller:newUserEmail,decoration:const InputDecoration(labelText:'Email')),
      DropdownButton<String>(value:newUserBranch,items:['ONT-BB','ONT-BR1'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>newUserBranch=v!)),
      DropdownButton<String>(value:newUserCategory,items:['FRONT DESK','INSURANCE USER','ACCOUNTS'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>newUserCategory=v!)),
      FilledButton(onPressed:() async {try{
        await api.request('upsertUser',body:{'uid':newUserUid.text,'name':newUserName.text,'email':newUserEmail.text,'role':'STAFF','branch':newUserBranch,'category':newUserCategory});
        message('Assignment saved'); await load();
      } catch(e){message(e.toString());}},child:const Text('Add user / assignment')),
      const SizedBox(height:15),
      ...users.map((u)=>ListTile(title:Text('${u['name']} — ${u['role']}'),subtitle:Text('${u['email']} | ${u['branch']} / ${u['category']}'))),
    ]);
  }
  Widget responsivePortal(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final pages = ['Daily Tasks','Dashboard','Settings'];
    final index = pages.indexOf(page).clamp(0,2);
    final content = Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal:narrow?16:32,vertical:narrow?18:28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth:1400),
          child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            if(error.isNotEmpty) Text(error,style:const TextStyle(color:Colors.red)),
            if(page=='Daily Tasks')entryPage(),
            if(page=='Dashboard')manager?dashboard():const Text('Manager access required'),
            if(page=='Settings')profile['role']=='ADMIN'?const AdminSettings():const Text('Admin access required'),
          ]),
        ),
      ),
    );
    if (narrow) {
      return Scaffold(
        appBar:AppBar(title:const Text('Ontario | TaskLog'),actions:[
          IconButton(onPressed:()=>FirebaseAuth.instance.signOut(),
            icon:const Icon(Icons.logout),tooltip:'Sign out'),
        ]),
        body:content,
        bottomNavigationBar:NavigationBar(
          selectedIndex:index,
          onDestinationSelected:(i)=>setState(()=>page=pages[i]),
          destinations:const [
            NavigationDestination(icon:Icon(Icons.edit_note),label:'Daily Tasks'),
            NavigationDestination(icon:Icon(Icons.bar_chart),label:'Dashboard'),
            NavigationDestination(icon:Icon(Icons.settings),label:'Settings'),
          ],
        ),
      );
    }
    return Scaffold(
      appBar:AppBar(toolbarHeight:72,title:const Row(children:[
        Icon(Icons.spa,color:TaskLogStyle.teal),SizedBox(width:12),
        Text('Ontario  |  TaskLog')]),actions:[
        TextButton(onPressed:()=>FirebaseAuth.instance.signOut(),child:const Text('Sign out')),
      ]),
      body:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        NavigationRail(
          minWidth:90,minExtendedWidth:205,
          extended:MediaQuery.sizeOf(context).width>1100,
          selectedIndex:index,
          leading:const Padding(padding:EdgeInsets.only(top:22,bottom:30),
            child:CircleAvatar(radius:24,backgroundColor:Color(0xFF285277),
              child:Icon(Icons.spa,color:Colors.white))),
          destinations:const [
            NavigationRailDestination(icon:Icon(Icons.edit_note),label:Text('Daily Tasks')),
            NavigationRailDestination(icon:Icon(Icons.bar_chart),label:Text('Dashboard')),
            NavigationRailDestination(icon:Icon(Icons.settings),label:Text('Settings')),
          ],
          onDestinationSelected:(i)=>setState(()=>page=pages[i]),
        ),
        Expanded(child:content),
      ]),
    );
  }

  @override Widget build(BuildContext context) => loading
      ? const Scaffold(body:Center(child:CircularProgressIndicator()))
      : !branchSelected
          ? Scaffold(body:branchSelector())
          : responsivePortal(context);
}
