/// AI 计划整合服务
/// 将 AI 生成的训练/饮食计划与现有功能模块（提醒、运动、笔记）关联

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';

/// AI 计划整合服务
class PlanIntegrationService {
  static PlanIntegrationService? _instance;

  PlanIntegrationService._internal();

  /// 获取单例实例
  static PlanIntegrationService get instance {
    _instance ??= PlanIntegrationService._internal();
    return _instance!;
  }

  AppDatabase _db = DatabaseProvider.instance;

  /// 初始化服务
  void init(AppDatabase db) {
    _db = db;
  }

  // ==================== 计划激活时的处理 ====================

  /// 激活训练计划 - 创建每日提醒和任务关联
  ///
  /// [planId] 训练计划ID
  /// [userProfileId] 用户画像ID
  Future<void> activateWorkoutPlan(int planId, int userProfileId) async {
    try {
      // 1. 获取训练计划的所有日程
      final query = _db.select(_db.workoutPlanDays)
        ..where((tbl) => tbl.workoutPlanId.equals(planId))
        ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.dayNumber)]);
      final planDays = await query.get();

      if (planDays.isEmpty) {
        debugPrint('训练计划没有日程数据');
        return;
      }

      // 2. 计算开始日期（默认从今天开始）
      final startDate = DateTime.now();

      // 3. 为每一天创建提醒
      for (final day in planDays) {
        final scheduledDate = startDate.add(Duration(days: day.dayNumber - 1));
        final reminderTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          9, // 早上9点提醒
          0,
          0,
        );

        // 创建提醒
        await _db.into(_db.reminders).insert(
          RemindersCompanion.insert(
            title: '今日训练：${day.dayName ?? '第${day.dayNumber}天'}',
            description: drift.Value(day.trainingFocus ?? ''),
            remindTime: reminderTime,
            repeatType: const drift.Value('none'), // 一次性提醒
            linkedPlanId: drift.Value(planId),
          ),
        );

        debugPrint('已创建第${day.dayNumber}天的训练提醒');
      }

      debugPrint('训练计划 $planId 激活成功，创建了 ${planDays.length} 条提醒');
    } catch (e) {
      debugPrint('激活训练计划失败: $e');
    }
  }

  /// 激活饮食计划 - 创建用餐提醒
  ///
  /// [planId] 饮食计划ID
  /// [userProfileId] 用户画像ID
  Future<void> activateDietPlan(int planId, int userProfileId) async {
    try {
      // 获取饮食计划的所有餐次
      final meals = await (_db.select(_db.dietPlanMeals)
            ..where((tbl) => tbl.dietPlanId.equals(planId)))
          .get();

      if (meals.isEmpty) {
        debugPrint('饮食计划没有餐次数据');
        return;
      }

      // 按日期分组
      final Map<int, List<dynamic>> mealsByDay = {};
      for (final meal in meals) {
        final dayNumber = meal.dayNumber ?? 1;
        mealsByDay.putIfAbsent(dayNumber, () => []).add(meal);
      }

      // 计算开始日期
      final startDate = DateTime.now();

      // 为每天创建用餐提醒
      for (final entry in mealsByDay.entries) {
        final dayNumber = entry.key;
        final dayMeals = entry.value as List;

        final scheduledDate = startDate.add(Duration(days: dayNumber - 1));

        // 早餐提醒 (7:30)
        final breakfast = dayMeals.firstWhere(
          (m) => m.mealType == 'breakfast',
          orElse: () => null,
        );
        if (breakfast != null) {
          final reminderTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            7,
            30,
            0,
          );
          await _db.into(_db.reminders).insert(
            RemindersCompanion.insert(
              title: '早餐：${breakfast.mealName ?? ''}',
              description: drift.Value('${breakfast.calories?.toStringAsFixed(0) ?? ''} kcal'),
              remindTime: reminderTime,
              linkedPlanId: drift.Value(planId),
            ),
          );
        }
      }

      debugPrint('饮食计划 $planId 激活成功');
    } catch (e) {
      debugPrint('激活饮食计划失败: $e');
    }
  }

  // ==================== 获取今日训练任务 ====================

  /// 获取今日应该完成的训练任务
  Future<TodayTrainingTask?> getTodayTrainingTask() async {
    try {
      // 1. 获取活跃的训练计划
      final activePlans = await (_db.select(_db.workoutPlans)
            ..where((tbl) => tbl.status.equals('active')))
          .get();

      if (activePlans.isEmpty) return null;

      // 2. 找出最早创建的活跃计划
      final plan = activePlans.reduce((a, b) =>
          a.createdAt.isBefore(b.createdAt) ? a : b);

      // 3. 计算当前是第几天
      final daysSinceStart = plan.startDate != null
          ? DateTime.now().difference(plan.startDate!).inDays + 1
          : 1;
      final currentDay = daysSinceStart.clamp(1, plan.totalDays);

      // 4. 获取当天的训练日程
      final todayPlanDays = await (_db.select(_db.workoutPlanDays)
            ..where((tbl) => tbl.workoutPlanId.equals(plan.id)))
          .get();

      final todayDay = todayPlanDays.firstWhere(
        (d) => d.dayNumber == currentDay,
        orElse: () => WorkoutPlanDay(
          id: -1,
          workoutPlanId: plan.id,
          dayNumber: currentDay,
          dayName: '第${currentDay}天训练',
          trainingFocus: '',
          estimatedMinutes: 30,
          scheduledDate: null,
          isCompleted: false,
          completedAt: null,
        ),
      );

      // 5. 获取训练动作
      final exercises = await (_db.select(_db.workoutPlanExercises)
            ..where((tbl) => tbl.workoutPlanDayId.equals(todayDay.id)))
          .get();

      return TodayTrainingTask(
        planId: plan.id,
        planName: plan.name,
        dayNumber: currentDay,
        totalDays: plan.totalDays,
        dayName: todayDay.dayName ?? '第$currentDay 天',
        trainingFocus: todayDay.trainingFocus ?? '',
        estimatedMinutes: todayDay.estimatedMinutes ?? 30,
        isCompleted: todayDay.isCompleted,
        exercises: exercises.map((e) => ExerciseItem(
          name: e.exerciseName,
          description: e.description ?? '',
          sets: e.sets,
          reps: e.repsDescription,
        )).toList(),
      );
    } catch (e) {
      debugPrint('获取今日训练任务失败: $e');
      return null;
    }
  }

  /// 获取今日饮食建议
  Future<TodayDietSuggestion?> getTodayDietSuggestion() async {
    try {
      // 1. 获取活跃的饮食计划
      final activePlans = await (_db.select(_db.dietPlans)
            ..where((tbl) => tbl.status.equals('active')))
          .get();

      if (activePlans.isEmpty) return null;

      // 2. 找出最早创建的活跃计划
      final plan = activePlans.reduce((a, b) =>
          a.createdAt.isBefore(b.createdAt) ? a : b);

      // 3. 计算当前是第几天
      final daysSinceStart = plan.createdAt != null
          ? DateTime.now().difference(plan.createdAt!).inDays + 1
          : 1;
      final currentDay = daysSinceStart.clamp(1, plan.totalDays);

      // 4. 获取当天的餐次
      final todayMeals = await (_db.select(_db.dietPlanMeals)
            ..where((tbl) => tbl.dietPlanId.equals(plan.id))
            ..where((tbl) => tbl.dayNumber.equals(currentDay)))
          .get();

      if (todayMeals.isEmpty) return null;

      return TodayDietSuggestion(
        planId: plan.id,
        planName: plan.name,
        dayNumber: currentDay,
        totalDays: plan.totalDays,
        dailyCalories: (plan.dailyCalories ?? 2000).toInt(),
        meals: todayMeals.map((m) => MealItem(
          mealType: m.mealType ?? '',
          mealName: m.mealName ?? '',
          eatingTime: m.eatingTime ?? '',
          calories: (m.calories ?? 0).toInt(),
        )).toList(),
      );
    } catch (e) {
      debugPrint('获取今日饮食建议失败: $e');
      return null;
    }
  }

  // ==================== 运动完成时的处理 ====================

  /// 完成运动训练后自动打卡到 AI 训练计划
  ///
  /// [workoutId] 运动记录ID
  /// [planId] 关联的训练计划ID
  Future<void> completeWorkoutForPlan(int workoutId, int planId) async {
    try {
      // 1. 获取运动记录
      final workout = await (_db.select(_db.workouts)
            ..where((tbl) => tbl.id.equals(workoutId)))
          .getSingleOrNull();

      if (workout == null) return;

      // 2. 计算当前是第几天
      final plan = await (_db.select(_db.workoutPlans)
            ..where((tbl) => tbl.id.equals(planId)))
          .getSingleOrNull();

      if (plan == null) return;

      final daysSinceStart = plan.startDate != null
          ? DateTime.now().difference(plan.startDate!).inDays + 1
          : 1;
      final currentDay = daysSinceStart.clamp(1, plan.totalDays);

      // 3. 更新训练计划日程为已完成
      await (_db.update(_db.workoutPlanDays)
            ..where((tbl) => tbl.workoutPlanId.equals(planId))
            ..where((tbl) => tbl.dayNumber.equals(currentDay)))
          .write(
            WorkoutPlanDaysCompanion(
              isCompleted: const drift.Value(true),
              completedAt: drift.Value(DateTime.now()),
            ),
          );

      // 4. 更新训练计划进度
      final completedCount = await (_db.select(_db.workoutPlanDays)
            ..where((tbl) => tbl.workoutPlanId.equals(planId))
            ..where((tbl) => tbl.isCompleted.equals(true)))
          .get()
          .then((list) => list.length);

      await (_db.update(_db.workoutPlans)
            ..where((tbl) => tbl.id.equals(planId)))
          .write(
            WorkoutPlansCompanion(
              completedWorkouts: drift.Value(completedCount),
              currentDay: drift.Value(currentDay < plan.totalDays ? currentDay + 1 : currentDay),
            ),
          );

      // 5. 如果计划全部完成，更新状态
      if (completedCount >= plan.totalDays) {
        await (_db.update(_db.workoutPlans)
              ..where((tbl) => tbl.id.equals(planId)))
            .write(
              WorkoutPlansCompanion(
                status: const drift.Value('completed'),
                actualEndDate: drift.Value(DateTime.now()),
              ),
            );
      }

      debugPrint('已将运动 $workoutId 打卡到训练计划 $planId');
    } catch (e) {
      debugPrint('完成运动打卡失败: $e');
    }
  }
}

