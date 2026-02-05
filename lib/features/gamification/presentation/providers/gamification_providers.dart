/// 游戏化模块 Providers
/// 提供游戏化相关的状态管理

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/gamification/gamification_service.dart';
import 'package:thick_notepad/services/gamification/shop_service.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';

// ==================== 游戏化服务 Providers ====================

/// 游戏化服务 Provider（单例）
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final service = GamificationService();
  final db = ref.watch(databaseProvider);
  service.setDatabase(db);
  return service;
});

/// 积分商店服务 Provider（单例）
final shopServiceProvider = Provider<ShopService>((ref) {
  final service = ShopService();
  final db = ref.watch(databaseProvider);
  final gamificationService = ref.watch(gamificationServiceProvider);
  service.setDatabase(db, gamificationService);
  return service;
});

// ==================== 用户游戏数据 Providers ====================

/// 用户游戏数据 Provider
/// 自动刷新当相关数据变化时
final userGameDataProvider = FutureProvider.autoDispose<UserGameDataModel>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  return await service.getUserGameData();
});

/// 当前等级 Provider
/// 使用 select 只在 level 字段变化时重建
/// 注意：这里需要监听整个 AsyncValue，因为 UserGameDataModel 是不可变的
/// 但是可以通过检查 value 是否变化来减少不必要的重建
final currentLevelProvider = Provider.autoDispose<int>((ref) {
  final data = ref.watch(userGameDataProvider);
  return data.when(
    data: (gameData) => gameData.level,
    loading: () => 1,
    error: (_, __) => 1,
  );
});

