/// 运动仓库 - 封装运动记录相关的数据库操作
/// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
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
}
