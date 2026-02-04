/// 运动统计模型
/// 用于图表展示的数据结构

import 'package:flutter/material.dart';
import 'package:thick_notepad/services/database/database.dart' as db;

/// 每日运动统计
class DailyWorkoutStats {
  final DateTime date;
  final int totalMinutes;
  final int workoutCount;
  final Map<String, int> minutesByType;
  final double totalCalories; // 总卡路里消耗

  DailyWorkoutStats({
    required this.date,
    required this.totalMinutes,
    required this.workoutCount,
    required this.minutesByType,
    this.totalCalories = 0,
  });

  /// 获取日期显示文本（如：1月1日）
  String get displayText => '${date.month}月${date.day}日';

  /// 获取星期显示文本（如：周一）
  String get weekdayText {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${weekdays[date.weekday - 1]}';
  }

  /// 获取卡路里显示文本
  String get caloriesText => '${totalCalories.toStringAsFixed(0)} 千卡';
}

/// 周度运动统计
class WeeklyWorkoutStats {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalMinutes;
  final int workoutCount;
  final Map<String, int> minutesByType;
  final List<DailyWorkoutStats> dailyStats;
  final double totalCalories; // 总卡路里消耗

  WeeklyWorkoutStats({
    required this.weekStart,
    required this.weekEnd,
    required this.totalMinutes,
    required this.workoutCount,
    required this.minutesByType,
    required this.dailyStats,
    this.totalCalories = 0,
  });

  /// 获取周显示文本（如：1月第1周）
  String get displayText => '${weekStart.month}月第${_getWeekNumber}周';

  int get _getWeekNumber => ((weekStart.day - 1) ~/ 7) + 1;

  /// 获取卡路里显示文本
  String get caloriesText => '${totalCalories.toStringAsFixed(0)} 千卡';
}

/// 月度运动统计
class MonthlyWorkoutStats {
  final DateTime month;
  final int totalMinutes;
  final int workoutCount;
  final int activeDays;
  final Map<String, int> minutesByType;
  final List<DailyWorkoutStats> dailyStats;
  final double totalCalories; // 总卡路里消耗

  MonthlyWorkoutStats({
    required this.month,
    required this.totalMinutes,
    required this.workoutCount,
    required this.activeDays,
    required this.minutesByType,
    required this.dailyStats,
    this.totalCalories = 0,
  });

  /// 获取月份显示文本（如：1月）
  String get displayText => '${month.month}月';

  /// 获取卡路里显示文本
  String get caloriesText => '${totalCalories.toStringAsFixed(0)} 千卡';

  /// 获取平均每日卡路里
  double get averageDailyCalories => activeDays > 0 ? totalCalories / activeDays : 0;
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
  final double calories; // 卡路里消耗

  WorkoutTrendPoint({
    required this.date,
    required this.minutes,
    required this.count,
    this.calories = 0,
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

  /// 根据运动类型获取颜色
  /// 使用数据库中定义的 WorkoutType 枚举
  static Color getColorByType(String type) {
    final workoutType = db.WorkoutType.fromString(type);
    if (workoutType == null) return getColor('other');
    return getColor(workoutType.category);
  }
}

// 导出数据库中的 WorkoutType 以便其他模块使用
typedef WorkoutType = db.WorkoutType;
