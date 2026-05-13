import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'memory_database.dart';

class DatabaseService {
  static Database? _database;
  static MemoryDatabase? _memoryDb;
  static const String _databaseName = 'gongdi.db';
  static const int _databaseVersion = 5;

  static const String tableWorkers = 'workers';
  static const String tableAttendance = 'attendance';
  static const String tableSiteLogs = 'site_logs';
  static const String tableSalaryRecords = 'salary_records';
  static const String tablePayments = 'payments';
  static const String tableMaterials = 'materials';
  static const String tableMaterialRecords = 'material_records';

  Future<dynamic> get _db async {
    if (kIsWeb) { _memoryDb ??= MemoryDatabase(); return _memoryDb!; }
    return await database;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE $tableWorkers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, work_type TEXT NOT NULL, daily_wage REAL NOT NULL DEFAULT 0, overtime_rate REAL, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE $tableAttendance (id INTEGER PRIMARY KEY AUTOINCREMENT, worker_id INTEGER NOT NULL, date TEXT NOT NULL, is_present INTEGER NOT NULL DEFAULT 1, overtime_hours REAL NOT NULL DEFAULT 0, note TEXT, created_at TEXT NOT NULL, FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id))''');
    await db.execute('''CREATE TABLE $tableSiteLogs (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, weather TEXT, content TEXT, voice_note TEXT, image_paths TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE $tableSalaryRecords (id INTEGER PRIMARY KEY AUTOINCREMENT, worker_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL, FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id))''');
    await db.execute('''CREATE TABLE $tablePayments (id INTEGER PRIMARY KEY AUTOINCREMENT, worker_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, note TEXT, image_path TEXT, created_at TEXT NOT NULL, FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id))''');
    await db.execute('''CREATE TABLE $tableMaterials (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, unit TEXT NOT NULL, min_stock REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE $tableMaterialRecords (id INTEGER PRIMARY KEY AUTOINCREMENT, material_id INTEGER NOT NULL, type TEXT NOT NULL, quantity REAL NOT NULL, date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL, FOREIGN KEY (material_id) REFERENCES $tableMaterials (id))''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''CREATE TABLE IF NOT EXISTS $tablePayments (id INTEGER PRIMARY KEY AUTOINCREMENT, worker_id INTEGER NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL, note TEXT, image_path TEXT, created_at TEXT NOT NULL, FOREIGN KEY (worker_id) REFERENCES $tableWorkers (id))''');
      await db.execute('''CREATE TABLE IF NOT EXISTS $tableMaterials (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, unit TEXT NOT NULL, min_stock REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS $tableMaterialRecords (id INTEGER PRIMARY KEY AUTOINCREMENT, material_id INTEGER NOT NULL, type TEXT NOT NULL, quantity REAL NOT NULL, date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL, FOREIGN KEY (material_id) REFERENCES $tableMaterials (id))''');
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE $tablePayments ADD COLUMN image_path TEXT'); } catch (e) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE $tableAttendance ADD COLUMN overtime_hours REAL NOT NULL DEFAULT 0'); } catch (e) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE $tableWorkers ADD COLUMN overtime_rate REAL'); } catch (e) {}
    }
  }

  Future<int> insertWorker(Map<String, dynamic> worker) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).insertWorker(worker);
    final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
    final data = Map<String, dynamic>.from(worker);
    data['overtime_rate'] ??= dailyWage / 8;
    return await (db as Database).insert(tableWorkers, data);
  }

  Future<List<Map<String, dynamic>>> getAllWorkers() async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getAllWorkers();
    return await (db as Database).query(tableWorkers, orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getWorkerById(int id) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getWorkerById(id);
    final results = await (db as Database).query(tableWorkers, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateWorker(int id, Map<String, dynamic> worker) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).updateWorker(id, worker);
    return await (db as Database).update(tableWorkers, worker, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteWorker(int id) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).deleteWorker(id);
    return await (db as Database).delete(tableWorkers, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAttendance(Map<String, dynamic> attendance) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).insertAttendance(attendance);
    final existing = await (db as Database).query(tableAttendance, where: 'worker_id = ? AND date = ?', whereArgs: [attendance['worker_id'], attendance['date']]);
    if (existing.isNotEmpty) return await db.update(tableAttendance, attendance, where: 'worker_id = ? AND date = ?', whereArgs: [attendance['worker_id'], attendance['date']]);
    return await db.insert(tableAttendance, attendance);
  }

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getAttendanceByDate(date);
    return await (db as Database).rawQuery('SELECT a.*, w.name, w.work_type FROM $tableAttendance a LEFT JOIN $tableWorkers w ON a.worker_id = w.id WHERE a.date = ? ORDER BY w.name', [date]);
  }

  Future<Map<String, dynamic>> getAttendanceStats(int workerId, String monthStart, String monthEnd) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getAttendanceStats(workerId, monthStart, monthEnd);
    final presentCount = Sqflite.firstIntValue(await (db as Database).rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [workerId, monthStart, monthEnd])) ?? 0;
    final absentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 0', [workerId, monthStart, monthEnd])) ?? 0;
    final leaveCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 2', [workerId, monthStart, monthEnd])) ?? 0;
    final overtimeResult = await db.rawQuery('SELECT SUM(overtime_hours) as total_overtime FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [workerId, monthStart, monthEnd]);
    final totalOvertime = (overtimeResult.first['total_overtime'] as num?)?.toDouble() ?? 0;
    return {'present': presentCount, 'absent': absentCount, 'leave': leaveCount, 'overtime_hours': totalOvertime};
  }

  Future<Map<String, dynamic>> getCumulativeAttendanceStats(int workerId) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getCumulativeAttendanceStats(workerId);
    final presentCount = Sqflite.firstIntValue(await (db as Database).rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND is_present = 1', [workerId])) ?? 0;
    final absentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND is_present = 0', [workerId])) ?? 0;
    final leaveCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND is_present = 2', [workerId])) ?? 0;
    final overtimeResult = await db.rawQuery('SELECT SUM(overtime_hours) as total FROM $tableAttendance WHERE worker_id = ? AND is_present = 1', [workerId]);
    return {'present': presentCount, 'absent': absentCount, 'leave': leaveCount, 'overtime_hours': (overtimeResult.first['total'] as num?)?.toDouble() ?? 0};
  }

  Future<List<Map<String, dynamic>>> getAttendanceByWorker(int workerId, String monthStart, String monthEnd) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getAttendanceByWorker(workerId, monthStart, monthEnd);
    return await (db as Database).query(tableAttendance, where: 'worker_id = ? AND date >= ? AND date <= ?', whereArgs: [workerId, monthStart, monthEnd], orderBy: 'date ASC');
  }

  Future<Map<String, int>> getTodayAttendanceStats(String date) async {
    final db = await _db;
    if (kIsWeb) return (db as MemoryDatabase).getTodayAttendanceStats(date);
    final totalWorkers = Sqflite.firstIntValue(await (db as Database).rawQuery('SELECT COUNT(*) FROM $tableWorkers')) ?? 0;
    final presentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE date = ? AND is_present = 1', [date])) ?? 0;
    final absentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE date = ? AND is_present = 0', [date])) ?? 0;
    final leaveCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE date = ? AND is_present = 2', [date])) ?? 0;
    return {'total': totalWorkers, 'present': presentCount, 'absent': absentCount, 'leave': leaveCount, 'unmarked': totalWorkers - presentCount - absentCount - leaveCount};
  }

  Future<int> insertSiteLog(Map<String, dynamic> log) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).insertSiteLog(log); return await (db as Database).insert(tableSiteLogs, log); }
  Future<Map<String, dynamic>?> getSiteLogByDate(String date) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getSiteLogByDate(date); final r = await (db as Database).query(tableSiteLogs, where: 'date = ?', whereArgs: [date]); return r.isNotEmpty ? r.first : null; }
  Future<List<Map<String, dynamic>>> getSiteLogsByMonth(String ms, String me) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getSiteLogsByMonth(ms, me); return await (db as Database).query(tableSiteLogs, where: 'date >= ? AND date <= ?', whereArgs: [ms, me], orderBy: 'date DESC'); }
  Future<int> insertSalaryRecord(Map<String, dynamic> r) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).insertSalaryRecord(r); return await (db as Database).insert(tableSalaryRecords, r); }
  Future<List<Map<String, dynamic>>> getSalaryRecordsByWorker(int wid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getSalaryRecordsByWorker(wid); return await (db as Database).query(tableSalaryRecords, where: 'worker_id = ?', whereArgs: [wid], orderBy: 'date DESC'); }
  Future<double> getTotalPaidByWorker(int wid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getTotalPaidByWorker(wid); final r = await (db as Database).rawQuery('SELECT SUM(amount) as total FROM $tableSalaryRecords WHERE worker_id = ?', [wid]); return (r.first['total'] as num?)?.toDouble() ?? 0; }
  Future<List<Map<String, dynamic>>> getAllSalaryRecords() async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getAllSalaryRecords(); return await (db as Database).rawQuery('SELECT s.*, w.name, w.work_type FROM $tableSalaryRecords s LEFT JOIN $tableWorkers w ON s.worker_id = w.id ORDER BY s.date DESC'); }
  Future<int> insertPayment(Map<String, dynamic> p) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).insertPayment(p); return await (db as Database).insert(tablePayments, p); }
  Future<List<Map<String, dynamic>>> getPaymentsByWorker(int wid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getPaymentsByWorker(wid); return await (db as Database).query(tablePayments, where: 'worker_id = ?', whereArgs: [wid], orderBy: 'date DESC'); }
  Future<double> getTotalPaymentsByWorker(int wid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getTotalPaymentsByWorker(wid); final r = await (db as Database).rawQuery('SELECT SUM(amount) as total FROM $tablePayments WHERE worker_id = ?', [wid]); return (r.first['total'] as num?)?.toDouble() ?? 0; }
  Future<double> getWorkerPaymentsByMonth(int wid, String ms, String me) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getWorkerPaymentsByMonth(wid, ms, me); final r = await (db as Database).rawQuery('SELECT COALESCE(SUM(amount), 0) as total FROM $tablePayments WHERE worker_id = ? AND date >= ? AND date <= ?', [wid, ms, me]); return (r.first['total'] as num?)?.toDouble() ?? 0; }
  Future<List<Map<String, dynamic>>> getAllPayments() async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getAllPayments(); return await (db as Database).rawQuery('SELECT p.*, w.name, w.work_type FROM $tablePayments p LEFT JOIN $tableWorkers w ON p.worker_id = w.id ORDER BY p.date DESC'); }
  Future<int> insertMaterial(Map<String, dynamic> m) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).insertMaterial(m); return await (db as Database).insert(tableMaterials, m); }
  Future<List<Map<String, dynamic>>> getAllMaterials() async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getAllMaterials(); return await (db as Database).query(tableMaterials, orderBy: 'name'); }
  Future<int> updateMaterial(int id, Map<String, dynamic> m) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).updateMaterial(id, m); return await (db as Database).update(tableMaterials, m, where: 'id = ?', whereArgs: [id]); }
  Future<int> deleteMaterial(int id) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).deleteMaterial(id); return await (db as Database).delete(tableMaterials, where: 'id = ?', whereArgs: [id]); }
  Future<int> insertMaterialRecord(Map<String, dynamic> r) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).insertMaterialRecord(r); return await (db as Database).insert(tableMaterialRecords, r); }
  Future<List<Map<String, dynamic>>> getMaterialRecords(int mid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getMaterialRecords(mid); return await (db as Database).rawQuery('SELECT mr.*, m.name, m.unit FROM $tableMaterialRecords mr LEFT JOIN $tableMaterials m ON mr.material_id = m.id WHERE mr.material_id = ? ORDER BY mr.date DESC', [mid]); }
  Future<List<Map<String, dynamic>>> getAllMaterialRecords() async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getAllMaterialRecords(); return await (db as Database).rawQuery('SELECT mr.*, m.name, m.unit FROM $tableMaterialRecords mr LEFT JOIN $tableMaterials m ON mr.material_id = m.id ORDER BY mr.date DESC'); }
  Future<double> getMaterialStock(int mid) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getMaterialStock(mid); final r = await (db as Database).rawQuery('SELECT COALESCE(SUM(CASE WHEN type = \'in\' THEN quantity ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN type = \'out\' THEN quantity ELSE 0 END), 0) as stock FROM $tableMaterialRecords WHERE material_id = ?', [mid]); return (r.first['stock'] as num?)?.toDouble() ?? 0; }
  Future<List<Map<String, dynamic>>> getMaterialsWithStock() async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getMaterialsWithStock(); return await (db as Database).rawQuery('SELECT m.*, COALESCE(SUM(CASE WHEN mr.type = \'in\' THEN mr.quantity ELSE 0 END), 0) as total_in, COALESCE(SUM(CASE WHEN mr.type = \'out\' THEN mr.quantity ELSE 0 END), 0) as total_out, COALESCE(SUM(CASE WHEN mr.type = \'in\' THEN mr.quantity ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN mr.type = \'out\' THEN mr.quantity ELSE 0 END), 0) as stock FROM $tableMaterials m LEFT JOIN $tableMaterialRecords mr ON m.id = mr.material_id GROUP BY m.id ORDER BY m.name'); }
  Future<Map<String, double>> getFinanceSummary(String ms, String me) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getFinanceSummary(ms, me); final workers = await (db as Database).query(tableWorkers); double totalSalary = 0, totalPaid = 0; for (var w in workers) { final wid = w['id'] as int; final dw = (w['daily_wage'] as num?)?.toDouble() ?? 0; final otRate = (w['overtime_rate'] as num?)?.toDouble() ?? (dw / 8); final pc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [wid, ms, me])) ?? 0; final otr = await db.rawQuery('SELECT SUM(overtime_hours) as total_overtime FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [wid, ms, me]); final oth = (otr.first['total_overtime'] as num?)?.toDouble() ?? 0; totalSalary += pc * dw + oth * otRate; } final pr = await db.rawQuery('SELECT SUM(amount) as total FROM $tablePayments WHERE date >= ? AND date <= ?', [ms, me]); totalPaid = (pr.first['total'] as num?)?.toDouble() ?? 0; return {'totalSalary': totalSalary, 'totalPaid': totalPaid, 'totalOwed': totalSalary - totalPaid}; }
  Future<List<Map<String, dynamic>>> getWorkerFinanceList(String ms, String me) async { final db = await _db; if (kIsWeb) return (db as MemoryDatabase).getWorkerFinanceList(ms, me); final workers = await (db as Database).query(tableWorkers); final result = <Map<String, dynamic>>[]; for (var w in workers) { final wid = w['id'] as int; final dw = (w['daily_wage'] as num?)?.toDouble() ?? 0; final otRate = (w['overtime_rate'] as num?)?.toDouble() ?? (dw / 8); final pc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [wid, ms, me])) ?? 0; final otr = await db.rawQuery('SELECT SUM(overtime_hours) as total_overtime FROM $tableAttendance WHERE worker_id = ? AND date >= ? AND date <= ? AND is_present = 1', [wid, ms, me]); final oth = (otr.first['total_overtime'] as num?)?.toDouble() ?? 0; final prr = await db.rawQuery('SELECT SUM(amount) as total FROM $tablePayments WHERE worker_id = ?', [wid]); final paid = (prr.first['total'] as num?)?.toDouble() ?? 0; final salary = pc * dw + oth * otRate; result.add({'id': wid, 'name': w['name'], 'work_type': w['work_type'], 'daily_wage': dw, 'work_days': pc, 'overtime_hours': oth, 'total_salary': salary, 'total_paid': paid, 'owed': salary - paid}); } return result; }
}
