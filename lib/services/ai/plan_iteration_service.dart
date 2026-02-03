/// 周期迭代提醒服务
/// 检查计划执行时间，触发迭代提醒，管理计划迭代周期

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/services/notification/notification_service.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/diet_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 迭代提醒周期
enum IterationCycle {
  weekly(7, '每周'),
  biweekly(14, '双周'),
  monthly(30, '每月');

  final int days;
  final String displayName;

  const IterationCycle(this.days, this.displayName);

  static IterationCycle fromDays(int days) {
    if (days <= 7) return IterationCycle.weekly;
    if (days <= 14) return IterationCycle.biweekly;
    return IterationCycle.monthly;
  }
}

/// 迭代状态
class IterationStatus {
  final String planType; // 'workout' 或 'diet'
  final int planId;
  final DateTime lastUpdateDate;
  final int iterationCount;
  final IterationCycle cycle;
  final bool reminderScheduled;
  final DateTime? nextReminderDate;

  IterationStatus({
    required this.planType,
    required this.planId,
    required this.lastUpdateDate,
    required this.iterationCount,
    required this.cycle,
    required this.reminderScheduled,
    this.nextReminderDate,
  });

  /// 计算是否需要提醒
  bool get needsReminder {
    if (reminderScheduled) return false;

    final daysSinceUpdate = DateTime.now().difference(lastUpdateDate).inDays;
    return daysSinceUpdate >= cycle.days;
  }

  /// 计算距离下次提醒的天数
  int get daysUntilReminder {
    final daysSinceUpdate = DateTime.now().difference(lastUpdateDate).inDays;
    return cycle.days - daysSinceUpdate;
  }

  /// 获取进度百分比
  double get progress {
    final daysSinceUpdate = DateTime.now().difference(lastUpdateDate).inDays;
    return (daysSinceUpdate / cycle.days).clamp(0.0, 1.0);
  }
}

/// 周期迭代提醒服务
class PlanIterationService {
  static PlanIterationService? _instance;
  static const _iterationKeyPrefix = 'plan_iteration_';
  static const _lastCheckKey = 'last_iteration_check';

  final NotificationService _notificationService = NotificationService();

  // 迭代周期（天）
  static const int _defaultIterationDays = 14;

  PlanIterationService._internal();

  /// 获取单例实例
  static PlanIterationService get instance {
    _instance ??= PlanIterationService._internal();
    return _instance!;
  }

  /// 初始化服务
  Future<void> initialize() async {
    await _notificationService.initialize();
    await _scheduleDailyCheck();
  }

  /// ==================== 计划迭代管理 ====================

