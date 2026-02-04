/// 运动模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';

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

// ==================== 图表数据 Providers ====================

/// 每日运动统计 Provider 族
/// 参数为天数，如 7天、30天
final dailyStatsProvider = FutureProvider.autoDispose.family<List<DailyWorkoutStats>, int>((ref, days) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getDailyStats(days);
});

/// 运动类型分布 Provider 族
/// 参数为天数
final typeDistributionProvider = FutureProvider.autoDispose.family<List<WorkoutTypeDistribution>, int>((ref, days) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getTypeDistribution(days);
});

/// 运动趋势数据 Provider 族
/// 参数为天数
final trendDataProvider = FutureProvider.autoDispose.family<List<WorkoutTrendPoint>, int>((ref, days) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getTrendData(days);
});

/// 周度运动统计 Provider 族
/// 参数为周数
final weeklyStatsProvider = FutureProvider.autoDispose.family<List<WeeklyWorkoutStats>, int>((ref, weeks) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getWeeklyStats(weeks);
});

/// 月度运动统计 Provider 族
/// 参数为月数
final monthlyStatsProvider = FutureProvider.autoDispose.family<List<MonthlyWorkoutStats>, int>((ref, months) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getMonthlyStats(months);
});

// ==================== 图表时间范围状态 Provider ====================

/// 图表时间范围状态 Provider
class ChartTimeRangeNotifier extends StateNotifier<ChartTimeRange> {
  ChartTimeRangeNotifier() : super(ChartTimeRange.week);

  void setRange(ChartTimeRange range) => state = range;
}

final chartTimeRangeProvider = StateNotifierProvider<ChartTimeRangeNotifier, ChartTimeRange>((ref) {
  return ChartTimeRangeNotifier();
});

/// 图表类型状态 Provider
class ChartTypeNotifier extends StateNotifier<ChartType> {
  ChartTypeNotifier() : super(ChartType.bar);

  void setType(ChartType type) => state = type;
}

final chartTypeProvider = StateNotifierProvider<ChartTypeNotifier, ChartType>((ref) {
  return ChartTypeNotifier();
});

// ==================== 卡路里统计 Providers ====================

/// 今日卡路里消耗 Provider
/// 返回整数值（千卡）
final todayCaloriesProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getTodayCalories();
});

/// 本周卡路里消耗 Provider
/// 返回整数值（千卡）
final thisWeekCaloriesProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisWeekCalories();
});

/// 本月卡路里消耗 Provider
/// 返回整数值（千卡）
final thisMonthCaloriesProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getThisMonthCalories();
});

/// 卡路里汇总 Provider（今日、本周、本月）
/// 返回 Map<String, int> 格式
final caloriesSummaryProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getCaloriesSummary();
});
