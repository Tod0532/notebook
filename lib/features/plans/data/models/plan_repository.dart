/// 计划仓库 - 封装计划相关的数据库操作
/// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/challenge/challenge_service.dart';
import 'package:drift/drift.dart' as drift;

/// 计划仓库异常类
class PlanRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  PlanRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'PlanRepositoryException: $message';
  }
}

class PlanRepository {
  final AppDatabase _db;
  ChallengeService? _challengeService;

  PlanRepository(this._db);

  /// 设置挑战服务（可选，用于挑战进度更新）
  void setChallengeService(ChallengeService? service) {
    _challengeService = service;
  }

  /// 获取所有计划
  Future<List<Plan>> getAllPlans() async {
    try {
      return await (_db.select(_db.plans)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取计划列表失败: $e');
      throw PlanRepositoryException('获取计划列表失败', e, st);
    }
  }

  /// 获取进行中的计划
  Future<List<Plan>> getActivePlans() async {
    try {
      return await (_db.select(_db.plans)
            ..where((tbl) => tbl.status.equals('active'))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.targetDate)]))
          .get();
    } catch (e, st) {
      debugPrint('获取进行中计划失败: $e');
      throw PlanRepositoryException('获取进行中计划失败', e, st);
    }
  }

  /// 获取已完成的计划
  Future<List<Plan>> getCompletedPlans() async {
    try {
      return await (_db.select(_db.plans)
            ..where((tbl) => tbl.status.equals('completed'))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取已完成计划失败: $e');
      throw PlanRepositoryException('获取已完成计划失败', e, st);
    }
  }

  /// 获取单个计划
  Future<Plan?> getPlanById(int id) async {
    try {
      return await (_db.select(_db.plans)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取计划详情失败: $e');
      throw PlanRepositoryException('获取计划详情失败', e, st);
    }
  }

  /// 创建计划
  Future<int> createPlan(PlansCompanion plan) async {
    try {
      return await _db.into(_db.plans).insert(plan);
    } catch (e, st) {
      debugPrint('创建计划失败: $e');
      throw PlanRepositoryException('创建计划失败', e, st);
    }
  }

  /// 更新计划
  Future<bool> updatePlan(Plan plan) async {
    try {
      return await _db.update(_db.plans).replace(plan);
    } catch (e, st) {
      debugPrint('更新计划失败: $e');
      throw PlanRepositoryException('更新计划失败', e, st);
    }
  }

  /// 删除计划（级联删除任务）
  Future<int> deletePlan(int id) async {
    try {
      // 先删除关联的任务
      await (_db.delete(_db.planTasks)..where((tbl) => tbl.planId.equals(id))).go();
      // 再删除计划
      return await (_db.delete(_db.plans)..where((tbl) => tbl.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('删除计划失败: $e');
      throw PlanRepositoryException('删除计划失败', e, st);
    }
  }

  /// 更新计划进度
  Future<void> updatePlanProgress(int planId) async {
    try {
      final tasks = await getPlanTasks(planId);
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((t) => t.isCompleted).length;

      await (_db.update(_db.plans)..where((tbl) => tbl.id.equals(planId))).write(
        PlansCompanion(
          totalTasks: drift.Value(totalTasks),
          completedTasks: drift.Value(completedTasks),
        ),
      );

      // 如果全部完成，自动标记计划为已完成
      if (totalTasks > 0 && completedTasks == totalTasks) {
        await (_db.update(_db.plans)..where((tbl) => tbl.id.equals(planId))).write(
          const PlansCompanion(status: drift.Value('completed')),
        );
      }
    } catch (e, st) {
      debugPrint('更新计划进度失败: $e');
      throw PlanRepositoryException('更新计划进度失败', e, st);
    }
  }

  /// 增加连续天数
  Future<void> incrementStreak(int planId) async {
    try {
      final plan = await getPlanById(planId);
      if (plan != null) {
        await updatePlan(plan.copyWith(streakDays: plan.streakDays + 1));
      }
    } catch (e, st) {
      debugPrint('增加连续天数失败: $e');
      throw PlanRepositoryException('增加连续天数失败', e, st);
    }
  }

  /// 重置连续天数
  Future<void> resetStreak(int planId) async {
    try {
      final plan = await getPlanById(planId);
      if (plan != null) {
        await updatePlan(plan.copyWith(streakDays: 0));
      }
    } catch (e, st) {
      debugPrint('重置连续天数失败: $e');
      throw PlanRepositoryException('重置连续天数失败', e, st);
    }
  }

  // ==================== 计划任务操作 ====================

  /// 获取计划的所有任务
  Future<List<PlanTask>> getPlanTasks(int planId) async {
    try {
      return await (_db.select(_db.planTasks)
            ..where((tbl) => tbl.planId.equals(planId))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
          .get();
    } catch (e, st) {
      debugPrint('获取计划任务列表失败: $e');
      throw PlanRepositoryException('获取计划任务列表失败', e, st);
    }
  }

  /// 获取所有任务
  Future<List<PlanTask>> getAllTasks() async {
    try {
      return await (_db.select(_db.planTasks)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.scheduledDate)]))
          .get();
    } catch (e, st) {
      debugPrint('获取所有任务失败: $e');
      throw PlanRepositoryException('获取所有任务失败', e, st);
    }
  }

  /// 按日期范围获取任务
  Future<List<PlanTask>> getTasksByDateRange(DateTime start, DateTime end) async {
    try {
      return await (_db.select(_db.planTasks)
            ..where((tbl) =>
                tbl.scheduledDate.isBiggerOrEqualValue(start) &
                tbl.scheduledDate.isSmallerOrEqualValue(end))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
          .get();
    } catch (e, st) {
      debugPrint('按日期范围获取任务失败: $e');
      throw PlanRepositoryException('按日期范围获取任务失败', e, st);
    }
  }

  /// 获取今日任务
  Future<List<PlanTask>> getTodayTasks() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      return await (_db.select(_db.planTasks)
            ..where((tbl) =>
                tbl.scheduledDate.isBiggerOrEqualValue(todayStart) &
                tbl.scheduledDate.isSmallerThanValue(todayEnd) &
                tbl.isCompleted.equals(false))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
          .get();
    } catch (e, st) {
      debugPrint('获取今日任务失败: $e');
      throw PlanRepositoryException('获取今日任务失败', e, st);
    }
  }

  /// 获取本周任务
  Future<List<PlanTask>> getThisWeekTasks() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final weekEnd = weekStartDay.add(const Duration(days: 7));

      return await (_db.select(_db.planTasks)
            ..where((tbl) =>
                tbl.scheduledDate.isBiggerOrEqualValue(weekStartDay) &
                tbl.scheduledDate.isSmallerThanValue(weekEnd))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
          .get();
    } catch (e, st) {
      debugPrint('获取本周任务失败: $e');
      throw PlanRepositoryException('获取本周任务失败', e, st);
    }
  }

  /// 获取单个任务
  Future<PlanTask?> getTaskById(int id) async {
    try {
      return await (_db.select(_db.planTasks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取任务详情失败: $e');
      throw PlanRepositoryException('获取任务详情失败', e, st);
    }
  }

  /// 创建任务
  Future<int> createTask(PlanTasksCompanion task) async {
    try {
      final taskId = await _db.into(_db.planTasks).insert(task);
      // 更新计划进度
      await updatePlanProgress(task.planId.value);
      return taskId;
    } catch (e, st) {
      debugPrint('创建任务失败: $e');
      throw PlanRepositoryException('创建任务失败', e, st);
    }
  }

  /// 更新任务
  Future<bool> updateTask(PlanTask task) async {
    try {
      final result = await _db.update(_db.planTasks).replace(task);
      // 更新计划进度
      await updatePlanProgress(task.planId);
      return result;
    } catch (e, st) {
      debugPrint('更新任务失败: $e');
      throw PlanRepositoryException('更新任务失败', e, st);
    }
  }

  /// 删除任务
  Future<int> deleteTask(int id) async {
    try {
      final task = await getTaskById(id);
      if (task == null) return 0;
      final result = await (_db.delete(_db.planTasks)..where((tbl) => tbl.id.equals(id))).go();
      // 更新计划进度
      await updatePlanProgress(task.planId);
      return result;
    } catch (e, st) {
      debugPrint('删除任务失败: $e');
      throw PlanRepositoryException('删除任务失败', e, st);
    }
  }

  /// 标记任务为完成
  Future<void> markTaskComplete(int id) async {
    try {
      final task = await getTaskById(id);
      if (task == null) return;

      await (_db.update(_db.planTasks)..where((tbl) => tbl.id.equals(id))).write(
        PlanTasksCompanion(
          isCompleted: const drift.Value(true),
          completedAt: drift.Value(DateTime.now()),
        ),
      );

      // 更新计划进度
      await updatePlanProgress(task.planId);

      // 增加连续天数
      await incrementStreak(task.planId);

      // 更新挑战进度（异步，不影响主流程）
      if (_challengeService != null) {
        _challengeService!.onPlanTaskCompleted().catchError(
          (e, s) => debugPrint('更新计划任务挑战进度失败: $e\n$s'),
        );
      }
    } catch (e, st) {
      debugPrint('标记任务完成失败: $e');
      throw PlanRepositoryException('标记任务完成失败', e, st);
    }
  }

  /// 标记任务为未完成
  Future<void> markTaskIncomplete(int id) async {
    try {
      final task = await getTaskById(id);
      if (task == null) return;

      await (_db.update(_db.planTasks)..where((tbl) => tbl.id.equals(id))).write(
        PlanTasksCompanion(
          isCompleted: const drift.Value(false),
          completedAt: const drift.Value(null),
        ),
      );

      // 更新计划进度
      await updatePlanProgress(task.planId);
    } catch (e, st) {
      debugPrint('标记任务未完成失败: $e');
      throw PlanRepositoryException('标记任务未完成失败', e, st);
    }
  }

  /// 关联提醒到任务
  Future<void> linkReminderToTask(int taskId, int reminderId) async {
    try {
      await (_db.update(_db.planTasks)..where((tbl) => tbl.id.equals(taskId))).write(
        PlanTasksCompanion(reminderId: drift.Value(reminderId)),
      );
    } catch (e, st) {
      debugPrint('关联提醒到任务失败: $e');
      throw PlanRepositoryException('关联提醒到任务失败', e, st);
    }
  }

  /// 获取任务统计
  Future<Map<String, dynamic>> getTaskStats() async {
    try {
      final todayTasks = await getTodayTasks();
      final completedToday = todayTasks.where((t) => t.isCompleted).length;

      final thisWeekTasks = await getThisWeekTasks();
      final completedThisWeek = thisWeekTasks.where((t) => t.isCompleted).length;

      return {
        'todayTotal': todayTasks.length,
        'todayCompleted': completedToday,
        'todayRemaining': todayTasks.length - completedToday,
        'weekTotal': thisWeekTasks.length,
        'weekCompleted': completedThisWeek,
        'weekRemaining': thisWeekTasks.length - completedThisWeek,
      };
    } catch (e, st) {
      debugPrint('获取任务统计失败: $e');
      throw PlanRepositoryException('获取任务统计失败', e, st);
    }
  }

  /// 删除所有计划（级联删除任务）
  Future<void> deleteAllPlans() async {
    try {
      // 先删除所有任务
      await _db.delete(_db.planTasks).go();
      // 再删除所有计划
      await _db.delete(_db.plans).go();
    } catch (e, st) {
      debugPrint('删除所有计划失败: $e');
      throw PlanRepositoryException('删除所有计划失败', e, st);
    }
  }

  /// 从 JSON 数据创建计划（用于备份恢复）
  Future<int> createPlanFromData(Map<String, dynamic> data) async {
    try {
      final companion = PlansCompanion.insert(
        title: data['title'] as String,
        category: data['category'] as String,
        startDate: DateTime.parse(data['start_date'] as String),
        targetDate: DateTime.parse(data['target_date'] as String),
        description: drift.Value(data['description'] as String? ?? ''),
        status: drift.Value(data['status'] as String? ?? 'active'),
        totalTasks: drift.Value(data['total_tasks'] as int? ?? 0),
        completedTasks: drift.Value(data['completed_tasks'] as int? ?? 0),
        streakDays: drift.Value(data['streak_days'] as int? ?? 0),
      );
      return await _db.into(_db.plans).insert(companion);
    } catch (e, st) {
      debugPrint('从数据创建计划失败: $e');
      throw PlanRepositoryException('从数据创建计划失败', e, st);
    }
  }

  /// 从 JSON 数据创建任务（用于备份恢复）
  Future<int> createTaskFromData(Map<String, dynamic> data) async {
    try {
      final companion = PlanTasksCompanion.insert(
        planId: data['plan_id'] as int,
        title: data['title'] as String,
        scheduledDate: DateTime.parse(data['scheduled_date'] as String),
        taskType: data['task_type'] as String? ?? 'other',
        isCompleted: data['is_completed'] as bool? ?? false ? const drift.Value(true) : const drift.Value(false),
        completedAt: data['completed_at'] != null
            ? drift.Value(DateTime.parse(data['completed_at'] as String))
            : const drift.Value.absent(),
        reminderId: drift.Value(data['reminder_id'] as int?),
      );
      return await _db.into(_db.planTasks).insert(companion);
    } catch (e, st) {
      debugPrint('从数据创建任务失败: $e');
      throw PlanRepositoryException('从数据创建任务失败', e, st);
    }
  }
}
