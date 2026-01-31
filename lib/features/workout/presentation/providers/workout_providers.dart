/// 运动模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 运动记录列表 Providers ====================

/// 所有运动记录 Provider
final allWorkoutsProvider = FutureProvider.autoDispose<List<Workout>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getAllWorkouts();
});

/// 本周运动记录 Provider
final thisWeekWorkoutsProvider = FutureProvider.autoDispose<List<Workout>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisWeekWorkouts();
});

/// 本月运动记录 Provider
final thisMonthWorkoutsProvider = FutureProvider.autoDispose<List<Workout>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisMonthWorkouts();
});

/// 按类型筛选的运动记录 Provider 族
final workoutsByTypeProvider = FutureProvider.autoDispose.family<List<Workout>, String>((ref, type) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getWorkoutsByType(type);
});

/// 单个运动记录 Provider 族
final workoutProvider = FutureProvider.autoDispose.family<Workout?, int>((ref, id) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getWorkoutById(id);
});

// ==================== 运动统计 Providers ====================

/// 本周运动统计 Provider
final thisWeekStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisWeekStats();
});

/// 本月运动统计 Provider
final thisMonthStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisMonthStats();
});

/// 连续运动天数 Provider
final workoutStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.calculateStreak();
});
