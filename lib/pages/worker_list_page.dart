import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import 'worker_detail_page.dart';

class WorkerListPage extends StatefulWidget {
  const WorkerListPage({super.key});

  @override
  State<WorkerListPage> createState() => _WorkerListPageState();
}

class _WorkerListPageState extends State<WorkerListPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;

  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _workerMonthData = [];
  double _monthTotalSalary = 0;
  double _monthTotalPaid = 0;
  double _monthTotalOwed = 0;
  int _monthPresentTotal = 0;
  bool _monthDataLoading = false;

  String get _monthStart =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1)
          .toIso8601String()
          .split('T')
          .first;
  String get _monthEnd =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0)
          .toIso8601String()
          .split('T')
          .first;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _db.getAllWorkers();
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
      _loadMonthData();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadMonthData() async {
    setState(() => _monthDataLoading = true);
    try {
      final monthData = <Map<String, dynamic>>[];
      double totalSalary = 0;
      double totalPaid = 0;
      double totalOwed = 0;
      int presentTotal = 0;

      for (var worker in _workers) {
        final workerId = worker['id'] as int;
        final dailyWage =
            (worker['daily_wage'] as num?)?.toDouble() ?? 0;
        final hourlyRate = dailyWage / 8;

        final stats =
            await _db.getAttendanceStats(workerId, _monthStart, _monthEnd);
        final present = (stats['present'] as num?)?.toInt() ?? 0;
        final overtime =
            (stats['overtime_hours'] as num?)?.toDouble() ?? 0;
        final salary = present * dailyWage + overtime * hourlyRate;
        final paid = await _db.getWorkerPaymentsByMonth(
            workerId, _monthStart, _monthEnd);
        final owed = salary - paid;

        totalSalary += salary;
        totalPaid += paid;
        totalOwed += owed;
        presentTotal += present;

        monthData.add({
          'id': workerId,
          'work_days': present,
          'overtime_hours': overtime,
          'total_salary': salary,
          'total_paid': paid,
          'owed': owed,
        });
      }

      setState(() {
        _workerMonthData = monthData;
        _monthTotalSalary = totalSalary;
        _monthTotalPaid = totalPaid;
        _monthTotalOwed = totalOwed;
        _monthPresentTotal = presentTotal;
        _monthDataLoading = false;
      });
    } catch (e) {
      setState(() => _monthDataLoading = false);
    }
  }

  Map<String, dynamic> _getWorkerMonthData(int workerId) {
    try {
      return _workerMonthData.firstWhere((d) => d['id'] == workerId);
    } catch (_) {
      return {
        'work_days': 0,
        'overtime_hours': 0.0,
        'total_salary': 0.0,
        'total_paid': 0.0,
        'owed': 0.0,
      };
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadMonthData();
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
    if (picked != null && mounted) {
      setState(() => _selectedMonth = picked);
      _loadMonthData();
    }
  }

  Future<void> _showAddWorkerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final wageController = TextEditingController();
    String selectedWorkType = '瓦工';
    final workTypes = [
      '瓦工',
      '木工',
      '钢筋工',
      '水电工',
      '油漆工',
      '架子工',
      '其他'
    ];

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          Colors.blue.shade300
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_add,
                            color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          '添加新工人',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '姓名 *',
                        prefixIcon: const Icon(Icons.person,
                            color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '联系电话',
                        prefixIcon: const Icon(Icons.phone,
                            color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedWorkType,
                      decoration: InputDecoration(
                        labelText: '工种 *',
                        prefixIcon: const Icon(Icons.work,
                            color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      items: workTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setModalState(
                            () => selectedWorkType = value!);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: wageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '日薪 (元) *',
                        prefixIcon: const Icon(Icons.attach_money,
                            color: AppTheme.primaryColor),
                        suffixText: '元/天',
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('取消',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请输入姓名'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            if (wageController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请输入日薪'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            try {
                              await _db.insertWorker({
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'work_type': selectedWorkType,
                                'daily_wage': double.tryParse(
                                        wageController.text.trim()) ??
                                    0,
                                'created_at':
                                    DateTime.now().toIso8601String(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '已添加工人：${nameController.text.trim()}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadWorkers();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('添加失败: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('确认添加',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWorker(Map<String, dynamic> worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('确认删除'),
          ],
        ),
        content:
            Text('确定要删除工人"${worker['name']}"吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _db.deleteWorker(worker['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除：${worker['name']}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadWorkers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('删除失败: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工人管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkers,
            tooltip: '刷新列表',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelectorBar(context),
          _buildSummaryCard(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _workers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadWorkers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _workers.length,
                          itemBuilder: (context, index) {
                            return _buildWorkerCard(
                                context, _workers[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('添加工人'),
      ),
    );
  }

  Widget _buildMonthSelectorBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
            tooltip: '上月',
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          GestureDetector(
            onTap: _selectMonth,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month,
                      size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    '${_selectedMonth.year}年${_selectedMonth.month}月',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            tooltip: '下月',
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
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
            '点击下方按钮添加工人',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('总人数', '${_workers.length}'),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildSummaryItem('出勤', '$_monthPresentTotal天', small: true),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildSummaryItem('应发', '¥${_monthTotalSalary.toStringAsFixed(0)}', small: true),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildSummaryItem('已付', '¥${_monthTotalPaid.toStringAsFixed(0)}', small: true),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildSummaryItem('欠款', '¥${_monthTotalOwed.toStringAsFixed(0)}', small: true),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value,
      {bool small = false}) {
    return Column(
      children: [
        _monthDataLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 14 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: small ? 10 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(
      BuildContext context, Map<String, dynamic> worker) {
    final monthData = _getWorkerMonthData(worker['id'] as int);
    final workDays = monthData['work_days'] as int? ?? 0;
    final salary = (monthData['total_salary'] as num?)?.toDouble() ?? 0;
    final paid = (monthData['total_paid'] as num?)?.toDouble() ?? 0;
    final owed = (monthData['owed'] as num?)?.toDouble() ?? 0;
    final overtime =
        (monthData['overtime_hours'] as num?)?.toDouble() ?? 0;

    return Dismissible(
      key: Key('worker_${worker['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text('确认删除'),
              ],
            ),
            content: Text('确定要删除工人"${worker['name']}"吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await _db.deleteWorker(worker['id'] as int);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已删除：${worker['name']}'),
                backgroundColor: Colors.green,
              ),
            );
            _loadWorkers();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('删除失败: $e'),
                  backgroundColor: Colors.red),
            );
          }
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerDetailPage(worker: worker),
              ),
            );
            _loadWorkers();
          },
          onLongPress: () => _deleteWorker(worker),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        (worker['name'] as String).isNotEmpty
                            ? worker['name'].substring(0, 1)
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
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
                          Row(
                            children: [
                              Text(
                                worker['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  worker['work_type'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 14,
                                  color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                worker['phone'] ?? '未填写',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.attach_money,
                                  size: 14,
                                  color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${worker['daily_wage'] ?? 0}元/天',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.grey[400]),
                      onPressed: () => _deleteWorker(worker),
                      tooltip: '删除',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.grey[100],
                ),
                const SizedBox(height: 10),
                _monthDataLoading
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCardStat('出勤', '$workDays天',
                              Colors.green),
                          if (overtime > 0)
                            _buildCardStat('加班', '${overtime}h',
                                Colors.orange),
                          _buildCardStat('应发',
                              '¥${salary.toStringAsFixed(0)}',
                              Colors.blue),
                          _buildCardStat('已付',
                              '¥${paid.toStringAsFixed(0)}',
                              Colors.green),
                          _buildCardStat(
                            '结余',
                            '¥${owed.toStringAsFixed(0)}',
                            owed > 0 ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
