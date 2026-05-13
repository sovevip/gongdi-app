import 'package:flutter/foundation.dart' show kIsWeb;

class MemoryDatabase {
  static final MemoryDatabase _instance = MemoryDatabase._internal();
  factory MemoryDatabase() => _instance;
  MemoryDatabase._internal();

  final List<Map<String, dynamic>> _workers = [];
  final List<Map<String, dynamic>> _attendance = [];
  final List<Map<String, dynamic>> _siteLogs = [];
  final List<Map<String, dynamic>> _salaryRecords = [];
  final List<Map<String, dynamic>> _payments = [];
  final List<Map<String, dynamic>> _materials = [];
  final List<Map<String, dynamic>> _materialRecords = [];
  
  int _workerIdCounter = 1, _attendanceIdCounter = 1, _siteLogIdCounter = 1, _salaryRecordIdCounter = 1, _paymentIdCounter = 1, _materialIdCounter = 1, _materialRecordIdCounter = 1;

  int insertWorker(Map<String, dynamic> worker) {
    final id = _workerIdCounter++; final dw = (worker['daily_wage'] as num?)?.toDouble() ?? 0; final ot = (worker['overtime_rate'] as num?)?.toDouble();
    _workers.add({'id': id, ...worker, 'overtime_rate': ot ?? (dw / 8)}); return id;
  }
  List<Map<String, dynamic>> getAllWorkers() => List.from(_workers.reversed);
  Map<String, dynamic>? getWorkerById(int id) { try { return _workers.firstWhere((w) => w['id'] == id); } catch (_) { return null; } }
  int updateWorker(int id, Map<String, dynamic> w) { final i = _workers.indexWhere((x) => x['id'] == id); if (i != -1) { _workers[i] = {'id': id, ..._workers[i], ...w}; return 1; } return 0; }
  int deleteWorker(int id) { final i = _workers.indexWhere((w) => w['id'] == id); if (i != -1) { _workers.removeAt(i); return 1; } return 0; }

