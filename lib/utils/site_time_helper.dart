class SiteTimeHelper {
  static String formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  static String formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }

  static String getWeekday(DateTime date) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${weekdays[date.weekday - 1]}';
  }

  static String getMonthName(int month) {
    return '$month月';
  }

  static String formatDateForFile(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    return '${year}_$month';
  }

  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getMonthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  static int getWorkingDaysInMonth(DateTime date, List<int> workDays) {
    int count = 0;
    final start = getMonthStart(date);
    final end = getMonthEnd(date);
    
    for (var d = start; d.isBefore(end.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      if (workDays.contains(d.day)) {
        count++;
      }
    }
    return count;
  }
}
