/// 运动仓库 - 封装运动记录相关的数据库操作
/// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';
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
          'uniqueDays': 0,
          'byType': <String, int>{},
        };
      }

      final totalMinutes = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);

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
          'uniqueDays': 0,
          'byType': <String, int>{},
        };
      }

      final totalMinutes = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final uniqueDays = workouts.map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day)).toSet().length;

      final byType = <String, int>{};
      for (final workout in workouts) {
        byType[workout.type] = (byType[workout.type] ?? 0) + workout.durationMinutes;
      }

      return {
        'count': workouts.length,
        'totalMinutes': totalMinutes,
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
  Future<List<DailyWorkoutStats>> getDailyStats(int days) async {
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
      final List<DailyWorkoutStats> dailyStats = [];
      for (int i = 0; i < days; i++) {
        final date = startOfDay.add(Duration(days: i));
        final dayWorkouts = workoutsByDate[date] ?? [];

        int totalMinutes = 0;
        final Map<String, int> minutesByType = {};

        for (final workout in dayWorkouts) {
          totalMinutes += workout.durationMinutes;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
        }

        dailyStats.add(DailyWorkoutStats(
          date: date,
          totalMinutes: totalMinutes,
          workoutCount: dayWorkouts.length,
          minutesByType: minutesByType,
        ));
      }

      return dailyStats;
    } catch (e, st) {
      debugPrint('获取每日运动统计失败: $e');
      throw WorkoutRepositoryException('获取每日运动统计失败', e, st);
    }
  }

  /// 获取运动类型分布统计
  Future<List<WorkoutTypeDistribution>> getTypeDistribution(int days) async {
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
      final List<WorkoutTypeDistribution> distribution = [];
      for (final entry in minutesByType.entries) {
        final workoutType = WorkoutType.fromString(entry.key);
        distribution.add(WorkoutTypeDistribution(
          type: entry.key,
          displayName: workoutType?.displayName ?? entry.key,
          minutes: entry.value,
          count: countByType[entry.key] ?? 0,
          color: WorkoutCategoryColors.getColorByType(entry.key),
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
  Future<List<WorkoutTrendPoint>> getTrendData(int days) async {
    try {
      final dailyStats = await getDailyStats(days);

      return dailyStats.map((stat) {
        return WorkoutTrendPoint(
          date: stat.date,
          minutes: stat.totalMinutes,
          count: stat.workoutCount,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('获取运动趋势数据失败: $e');
      throw WorkoutRepositoryException('获取运动趋势数据失败', e, st);
    }
  }

  /// 获取按周统计的数据
  /// [weeks] 周数
  Future<List<WeeklyWorkoutStats>> getWeeklyStats(int weeks) async {
    try {
      final now = DateTime.now();
      final List<WeeklyWorkoutStats> weeklyStats = [];

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
        final Map<String, int> minutesByType = {};
        for (final workout in workouts) {
          totalMinutes += workout.durationMinutes;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
        }

        weeklyStats.add(WeeklyWorkoutStats(
          weekStart: weekStartDay,
          weekEnd: weekEndDay,
          totalMinutes: totalMinutes,
          workoutCount: workouts.length,
          minutesByType: minutesByType,
          dailyStats: [], // 简化版，不展开每日数据
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
  Future<List<MonthlyWorkoutStats>> getMonthlyStats(int months) async {
    try {
      final now = DateTime.now();
      final List<MonthlyWorkoutStats> monthlyStats = [];

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
        final Map<String, int> minutesByType = {};
        final Set<DateTime> activeDays = {};

        for (final workout in workouts) {
          totalMinutes += workout.durationMinutes;
          minutesByType[workout.type] = (minutesByType[workout.type] ?? 0) + workout.durationMinutes;
          activeDays.add(DateTime(workout.startTime.year, workout.startTime.month, workout.startTime.day));
        }

        monthlyStats.add(MonthlyWorkoutStats(
          month: month,
          totalMinutes: totalMinutes,
          workoutCount: workouts.length,
          activeDays: activeDays.length,
          minutesByType: minutesByType,
          dailyStats: [], // 简化版
        ));
      }

      return monthlyStats;
    } catch (e, st) {
      debugPrint('获取月度运动统计失败: $e');
      throw WorkoutRepositoryException('获取月度运动统计失败', e, st);
    }
  }
}
