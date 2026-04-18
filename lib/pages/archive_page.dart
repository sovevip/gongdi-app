import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final DatabaseService _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<Map<String, dynamic>> _attendanceData = [];
  Map<String, dynamic>? _siteLog;
  Set<String> _datesWithRecords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      final attendance = await _db.getAttendanceByDate(dateStr);
      final log = await _db.getSiteLogByDate(dateStr);

      final monthStart = DateTime(_focusedDate.year, _focusedDate.month, 1);
      final monthEnd = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
      final monthLogs = await _db.getSiteLogsByMonth(
        monthStart.toIso8601String().split('T').first,
        monthEnd.toIso8601String().split('T').first,
      );

      final datesWithRecords = <String>{};
      for (var log in monthLogs) {
        if (log['date'] != null) {
          datesWithRecords.add(log['date'] as String);
        }
      }

      setState(() {
        _attendanceData = attendance;
        _siteLog = log;
        _datesWithRecords = datesWithRecords;
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

  List<String> _getImagePaths() {
    final paths = _siteLog?['image_paths'] as String?;
    if (paths == null || paths.isEmpty) return [];
    return paths.split('|').where((p) => p.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史查询'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarSection(context),
            _buildDetailContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCalendarHeader(context),
          const SizedBox(height: 8),
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
              });
              _loadData();
            },
            icon: const Icon(Icons.chevron_left),
            color: AppTheme.primaryColor,
            visualDensity: VisualDensity.compact,
          ),
          Column(
            children: [
              Text(
                '${_focusedDate.year}年',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                SiteTimeHelper.getMonthName(_focusedDate.month),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
              });
              _loadData();
            },
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.primaryColor,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final daysInMonth = <Widget>[];

    for (var i = 0; i < startingWeekday; i++) {
      daysInMonth.add(const SizedBox());
    }

    for (var day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_focusedDate.year, _focusedDate.month, day);
      final dateStr = date.toIso8601String().split('T').first;
      final isSelected = SiteTimeHelper.isSameDay(date, _selectedDate);
      final isToday = SiteTimeHelper.isSameDay(date, DateTime.now());
      final hasRecord = _datesWithRecords.contains(dateStr);

      daysInMonth.add(
        GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
            _loadData();
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : null,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (hasRecord && !isSelected)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((day) => SizedBox(
                    width: 40,
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
        const SizedBox(height: 2),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
          childAspectRatio: 1.0,
          children: daysInMonth,
        ),
      ],
    );
  }

  Widget _buildDetailContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedDateHeader(context),
                const SizedBox(height: 12),
                _buildAttendanceCard(context),
                const SizedBox(height: 12),
                _buildSiteLogCard(context),
                const SizedBox(height: 12),
                _buildImagesSection(context),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildSelectedDateHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SiteTimeHelper.formatDate(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                SiteTimeHelper.getWeekday(_selectedDate),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getWeatherIcon(_siteLog?['weather'] ?? '晴天'), color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  _siteLog?['weather'] ?? '晴天',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String weather) {
    switch (weather) {
      case '晴天':
        return Icons.wb_sunny;
      case '多云':
        return Icons.wb_cloudy;
      case '阴天':
        return Icons.cloud;
      case '小雨':
      case '大雨':
        return Icons.grain;
      default:
        return Icons.wb_sunny;
    }
  }

  Widget _buildAttendanceCard(BuildContext context) {
    final presentCount = _attendanceData.where((d) => d['is_present'] == 1).length;
    final absentCount = _attendanceData.where((d) => d['is_present'] == 0).length;
    final leaveCount = _attendanceData.where((d) => d['is_present'] == 2).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '人员出勤',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAttendanceBadge('出勤 $presentCount', Colors.green),
                    const SizedBox(width: 4),
                    _buildAttendanceBadge('缺勤 $absentCount', Colors.red),
                    const SizedBox(width: 4),
                    _buildAttendanceBadge('请假 $leaveCount', Colors.blue),
                  ],
                ),
              ],
            ),
            if (_attendanceData.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '暂无考勤记录',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              )
            else ...[
              const Divider(height: 20),
              ..._attendanceData.map((data) => _buildAttendanceItem(data)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(Map<String, dynamic> data) {
    final isPresent = data['is_present'] as int?;
    final name = data['name'] as String? ?? '未知';
    final workType = data['work_type'] as String? ?? '';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.radio_button_unchecked;
    String statusText = '未点名';

    if (isPresent == 1) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '出勤';
    } else if (isPresent == 0) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = '缺勤';
    } else if (isPresent == 2) {
      statusColor = Colors.blue;
      statusIcon = Icons.beach_access;
      statusText = '请假';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (workType.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                workType,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteLogCard(BuildContext context) {
    final content = _siteLog?['content'] as String?;
    final weather = _siteLog?['weather'] as String?;
    final voiceNote = _siteLog?['voice_note'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '施工记录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (weather != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getWeatherIcon(weather), color: Colors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          weather,
                          style: const TextStyle(fontSize: 10, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (content == null || content.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 36, color: Colors.grey[300]),
                      const SizedBox(height: 6),
                      Text(
                        '暂无施工记录',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              if (voiceNote != null && voiceNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mic, size: 14, color: Colors.red[400]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '语音: $voiceNote',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context) {
    final imagePaths = _getImagePaths();

    if (imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '现场照片 (${imagePaths.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imagePaths.length,
                itemBuilder: (context, index) {
                  return _buildImageItem(imagePaths[index], index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(String path, int index) {
    return GestureDetector(
      onTap: () => _showImagePreview(path, index),
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: kIsWeb
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Icon(Icons.image, size: 24, color: AppTheme.primaryColor),
                )
              : Image.file(
                  File(path),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: const Icon(Icons.image, size: 24, color: AppTheme.primaryColor),
                  ),
                ),
        ),
      ),
    );
  }

  void _showImagePreview(String path, int index) {
    final imagePaths = _getImagePaths();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? Container(
                      width: 280,
                      height: 280,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 48, color: AppTheme.primaryColor),
                          SizedBox(height: 12),
                          Text('照片预览', style: TextStyle(color: AppTheme.primaryColor)),
                        ],
                      ),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 280,
                        height: 280,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            if (imagePaths.length > 1)
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1} / ${imagePaths.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
