/// 计划仓库 - 封装计划相关的数据库操作

import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class PlanRepository {
  final AppDatabase _db;

  PlanRepository(this._db);

  /// 获取所有计划
  Future<List<Plan>> getAllPlans() async {
    return await (_db.select(_db.plans)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取进行中的计划
  Future<List<Plan>> getActivePlans() async {
    return await (_db.select(_db.plans)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.targetDate)]))
        .get();
  }

  /// 获取已完成的计划
  Future<List<Plan>> getCompletedPlans() async {
    return await (_db.select(_db.plans)
          ..where((tbl) => tbl.status.equals('completed'))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取单个计划
  Future<Plan?> getPlanById(int id) async {
    return await (_db.select(_db.plans)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建计划
  Future<int> createPlan(PlansCompanion plan) async {
    return await _db.into(_db.plans).insert(plan);
  }

  /// 更新计划
  Future<bool> updatePlan(Plan plan) async {
    return await _db.update(_db.plans).replace(plan);
  }

  /// 删除计划（级联删除任务）
  Future<int> deletePlan(int id) async {
    // 先删除关联的任务
    await (_db.delete(_db.planTasks)..where((tbl) => tbl.planId.equals(id))).go();
    // 再删除计划
    return await (_db.delete(_db.plans)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 更新计划进度
  Future<void> updatePlanProgress(int planId) async {
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
  }

  /// 增加连续天数
  Future<void> incrementStreak(int planId) async {
    final plan = await getPlanById(planId);
    if (plan != null) {
      await updatePlan(plan.copyWith(streakDays: plan.streakDays + 1));
    }
  }

  /// 重置连续天数
  Future<void> resetStreak(int planId) async {
    final plan = await getPlanById(planId);
    if (plan != null) {
      await updatePlan(plan.copyWith(streakDays: 0));
    }
  }

  // ==================== 计划任务操作 ====================

  /// 获取计划的所有任务
  Future<List<PlanTask>> getPlanTasks(int planId) async {
    return await (_db.select(_db.planTasks)
          ..where((tbl) => tbl.planId.equals(planId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
        .get();
  }

  /// 获取所有任务
  Future<List<PlanTask>> getAllTasks() async {
    return await (_db.select(_db.planTasks)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.scheduledDate)]))
        .get();
  }

  /// 按日期范围获取任务
  Future<List<PlanTask>> getTasksByDateRange(DateTime start, DateTime end) async {
    return await (_db.select(_db.planTasks)
          ..where((tbl) =>
              tbl.scheduledDate.isBiggerOrEqualValue(start) &
              tbl.scheduledDate.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.scheduledDate)]))
        .get();
  }

  /// 获取今日任务
  Future<List<PlanTask>> getTodayTasks() async {
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
  }

  /// 获取本周任务
  Future<List<PlanTask>> getThisWeekTasks() async {
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
  }

  /// 获取单个任务
  Future<PlanTask?> getTaskById(int id) async {
    return await (_db.select(_db.planTasks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建任务
  Future<int> createTask(PlanTasksCompanion task) async {
    final taskId = await _db.into(_db.planTasks).insert(task);
    // 更新计划进度
    await updatePlanProgress(task.planId.value);
    return taskId;
  }

  /// 更新任务
  Future<bool> updateTask(PlanTask task) async {
    final result = await _db.update(_db.planTasks).replace(task);
    // 更新计划进度
    await updatePlanProgress(task.planId);
    return result;
  }

  /// 删除任务
  Future<int> deleteTask(int id) async {
    final task = await getTaskById(id);
    if (task == null) return 0;
    final result = await (_db.delete(_db.planTasks)..where((tbl) => tbl.id.equals(id))).go();
    // 更新计划进度
    await updatePlanProgress(task.planId);
    return result;
  }

  /// 标记任务为完成
  Future<void> markTaskComplete(int id) async {
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
  }

  /// 标记任务为未完成
  Future<void> markTaskIncomplete(int id) async {
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
  }

  /// 关联提醒到任务
  Future<void> linkReminderToTask(int taskId, int reminderId) async {
    await (_db.update(_db.planTasks)..where((tbl) => tbl.id.equals(taskId))).write(
      PlanTasksCompanion(reminderId: drift.Value(reminderId)),
    );
  }

  /// 获取任务统计
  Future<Map<String, dynamic>> getTaskStats() async {
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
  }

  /// 删除所有计划（级联删除任务）
  Future<void> deleteAllPlans() async {
    // 先删除所有任务
    await _db.delete(_db.planTasks).go();
    // 再删除所有计划
    await _db.delete(_db.plans).go();
  }

  /// 从 JSON 数据创建计划（用于备份恢复）
  Future<int> createPlanFromData(Map<String, dynamic> data) async {
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
  }

  /// 从 JSON 数据创建任务（用于备份恢复）
  Future<int> createTaskFromData(Map<String, dynamic> data) async {
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
  }
}
