/// 日期格式化工具类
/// 统一管理日期格式化逻辑，自动使用本地时区

import 'package:intl/intl.dart';

/// 日期格式化工具
class DateFormatter {
  // 私有构造函数，防止实例化
  DateFormatter._();

  /// 获取当前系统语言环境
  static String get _locale => 'zh_CN';

  /// 日期格式：月日
  static final DateFormat _monthDayFormat = DateFormat('M月d日', _locale);

  /// 日期格式：月日 星期
  static final DateFormat _monthDayWeekFormat = DateFormat('M月d日 EEEE', _locale);

  /// 日期格式：年月日
  static final DateFormat _fullDateFormat = DateFormat('yyyy年M月d日', _locale);

  /// 时间格式：时:分
  static final DateFormat _timeFormat = DateFormat('HH:mm', _locale);

  /// 日期时间格式：年月日 时:分
  static final DateFormat _dateTimeFormat = DateFormat('yyyy年M月d日 HH:mm', _locale);

  /// 格式化为 "M月d日"
  static String formatMonthDay(DateTime date) {
    return _monthDayFormat.format(date);
  }

  /// 格式化为 "M月d日 EEEE" (带星期)
  static String formatMonthDayWeek(DateTime date) {
    return _monthDayWeekFormat.format(date);
  }

  /// 格式化为 "yyyy年M月d日"
  static String formatFull(DateTime date) {
    return _fullDateFormat.format(date);
  }

  /// 格式化为 "HH:mm"
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// 格式化为 "yyyy年M月d日 HH:mm"
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// 智能格式化时间（相对时间）
  /// 返回：刚刚、X分钟前、X小时前、昨天、X天前、M月d日
  static String formatRelative(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formatMonthDay(time);
    }
  }

  /// 检查是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 检查是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取当天的开始时间（00:00:00）
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取当天的结束时间（23:59:59）
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// 获取本周的开始时间（周一）
  static DateTime getStartOfWeek(DateTime date) {
    // 在中国，周一是一周的开始
    final dayOfWeek = date.weekday;
    return getStartOfDay(date.subtract(Duration(days: dayOfWeek - 1)));
  }

  /// 获取本周的结束时间（周日）
  static DateTime getEndOfWeek(DateTime date) {
    final dayOfWeek = date.weekday;
    return getEndOfDay(date.add(Duration(days: 7 - dayOfWeek)));
  }

  /// 获取本月的开始时间
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 获取本月的结束时间
  static DateTime getEndOfMonth(DateTime date) {
    final nextMonth = date.month == 12
        ? DateTime(date.year + 1, 1, 1)
        : DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }
}
