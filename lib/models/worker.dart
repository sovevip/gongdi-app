class Worker {
  final String id;
  final String name;
  final String phone;
  final String workType;
  final int workDaysThisMonth;
  final double totalSalary;
  final double paidSalary;
  final double owedSalary;

  const Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.workType,
    this.workDaysThisMonth = 0,
    this.totalSalary = 0,
    this.paidSalary = 0,
    this.owedSalary = 0,
  });
}

class SalaryRecord {
  final String id;
  final String workerId;
  final double amount;
  final DateTime date;
  final String? note;

  const SalaryRecord({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.date,
    this.note,
  });
}

class SiteLog {
  final String id;
  final DateTime date;
  final String content;
  final List<String> imagePaths;
  final String weather;
  final String? voiceNote;

  const SiteLog({
    required this.id,
    required this.date,
    required this.content,
    this.imagePaths = const [],
    this.weather = '晴天',
    this.voiceNote,
  });
}

class AttendanceRecord {
  final String id;
  final String workerId;
  final String workerName;
  final DateTime date;
  final bool isPresent;
  final String? note;

  const AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.date,
    this.isPresent = true,
    this.note,
  });
}
