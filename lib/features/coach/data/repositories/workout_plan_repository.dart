/// AI训练计划仓库 - 封装训练计划相关的数据库操作

import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class WorkoutPlanRepository {
  final AppDatabase _db;

  WorkoutPlanRepository(this._db);

  /// 获取所有训练计划
  Future<List<WorkoutPlan>> getAllPlans() async {
    return await (_db.select(_db.workoutPlans)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取进行中的训练计划
  Future<List<WorkoutPlan>> getActivePlans() async {
    return await (_db.select(_db.workoutPlans)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 根据用户画像获取训练计划
  Future<List<WorkoutPlan>> getPlansByProfileId(int profileId) async {
    return await (_db.select(_db.workoutPlans)
          ..where((tbl) => tbl.userProfileId.equals(profileId))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 根据ID获取训练计划
  Future<WorkoutPlan?> getPlanById(int id) async {
    return await (_db.select(_db.workoutPlans)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建训练计划
  Future<int> createPlan(WorkoutPlansCompanion plan) async {
    return await _db.into(_db.workoutPlans).insert(plan);
  }

  /// 更新训练计划
  Future<bool> updatePlan(WorkoutPlan plan) async {
    return await _db.update(_db.workoutPlans).replace(plan);
  }

  /// 更新训练计划进度
  Future<void> updatePlanProgress(int planId, int completedWorkouts) async {
    await (_db.update(_db.workoutPlans)..where((tbl) => tbl.id.equals(planId))).write(
      WorkoutPlansCompanion(
        completedWorkouts: drift.Value(completedWorkouts),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 完成训练计划
  Future<void> completePlan(int planId) async {
    await (_db.update(_db.workoutPlans)..where((tbl) => tbl.id.equals(planId))).write(
      WorkoutPlansCompanion(
        status: const drift.Value('completed'),
        actualEndDate: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 暂停/恢复训练计划
  Future<void> togglePausePlan(int planId, bool pause) async {
    await (_db.update(_db.workoutPlans)..where((tbl) => tbl.id.equals(planId))).write(
      WorkoutPlansCompanion(
        status: drift.Value(pause ? 'paused' : 'active'),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 更新训练计划状态
  Future<void> updatePlanStatus(int planId, String status) async {
    await (_db.update(_db.workoutPlans)..where((tbl) => tbl.id.equals(planId))).write(
      WorkoutPlansCompanion(
        status: drift.Value(status),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除训练计划
  Future<int> deletePlan(int id) async {
    // 删除计划及其关联的所有数据
    final days = await getPlanDays(id);
    for (final day in days) {
      await deletePlanDay(day.id);
    }
    return await (_db.delete(_db.workoutPlans)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== 训练日程相关 ====================

  /// 获取训练计划的所有日程
  Future<List<WorkoutPlanDay>> getPlanDays(int planId) async {
    return await (_db.select(_db.workoutPlanDays)
          ..where((tbl) => tbl.workoutPlanId.equals(planId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.dayNumber)]))
        .get();
  }

  /// 获取指定日期的日程
  Future<List<WorkoutPlanDay>> getDaysByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return await (_db.select(_db.workoutPlanDays)
          ..where((tbl) =>
              tbl.scheduledDate.isBiggerThanValue(start.subtract(const Duration(milliseconds: 1))) &
              tbl.scheduledDate.isSmallerThanValue(end))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.dayNumber)]))
        .get();
  }

  /// 根据ID获取日程
  Future<WorkoutPlanDay?> getDayById(int id) async {
    return await (_db.select(_db.workoutPlanDays)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建训练日程
  Future<int> createDay(WorkoutPlanDaysCompanion day) async {
    return await _db.into(_db.workoutPlanDays).insert(day);
  }

  /// 批量创建训练日程
  Future<void> createDays(List<WorkoutPlanDaysCompanion> days) async {
    await _db.batch((batch) {
      for (final day in days) {
        batch.insert(_db.workoutPlanDays, day);
      }
    });
  }

  /// 更新训练日程
  Future<bool> updateDay(WorkoutPlanDay day) async {
    return await _db.update(_db.workoutPlanDays).replace(day);
  }

  /// 完成训练日程
  Future<void> completeDay(int dayId) async {
    await (_db.update(_db.workoutPlanDays)..where((tbl) => tbl.id.equals(dayId))).write(
      WorkoutPlanDaysCompanion(
        isCompleted: const drift.Value(true),
        completedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除训练日程
  Future<int> deletePlanDay(int id) async {
    // 删除日程及其关联的所有动作
    final exercises = await getDayExercises(id);
    for (final exercise in exercises) {
      await deleteExercise(exercise.id);
    }
    return await (_db.delete(_db.workoutPlanDays)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== 训练动作相关 ====================

  /// 获取训练日程的所有动作
  Future<List<WorkoutPlanExercise>> getDayExercises(int dayId) async {
    return await (_db.select(_db.workoutPlanExercises)
          ..where((tbl) => tbl.workoutPlanDayId.equals(dayId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.exerciseOrder)]))
        .get();
  }

  /// 根据ID获取动作
  Future<WorkoutPlanExercise?> getExerciseById(int id) async {
    return await (_db.select(_db.workoutPlanExercises)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建训练动作
  Future<int> createExercise(WorkoutPlanExercisesCompanion exercise) async {
    return await _db.into(_db.workoutPlanExercises).insert(exercise);
  }

  /// 批量创建训练动作
  Future<void> createExercises(List<WorkoutPlanExercisesCompanion> exercises) async {
    await _db.batch((batch) {
      for (final exercise in exercises) {
        batch.insert(_db.workoutPlanExercises, exercise);
      }
    });
  }

  /// 更新训练动作
  Future<bool> updateExercise(WorkoutPlanExercise exercise) async {
    return await _db.update(_db.workoutPlanExercises).replace(exercise);
  }

  /// 完成训练动作
  Future<void> completeExercise(int exerciseId) async {
    await (_db.update(_db.workoutPlanExercises)..where((tbl) => tbl.id.equals(exerciseId))).write(
      WorkoutPlanExercisesCompanion(
        isCompleted: const drift.Value(true),
      ),
    );
  }

  /// 替换训练动作
  Future<void> replaceExercise(int exerciseId, String newExercise) async {
    await (_db.update(_db.workoutPlanExercises)..where((tbl) => tbl.id.equals(exerciseId))).write(
      WorkoutPlanExercisesCompanion(
        exerciseName: drift.Value(newExercise),
      ),
    );
  }

  /// 删除训练动作
  Future<int> deleteExercise(int id) async {
    return await (_db.delete(_db.workoutPlanExercises)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 获取完整的训练计划（含日程和动作）
  Future<WorkoutPlanWithDetails?> getPlanWithDetails(int planId) async {
    final plan = await getPlanById(planId);
    if (plan == null) return null;

    final days = await getPlanDays(planId);
    final daysWithExercises = <WorkoutPlanDayWithExercises>[];

    for (final day in days) {
      final exercises = await getDayExercises(day.id);
      daysWithExercises.add(WorkoutPlanDayWithExercises(
        day: day,
        exercises: exercises,
      ));
    }

    return WorkoutPlanWithDetails(
      plan: plan,
      days: daysWithExercises,
    );
  }
}

// ==================== 数据模型 ====================

/// 完整的训练计划（含日程和动作）
class WorkoutPlanWithDetails {
  final WorkoutPlan plan;
  final List<WorkoutPlanDayWithExercises> days;

  WorkoutPlanWithDetails({
    required this.plan,
    required this.days,
  });

  /// 计算完成进度
  double get progress {
    if (plan.totalDays == 0) return 0;
    return plan.currentDay / plan.totalDays;
  }

  /// 获取今日训练
  WorkoutPlanDayWithExercises? getTodayWorkout() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    for (final dayWithEx in days) {
      final scheduled = dayWithEx.day.scheduledDate;
      if (scheduled != null && scheduled.isAfter(start) && scheduled.isBefore(end)) {
        return dayWithEx;
      }
    }
    return null;
  }
}

/// 训练日程及其动作
class WorkoutPlanDayWithExercises {
  final WorkoutPlanDay day;
  final List<WorkoutPlanExercise> exercises;

  WorkoutPlanDayWithExercises({
    required this.day,
    required this.exercises,
  });

  /// 按动作类型分组
  Map<String, List<WorkoutPlanExercise>> get exercisesByType {
    final grouped = <String, List<WorkoutPlanExercise>>{};
    for (final exercise in exercises) {
      final type = exercise.exerciseType;
      grouped.putIfAbsent(type, () => []).add(exercise);
    }
    return grouped;
  }
}
