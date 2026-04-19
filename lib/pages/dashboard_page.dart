import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/site_time_helper.dart';
import '../services/database_service.dart';
import 'site_log_page.dart';
import 'attendance_page.dart';
import 'finance_page.dart';
import 'material_stock_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseService _db = DatabaseService();
  Map<String, int> _attendanceStats = {'total': 0, 'present': 0, 'absent': 0, 'leave': 0, 'unmarked': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final stats = await _db.getTodayAttendanceStats(today);
      setState(() {
        _attendanceStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施工管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeatherAndAttendanceCard(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '快捷功能'),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '今日动态'),
            const SizedBox(height: 16),
            _buildTodaySummary(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherAndAttendanceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SiteTimeHelper.formatDate(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SiteTimeHelper.getWeekday(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wb_sunny, color: Colors.amber, size: 28),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '晴天',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '18°C - 26°C',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttendanceItem('应到', '${_attendanceStats['total']}', Colors.white),
                    _buildAttendanceItem('实到', '${_attendanceStats['present']}', Colors.greenAccent),
                    _buildAttendanceItem('缺勤', '${_attendanceStats['absent']}', Colors.redAccent),
                    _buildAttendanceItem('请假', '${_attendanceStats['leave']}', Colors.lightBlueAccent),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildActionCard(
          context,
          icon: Icons.edit_note,
          title: '施工日志',
          subtitle: '记录今日施工',
          color: const Color(0xFF1565C0),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SiteLogPage()),
            );
            _loadData();
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.people_alt,
          title: '考勤点名',
          subtitle: '今日出勤管理',
          color: const Color(0xFF0277BD),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendancePage()),
            );
            _loadData();
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.inventory_2,
          title: '材料管理',
          subtitle: '材料进出记录',
          color: const Color(0xFF00838F),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialStockPage()),
            );
            _loadData();
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.account_balance_wallet,
          title: '财务结算',
          subtitle: '工资发放管理',
          color: const Color(0xFF00695C),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinancePage()),
            );
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummary(BuildContext context) {
    return Column(
      children: [
        _buildSummaryItem(
          icon: Icons.engineering,
          title: '施工内容',
          content: '3号楼二层混凝土浇筑，已完成80%',
          time: '08:30',
        ),
        const SizedBox(height: 12),
        _buildSummaryItem(
          icon: Icons.warning_amber,
          title: '注意事项',
          content: '下午预计有雨，需做好防护措施',
          time: '10:00',
          isWarning: true,
        ),
        const SizedBox(height: 12),
        _buildSummaryItem(
          icon: Icons.check_circle_outline,
          title: '安全检查',
          content: '已完成今日安全巡检，无异常',
          time: '14:00',
          isSuccess: true,
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String content,
    required String time,
    bool isWarning = false,
    bool isSuccess = false,
  }) {
    Color iconColor = AppTheme.primaryColor;
    if (isWarning) iconColor = Colors.orange;
    if (isSuccess) iconColor = Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