// ==================== 数据模型 ====================

/// 今日训练任务
class TodayTrainingTask {
  final int planId;
  final String planName;
  final int dayNumber;
  final int totalDays;
  final String dayName;
  final String trainingFocus;
  final int estimatedMinutes;
  final bool isCompleted;
  final List<ExerciseItem> exercises;

  TodayTrainingTask({
    required this.planId,
    required this.planName,
    required this.dayNumber,
    required this.totalDays,
    required this.dayName,
    required this.trainingFocus,
    required this.estimatedMinutes,
    required this.isCompleted,
    required this.exercises,
  });

  /// 完成度百分比
  double get progress => dayNumber / totalDays;

  /// 剩余天数
  int get remainingDays => totalDays - dayNumber;
}

/// 今日饮食建议
class TodayDietSuggestion {
  final int planId;
  final String planName;
  final int dayNumber;
  final int totalDays;
  final int dailyCalories;
  final List<MealItem> meals;

  TodayDietSuggestion({
    required this.planId,
    required this.planName,
    required this.dayNumber,
    required this.totalDays,
    required this.dailyCalories,
    required this.meals,
  });
}

/// 训练动作
class ExerciseItem {
  final String name;
  final String description;
  final int? sets;
  final String? reps;

  ExerciseItem({
    required this.name,
    required this.description,
    this.sets,
    this.reps,
  });
}

/// 饮食项
class MealItem {
  final String mealType;
  final String mealName;
  final String eatingTime;
  final int calories;

  MealItem({
    required this.mealType,
    required this.mealName,
    required this.eatingTime,
    required this.calories,
  });
}
