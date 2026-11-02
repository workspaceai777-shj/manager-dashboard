import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'tasklog_style.dart';

class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key,required this.records,required this.refresh});
  final List<dynamic> records;
  final Future<void> Function() refresh;
  @override State<PerformanceDashboard> createState()=>_PerformanceDashboardState();
}
class _PerformanceDashboardState extends State<PerformanceDashboard> {
  String branch='ALL',category='ALL',employee='ALL';
  DateTimeRange? period;
  double num(dynamic x)=>double.tryParse(x.toString())??0;
  List<String> options(String key)=>['ALL',...widget.records.map((e)=>e[key].toString())].toSet().toList();
  List<dynamic> get rows=>widget.records.where((e){
    if(branch!='ALL'&&e['branch']!=branch)return false;
    if(category!='ALL'&&e['category']!=category)return false;
    if(employee!='ALL'&&e['employeeName']!=employee)return false;
    if(period!=null){
      final d=DateTime.tryParse(e['date'].toString());
      if(d==null||d.isBefore(period!.start)||d.isAfter(period!.end))return false;
    }
    return true;
  }).toList();
  Widget picker(String name,String selected,List<String> opts,ValueChanged<String?> change)=>
    SizedBox(width:180,child:DropdownButtonFormField<String>(key:ValueKey(name+selected),
      initialValue:opts.contains(selected)?selected:'ALL',
      decoration:InputDecoration(labelText:name,isDense:true),
      items:opts.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
      onChanged:change));
  Widget tile(String title,String val,IconData icon,Color color)=>
    Container(width:220,padding:const EdgeInsets.all(22),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
        border:Border.all(color:const Color(0xFFE5EAF2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CircleAvatar(backgroundColor:color.withValues(alpha:0.1),child:Icon(icon,color:color)),
        const SizedBox(height:16),
        Text(val,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w800,color:TaskLogStyle.ink)),
        Text(title,style:const TextStyle(color:TaskLogStyle.muted)),
      ]));
  Widget panel(String title,Widget child)=>Container(
    padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0xFFE5EAF2))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      const SizedBox(height:16),child,
    ]));
  @override Widget build(BuildContext context){
    final totals=<String,double>{}, hours=<String,double>{},byEmployee=<String,double>{};
    for(final e in rows){
      final task=e['taskId'].toString();
      totals[task]=(totals[task]??0)+num(e['quantity']);
      hours[task]=(hours[task]??0)+num(e['hours']);
      if(task=='ledger_prepared'||task=='ledger_updated'){
        final name=e['employeeName'].toString();
        byEmployee[name]=(byEmployee[name]??0)+num(e['quantity']);
      }
    }
    final quantityTasks=totals.entries.where((e)=>e.key!='collection').toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final hourTasks=hours.entries.where((e)=>e.value>0).toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final totalHours=hours.values.fold(0.0,(a,b)=>a+b);
    final max=quantityTasks.isEmpty?1.0:quantityTasks.first.value+1;
    const chartColors=[Color(0xFF0E9488),Color(0xFF397DCE),Color(0xFF8D66D5),
      Color(0xFFE6A34C),Color(0xFFE67988),Color(0xFF52B9AA)];
    final chart1=panel('Task quantities',SizedBox(height:280,child:quantityTasks.isEmpty
      ?const Center(child:Text('No records for selected filters'))
      :BarChart(BarChartData(maxY:max*1.18,gridData:const FlGridData(show:false),
        borderData:FlBorderData(show:false),
        titlesData:const FlTitlesData(topTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
          rightTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
          bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:false))),
        barGroups:quantityTasks.take(9).toList().asMap().entries.map((e)=>
          BarChartGroupData(x:e.key,barRods:[BarChartRodData(toY:e.value.value,
            color:TaskLogStyle.teal,width:24,
            borderRadius:const BorderRadius.vertical(top:Radius.circular(7)))] )).toList(),
      ))));
    final chart2=panel('Time spent by activity',SizedBox(height:280,child:hourTasks.isEmpty
      ?const Center(child:Text('No hours recorded'))
      :Row(children:[
        Expanded(child:PieChart(PieChartData(centerSpaceRadius:45,sections:
          hourTasks.take(6).toList().asMap().entries.map((e)=>
            PieChartSectionData(value:e.value.value,color:chartColors[e.key%6],
              radius:44,showTitle:false)).toList()))),
        SizedBox(width:160,child:Column(mainAxisAlignment:MainAxisAlignment.center,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(totalHours.toStringAsFixed(2)+' hours',
            style:const TextStyle(fontWeight:FontWeight.w700,fontSize:18)),
          const SizedBox(height:8),
          ...hourTasks.take(5).map((e)=>Padding(padding:const EdgeInsets.only(bottom:5),
            child:Text(e.key.replaceAll('_',' ')+' — '+e.value.toStringAsFixed(1)+'h',
              maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11)))),
        ])),
      ])));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Performance dashboard',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:TaskLogStyle.ink)),
        SizedBox(height:5),
        Text('A clear view of daily activity, hours and ledger work',
          style:TextStyle(color:TaskLogStyle.muted)),
      ])),OutlinedButton.icon(onPressed:widget.refresh,icon:const Icon(Icons.refresh),label:const Text('Refresh'))]),
      const SizedBox(height:24),
      Wrap(spacing:12,runSpacing:12,children:[
        picker('Branch',branch,options('branch'),(v)=>setState(()=>branch=v??'ALL')),
        picker('Category',category,options('category'),(v)=>setState(()=>category=v??'ALL')),
        picker('Employee',employee,options('employeeName'),(v)=>setState(()=>employee=v??'ALL')),
        OutlinedButton.icon(icon:const Icon(Icons.date_range),
          onPressed:() async {final v=await showDateRangePicker(context:context,
            firstDate:DateTime(2024),lastDate:DateTime(2036));
            if(v!=null)setState(()=>period=v);},
          label:Text(period==null?'All dates':'Filtered dates')),
        if(period!=null)TextButton(onPressed:()=>setState(()=>period=null),child:const Text('Clear')),
      ]),
      const SizedBox(height:24),
      Wrap(spacing:14,runSpacing:14,children:[
        tile('Ledgers prepared',(totals['ledger_prepared']??0).toStringAsFixed(0),
          Icons.menu_book_outlined,chartColors[1]),
        tile('Ledgers updated',(totals['ledger_updated']??0).toStringAsFixed(0),
          Icons.edit_document,chartColors[0]),
        tile('Total task hours',totalHours.toStringAsFixed(2),Icons.schedule,chartColors[3]),
        tile('Collection (AED)',(totals['collection']??0).toStringAsFixed(2),
          Icons.account_balance_wallet_outlined,chartColors[2]),
      ]),
      const SizedBox(height:20),
      LayoutBuilder(builder:(context,c)=>c.maxWidth>850
        ?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:chart1),const SizedBox(width:16),Expanded(child:chart2)])
        :Column(children:[chart1,const SizedBox(height:16),chart2])),
      const SizedBox(height:20),
      panel('Ledger activity by employee',byEmployee.isEmpty
        ?const Text('No ledger records')
        :Column(children:byEmployee.entries.map((e)=>Padding(
          padding:const EdgeInsets.symmetric(vertical:10),
          child:Row(children:[
            SizedBox(width:140,child:Text(e.key,overflow:TextOverflow.ellipsis)),
            Expanded(child:LinearProgressIndicator(value:(e.value/25).clamp(0.0,1.0),
              minHeight:10,borderRadius:BorderRadius.circular(12))),
            const SizedBox(width:14),
            Text(e.value.toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w700)),
          ]))).toList())),
      const SizedBox(height:12),
      const Text('Ledger bars show recorded quantities, not target achievement.',
        style:TextStyle(color:TaskLogStyle.muted,fontSize:12)),
    ]);
  }
}
