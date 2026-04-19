import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

class WorkerDetailPage extends StatefulWidget {
  final Map<String, dynamic> worker;

  const WorkerDetailPage({super.key, required this.worker});

  @override
  State<WorkerDetailPage> createState() => _WorkerDetailPageState();
}

class _WorkerDetailPageState extends State<WorkerDetailPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic> _attendanceStats = {'present': 0, 'absent': 0, 'leave': 0, 'overtime_hours': 0.0};
  double _totalPaid = 0;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  int get _workerId => widget.worker['id'] as int;
  double get _dailyWage => (widget.worker['daily_wage'] as num?)?.toDouble() ?? 0;

  String get _monthStart => DateTime(_selectedMonth.year, _selectedMonth.month, 1).toIso8601String().split('T').first;
  String get _monthEnd => DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getAttendanceStats(_workerId, _monthStart, _monthEnd);
      final records = await _db.getAttendanceByWorker(_workerId, _monthStart, _monthEnd);
      final payments = await _db.getPaymentsByWorker(_workerId);
      final paid = await _db.getTotalPaymentsByWorker(_workerId);
      
      setState(() {
        _attendanceStats = stats;
        _attendanceRecords = records;
        _payments = payments;
        _totalPaid = paid;
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

  double get _totalSalary {
    final present = (_attendanceStats['present'] as num?)?.toInt() ?? 0;
    final overtime = (_attendanceStats['overtime_hours'] as num?)?.toDouble() ?? 0;
    final hourlyRate = _dailyWage / 8;
    return present * _dailyWage + overtime * hourlyRate;
  }
  double get _owedSalary => _totalSalary - _totalPaid;

  Set<String> get _presentDates => _attendanceRecords
      .where((r) => r['is_present'] == 1)
      .map((r) => r['date'] as String)
      .toSet();

  Set<String> get _absentDates => _attendanceRecords
      .where((r) => r['is_present'] == 0)
      .map((r) => r['date'] as String)
      .toSet();

  Set<String> get _leaveDates => _attendanceRecords
      .where((r) => r['is_present'] == 2)
      .map((r) => r['date'] as String)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worker['name'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: '选择月份',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteWorker,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderCard(context),
                  _buildMonthSelector(context),
                  _buildAttendanceCalendar(context),
                  _buildFinanceTimeline(context),
                  _buildPaymentRecords(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context),
        icon: const Icon(Icons.payment),
        label: const Text('记录发薪'),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Text(
                  (widget.worker['name'] as String?)?.isNotEmpty == true
                      ? widget.worker['name'].substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.worker['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.worker['work_type'] ?? ''} · ${_dailyWage.toStringAsFixed(0)}元/天',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderItem('出勤', '${_attendanceStats['present']}', '天', Colors.green),
              _buildHeaderItem('缺勤', '${_attendanceStats['absent']}', '天', Colors.red),
              _buildHeaderItem('请假', '${_attendanceStats['leave']}', '天', Colors.orange),
              _buildHeaderItem('欠款', '¥${_owedSalary.toStringAsFixed(0)}', '', _owedSalary > 0 ? Colors.amber : Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
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
              Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_selectedMonth.year}年${_selectedMonth.month}月',
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
      ),
    );
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

  Widget _buildAttendanceCalendar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '出勤日历',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildLegend(Colors.green, '出勤'),
                      const SizedBox(width: 12),
                      _buildLegend(Colors.red, '缺勤'),
                      const SizedBox(width: 12),
                      _buildLegend(Colors.orange, '请假'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCalendarGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final daysInMonth = <Widget>[];

    for (var i = 0; i < startingWeekday; i++) {
      daysInMonth.add(const SizedBox());
    }

    for (var day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final dateStr = date.toIso8601String().split('T').first;
      final isPresent = _presentDates.contains(dateStr);
      final isAbsent = _absentDates.contains(dateStr);
      final isLeave = _leaveDates.contains(dateStr);
      final isToday = SiteTimeHelper.isSameDay(date, DateTime.now());
      final isFuture = date.isAfter(DateTime.now());

      daysInMonth.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isPresent
                ? Colors.green.withOpacity(0.2)
                : isAbsent
                    ? Colors.red.withOpacity(0.2)
                    : isLeave
                        ? Colors.orange.withOpacity(0.2)
                        : null,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: AppTheme.primaryColor, width: 2)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isFuture
                      ? Colors.grey[300]
                      : isPresent
                          ? Colors.green[700]
                          : isAbsent
                              ? Colors.red[700]
                              : isLeave
                                  ? Colors.orange[700]
                                  : AppTheme.textPrimary,
                ),
              ),
              if (isPresent || isAbsent || isLeave)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isPresent
                          ? Colors.green
                          : isAbsent
                              ? Colors.red
                              : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((day) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
          children: daysInMonth,
        ),
      ],
    );
  }

  Widget _buildFinanceTimeline(BuildContext context) {
    final timelineItems = <Map<String, dynamic>>[];

    for (var record in _attendanceRecords.where((r) => r['is_present'] == 1)) {
      timelineItems.add({
        'type': 'work',
        'date': record['date'],
        'amount': _dailyWage,
        'description': '干活挣钱',
      });
    }

    for (var payment in _payments) {
      timelineItems.add({
        'type': 'payment',
        'date': payment['date'],
        'amount': payment['amount'],
        'description': payment['note'] ?? '发薪记录',
        'payment': payment,
      });
    }

    timelineItems.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '财务流水线',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (timelineItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.timeline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无记录', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: timelineItems.take(10).map((item) {
                  final isLast = item == timelineItems.take(10).last;
                  final isWork = item['type'] == 'work';
                  return Column(
                    children: [
                      _buildTimelineItem(item, isWork),
                      if (!isLast) const Divider(height: 1, indent: 60),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, bool isWork) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final date = item['date'] as String? ?? '';
    final description = item['description'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isWork ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWork ? Icons.work : Icons.payment,
              color: isWork ? Colors.green : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            isWork ? '+¥${amount.toStringAsFixed(0)}' : '-¥${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isWork ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRecords(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '发薪记录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '共 ${_payments.length} 条',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_payments.isEmpty)
            Card(
              child: Padding(
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
              ),
            )
          else
            Card(
              child: Column(
                children: _payments.map((record) {
                  final isLast = record == _payments.last;
                  return Column(
                    children: [
                      _buildPaymentItem(record),
                      if (!isLast) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> record) {
    final amount = (record['amount'] as num?)?.toDouble() ?? 0;
    final date = record['date'] as String?;
    final note = record['note'] as String?;
    final hasImage = (record['image_path'] as String?)?.isNotEmpty == true;

    return ListTile(
      onTap: () => _showPaymentDetail(record),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.payment, color: Colors.green, size: 20),
      ),
      title: Text(
        note ?? '发薪记录',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            date ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (hasImage) ...[
            const SizedBox(width: 8),
            Icon(Icons.image, size: 14, color: Colors.grey[400]),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
        ],
      ),
    );
  }

  void _showPaymentDetail(Map<String, dynamic> record) {
    final amount = (record['amount'] as num?)?.toDouble() ?? 0;
    final date = record['date'] as String? ?? '';
    final note = record['note'] as String? ?? '无备注';
    final imagePath = record['image_path'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: imagePath != null ? 0.8 : 0.5,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payment, color: Colors.green, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¥${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              date,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '备注说明',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      note,
                      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                    ),
                  ),
                  if (imagePath != null && imagePath.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '领款单据',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullImage(imagePath),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                ),
                              )
                            : Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: kIsWeb
                ? Image.network(imagePath, fit: BoxFit.contain)
                : Image.file(File(imagePath), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWorker() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除工人 "${widget.worker['name']}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _db.deleteWorker(_workerId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已删除'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showPaymentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentDialog(
        workerId: _workerId,
        workerName: widget.worker['name'] ?? '',
        owedAmount: _owedSalary,
        onConfirm: (amount, date, note, imagePath) async {
          try {
            await _db.insertPayment({
              'worker_id': _workerId,
              'amount': double.tryParse(amount) ?? 0,
              'date': date.toIso8601String().split('T').first,
              'note': note,
              'image_path': imagePath,
              'created_at': DateTime.now().toIso8601String(),
            });
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已记录发薪 ¥$amount'),
                  backgroundColor: Colors.green,
                ),
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
}

class _PaymentDialog extends StatefulWidget {
  final int workerId;
  final String workerName;
  final double owedAmount;
  final Function(String amount, DateTime date, String note, String? imagePath) onConfirm;

  const _PaymentDialog({
    required this.workerId,
    required this.workerName,
    required this.owedAmount,
    required this.onConfirm,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.owedAmount > 0) {
      _amountController.text = widget.owedAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
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
                  Text(
                    '记录发薪 - ${widget.workerName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '发薪金额',
                  prefixText: '¥ ',
                  prefixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _amountController.clear(),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '领款单据',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Spacer(),
                  if (!kIsWeb) ...[
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('拍照'),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo, size: 18),
                    label: const Text('相册'),
                  ),
                ],
              ),
              if (_imagePath != null) ...[
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(_imagePath!, height: 120, fit: BoxFit.cover)
                          : Image.file(File(_imagePath!), height: 120, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePath = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入发薪金额'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    widget.onConfirm(
      _amountController.text,
      _selectedDate,
      _noteController.text,
      _imagePath,
    );
  }
}