/// 当前经验值 Provider
/// 使用 select 只在 exp 字段变化时重建
final currentExpProvider = Provider.autoDispose<int>((ref) {
  final data = ref.watch(userGameDataProvider);
  return data.when(
    data: (gameData) => gameData.exp,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// 当前积分 Provider
/// 使用 select 只在 points 字段变化时重建
final currentPointsProvider = Provider.autoDispose<int>((ref) {
  final data = ref.watch(userGameDataProvider);
  return data.when(
    data: (gameData) => gameData.points,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// 当前连续打卡天数 Provider
final currentStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  return await service.getCurrentStreak();
});

// ==================== 成就系统 Providers ====================

/// 所有成就进度 Provider
final allAchievementsProvider = FutureProvider.autoDispose<List<AchievementProgress>>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  return await service.getAllAchievementsProgress();
});

/// 已解锁成就列表 Provider
/// 派生自 allAchievementsProvider，使用 select 过滤已解锁的成就
/// 这样可以复用缓存，避免重复查询
final unlockedAchievementsProvider = Provider.autoDispose<List<AchievementProgress>>((ref) {
  return ref.watch(allAchievementsProvider).when(
    data: (achievements) => achievements.where((a) => a.isUnlocked).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// 未解锁成就列表 Provider
/// 派生自 allAchievementsProvider，使用 select 过滤未解锁的成就
final lockedAchievementsProvider = Provider.autoDispose<List<AchievementProgress>>((ref) {
  return ref.watch(allAchievementsProvider).when(
    data: (achievements) => achievements.where((a) => !a.isUnlocked).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// 按分类筛选的成就 Provider
/// 派生自 allAchievementsProvider，避免重复查询
final achievementsByCategoryProvider = Provider.autoDispose.family<AsyncValue<List<AchievementProgress>>, AchievementCategory>((ref, category) {
  return ref.watch(allAchievementsProvider).when(
    data: (achievements) => AsyncValue.data(achievements.where((a) => a.achievement.category == category).toList()),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// 按稀有度筛选的成就 Provider
/// 派生自 allAchievementsProvider，避免重复查询
final achievementsByTierProvider = Provider.autoDispose.family<AsyncValue<List<AchievementProgress>>, AchievementTier>((ref, tier) {
  return ref.watch(allAchievementsProvider).when(
    data: (achievements) => AsyncValue.data(achievements.where((a) => a.achievement.tier == tier).toList()),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

// ==================== 商店系统 Providers ====================

/// 所有商店物品 Provider
final allShopItemsProvider = FutureProvider.autoDispose<List<ShopItemModel>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return await service.getAllShopItems();
});

/// 按类型筛选的商店物品 Provider
final shopItemsByTypeProvider = FutureProvider.autoDispose.family<List<ShopItemModel>, ShopItemType>((ref, type) async {
  final service = ref.watch(shopServiceProvider);
  return await service.getShopItemsByType(type);
});

/// 用户可购买的物品 Provider
final affordableShopItemsProvider = FutureProvider.autoDispose<List<ShopItemModel>>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return await service.getAffordableItems();
});

// ==================== 游戏化事件 Providers ====================

/// 每日打卡状态 Provider
class DailyCheckInNotifier extends StateNotifier<DailyCheckInState> {
  DailyCheckInNotifier(this._service) : super(const DailyCheckInState.initial());

  final GamificationService _service;

  /// 执行每日打卡
  Future<void> performCheckIn() async {
    state = const DailyCheckInState.loading();
    try {
      final (isConsecutive, streakDays, pointsEarned, expEarned) =
          await _service.performDailyCheckIn();

      // 刷新用户数据
      final gameData = await _service.getUserGameData();

      state = DailyCheckInState.success(
        isConsecutive: isConsecutive,
        streakDays: streakDays,
        pointsEarned: pointsEarned,
        expEarned: expEarned,
        newLevel: gameData.level,
      );
    } catch (e) {
      state = DailyCheckInState.error(e.toString());
    }
  }

  /// 重置状态
  void reset() {
    state = const DailyCheckInState.initial();
  }
}

/// 每日打卡状态 Provider
final dailyCheckInProvider = StateNotifierProvider<DailyCheckInNotifier, DailyCheckInState>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  return DailyCheckInNotifier(service);
});

// ==================== 成就分类统计 Providers ====================

/// 成就分类统计 Provider
class AchievementStatsNotifier extends StateNotifier<AchievementStats?> {
  AchievementStatsNotifier(this._service) : super(null);

  final GamificationService _service;

  /// 加载成就统计
  Future<void> loadStats() async {
    try {
      final all = await _service.getAllAchievementsProgress();

      final total = all.length;
      final unlocked = all.where((a) => a.isUnlocked).length;

      // 按分类统计
      final categoryStats = <AchievementCategory, int>{};
      for (final category in AchievementCategory.values) {
        final categoryAchievements = all.where((a) => a.achievement.category == category);
        final unlockedInCategory = categoryAchievements.where((a) => a.isUnlocked).length;
        categoryStats[category] = unlockedInCategory;
      }

      // 按稀有度统计
      final tierStats = <AchievementTier, int>{};
      for (final tier in AchievementTier.values) {
        final tierAchievements = all.where((a) => a.achievement.tier == tier);
        final unlockedInTier = tierAchievements.where((a) => a.isUnlocked).length;
        tierStats[tier] = unlockedInTier;
      }

      state = AchievementStats(
        total: total,
        unlocked: unlocked,
        categoryStats: categoryStats,
        tierStats: tierStats,
      );
    } catch (e) {
      state = null;
    }
  }
}

/// 成就统计 Provider
final achievementStatsProvider = StateNotifierProvider<AchievementStatsNotifier, AchievementStats?>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  final notifier = AchievementStatsNotifier(service);
  // 自动加载统计数据
  Future.microtask(() => notifier.loadStats());
  return notifier;
});

// ==================== 游戏化事件触发器 ====================

/// 触发运动事件
Future<void> triggerWorkoutEvent(WidgetRef ref, int durationMinutes) async {
  final service = ref.read(gamificationServiceProvider);
  await service.recordWorkout(durationMinutes);
  // 刷新相关 Provider
  ref.invalidate(userGameDataProvider);
  ref.invalidate(allAchievementsProvider);
  ref.invalidate(achievementStatsProvider);
}

/// 触发笔记创建事件
Future<void> triggerNoteCreatedEvent(WidgetRef ref) async {
  final service = ref.read(gamificationServiceProvider);
  await service.recordNoteCreated();
  // 刷新相关 Provider
  ref.invalidate(userGameDataProvider);
  ref.invalidate(allAchievementsProvider);
  ref.invalidate(achievementStatsProvider);
}

/// 触发计划创建事件
Future<void> triggerPlanCreatedEvent(WidgetRef ref) async {
  final service = ref.read(gamificationServiceProvider);
  await service.recordPlanCreated();
  // 刷新相关 Provider
  ref.invalidate(userGameDataProvider);
  ref.invalidate(allAchievementsProvider);
  ref.invalidate(achievementStatsProvider);
}

/// 触发计划完成事件
Future<void> triggerPlanCompletedEvent(WidgetRef ref) async {
  final service = ref.read(gamificationServiceProvider);
  await service.recordPlanCompleted();
  // 刷新相关 Provider
  ref.invalidate(userGameDataProvider);
  ref.invalidate(allAchievementsProvider);
  ref.invalidate(achievementStatsProvider);
}

/// 触发任务完成事件
Future<void> triggerTaskCompletedEvent(WidgetRef ref) async {
  final service = ref.read(gamificationServiceProvider);
  await service.recordPlanTaskCompleted();
  // 刷新相关 Provider
  ref.invalidate(userGameDataProvider);
}

// ==================== 状态数据类 ====================

/// 每日打卡状态
class DailyCheckInState {
  const DailyCheckInState.initial()
      : status = _DailyCheckInStatus.initial,
        isConsecutive = null,
        streakDays = null,
        pointsEarned = null,
        expEarned = null,
        newLevel = null,
        message = null;
  const DailyCheckInState.loading()
      : status = _DailyCheckInStatus.loading,
        isConsecutive = null,
        streakDays = null,
        pointsEarned = null,
        expEarned = null,
        newLevel = null,
        message = null;
  const DailyCheckInState.success({
    required this.isConsecutive,
    required this.streakDays,
    required this.pointsEarned,
    required this.expEarned,
    required this.newLevel,
  })  : status = _DailyCheckInStatus.success,
        message = null;
  const DailyCheckInState.error(this.message)
      : status = _DailyCheckInStatus.error,
        isConsecutive = null,
        streakDays = null,
        pointsEarned = null,
        expEarned = null,
        newLevel = null;

  final _DailyCheckInStatus status;
  final bool? isConsecutive;
  final int? streakDays;
  final int? pointsEarned;
  final int? expEarned;
  final int? newLevel;
  final String? message;

  /// 是否正在加载
  bool get isLoading => status == _DailyCheckInStatus.loading;

  /// 是否成功
  bool get isSuccess => status == _DailyCheckInStatus.success;

  /// 是否出错
  bool get hasError => status == _DailyCheckInStatus.error;
}

enum _DailyCheckInStatus { initial, loading, success, error }

/// 成就统计数据
class AchievementStats {
  final int total;
  final int unlocked;
  final Map<AchievementCategory, int> categoryStats;
  final Map<AchievementTier, int> tierStats;

  AchievementStats({
    required this.total,
    required this.unlocked,
    required this.categoryStats,
    required this.tierStats,
  });

  /// 解锁进度百分比
  double get progress => total > 0 ? unlocked / total : 0;

  /// 是否已全部解锁
  bool get isAllUnlocked => unlocked >= total;
}