  /// 记录计划创建/更新事件
  Future<void> recordPlanUpdate({
    required String planType,
    required int planId,
    required DateTime updateDate,
    IterationCycle? cycle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_iterationKeyPrefix${planType}_$planId';

    final iterationCycle = cycle ?? IterationCycle.fromDays(_defaultIterationDays);

    final status = {
      'plan_type': planType,
      'plan_id': planId,
      'last_update': updateDate.toIso8601String(),
      'iteration_count': 1,
      'cycle_days': iterationCycle.days,
      'reminder_scheduled': false,
    };

    await prefs.setString(key, status.toString());

    // 安排迭代提醒
    await _scheduleIterationReminder(
      planType: planType,
      planId: planId,
      updateDate: updateDate,
      cycleDays: iterationCycle.days,
    );

    debugPrint('记录计划更新: $planType #$planId, 迭代周期: ${iterationCycle.days}天');
  }

  /// 获取计划的迭代状态
  Future<IterationStatus?> getPlanStatus({
    required String planType,
    required int planId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_iterationKeyPrefix${planType}_$planId';
    final statusStr = prefs.getString(key);

    if (statusStr == null) return null;

    // 解析状态（简化版，实际应使用JSON）
    final lastUpdate = DateTime.tryParse(statusStr) ?? DateTime.now();
    final iterationCount = prefs.getInt('${key}_count') ?? 1;
    final cycleDays = prefs.getInt('${key}_cycle') ?? _defaultIterationDays;

    return IterationStatus(
      planType: planType,
      planId: planId,
      lastUpdateDate: lastUpdate,
      iterationCount: iterationCount,
      cycle: IterationCycle.fromDays(cycleDays),
      reminderScheduled: false,
    );
  }

  /// 增加计划迭代次数
  Future<void> incrementIterationCount({
    required String planType,
    required int planId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_iterationKeyPrefix${planType}_$planId';
    final countKey = '${key}_count';

    final currentCount = prefs.getInt(countKey) ?? 1;
    await prefs.setInt(countKey, currentCount + 1);

    // 更新最后更新时间
    await prefs.setString(key, DateTime.now().toIso8601String());

    // 重新安排提醒
    final cycleDays = prefs.getInt('${key}_cycle') ?? _defaultIterationDays;
    await _scheduleIterationReminder(
      planType: planType,
      planId: planId,
      updateDate: DateTime.now(),
      cycleDays: cycleDays,
    );

    debugPrint('增加迭代次数: $planType #$planId, 当前: ${currentCount + 1}');
  }

  /// 设置迭代周期
  Future<void> setIterationCycle({
    required String planType,
    required int planId,
    required IterationCycle cycle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_iterationKeyPrefix${planType}_$planId';
    final cycleKey = '${key}_cycle';

    await prefs.setInt(cycleKey, cycle.days);

    // 重新安排提醒
    final lastUpdateStr = prefs.getString(key);
    if (lastUpdateStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      await _scheduleIterationReminder(
        planType: planType,
        planId: planId,
        updateDate: lastUpdate,
        cycleDays: cycle.days,
      );
    }

    debugPrint('设置迭代周期: $planType #$planId, ${cycle.days}天');
  }

  /// ==================== 提醒管理 ====================

  /// 安排迭代提醒
  Future<void> _scheduleIterationReminder({
    required String planType,
    required int planId,
    required DateTime updateDate,
    required int cycleDays,
  }) async {
    // 计算提醒时间
    final reminderDate = updateDate.add(Duration(days: cycleDays));

    // 生成唯一的通知ID
    final notificationId = _generateNotificationId(planType, planId);

    await _notificationService.scheduleNotification(
      id: notificationId,
      title: _getReminderTitle(planType),
      body: _getReminderBody(planType, cycleDays),
      scheduledTime: reminderDate,
      payload: 'iteration_${planType}_$planId',
    );

    debugPrint('安排迭代提醒: $planType #$planId, 日期: ${reminderDate.toIso8601String()}');
  }

  /// 检查并处理需要迭代的计划
  ///
  /// 应该定期调用此方法（如每天一次）
  Future<List<IterationStatus>> checkAndNotifyPlansNeedingIteration() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_iterationKeyPrefix)).toList();

    final plansNeedingIteration = <IterationStatus>[];

    for (final key in keys) {
      // 解析key获取planType和planId
      final parts = key.replaceFirst(_iterationKeyPrefix, '').split('_');
      if (parts.length < 2) continue;

      final planType = parts[0];
      final planId = int.tryParse(parts[1]);
      if (planId == null) continue;

      final status = await getPlanStatus(planType: planType, planId: planId);
      if (status == null) continue;

      if (status.needsReminder) {
        plansNeedingIteration.add(status);

        // 发送即时提醒
        await _sendImmediateIterationReminder(status);
      }
    }

    // 更新最后检查时间
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

    return plansNeedingIteration;
  }

  /// 发送即时迭代提醒
  Future<void> _sendImmediateIterationReminder(IterationStatus status) async {
    final notificationId = _generateNotificationId(status.planType, status.planId);

    await _notificationService.showNotification(
      id: notificationId,
      title: _getReminderTitle(status.planType),
      body: _getReminderBody(status.planType, status.cycle.days),
      payload: 'iteration_${status.planType}_${status.planId}',
    );
  }

  /// 取消计划的迭代提醒
  Future<void> cancelIterationReminder({
    required String planType,
    required int planId,
  }) async {
    final notificationId = _generateNotificationId(planType, planId);
    await _notificationService.cancelNotification(notificationId);

    debugPrint('取消迭代提醒: $planType #$planId');
  }

  /// 取消所有迭代提醒
  Future<void> cancelAllIterationReminders() async {
    // 迭代提醒使用 800000-899999 的ID范围
    for (int i = 800000; i < 890000; i++) {
      await _notificationService.cancelNotification(i);
    }

    debugPrint('取消所有迭代提醒');
  }

  /// ==================== 自动迭代 ====================

  /// 执行计划迭代（生成新计划）
  ///
  /// [planType] 计划类型 ('workout' 或 'diet')
  /// [planId] 计划ID
  /// [userProfileId] 用户画像ID
  /// [feedbacks] 用户反馈列表（可选）
  Future<Map<String, dynamic>?> executePlanIteration({
    required String planType,
    required int planId,
    required int userProfileId,
    List<Map<String, dynamic>>? feedbacks,
  }) async {
    try {
      // 获取用户画像
      final profileRepo = UserProfileRepository(AppDatabase); // 需要传入实际的数据库实例
      final userProfile = await profileRepo.getProfileById(userProfileId);
      if (userProfile == null) {
        throw Exception('用户画像不存在');
      }

      // 获取当前计划
      Map<String, dynamic> currentPlan;
      if (planType == 'workout') {
        final workoutRepo = WorkoutPlanRepository(AppDatabase);
        final planWithDetails = await workoutRepo.getPlanWithDetails(planId);
        if (planWithDetails == null) {
          throw Exception('训练计划不存在');
        }
        // 转换为JSON格式
        currentPlan = {
          'planName': planWithDetails.plan.name,
          'description': planWithDetails.plan.description,
          'totalWorkouts': planWithDetails.plan.totalDays,
          'days': planWithDetails.days.map((d) => {
            'day': d.day.dayNumber,
            'dayName': d.day.dayName,
            'trainingFocus': d.day.trainingFocus,
            'exercises': d.exercises.map((e) => {
              'name': e.exerciseName,
              'sets': e.sets,
              'reps': e.repsDescription,
              'difficulty': e.difficulty,
              'exerciseType': e.exerciseType,
            }).toList(),
          }).toList(),
        };
      } else {
        final dietRepo = DietPlanRepository(AppDatabase);
        // 饮食计划处理类似
        currentPlan = {};
      }

      // 获取用户反馈
      final feedbackRepo = UserFeedbackRepository(AppDatabase);
      final userFeedbackList = feedbacks ?? [];
      if (userFeedbackList.isEmpty) {
        final feedbacksData = await feedbackRepo.getRecentFeedbacks(
          userProfileId: userProfileId,
          limit: 50,
        );
        // 转换为JSON格式
        for (final f in feedbacksData) {
          userFeedbackList.add({
            'feedback_type': f.feedbackType,
            'reason': f.reason,
            'original_name': f.originalName,
            'replacement_name': f.replacementName,
            'notes': f.notes,
          });
        }
      }

      // 获取迭代状态
      final status = await getPlanStatus(planType: planType, planId: planId);
      final iterationCount = status?.iterationCount ?? 1;

      // 构建用户画像数据
      final userProfileData = {
        'goal_type': userProfile.goalType,
        'fitness_level': userProfile.fitnessLevel,
        'equipment_type': userProfile.equipmentType,
        'diet_type': userProfile.dietType,
        'dietary_restrictictions': userProfile.dietaryRestrictions,
        'injuries': userProfile.injuries,
        'gender': userProfile.gender,
        'age': userProfile.age,
        'height': userProfile.height,
        'weight': userProfile.weight,
      };

      // 调用AI生成迭代计划
      final aiService = DeepSeekService.instance;
      await aiService.init();

      Map<String, dynamic> newPlan;
      if (planType == 'workout') {
        newPlan = await aiService.generateIteratedWorkoutPlan(
          currentPlan: currentPlan,
          userFeedbacks: userFeedbackList,
          userProfile: userProfileData,
          iterationCount: iterationCount,
        );
      } else {
        newPlan = await aiService.generateIteratedDietPlan(
          currentPlan: currentPlan,
          userFeedbacks: userFeedbackList,
          userProfile: userProfileData,
          iterationCount: iterationCount,
        );
      }

      // 增加迭代计数
      await incrementIterationCount(planType: planType, planId: planId);

      return newPlan;
    } catch (e) {
      debugPrint('执行计划迭代失败: $e');
      return null;
    }
  }

  /// ==================== 定时检查 ====================

  /// 安排每日检查
  Future<void> _scheduleDailyCheck() async {
    // 这里可以使用 flutter_background_service 或类似插件
    // 实现后台定时检查
    // 简化版：每次应用启动时检查一次

    // 延迟5秒后执行检查，避免应用启动时性能影响
    Future.delayed(const Duration(seconds: 5), () {
      checkAndNotifyPlansNeedingIteration();
    });
  }

  /// ==================== 辅助方法 ====================

  /// 生成通知ID
  int _generateNotificationId(String planType, int planId) {
    // 800000-899999 用于迭代提醒
    final typeOffset = planType == 'workout' ? 0 : 50000;
    return 800000 + typeOffset + (planId % 50000);
  }

  /// 获取提醒标题
  String _getReminderTitle(String planType) {
    return planType == 'workout' ? '训练计划迭代提醒' : '饮食计划迭代提醒';
  }

  /// 获取提醒内容
  String _getReminderBody(String planType, int cycleDays) {
    final planName = planType == 'workout' ? '训练计划' : '饮食计划';
    return '您的$planName已运行 $cycleDays 天，建议根据最新数据优化更新计划';
  }

  /// 获取所有迭代计划状态
  Future<List<IterationStatus>> getAllIterationStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_iterationKeyPrefix)).toList();

    final statuses = <IterationStatus>[];

    for (final key in keys) {
      final parts = key.replaceFirst(_iterationKeyPrefix, '').split('_');
      if (parts.length < 2) continue;

      final planType = parts[0];
      final planId = int.tryParse(parts[1]);
      if (planId == null) continue;

      final status = await getPlanStatus(planType: planType, planId: planId);
      if (status != null) {
        statuses.add(status);
      }
    }

    // 按剩余天数排序
    statuses.sort((a, b) => a.daysUntilReminder.compareTo(b.daysUntilReminder));
    return statuses;
  }

  /// 获取优化建议
  Future<List<Map<String, dynamic>>> getOptimizationSuggestions({
    required String planType,
    required int planId,
    required int userProfileId,
  }) async {
    final status = await getPlanStatus(planType: planType, planId: planId);
    if (status == null) return [];

    final daysSinceUpdate = DateTime.now().difference(status.lastUpdateDate).inDays;

    final feedbackRepo = UserFeedbackRepository(AppDatabase);
    final feedbacksData = await feedbackRepo.getRecentFeedbacks(
      userProfileId: userProfileId,
      limit: 50,
    );

    final feedbacks = feedbacksData.map((f) => {
      'feedback_type': f.feedbackType,
      'reason': f.reason,
      'original_name': f.originalName,
    }).toList();

    final aiService = DeepSeekService.instance;
    await aiService.init();

    return await aiService.generatePlanOptimizationSuggestions(
      userFeedbacks: feedbacks,
      planType: planType,
      daysSinceUpdate: daysSinceUpdate,
    );
  }
}