  int insertAttendance(Map<String, dynamic> a) { final ei = _attendance.indexWhere((x) => x['worker_id'] == a['worker_id'] && x['date'] == a['date']); if (ei != -1) { _attendance[ei] = {'id': _attendance[ei]['id'], ...a}; return 1; } final id = _attendanceIdCounter++; _attendance.add({'id': id, ...a}); return id; }
  List<Map<String, dynamic>> getAttendanceByDate(String date) => _attendance.where((a) => a['date'] == date).map((a) { final w = getWorkerById(a['worker_id'] as int); return {...a, 'name': w?['name'] ?? '未知', 'work_type': w?['work_type'] ?? ''}; }).toList();
  Map<String, dynamic> getAttendanceStats(int wid, String ms, String me) { final pc=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).length; final ac=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==0).length; final lc=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==2).length; final oh=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).fold(0.0,(s,a)=>s+((a['overtime_hours'] as num?)?.toDouble()??0)); return {'present':pc,'absent':ac,'leave':lc,'overtime_hours':oh}; }
  Map<String, dynamic> getCumulativeAttendanceStats(int wid) { final all=_attendance.where((a)=>a['worker_id']==wid); return {'present':all.where((a)=>a['is_present']==1).length,'absent':all.where((a)=>a['is_present']==0).length,'leave':all.where((a)=>a['is_present']==2).length,'overtime_hours':all.where((a)=>a['is_present']==1).fold(0.0,(s,a)=>s+((a['overtime_hours'] as num?)?.toDouble()??0))}; }
  List<Map<String, dynamic>> getAttendanceByWorker(int wid, String ms, String me) => _attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0).toList();
  Map<String, int> getTodayAttendanceStats(String date) { final today=_attendance.where((a)=>a['date']==date).toList(); int p=0,a=0,l=0; for(var r in today){final s=r['is_present'] as int?;if(s==1)p++;else if(s==0)a++;else if(s==2)l++;} return {'total':_workers.length,'present':p,'absent':a,'leave':l,'unmarked':_workers.length-p-a-l}; }
  int insertSiteLog(Map<String, dynamic> l) { final id=_siteLogIdCounter++; _siteLogs.add({'id':id,...l}); return id; }
  Map<String, dynamic>? getSiteLogByDate(String d) { try { return _siteLogs.firstWhere((l)=>l['date']==d); } catch(_) { return null; } }
  List<Map<String, dynamic>> getSiteLogsByMonth(String ms,String me) => _siteLogs.where((l)=>l['date']!=null&&l['date'].compareTo(ms)>=0&&l['date'].compareTo(me)<=0).toList();
  int insertSalaryRecord(Map<String, dynamic> r) { final id=_salaryRecordIdCounter++; _salaryRecords.add({'id':id,...r}); return id; }
  List<Map<String, dynamic>> getSalaryRecordsByWorker(int wid) => _salaryRecords.where((r)=>r['worker_id']==wid).toList();
  double getTotalPaidByWorker(int wid) => _salaryRecords.where((r)=>r['worker_id']==wid).fold(0.0,(s,r)=>s+((r['amount'] as num?)?.toDouble()??0));
  List<Map<String, dynamic>> getAllSalaryRecords() => _salaryRecords.map((r){final w=getWorkerById(r['worker_id'] as int);return{...r,'name':w?['name']??'未知','work_type':w?['work_type']??''};}).toList();
  int insertPayment(Map<String, dynamic> p) { final id=_paymentIdCounter++; _payments.add({'id':id,...p}); return id; }
  List<Map<String, dynamic>> getPaymentsByWorker(int wid) => _payments.where((p)=>p['worker_id']==wid).toList();
  double getTotalPaymentsByWorker(int wid) => _payments.where((p)=>p['worker_id']==wid).fold(0.0,(s,p)=>s+((p['amount'] as num?)?.toDouble()??0));
  double getWorkerPaymentsByMonth(int wid,String ms,String me) => _payments.where((p)=>p['worker_id']==wid&&p['date']!=null&&p['date'].compareTo(ms)>=0&&p['date'].compareTo(me)<=0).fold(0.0,(s,p)=>s+((p['amount'] as num?)?.toDouble()??0));
  List<Map<String, dynamic>> getAllPayments() => _payments.map((p){final w=getWorkerById(p['worker_id'] as int);return{...p,'name':w?['name']??'未知','work_type':w?['work_type']??''};}).toList();
  int insertMaterial(Map<String, dynamic> m) { final id=_materialIdCounter++; _materials.add({'id':id,...m}); return id; }
  List<Map<String, dynamic>> getAllMaterials() => List.from(_materials)..sort((a,b)=>(a['name'] as String).compareTo(b['name'] as String));
  int updateMaterial(int id,Map<String, dynamic> m) { final i=_materials.indexWhere((x)=>x['id']==id); if(i!=-1){_materials[i]={'id':id,...m};return 1;} return 0; }
  int deleteMaterial(int id) { final i=_materials.indexWhere((x)=>x['id']==id); if(i!=-1){_materials.removeAt(i);return 1;} return 0; }
  int insertMaterialRecord(Map<String, dynamic> r) { final id=_materialRecordIdCounter++; _materialRecords.add({'id':id,...r}); return id; }
  List<Map<String, dynamic>> getMaterialRecords(int mid) => _materialRecords.where((r)=>r['material_id']==mid).map((r){final m=_materials.firstWhere((x)=>x['id']==mid,orElse:()=>{});return{...r,'name':m['name']??'','unit':m['unit']??''};}).toList();
  List<Map<String, dynamic>> getAllMaterialRecords() => _materialRecords.map((r){final m=_materials.firstWhere((x)=>x['id']==r['material_id'],orElse:()=>{});return{...r,'name':m['name']??'','unit':m['unit']??''};}).toList();
  double getMaterialStock(int mid) { final ti=_materialRecords.where((r)=>r['material_id']==mid&&r['type']=='in').fold(0.0,(s,r)=>s+((r['quantity'] as num?)?.toDouble()??0)); final to=_materialRecords.where((r)=>r['material_id']==mid&&r['type']=='out').fold(0.0,(s,r)=>s+((r['quantity'] as num?)?.toDouble()??0)); return ti-to; }
  List<Map<String, dynamic>> getMaterialsWithStock() => _materials.map((m){final mid=m['id'] as int;final ti=_materialRecords.where((r)=>r['material_id']==mid&&r['type']=='in').fold(0.0,(s,r)=>s+((r['quantity'] as num?)?.toDouble()??0));final to=_materialRecords.where((r)=>r['material_id']==mid&&r['type']=='out').fold(0.0,(s,r)=>s+((r['quantity'] as num?)?.toDouble()??0));return{...m,'total_in':ti,'total_out':to,'stock':ti-to};}).toList();
  Map<String, double> getFinanceSummary(String ms,String me) { double ts=0,tp=0; for(var w in _workers){final wid=w['id'] as int;final dw=(w['daily_wage'] as num?)?.toDouble()??0;final or=(w['overtime_rate'] as num?)?.toDouble();final ot=or??(dw/8);final pc=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).length;final oh=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).fold(0.0,(s,a)=>s+((a['overtime_hours'] as num?)?.toDouble()??0));ts+=pc*dw+oh*ot;} tp=_payments.where((p)=>p['date']!=null&&p['date'].compareTo(ms)>=0&&p['date'].compareTo(me)<=0).fold(0.0,(s,p)=>s+((p['amount'] as num?)?.toDouble()??0));return{'totalSalary':ts,'totalPaid':tp,'totalOwed':ts-tp};}
  List<Map<String, dynamic>> getWorkerFinanceList(String ms,String me) => _workers.map((w){final wid=w['id'] as int;final dw=(w['daily_wage'] as num?)?.toDouble()??0;final or=(w['overtime_rate'] as num?)?.toDouble();final ot=or??(dw/8);final pc=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).length;final oh=_attendance.where((a)=>a['worker_id']==wid&&a['date']!=null&&a['date'].compareTo(ms)>=0&&a['date'].compareTo(me)<=0&&a['is_present']==1).fold(0.0,(s,a)=>s+((a['overtime_hours'] as num?)?.toDouble()??0));final p=_payments.where((x)=>x['worker_id']==wid).fold(0.0,(s,x)=>s+((x['amount'] as num?)?.toDouble()??0));final sal=pc*dw+oh*ot;return{'id':wid,'name':w['name'],'work_type':w['work_type'],'daily_wage':dw,'work_days':pc,'overtime_hours':oh,'total_salary':sal,'total_paid':p,'owed':sal-p};}).toList();
}
