import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _workerFinanceList = [];
  List<Map<String, dynamic>> _payments = [];
  Map<String, double> _summary = {'totalSalary': 0, 'totalPaid': 0, 'totalOwed': 0};
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthStart => DateTime(_selectedMonth.year, _selectedMonth.month, 1).toIso8601String().split('T').first;
  String get _monthEnd => DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).toIso8601String().split('T').first;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _db.getFinanceSummary(_monthStart, _monthEnd);
      final workerList = await _db.getWorkerFinanceList(_monthStart, _monthEnd);
      final payments = await _db.getAllPayments();
      
      setState(() {
        _summary = summary;
        _workerFinanceList = workerList;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    if (_workerFinanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无数据可导出'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isExporting = true);
    
    try {
      final excel = Excel.createExcel();
      
      await _createAttendanceSheet(excel);
      await _createSummarySheet(excel);

      final fileName = '考勤工资表_${SiteTimeHelper.formatDateForFile(_selectedMonth)}.xlsx';
      final bytes = excel.encode();
      
      if (bytes != null) {
        if (kIsWeb) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Excel已生成，Web端暂不支持下载'), backgroundColor: Colors.green),
            );
          }
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          if (mounted) {
            await Share.shareXFiles(
              [XFile(filePath)],
              subject: '考勤工资表',
              text: '考勤工资表 - ${SiteTimeHelper.getMonthName(_selectedMonth.month)}',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _createAttendanceSheet(Excel excel) async {
    final sheet = excel['月度考勤汇总'];
    
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    final titleRow = <CellValue>[];
    titleRow.add(TextCellValue('${_selectedMonth.year}年${_selectedMonth.month}月考勤汇总表'));
    for (var i = 1; i < daysInMonth + 5; i++) {
      titleRow.add(TextCellValue(''));
    }
    sheet.appendRow(titleRow);

    final headerRow = <CellValue>[
      TextCellValue('姓名'),
      TextCellValue('工种'),
    ];
    for (var day = 1; day <= daysInMonth; day++) {
      headerRow.add(TextCellValue('$day'));
    }
    headerRow.addAll([
      TextCellValue('总天数'),
      TextCellValue('总加班(h)'),
      TextCellValue('应发工资'),
    ]);
    sheet.appendRow(headerRow);

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final dataStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final nameStyle = CellStyle(
      fontSize: 10,
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final summaryStyle = CellStyle(
      fontSize: 10,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByColumnRow(columnIndex: daysInMonth + 4, rowIndex: 0));

    for (var col = 0; col < daysInMonth + 5; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
      cell.cellStyle = headerStyle;
    }

    for (var worker in _workerFinanceList) {
      final workerId = worker['id'] as int;
      final attendance = await _db.getAttendanceByWorker(workerId, _monthStart, _monthEnd);
      final attendanceMap = {for (var a in attendance) a['date'] as String: a};
      
      final row = <CellValue>[
        TextCellValue(worker['name'] ?? ''),
        TextCellValue(worker['work_type'] ?? ''),
      ];
      
      int presentDays = 0;
      double totalOvertime = 0;
      
      for (var day = 1; day <= daysInMonth; day++) {
        final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final record = attendanceMap[dateStr];
        final isPresent = record?['is_present'] as int?;
        final overtime = (record?['overtime_hours'] as num?)?.toDouble() ?? 0;
        
        String cellValue = '';
        if (isPresent == 1) {
          presentDays++;
          totalOvertime += overtime;
          if (overtime > 0) {
            cellValue = '√+${overtime.toStringAsFixed(0)}h';
          } else {
            cellValue = '√';
          }
        } else if (isPresent == 0) {
          cellValue = '×';
        } else if (isPresent == 2) {
          cellValue = '假';
        }
        row.add(TextCellValue(cellValue));
      }
      
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      final hourlyRate = dailyWage / 8;
      final overtimePay = totalOvertime * hourlyRate;
      final totalSalary = presentDays * dailyWage + overtimePay;
      
      row.addAll([
        TextCellValue(presentDays.toString()),
        TextCellValue(totalOvertime.toStringAsFixed(1)),
        TextCellValue('¥${totalSalary.toStringAsFixed(0)}'),
      ]);
      
      sheet.appendRow(row);
    }

    final totalPresentDays = _workerFinanceList.fold(0, (sum, w) => sum + ((w['work_days'] as num?)?.toInt() ?? 0));
    double totalOvertimeAll = 0;
    double totalSalaryAll = 0;
    for (var worker in _workerFinanceList) {
      final overtime = (worker['overtime_hours'] as num?)?.toDouble() ?? 0;
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      totalOvertimeAll += overtime;
      totalSalaryAll += (worker['work_days'] as num?)?.toInt() ?? 0 * dailyWage + overtime * (dailyWage / 8);
    }
    totalSalaryAll = _summary['totalSalary'] ?? 0;

    final summaryRow = <CellValue>[
      TextCellValue('合计'),
      TextCellValue(''),
    ];
    for (var day = 1; day <= daysInMonth; day++) {
      summaryRow.add(TextCellValue(''));
    }
    summaryRow.addAll([
      TextCellValue(totalPresentDays.toString()),
      TextCellValue(totalOvertimeAll.toStringAsFixed(1)),
      TextCellValue('¥${totalSalaryAll.toStringAsFixed(0)}'),
    ]);
    sheet.appendRow(summaryRow);

    final lastRowIndex = _workerFinanceList.length + 2;
    for (var col = 0; col < daysInMonth + 5; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRowIndex));
      cell.cellStyle = summaryStyle;
    }

    sheet.setColumnWidth(0, 10);
    sheet.setColumnWidth(1, 8);
    for (var col = 2; col < daysInMonth + 2; col++) {
      sheet.setColumnWidth(col, 3.5);
    }
    sheet.setColumnWidth(daysInMonth + 2, 8);
    sheet.setColumnWidth(daysInMonth + 3, 10);
    sheet.setColumnWidth(daysInMonth + 4, 10);

    for (var row = 2; row < _workerFinanceList.length + 2; row++) {
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      nameCell.cellStyle = nameStyle;
      
      final workTypeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      workTypeCell.cellStyle = dataStyle;
      
      for (var col = 2; col < daysInMonth + 5; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.cellStyle = dataStyle;
      }
    }

    final rowHeight = 18.0;
    for (var row = 1; row < _workerFinanceList.length + 3; row++) {
      sheet.setRowHeight(row, rowHeight);
    }
  }

  Future<void> _createSummarySheet(Excel excel) async {
    final sheet = excel['工资结算汇总'];
    
    sheet.appendRow([
      TextCellValue('序号'),
      TextCellValue('姓名'),
      TextCellValue('工种'),
      TextCellValue('日薪(元)'),
      TextCellValue('出勤天数'),
      TextCellValue('加班小时'),
      TextCellValue('加班费(元)'),
      TextCellValue('应发工资(元)'),
      TextCellValue('已发工资(元)'),
      TextCellValue('欠款(元)'),
    ]);

    for (var i = 0; i < _workerFinanceList.length; i++) {
      final worker = _workerFinanceList[i];
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      final overtimeHours = (worker['overtime_hours'] as num?)?.toDouble() ?? 0;
      final overtimePay = overtimeHours * (dailyWage / 8);
      
      sheet.appendRow([
        TextCellValue((i + 1).toString()),
        TextCellValue(worker['name'] ?? ''),
        TextCellValue(worker['work_type'] ?? ''),
        TextCellValue(dailyWage.toStringAsFixed(0)),
        TextCellValue((worker['work_days'] ?? 0).toString()),
        TextCellValue(overtimeHours.toStringAsFixed(1)),
        TextCellValue(overtimePay.toStringAsFixed(0)),
        TextCellValue(((worker['total_salary'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)),
        TextCellValue(((worker['total_paid'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)),
        TextCellValue(((worker['owed'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)),
      ]);
    }

    double totalOvertimeAll = 0;
    double totalOvertimePayAll = 0;
    for (var worker in _workerFinanceList) {
      final overtime = (worker['overtime_hours'] as num?)?.toDouble() ?? 0;
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      totalOvertimeAll += overtime;
      totalOvertimePayAll += overtime * (dailyWage / 8);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('合计:'),
      TextCellValue(totalOvertimeAll.toStringAsFixed(1)),
      TextCellValue(totalOvertimePayAll.toStringAsFixed(0)),
      TextCellValue((_summary['totalSalary'] ?? 0).toStringAsFixed(0)),
      TextCellValue((_summary['totalPaid'] ?? 0).toStringAsFixed(0)),
      TextCellValue((_summary['totalOwed'] ?? 0).toStringAsFixed(0)),
    ]);
  }

  void _showPaymentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentDialog(
        workers: _workerFinanceList,
        onConfirm: (workerId, amount, date, note) async {
          try {
            await _db.insertPayment({
              'worker_id': workerId,
              'amount': double.tryParse(amount) ?? 0,
              'date': date.toIso8601String().split('T').first,
              'note': note,
              'created_at': DateTime.now().toIso8601String(),
            });
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已记录发薪 ¥$amount'), backgroundColor: Colors.green),
              );
              _loadData();
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('财务结算'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: '选择月份',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthSelector(context),
                  const SizedBox(height: 16),
                  _buildSummaryCard(context),
                  const SizedBox(height: 20),
                  _buildWorkerList(context),
                  const SizedBox(height: 20),
                  _buildRecentPayments(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _workerFinanceList.isEmpty ? null : _showPaymentDialog,
        icon: const Icon(Icons.payment),
        label: const Text('记录发薪'),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _isExporting || _workerFinanceList.isEmpty ? null : _exportToExcel,
          icon: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.file_download),
          label: Text(_isExporting ? '导出中...' : '导出专业考勤表'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return GestureDetector(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '${_selectedMonth.year}年${SiteTimeHelper.getMonthName(_selectedMonth.month)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    double totalOvertime = 0;
    double totalOvertimePay = 0;
    for (var worker in _workerFinanceList) {
      final overtime = (worker['overtime_hours'] as num?)?.toDouble() ?? 0;
      final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
      totalOvertime += overtime;
      totalOvertimePay += overtime * (dailyWage / 8);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本月财务概况',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_workerFinanceList.length}人',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFinanceItem(
                  '应发工资',
                  '¥${(_summary['totalSalary'] ?? 0).toStringAsFixed(0)}',
                  Icons.account_balance_wallet,
                ),
              ),
              Container(height: 60, width: 1, color: Colors.white24),
              Expanded(
                child: _buildFinanceItem(
                  '已发工资',
                  '¥${(_summary['totalPaid'] ?? 0).toStringAsFixed(0)}',
                  Icons.check_circle,
                ),
              ),
              Container(height: 60, width: 1, color: Colors.white24),
              Expanded(
                child: _buildFinanceItem(
                  '待发工资',
                  '¥${(_summary['totalOwed'] ?? 0).toStringAsFixed(0)}',
                  Icons.pending_actions,
                  highlight: (_summary['totalOwed'] ?? 0) > 0,
                ),
              ),
            ],
          ),
          if (totalOvertime > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    '加班总计: ${totalOvertime.toStringAsFixed(1)}小时 = ¥${totalOvertimePay.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceItem(String label, String value, IconData icon, {bool highlight = false}) {
    return Column(
      children: [
        Icon(icon, color: highlight ? Colors.amber : Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.amber : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerList(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '工人工资明细',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '点击查看详情',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_workerFinanceList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无工人数据', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _workerFinanceList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final worker = _workerFinanceList[index];
                  return _buildWorkerItem(worker);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerItem(Map<String, dynamic> worker) {
    final owed = (worker['owed'] as num?)?.toDouble() ?? 0;
    final workDays = worker['work_days'] ?? 0;
    final overtimeHours = (worker['overtime_hours'] as num?)?.toDouble() ?? 0;
    final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;
    final overtimePay = overtimeHours * (dailyWage / 8);
    final totalSalary = (worker['total_salary'] as num?)?.toDouble() ?? 0;
    final totalPaid = (worker['total_paid'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              (worker['name'] as String?)?.isNotEmpty == true
                  ? worker['name'].substring(0, 1)
                  : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      worker['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        worker['work_type'] ?? '',
                        style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$workDays天',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '×${dailyWage.toStringAsFixed(0)}元',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (overtimeHours > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${overtimeHours.toStringAsFixed(1)}h加班',
                          style: const TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '=¥${totalSalary.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${totalPaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
              if (owed > 0)
                Text(
                  '欠¥${owed.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments(BuildContext context) {
    final recentPayments = _payments.take(10).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近发薪记录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '共 ${_payments.length} 条',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无发薪记录', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentPayments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = recentPayments[index];
                  return _buildPaymentItem(record);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> record) {
    final amount = (record['amount'] as num?)?.toDouble() ?? 0;
    final name = record['name'] as String? ?? '未知';
    final date = record['date'] as String? ?? '';
    final note = record['note'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payment, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '- $note',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> workers;
  final Function(int workerId, String amount, DateTime date, String note) onConfirm;

  const _PaymentDialog({
    required this.workers,
    required this.onConfirm,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedWorkerId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.payment, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text(
                    '记录发薪',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                value: _selectedWorkerId,
                decoration: const InputDecoration(
                  labelText: '选择工人',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                items: widget.workers.map((w) => DropdownMenuItem(
                  value: w['id'] as int,
                  child: Text('${w['name']} - ${w['work_type']}'),
                )).toList(),
                onChanged: (value) {
                  setState(() => _selectedWorkerId = value);
                  if (value != null) {
                    final worker = widget.workers.firstWhere((w) => w['id'] == value);
                    final owed = (worker['owed'] as num?)?.toDouble() ?? 0;
                    if (owed > 0) {
                      _amountController.text = owed.toStringAsFixed(0);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '发薪金额',
                  prefixText: '¥ ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '发薪日期',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    SiteTimeHelper.formatDate(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '例如：3月份工资',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleConfirm,
                      child: const Text('确认发薪'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleConfirm() {
    if (_selectedWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择工人'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入发薪金额'), backgroundColor: Colors.orange),
      );
      return;
    }
    widget.onConfirm(
      _selectedWorkerId!,
      _amountController.text,
      _selectedDate,
      _noteController.text,
    );
  }
}
