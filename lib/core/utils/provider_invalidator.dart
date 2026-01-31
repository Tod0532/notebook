/// Provider 刷新工具类
/// 统一管理相关 Provider 的刷新逻辑，避免手动刷新遗漏

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:thick_notepad/shared/widgets/recent_activities.dart';

/// Provider 刷新工具
class ProviderInvalidator {
  /// 刷新笔记相关的所有 Provider (Ref 版本)
  static void invalidateNotesRef(Ref ref) {
    ref.invalidate(allNotesProvider);
    ref.invalidate(pinnedNotesProvider);
  }

  /// 刷新运动相关的所有 Provider (Ref 版本)
  static void invalidateWorkoutsRef(Ref ref) {
    ref.invalidate(allWorkoutsProvider);
    ref.invalidate(thisWeekWorkoutsProvider);
    ref.invalidate(thisMonthWorkoutsProvider);
    ref.invalidate(thisWeekStatsProvider);
    ref.invalidate(workoutStreakProvider);
  }

  /// 刷新计划相关的所有 Provider (Ref 版本)
  static void invalidatePlansRef(Ref ref) {
    ref.invalidate(allPlansProvider);
    ref.invalidate(activePlansProvider);
    ref.invalidate(completedPlansProvider);
  }

  /// 刷新任务相关的所有 Provider (Ref 版本)
  static void invalidateTasksRef(Ref ref) {
    ref.invalidate(todayTasksProvider);
    ref.invalidate(thisWeekTasksProvider);
    ref.invalidate(taskStatsProvider);
  }

  /// 刷新提醒相关的所有 Provider (Ref 版本)
  static void invalidateRemindersRef(Ref ref) {
    ref.invalidate(allRemindersProvider);
    ref.invalidate(pendingRemindersProvider);
    ref.invalidate(completedRemindersProvider);
    ref.invalidate(todayRemindersProvider);
  }

  /// 刷新动态列表 (Ref 版本)
  static void invalidateActivitiesRef(Ref ref) {
    ref.invalidate(recentActivitiesProvider);
  }

  /// 刷新笔记相关的所有 Provider (WidgetRef 版本)
  static void invalidateNotes(WidgetRef ref) {
    ref.invalidate(allNotesProvider);
    ref.invalidate(pinnedNotesProvider);
  }

  /// 刷新运动相关的所有 Provider (WidgetRef 版本)
  static void invalidateWorkouts(WidgetRef ref) {
    ref.invalidate(allWorkoutsProvider);
    ref.invalidate(thisWeekWorkoutsProvider);
    ref.invalidate(thisMonthWorkoutsProvider);
    ref.invalidate(thisWeekStatsProvider);
    ref.invalidate(workoutStreakProvider);
  }

  /// 刷新计划相关的所有 Provider (WidgetRef 版本)
  static void invalidatePlans(WidgetRef ref) {
    ref.invalidate(allPlansProvider);
    ref.invalidate(activePlansProvider);
    ref.invalidate(completedPlansProvider);
  }

  /// 刷新任务相关的所有 Provider (WidgetRef 版本)
  static void invalidateTasks(WidgetRef ref) {
    ref.invalidate(todayTasksProvider);
    ref.invalidate(thisWeekTasksProvider);
    ref.invalidate(taskStatsProvider);
  }

  /// 刷新提醒相关的所有 Provider (WidgetRef 版本)
  static void invalidateReminders(WidgetRef ref) {
    ref.invalidate(allRemindersProvider);
    ref.invalidate(pendingRemindersProvider);
    ref.invalidate(completedRemindersProvider);
    ref.invalidate(todayRemindersProvider);
  }

  /// 刷新动态列表 (WidgetRef 版本)
  static void invalidateActivities(WidgetRef ref) {
    ref.invalidate(recentActivitiesProvider);
  }

  /// 刷新运动记录后的完整刷新 (WidgetRef 版本)
  static void invalidateAfterWorkout(WidgetRef ref) {
    invalidateWorkouts(ref);
    invalidatePlans(ref);
    invalidateTasks(ref);
    invalidateActivities(ref);
  }

  /// 刷新计划操作后的完整刷新 (Ref 版本)
  static void invalidateAfterPlanRef(Ref ref) {
    invalidatePlansRef(ref);
    invalidateTasksRef(ref);
    invalidateActivitiesRef(ref);
  }

  /// 刷新任务操作后的完整刷新 (Ref 版本)
  static void invalidateAfterTaskRef(Ref ref) {
    invalidatePlansRef(ref);
    invalidateTasksRef(ref);
    invalidateActivitiesRef(ref);
  }

  /// 刷新提醒操作后的完整刷新 (Ref 版本)
  static void invalidateAfterReminderRef(Ref ref) {
    invalidateRemindersRef(ref);
    invalidateActivitiesRef(ref);
  }
}
