import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

enum AttendanceStatus { unmarked, present, absent, leave }

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> with AutomaticKeepAliveClientMixin {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _workers = [];
  Map<int, AttendanceStatus> _attendanceStatus = {};
  Map<int, double> _overtimeHours = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _db.getAllWorkers();
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      final attendance = await _db.getAttendanceByDate(dateStr);
      
      final status = <int, AttendanceStatus>{};
      final overtime = <int, double>{};
      for (var worker in workers) {
        final workerId = worker['id'] as int;
        final record = attendance.where((a) => a['worker_id'] == workerId).firstOrNull;
        final isPresent = record?['is_present'] as int?;
        if (isPresent == 1) {
          status[workerId] = AttendanceStatus.present;
        } else if (isPresent == 0) {
          status[workerId] = AttendanceStatus.absent;
        } else if (isPresent == 2) {
          status[workerId] = AttendanceStatus.leave;
        } else {
          status[workerId] = AttendanceStatus.unmarked;
        }
        overtime[workerId] = (record?['overtime_hours'] as num?)?.toDouble() ?? 0;
      }
      
      setState(() {
        _workers = workers;
        _attendanceStatus = status;
        _overtimeHours = overtime;
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

  Future<void> _setAttendance(int workerId, AttendanceStatus status, {double? overtime}) async {
    int isPresent;
    switch (status) {
      case AttendanceStatus.present:
        isPresent = 1;
        break;
      case AttendanceStatus.absent:
        isPresent = 0;
        break;
      case AttendanceStatus.leave:
        isPresent = 2;
        break;
      case AttendanceStatus.unmarked:
        return;
    }

    try {
      await _db.insertAttendance({
        'worker_id': workerId,
        'date': _selectedDate.toIso8601String().split('T').first,
        'is_present': isPresent,
        'overtime_hours': overtime ?? _overtimeHours[workerId] ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      setState(() {
        _attendanceStatus[workerId] = status;
        if (overtime != null) {
          _overtimeHours[workerId] = overtime;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateOvertime(int workerId, double hours) async {
    _overtimeHours[workerId] = hours;
    if (_attendanceStatus[workerId] == AttendanceStatus.present) {
      await _setAttendance(workerId, AttendanceStatus.present, overtime: hours);
    }
  }

  Future<void> _markAllPresent() async {
    try {
      for (var worker in _workers) {
        final workerId = worker['id'] as int;
        await _db.insertAttendance({
          'worker_id': workerId,
          'date': _selectedDate.toIso8601String().split('T').first,
          'is_present': 1,
          'overtime_hours': _overtimeHours[workerId] ?? 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        _attendanceStatus[workerId] = AttendanceStatus.present;
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已全部标记出勤'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final presentCount = _attendanceStatus.values.where((v) => v == AttendanceStatus.present).length;
    final absentCount = _attendanceStatus.values.where((v) => v == AttendanceStatus.absent).length;
    final leaveCount = _attendanceStatus.values.where((v) => v == AttendanceStatus.leave).length;
    final unmarkedCount = _workers.length - presentCount - absentCount - leaveCount;
    final totalOvertime = _overtimeHours.values.fold(0.0, (sum, h) => sum + h);

    return Scaffold(
      appBar: AppBar(
        title: const Text('考勤点名'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '选择日期',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateCard(context),
            _buildStatsCard(context, presentCount, absentCount, leaveCount, unmarkedCount, totalOvertime),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _workers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _workers.length,
                          itemBuilder: (context, index) {
                            return _buildWorkerItem(_workers[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _workers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _markAllPresent,
              icon: const Icon(Icons.done_all),
              label: const Text('全部出勤'),
            ),
    );
  }

  Widget _buildDateCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SiteTimeHelper.formatDate(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                SiteTimeHelper.getWeekday(_selectedDate),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.edit_calendar, color: Colors.white),
            label: const Text('切换日期', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, int present, int absent, int leave, int unmarked, double totalOvertime) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('应到', '${_workers.length}', AppTheme.primaryColor),
              Container(height: 40, width: 1, color: Colors.grey[200]),
              _buildStatItem('出勤', '$present', Colors.green),
              Container(height: 40, width: 1, color: Colors.grey[200]),
              _buildStatItem('缺勤', '$absent', Colors.red),
              Container(height: 40, width: 1, color: Colors.grey[200]),
              _buildStatItem('请假', '$leave', Colors.blue),
            ],
          ),
          if (totalOvertime > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '今日加班总计: ${totalOvertime.toStringAsFixed(1)} 小时',
                    style: const TextStyle(
                      color: Colors.orange,
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无工人数据',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '请先在工人管理中添加工人',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateDemoData,
              icon: const Icon(Icons.science),
              label: const Text('生成演示数据'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateDemoData() async {
    try {
      final demoWorkers = [
        {'name': '张三', 'work_type': '钢筋工', 'phone': '13800138001', 'daily_wage': 300.0},
        {'name': '李四', 'work_type': '木工', 'phone': '13800138002', 'daily_wage': 280.0},
        {'name': '王五', 'work_type': '混凝土工', 'phone': '13800138003', 'daily_wage': 320.0},
        {'name': '赵六', 'work_type': '电工', 'phone': '13800138004', 'daily_wage': 350.0},
        {'name': '钱七', 'work_type': '焊工', 'phone': '13800138005', 'daily_wage': 380.0},
      ];

      for (var worker in demoWorkers) {
        await _db.insertWorker(worker);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已生成 5 个演示工人数据'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildWorkerItem(Map<String, dynamic> worker) {
    final workerId = worker['id'] as int;
    final status = _attendanceStatus[workerId] ?? AttendanceStatus.unmarked;
    final overtime = _overtimeHours[workerId] ?? 0;
    final dailyWage = (worker['daily_wage'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatusIndicator(status),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    (worker['name'] as String).isNotEmpty
                        ? worker['name'].substring(0, 1)
                        : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            worker['work_type'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
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
                              '${dailyWage.toStringAsFixed(0)}元/天',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton(
                        icon: Icons.check,
                        label: '出勤',
                        isSelected: status == AttendanceStatus.present,
                        color: Colors.green,
                        onTap: () => _setAttendance(workerId, AttendanceStatus.present),
                      ),
                      _buildStatusButton(
                        icon: Icons.close,
                        label: '缺勤',
                        isSelected: status == AttendanceStatus.absent,
                        color: Colors.red,
                        onTap: () => _setAttendance(workerId, AttendanceStatus.absent),
                      ),
                      _buildStatusButton(
                        icon: Icons.beach_access,
                        label: '请假',
                        isSelected: status == AttendanceStatus.leave,
                        color: Colors.blue,
                        onTap: () => _setAttendance(workerId, AttendanceStatus.leave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status == AttendanceStatus.present) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      '加班小时:',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    _buildOvertimeButton(workerId, 0, overtime == 0),
                    _buildOvertimeButton(workerId, 1, overtime == 1),
                    _buildOvertimeButton(workerId, 2, overtime == 2),
                    _buildOvertimeButton(workerId, 3, overtime == 3),
                    _buildOvertimeButton(workerId, 4, overtime == 4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '自定义',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        controller: TextEditingController(text: overtime > 4 ? overtime.toStringAsFixed(1) : ''),
                        onSubmitted: (value) {
                          final hours = double.tryParse(value) ?? 0;
                          _updateOvertime(workerId, hours);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeButton(int workerId, double hours, bool isSelected) {
    return GestureDetector(
      onTap: () => _updateOvertime(workerId, hours),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            hours.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.orange,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AttendanceStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case AttendanceStatus.leave:
        color = Colors.blue;
        icon = Icons.beach_access;
        break;
      case AttendanceStatus.unmarked:
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildStatusButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }
}
