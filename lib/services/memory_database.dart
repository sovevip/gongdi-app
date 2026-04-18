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
  
  int _workerIdCounter = 1;
  int _attendanceIdCounter = 1;
  int _siteLogIdCounter = 1;
  int _salaryRecordIdCounter = 1;
  int _paymentIdCounter = 1;
  int _materialIdCounter = 1;
  int _materialRecordIdCounter = 1;

  List<Map<String, dynamic>> get workers => _workers;
  List<Map<String, dynamic>> get attendance => _attendance;
  List<Map<String, dynamic>> get siteLogs => _siteLogs;
  List<Map<String, dynamic>> get salaryRecords => _salaryRecords;
  List<Map<String, dynamic>> get payments => _payments;
  List<Map<String, dynamic>> get materials => _materials;
  List<Map<String, dynamic>> get materialRecords => _materialRecords;

  int insertWorker(Map<String, dynamic> worker) {
    final id = _workerIdCounter++;
    _workers.add({'id': id, ...worker});
    return id;
  }

  List<Map<String, dynamic>> getAllWorkers() {
    return List.from(_workers.reversed);
  }

  Map<String, dynamic>? getWorkerById(int id) {
    try {
      return _workers.firstWhere((w) => w['id'] == id);
    } catch (_) {
      return null;
    }
  }

  int updateWorker(int id, Map<String, dynamic> worker) {
    final index = _workers.indexWhere((w) => w['id'] == id);
    if (index != -1) {
      _workers[index] = {'id': id, ...worker};
      return 1;
    }
    return 0;
  }

  int deleteWorker(int id) {
    final index = _workers.indexWhere((w) => w['id'] == id);
    if (index != -1) {
      _workers.removeAt(index);
      return 1;
    }
    return 0;
  }

  int insertAttendance(Map<String, dynamic> attendance) {
    final workerId = attendance['worker_id'];
    final date = attendance['date'];
    final existingIndex = _attendance.indexWhere(
      (a) => a['worker_id'] == workerId && a['date'] == date,
    );
    
    if (existingIndex != -1) {
      _attendance[existingIndex] = {
        'id': _attendance[existingIndex]['id'],
        ...attendance
      };
      return 1;
    }
    
    final id = _attendanceIdCounter++;
    _attendance.add({'id': id, ...attendance});
    return id;
  }

  List<Map<String, dynamic>> getAttendanceByDate(String date) {
    final results = _attendance.where((a) => a['date'] == date).toList();
    return results.map((a) {
      final worker = getWorkerById(a['worker_id'] as int);
      return {
        ...a,
        'name': worker?['name'] ?? '未知',
        'work_type': worker?['work_type'] ?? '',
      };
    }).toList();
  }

  Map<String, int> getAttendanceStats(int workerId, String monthStart, String monthEnd) {
    final presentCount = _attendance.where((a) =>
      a['worker_id'] == workerId &&
      a['date'] != null &&
      a['date'].compareTo(monthStart) >= 0 &&
      a['date'].compareTo(monthEnd) <= 0 &&
      a['is_present'] == 1
    ).length;
    
    final absentCount = _attendance.where((a) =>
      a['worker_id'] == workerId &&
      a['date'] != null &&
      a['date'].compareTo(monthStart) >= 0 &&
      a['date'].compareTo(monthEnd) <= 0 &&
      a['is_present'] == 0
    ).length;
    
    final leaveCount = _attendance.where((a) =>
      a['worker_id'] == workerId &&
      a['date'] != null &&
      a['date'].compareTo(monthStart) >= 0 &&
      a['date'].compareTo(monthEnd) <= 0 &&
      a['is_present'] == 2
    ).length;

    return {'present': presentCount, 'absent': absentCount, 'leave': leaveCount};
  }

  List<Map<String, dynamic>> getAttendanceByWorker(int workerId, String monthStart, String monthEnd) {
    return _attendance.where((a) =>
      a['worker_id'] == workerId &&
      a['date'] != null &&
      a['date'].compareTo(monthStart) >= 0 &&
      a['date'].compareTo(monthEnd) <= 0
    ).toList();
  }

  Map<String, int> getTodayAttendanceStats(String date) {
    final totalWorkers = _workers.length;
    final todayRecords = _attendance.where((a) => a['date'] == date).toList();
    
    int present = 0;
    int absent = 0;
    int leave = 0;
    
    for (var record in todayRecords) {
      final status = record['is_present'] as int?;
      if (status == 1) present++;
      else if (status == 0) absent++;
      else if (status == 2) leave++;
    }
    
    return {
      'total': totalWorkers,
      'present': present,
      'absent': absent,
      'leave': leave,
      'unmarked': totalWorkers - present - absent - leave,
    };
  }

  int insertSiteLog(Map<String, dynamic> log) {
    final id = _siteLogIdCounter++;
    _siteLogs.add({'id': id, ...log});
    return id;
  }

  Map<String, dynamic>? getSiteLogByDate(String date) {
    try {
      return _siteLogs.firstWhere((l) => l['date'] == date);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> getSiteLogsByMonth(String monthStart, String monthEnd) {
    return _siteLogs.where((l) =>
      l['date'] != null &&
      l['date'].compareTo(monthStart) >= 0 &&
      l['date'].compareTo(monthEnd) <= 0
    ).toList();
  }

  int insertSalaryRecord(Map<String, dynamic> record) {
    final id = _salaryRecordIdCounter++;
    _salaryRecords.add({'id': id, ...record});
    return id;
  }

  List<Map<String, dynamic>> getSalaryRecordsByWorker(int workerId) {
    return _salaryRecords.where((r) => r['worker_id'] == workerId).toList();
  }

  double getTotalPaidByWorker(int workerId) {
    return _salaryRecords
        .where((r) => r['worker_id'] == workerId)
        .fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
  }

  List<Map<String, dynamic>> getAllSalaryRecords() {
    return _salaryRecords.map((r) {
      final worker = getWorkerById(r['worker_id'] as int);
      return {
        ...r,
        'name': worker?['name'] ?? '未知',
        'work_type': worker?['work_type'] ?? '',
      };
    }).toList();
  }

  int insertPayment(Map<String, dynamic> payment) {
    final id = _paymentIdCounter++;
    _payments.add({'id': id, ...payment});
    return id;
  }

  List<Map<String, dynamic>> getPaymentsByWorker(int workerId) {
    return _payments.where((p) => p['worker_id'] == workerId).toList();
  }

  double getTotalPaymentsByWorker(int workerId) {
    return _payments
        .where((p) => p['worker_id'] == workerId)
        .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));
  }

  List<Map<String, dynamic>> getAllPayments() {
    return _payments.map((p) {
      final worker = getWorkerById(p['worker_id'] as int);
      return {
        ...p,
        'name': worker?['name'] ?? '未知',
        'work_type': worker?['work_type'] ?? '',
      };
    }).toList();
  }

  int insertMaterial(Map<String, dynamic> material) {
    final id = _materialIdCounter++;
    _materials.add({'id': id, ...material});
    return id;
  }

  List<Map<String, dynamic>> getAllMaterials() {
    return List.from(_materials)..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  int updateMaterial(int id, Map<String, dynamic> material) {
    final index = _materials.indexWhere((m) => m['id'] == id);
    if (index != -1) {
      _materials[index] = {'id': id, ...material};
      return 1;
    }
    return 0;
  }

  int deleteMaterial(int id) {
    final index = _materials.indexWhere((m) => m['id'] == id);
    if (index != -1) {
      _materials.removeAt(index);
      return 1;
    }
    return 0;
  }

  int insertMaterialRecord(Map<String, dynamic> record) {
    final id = _materialRecordIdCounter++;
    _materialRecords.add({'id': id, ...record});
    return id;
  }

  List<Map<String, dynamic>> getMaterialRecords(int materialId) {
    return _materialRecords.where((r) => r['material_id'] == materialId).map((r) {
      final material = _materials.firstWhere((m) => m['id'] == materialId, orElse: () => {});
      return {
        ...r,
        'name': material['name'] ?? '',
        'unit': material['unit'] ?? '',
      };
    }).toList();
  }

  List<Map<String, dynamic>> getAllMaterialRecords() {
    return _materialRecords.map((r) {
      final material = _materials.firstWhere((m) => m['id'] == r['material_id'], orElse: () => {});
      return {
        ...r,
        'name': material['name'] ?? '',
        'unit': material['unit'] ?? '',
      };
    }).toList();
  }

  double getMaterialStock(int materialId) {
    final totalIn = _materialRecords
        .where((r) => r['material_id'] == materialId && r['type'] == 'in')
        .fold(0.0, (sum, r) => sum + ((r['quantity'] as num?)?.toDouble() ?? 0));
    final totalOut = _materialRecords
        .where((r) => r['material_id'] == materialId && r['type'] == 'out')
        .fold(0.0, (sum, r) => sum + ((r['quantity'] as num?)?.toDouble() ?? 0));
    return totalIn - totalOut;
  }

  List<Map<String, dynamic>> getMaterialsWithStock() {
    return _materials.map((m) {
      final materialId = m['id'] as int;
      final totalIn = _materialRecords
          .where((r) => r['material_id'] == materialId && r['type'] == 'in')
          .fold(0.0, (sum, r) => sum + ((r['quantity'] as num?)?.toDouble() ?? 0));
      final totalOut = _materialRecords
          .where((r) => r['material_id'] == materialId && r['type'] == 'out')
          .fold(0.0, (sum, r) => sum + ((r['quantity'] as num?)?.toDouble() ?? 0));
      return {
        ...m,
        'total_in': totalIn,
        'total_out': totalOut,
        'stock': totalIn - totalOut,
      };
    }).toList();
  }

  Map<String, double> getFinanceSummary(String monthStart, String monthEnd) {
    double totalSalary = 0;
    double totalPaid = 0;

    for (var worker in _workers) {
      final workerId = worker['id'] as int;
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      
      final presentCount = _attendance.where((a) =>
        a['worker_id'] == workerId &&
        a['date'] != null &&
        a['date'].compareTo(monthStart) >= 0 &&
        a['date'].compareTo(monthEnd) <= 0 &&
        a['is_present'] == 1
      ).length;
      
      totalSalary += presentCount * dailyWage;
    }

    totalPaid = _payments
        .where((p) => 
          p['date'] != null &&
          p['date'].compareTo(monthStart) >= 0 &&
          p['date'].compareTo(monthEnd) <= 0
        )
        .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

    return {
      'totalSalary': totalSalary,
      'totalPaid': totalPaid,
      'totalOwed': totalSalary - totalPaid,
    };
  }

  List<Map<String, dynamic>> getWorkerFinanceList(String monthStart, String monthEnd) {
    return _workers.map((worker) {
      final workerId = worker['id'] as int;
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      
      final presentCount = _attendance.where((a) =>
        a['worker_id'] == workerId &&
        a['date'] != null &&
        a['date'].compareTo(monthStart) >= 0 &&
        a['date'].compareTo(monthEnd) <= 0 &&
        a['is_present'] == 1
      ).length;
      
      final paid = _payments
          .where((p) => p['worker_id'] == workerId)
          .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));
      
      final salary = presentCount * dailyWage;

      return {
        'id': workerId,
        'name': worker['name'],
        'work_type': worker['work_type'],
        'daily_wage': dailyWage,
        'work_days': presentCount,
        'total_salary': salary,
        'total_paid': paid,
        'owed': salary - paid,
      };
    }).toList();
  }
}
