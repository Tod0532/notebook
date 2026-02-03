/// 运动统计模型
/// 用于图表展示的数据结构

/// 每日运动统计
class DailyWorkoutStats {
  final DateTime date;
  final int totalMinutes;
  final int workoutCount;
  final Map<String, int> minutesByType;

  DailyWorkoutStats({
    required this.date,
    required this.totalMinutes,
    required this.workoutCount,
    required this.minutesByType,
  });

  /// 获取日期显示文本（如：1月1日）
  String get displayText => '${date.month}月${date.day}日';

  /// 获取星期显示文本（如：周一）
  String get weekdayText {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${weekdays[date.weekday - 1]}';
  }
}

/// 周度运动统计
class WeeklyWorkoutStats {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalMinutes;
  final int workoutCount;
  final Map<String, int> minutesByType;
  final List<DailyWorkoutStats> dailyStats;

  WeeklyWorkoutStats({
    required this.weekStart,
    required this.weekEnd,
    required this.totalMinutes,
    required this.workoutCount,
    required this.minutesByType,
    required this.dailyStats,
  });

  /// 获取周显示文本（如：1月第1周）
  String get displayText => '${weekStart.month}月第${_getWeekNumber}周';

  int get _getWeekNumber => ((weekStart.day - 1) ~/ 7) + 1;
}

/// 月度运动统计
class MonthlyWorkoutStats {
  final DateTime month;
  final int totalMinutes;
  final int workoutCount;
  final int activeDays;
  final Map<String, int> minutesByType;
  final List<DailyWorkoutStats> dailyStats;

  MonthlyWorkoutStats({
    required this.month,
    required this.totalMinutes,
    required this.workoutCount,
    required this.activeDays,
    required this.minutesByType,
    required this.dailyStats,
  });

  /// 获取月份显示文本（如：1月）
  String get displayText => '${month.month}月';
}

/// 运动类型分布统计
class WorkoutTypeDistribution {
  final String type;
  final String displayName;
  final int minutes;
  final int count;
  final Color color;

  WorkoutTypeDistribution({
    required this.type,
    required this.displayName,
    required this.minutes,
    required this.count,
    required this.color,
  });

  /// 获取百分比
  double getPercentage(int totalMinutes) {
    if (totalMinutes == 0) return 0;
    return (minutes / totalMinutes * 100);
  }
}

/// 运动趋势数据点
class WorkoutTrendPoint {
  final DateTime date;
  final int minutes;
  final int count;

  WorkoutTrendPoint({
    required this.date,
    required this.minutes,
    required this.count,
  });
}

/// 图表数据类型枚举
enum ChartTimeRange {
  week('本周', 7),
  month('本月', 30),
  quarter('近三月', 90),
  year('本年', 365);

  final String displayName;
  final int days;

  const ChartTimeRange(this.displayName, this.days);
}

/// 图表类型枚举
enum ChartType {
  bar('柱状图'),
  line('折线图'),
  pie('饼图');

  final String displayName;

  const ChartType(this.displayName);
}

/// 导入主题色
import 'package:flutter/material.dart';

/// 运动分类色配置
class WorkoutCategoryColors {
  static const Map<String, Color> colors = {
    'cardio': Color(0xFFFF6B6B),      // 有氧 - 红色
    'strength': Color(0xFF4ECDC4),    // 力量 - 青色
    'sports': Color(0xFF95E1D3),      // 球类 - 绿色
    'other': Color(0xFFA8E6CF),       // 其他 - 浅绿
  };

  static Color getColor(String category) {
    return colors[category] ?? colors['other']!;
  }

  static Color getColorByType(String type) {
    // 根据运动类型获取颜色
    for (final workoutType in WorkoutType.values) {
      if (workoutType.name == type) {
        return getColor(workoutType.category);
      }
    }
    return colors['other']!;
  }
}

/// 运动类型枚举（从数据库导入）
enum WorkoutType {
  // 有氧类
  running('跑步', 'cardio'),
  cycling('骑行', 'cardio'),
  swimming('游泳', 'cardio'),
  jumpRope('跳绳', 'cardio'),
  hiit('HIIT', 'cardio'),
  aerobics('有操', 'cardio'),
  stairClimbing('爬楼梯', 'cardio'),

  // 力量类
  chest('胸肌', 'strength'),
  back('背肌', 'strength'),
  legs('腿部', 'strength'),
  shoulders('肩部', 'strength'),
  arms('手臂', 'strength'),
  core('核心', 'strength'),
  fullBody('全身', 'strength'),

  // 球类
  basketball('篮球', 'sports'),
  football('足球', 'sports'),
  badminton('羽毛球', 'sports'),
  tableTennis('乒乓球', 'sports'),
  tennis('网球', 'sports'),
  volleyball('排球', 'sports'),

  // 其他
  yoga('瑜伽', 'other'),
  pilates('普拉提', 'other'),
  hiking('徒步', 'other'),
  climbing('登山', 'other'),
  meditation('冥想', 'other'),
  stretching('拉伸', 'other'),
  walking('散步', 'other'),
  other('其他', 'other');

  final String displayName;
  final String category;

  const WorkoutType(this.displayName, this.category);

  static WorkoutType? fromString(String value) {
    return WorkoutType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WorkoutType.other,
    );
  }

  static List<WorkoutType> getByCategory(String category) {
    return WorkoutType.values.where((e) => e.category == category).toList();
  }
}
