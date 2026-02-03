/// 全局 Providers
/// 提供数据库和仓库实例

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/reminders/data/models/reminder_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';
import 'package:thick_notepad/features/plans/data/models/plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/diet_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/services/ai/plan_iteration_service.dart';
import 'package:thick_notepad/services/heart_rate/heart_rate_service.dart';

// ==================== 数据库 Provider ====================

/// 数据库单例 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return DatabaseProvider.instance;
});

// ==================== 仓库 Providers ====================

/// 笔记仓库 Provider
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseProvider));
});

/// 提醒仓库 Provider
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(databaseProvider));
});

/// 运动仓库 Provider
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(databaseProvider));
});

/// 计划仓库 Provider
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(databaseProvider));
});

// ==================== AI教练功能仓库 Providers ====================

/// 用户画像仓库 Provider
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(databaseProvider));
});

/// AI训练计划仓库 Provider
final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>((ref) {
  return WorkoutPlanRepository(ref.watch(databaseProvider));
});

/// AI饮食计划仓库 Provider
final dietPlanRepositoryProvider = Provider<DietPlanRepository>((ref) {
  return DietPlanRepository(ref.watch(databaseProvider));
});

/// 用户反馈仓库 Provider
final userFeedbackRepositoryProvider = Provider<UserFeedbackRepository>((ref) {
  return UserFeedbackRepository(ref.watch(databaseProvider));
});

// ==================== 服务 Providers ====================

/// 计划迭代服务 Provider
final planIterationServiceProvider = Provider<PlanIterationService>((ref) {
  return PlanIterationService.instance;
});

// ==================== 心率监测服务 Providers ====================

/// 心率服务 Provider（单例）
final heartRateServiceProvider = Provider<HeartRateService>((ref) {
  return HeartRateService();
});

/// 心率服务初始化 Provider
final heartRateServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(heartRateServiceProvider);
  final db = ref.watch(databaseProvider);
  service.setDatabase(db);
});
