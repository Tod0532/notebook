/// 运动仓库 - 封装运动记录相关的数据库操作
/// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart' as stats;
import 'package:thick_notepad/services/calories/calorie_calculator_service.dart';
import 'package:drift/drift.dart' as drift;

/// 运动仓库异常类
class WorkoutRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  WorkoutRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'WorkoutRepositoryException: $message';
  }
}

class WorkoutRepository {
  final AppDatabase _db;

  WorkoutRepository(this._db);

  /// 获取所有运动记录
  Future<List<Workout>> getAllWorkouts() async {
    try {
      return await (_db.select(_db.workouts)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.startTime)]))
          .get();
    } catch (e, st) {
      debugPrint('获取运动记录失败: $e');
      throw WorkoutRepositoryException('获取运动记录失败', e, st);
    }
  }

  /// 按类型获取运动记录
  Future<List<Workout>> getWorkoutsByType(String type) async {
    try {
      return await (_db.select(_db.workouts)
            ..where((tbl) => tbl.type.equals(type))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.startTime)]))
          .get();
    } catch (e, st) {
      debugPrint('按类型获取运动记录失败: $e');
      throw WorkoutRepositoryException('按类型获取运动记录失败', e, st);
    }
  }

  /// 获取本周运动记录
  Future<List<Workout>> getThisWeekWorkouts() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);

      return await (_db.select(_db.workouts)
            ..where((tbl) => tbl.startTime.isBiggerOrEqualValue(weekStartDay))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.startTime)]))
          .get();
    } catch (e, st) {
      debugPrint('获取本周运动记录失败: $e');
      throw WorkoutRepositoryException('获取本周运动记录失败', e, st);
    }
  }

  /// 获取本月运动记录
  Future<List<Workout>> getThisMonthWorkouts() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      return await (_db.select(_db.workouts)
            ..where((tbl) => tbl.startTime.isBiggerOrEqualValue(monthStart))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.startTime)]))
          .get();
    } catch (e, st) {
      debugPrint('获取本月运动记录失败: $e');
      throw WorkoutRepositoryException('获取本月运动记录失败', e, st);
    }
  }

  /// 获取单个运动记录
  Future<Workout?> getWorkoutById(int id) async {
    try {
      return await (_db.select(_db.workouts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取运动记录详情失败: $e');
      throw WorkoutRepositoryException('获取运动记录详情失败', e, st);
    }
  }

  /// 创建运动记录
  Future<int> createWorkout(WorkoutsCompanion workout) async {
    try {
      return await _db.into(_db.workouts).insert(workout);
    } catch (e, st) {
      debugPrint('创建运动记录失败: $e');
      throw WorkoutRepositoryException('创建运动记录失败', e, st);
    }
  }

  /// 更新运动记录
  Future<bool> updateWorkout(Workout workout) async {
    try {
      return await _db.update(_db.workouts).replace(workout);
    } catch (e, st) {
      debugPrint('更新运动记录失败: $e');
      throw WorkoutRepositoryException('更新运动记录失败', e, st);
    }
  }

  /// 删除运动记录
  Future<int> deleteWorkout(int id) async {
    try {
      return await (_db.delete(_db.workouts)..where((tbl) => tbl.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('删除运动记录失败: $e');
      throw WorkoutRepositoryException('删除运动记录失败', e, st);
    }
  }

  /// 更新关联的笔记ID
  Future<void> updateLinkedNoteId(int workoutId, int? noteId) async {
    try {
      await (_db.update(_db.workouts)..where((tbl) => tbl.id.equals(workoutId))).write(
        WorkoutsCompanion(linkedNoteId: drift.Value(noteId)),
      );
    } catch (e, st) {
      debugPrint('更新关联笔记失败: $e');
      throw WorkoutRepositoryException('更新关联笔记失败', e, st);
    }
  }

  /// 获取本周运动统计
  Future<Map<String, dynamic>> getThisWeekStats() async {
    try {
      final workouts = await getThisWeekWorkouts();

      if (workouts.isEmpty) {
        return {
          'count': 0,
          'totalMinutes': 0,
          'totalCalories': 0.0,
          'uniqueDays': 0,
          'byType': <String, int>{},
        };
      }

      final totalMinutes = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));

      // 计算运动天数
      final uniqueDays = workouts.map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day)).toSet().length;

      // 按类型统计
      final byType = <String, int>{};
      for (final workout in workouts) {
        byType[workout.type] = (byType[workout.type] ?? 0) + workout.durationMinutes;
      }

      return {
        'count': workouts.length,
        'totalMinutes': totalMinutes,
        'totalCalories': totalCalories,
        'uniqueDays': uniqueDays,
        'byType': byType,
      };
    } catch (e, st) {
      debugPrint('获取本周运动统计失败: $e');
      throw WorkoutRepositoryException('获取本周运动统计失败', e, st);
    }
  }

  /// 获取本月运动统计
  Future<Map<String, dynamic>> getThisMonthStats() async {
    try {
      final workouts = await getThisMonthWorkouts();

      if (workouts.isEmpty) {
        return {
          'count': 0,
          'totalMinutes': 0,
          'totalCalories': 0.0,
          'uniqueDays': 0,
          'byType': <String, int>{},
        };
      }

      final totalMinutes = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));
      final uniqueDays = workouts.map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day)).toSet().length;

      final byType = <String, int>{};
      for (final workout in workouts) {
        byType[workout.type] = (byType[workout.type] ?? 0) + workout.durationMinutes;
      }

      return {
        'count': workouts.length,
        'totalMinutes': totalMinutes,
        'totalCalories': totalCalories,
        'uniqueDays': uniqueDays,
        'byType': byType,
      };
    } catch (e, st) {
      debugPrint('获取本月运动统计失败: $e');
      throw WorkoutRepositoryException('获取本月运动统计失败', e, st);
    }
  }

  /// 计算连续运动天数（Streak）
  Future<int> calculateStreak() async {
    try {
      final workouts = await getAllWorkouts();

      if (workouts.isEmpty) return 0;

      // 按日期分组
      final days = workouts
          .map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      if (days.isEmpty) return 0;

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final yesterday = today.subtract(const Duration(days: 1));

      int streak = 0;
      DateTime checkDate = today;

      // 检查是否从今天或昨天开始有连续运动
      if (days.contains(today) || days.contains(yesterday)) {
        // 如果今天没有运动，从昨天开始算
        if (!days.contains(today)) {
          checkDate = yesterday;
        }

        for (int i = 0; i < days.length; i++) {
          if (days.contains(checkDate)) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      }

      return streak;
    } catch (e, st) {
      debugPrint('计算连续运动天数失败: $e');
      throw WorkoutRepositoryException('计算连续运动天数失败', e, st);
    }
  }

  /// 获取运动类型列表
  List<WorkoutType> getWorkoutTypes() {
    return WorkoutType.values;
  }

  /// 获取按分类的运动类型
  Map<String, List<WorkoutType>> getWorkoutTypesByCategory() {
    final result = <String, List<WorkoutType>>{};
    for (final type in WorkoutType.values) {
      result.putIfAbsent(type.category, () => []).add(type);
    }
    return result;
  }

  /// 删除所有运动记录
  Future<void> deleteAllWorkouts() async {
    try {
      await _db.delete(_db.workouts).go();
    } catch (e, st) {
      debugPrint('删除所有运动记录失败: $e');
      throw WorkoutRepositoryException('删除所有运动记录失败', e, st);
    }
  }

  /// 从 JSON 数据创建运动记录（用于备份恢复）
  Future<int> createWorkoutFromData(Map<String, dynamic> data) async {
    try {
      final companion = WorkoutsCompanion.insert(
        type: data['type'] as String,
        durationMinutes: data['duration_minutes'] as int,
        startTime: DateTime.parse(data['start_time'] as String),
        distance: data['distance'] != null ? drift.Value((data['distance'] as num).toDouble()) : const drift.Value.absent(),
        calories: data['calories'] != null ? drift.Value((data['calories'] as num).toDouble()) : const drift.Value.absent(),
        notes: drift.Value(data['notes'] as String? ?? ''),
        linkedPlanId: drift.Value(data['linked_plan_id'] as int?),
        linkedNoteId: drift.Value(data['linked_note_id'] as int?),
      );
      return await _db.into(_db.workouts).insert(companion);
    } catch (e, st) {
      debugPrint('从数据创建运动记录失败: $e');
      throw WorkoutRepositoryException('从数据创建运动记录失败', e, st);
    }
  }

  // ==================== 图表数据查询方法 ====================

  /// 获取指定日期范围内的每日运动统计
  /// [days] 天数，如7天、30天
  Future<List<stats.DailyWorkoutStats>> getDailyStats(int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days - 1));
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);

      final workouts = await (_db.select(_db.workouts)
            ..where((tbl) => tbl.startTime.isBiggerOrEqualValue(startOfDay))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.startTime)]))
          .get();

      // 按日期分组统计
      final Map<DateTime, List<Workout>> workoutsByDate = {};
      for (final workout in workouts) {
        final dateKey = DateTime(workout.startTime.year, workout.startTime.month, workout.startTime.day);
        workoutsByDate.putIfAbsent(dateKey, () => []).add(workout);
      }

      // 生成每日统计数据
      final List<stats.DailyWorkoutStats> dailyStats = [];
      for (int i = 0; i < days; i++) {
        final date = startOfDay.add(Duration(days: i));
        final dayWorkouts = workoutsByDate[date] ?? [];

        int totalMinutes = 0;
        double totalCalories = 0;
        final Map<String, int> minutesByType = {};

        for (final workout in dayWorkouts) {
          totalMinutes += workout.durationMinutes;
          totalCalories += workout.calories ?? 0;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
        }

        dailyStats.add(stats.DailyWorkoutStats(
          date: date,
          totalMinutes: totalMinutes,
          workoutCount: dayWorkouts.length,
          minutesByType: minutesByType,
          totalCalories: totalCalories,
        ));
      }

      return dailyStats;
    } catch (e, st) {
      debugPrint('获取每日运动统计失败: $e');
      throw WorkoutRepositoryException('获取每日运动统计失败', e, st);
    }
  }

  /// 获取运动类型分布统计
  Future<List<stats.WorkoutTypeDistribution>> getTypeDistribution(int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days - 1));
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);

      final workouts = await (_db.select(_db.workouts)
            ..where((tbl) => tbl.startTime.isBiggerOrEqualValue(startOfDay)))
          .get();

      // 按类型统计
      final Map<String, int> minutesByType = {};
      final Map<String, int> countByType = {};

      for (final workout in workouts) {
        minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
        countByType[workout.type] = (countByType[workout.type] ?? 0) + 1;
      }

      // 转换为分布数据
      final List<stats.WorkoutTypeDistribution> distribution = [];
      for (final entry in minutesByType.entries) {
        final workoutType = WorkoutType.fromString(entry.key);
        distribution.add(stats.WorkoutTypeDistribution(
          type: entry.key,
          displayName: workoutType?.displayName ?? entry.key,
          minutes: entry.value,
          count: countByType[entry.key] ?? 0,
          color: stats.WorkoutCategoryColors.getColorByType(entry.key),
        ));
      }

      // 按分钟数降序排序
      distribution.sort((a, b) => b.minutes.compareTo(a.minutes));
      return distribution;
    } catch (e, st) {
      debugPrint('获取运动类型分布失败: $e');
      throw WorkoutRepositoryException('获取运动类型分布失败', e, st);
    }
  }

  /// 获取运动趋势数据点
  /// 用于折线图展示
  Future<List<stats.WorkoutTrendPoint>> getTrendData(int days) async {
    try {
      final dailyStats = await getDailyStats(days);

      return dailyStats.map((stat) {
        return stats.WorkoutTrendPoint(
          date: stat.date,
          minutes: stat.totalMinutes,
          count: stat.workoutCount,
          calories: stat.totalCalories,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('获取运动趋势数据失败: $e');
      throw WorkoutRepositoryException('获取运动趋势数据失败', e, st);
    }
  }

  /// 获取按周统计的数据
  /// [weeks] 周数
  Future<List<stats.WeeklyWorkoutStats>> getWeeklyStats(int weeks) async {
    try {
      final now = DateTime.now();
      final List<stats.WeeklyWorkoutStats> weeklyStats = [];

      for (int i = weeks - 1; i >= 0; i--) {
        final weekEnd = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
        final weekStart = weekEnd.subtract(const Duration(days: 6));

        final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final weekEndDay = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);

        final workouts = await (_db.select(_db.workouts)
              ..where((tbl) =>
                  tbl.startTime.isBiggerOrEqualValue(weekStartDay) &
                  tbl.startTime.isSmallerOrEqualValue(weekEndDay)))
            .get();

        int totalMinutes = 0;
        double totalCalories = 0;
        final Map<String, int> minutesByType = {};
        for (final workout in workouts) {
          totalMinutes += workout.durationMinutes;
          totalCalories += workout.calories ?? 0;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
        }

        weeklyStats.add(stats.WeeklyWorkoutStats(
          weekStart: weekStartDay,
          weekEnd: weekEndDay,
          totalMinutes: totalMinutes,
          workoutCount: workouts.length,
          minutesByType: minutesByType,
          dailyStats: [], // 简化版，不展开每日数据
          totalCalories: totalCalories,
        ));
      }

      return weeklyStats;
    } catch (e, st) {
      debugPrint('获取周度运动统计失败: $e');
      throw WorkoutRepositoryException('获取周度运动统计失败', e, st);
    }
  }

  /// 获取按月统计的数据
  /// [months] 月数
  Future<List<stats.MonthlyWorkoutStats>> getMonthlyStats(int months) async {
    try {
      final now = DateTime.now();
      final List<stats.MonthlyWorkoutStats> monthlyStats = [];

      for (int i = months - 1; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final monthEnd = nextMonth.subtract(const Duration(days: 1));

        final workouts = await (_db.select(_db.workouts)
              ..where((tbl) =>
                  tbl.startTime.isBiggerOrEqualValue(month) &
                  tbl.startTime.isSmallerOrEqualValue(
                    DateTime(monthEnd.year, monthEnd.month, monthEnd.day, 23, 59, 59),
                  )))
            .get();

        int totalMinutes = 0;
        double totalCalories = 0;
        final Map<String, int> minutesByType = {};
        final Set<DateTime> activeDays = {};

        for (final workout in workouts) {
          totalMinutes += workout.durationMinutes;
          totalCalories += workout.calories ?? 0;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
          activeDays.add(DateTime(workout.startTime.year, workout.startTime.month, workout.startTime.day));
        }

        monthlyStats.add(stats.MonthlyWorkoutStats(
          month: month,
          totalMinutes: totalMinutes,
          workoutCount: workouts.length,
          activeDays: activeDays.length,
          minutesByType: minutesByType,
          dailyStats: [], // 简化版
          totalCalories: totalCalories,
        ));
      }

      return monthlyStats;
    } catch (e, st) {
      debugPrint('获取月度运动统计失败: $e');
      throw WorkoutRepositoryException('获取月度运动统计失败', e, st);
    }
  }

  // ==================== 卡路里计算相关方法 ====================

  /// 估算单次运动消耗的卡路里
  ///
  /// 参数:
  /// - [workoutType] 运动类型
  /// - [durationMinutes] 运动时长（分钟）
  /// - [distance] 运动距离（米）- 可选
  /// - [sets] 力量训练组数 - 可选
  /// - [weight] 用户体重（公斤）- 可选，默认70kg
  ///
  /// 返回值: 估算的卡路里消耗（千卡）
  double estimateCalories({
    required String workoutType,
    required int durationMinutes,
    double? distance,
    int? sets,
    double? weight,
  }) {
    final service = CalorieCalculatorService();

    if (distance != null && distance > 0) {
      return service.calculateCaloriesWithDistance(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        distanceMeters: distance,
        weight: weight,
      );
    } else if (sets != null && sets > 0) {
      return service.calculateStrengthCalories(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        sets: sets,
        weight: weight,
      );
    } else {
      return service.calculateCalories(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        weight: weight,
      );
    }
  }

  /// 获取今日运动总卡路里消耗
  /// 返回整数值（千卡）
  Future<int> getTodayCalories() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final workouts = await (_db.select(_db.workouts)
            ..where((tbl) =>
                tbl.startTime.isBiggerOrEqualValue(todayStart) &
                tbl.startTime.isSmallerOrEqualValue(todayEnd)))
          .get();

      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));
      return totalCalories.round();
    } catch (e, st) {
      debugPrint('获取今日卡路里失败: $e');
      throw WorkoutRepositoryException('获取今日卡路里失败', e, st);
    }
  }

  /// 获取本周运动总卡路里消耗
  /// 返回整数值（千卡）
  Future<int> getThisWeekCalories() async {
    try {
      final workouts = await getThisWeekWorkouts();
      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));
      return totalCalories.round();
    } catch (e, st) {
      debugPrint('获取本周卡路里失败: $e');
      throw WorkoutRepositoryException('获取本周卡路里失败', e, st);
    }
  }

  /// 获取本月运动总卡路里消耗
  /// 返回整数值（千卡）
  Future<int> getThisMonthCalories() async {
    try {
      final workouts = await getThisMonthWorkouts();
      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));
      return totalCalories.round();
    } catch (e, st) {
      debugPrint('获取本月卡路里失败: $e');
      throw WorkoutRepositoryException('获取本月卡路里失败', e, st);
    }
  }

  /// 获取指定日期范围内的总卡路里消耗
  /// 返回整数值（千卡）
  Future<int> getCaloriesInDateRange(DateTime start, DateTime end) async {
    try {
      final workouts = await (_db.select(_db.workouts)
            ..where((tbl) =>
                tbl.startTime.isBiggerOrEqualValue(start) &
                tbl.startTime.isSmallerOrEqualValue(end)))
          .get();

      final totalCalories = workouts.fold<double>(0, (sum, w) => sum + (w.calories ?? 0));
      return totalCalories.round();
    } catch (e, st) {
      debugPrint('获取日期范围卡路里失败: $e');
      throw WorkoutRepositoryException('获取日期范围卡路里失败', e, st);
    }
  }

  /// 获取运动卡路里统计（包含今日、本周、本月）
  /// 返回 Map<String, int> 格式
  Future<Map<String, int>> getCaloriesSummary() async {
    try {
      final today = await getTodayCalories();
      final week = await getThisWeekCalories();
      final month = await getThisMonthCalories();

      return {
        'today': today,
        'week': week,
        'month': month,
      };
    } catch (e, st) {
      debugPrint('获取卡路里汇总失败: $e');
      throw WorkoutRepositoryException('获取卡路里汇总失败', e, st);
    }
  }

  /// 自动计算并更新运动记录的卡路里
  /// 用于已存在但卡路里为空的记录
  Future<bool> updateWorkoutCalories(int workoutId) async {
    try {
      final workout = await getWorkoutById(workoutId);
      if (workout == null) return false;

      // 如果已经有卡路里数据，跳过
      if (workout.calories != null && workout.calories! > 0) {
        return true;
      }

      // 计算卡路里
      final estimatedCalories = estimateCalories(
        workoutType: workout.type,
        durationMinutes: workout.durationMinutes,
        distance: workout.distance,
        sets: workout.sets,
      );

      // 更新数据库
      await (_db.update(_db.workouts)..where((tbl) => tbl.id.equals(workoutId))).write(
        WorkoutsCompanion(calories: drift.Value(estimatedCalories)),
      );

      return true;
    } catch (e, st) {
      debugPrint('更新运动卡路里失败: $e');
      throw WorkoutRepositoryException('更新运动卡路里失败', e, st);
    }
  }

  /// 批量更新所有缺失卡路里的运动记录
  Future<int> updateAllMissingCalories() async {
    try {
      // 获取所有卡路里为空或为0的记录
      final workouts = await (_db.select(_db.workouts)
            ..where((tbl) =>
                tbl.calories.isNull() | (tbl.calories.equals(0))))
          .get();

      int updated = 0;
      for (final workout in workouts) {
        final success = await updateWorkoutCalories(workout.id!);
        if (success) updated++;
      }

      return updated;
    } catch (e, st) {
      debugPrint('批量更新卡路里失败: $e');
      throw WorkoutRepositoryException('批量更新卡路里失败', e, st);
    }
  }
}
