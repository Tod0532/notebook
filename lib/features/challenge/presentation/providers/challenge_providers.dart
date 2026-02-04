/// 挑战系统 Providers
/// 提供挑战状态管理的 Riverpod providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/challenge/challenge_service.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 挑战服务 Provider ====================

/// 挑战服务 Provider
final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService.instance;
});

// ==================== 今日挑战 Providers ====================

/// 今日挑战列表 Provider
final todayChallengesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(challengeServiceProvider);
  await service.generateTodayChallenges();
  return await service.getTodayChallengesWithProgress();
});

/// 今日挑战刷新倒计时 Provider
final challengeRefreshCountdownProvider = StreamProvider.autoDispose<Duration>((ref) {
  return Stream.periodic(
    const Duration(seconds: 1),
    (_) {
      final service = ChallengeService.instance;
      return service.getTimeUntilNextRefresh();
    },
  );
});

/// 待领取奖励的今日挑战数量 Provider
final pendingDailyRewardsProvider = Provider.autoDispose<int>((ref) {
  final challengesAsync = ref.watch(todayChallengesProvider);
  return challengesAsync.when(
    data: (challenges) {
      return challenges.where((c) {
        final progress = c['progress'] as UserChallengeProgress?;
        return progress?.isCompleted == true && progress?.rewardClaimed == false;
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ==================== 每周挑战 Providers ====================

/// 每周挑战列表 Provider
final weeklyChallengesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(challengeServiceProvider);
  await service.generateThisWeekChallenges();
  return await service.getThisWeekChallengesWithProgress();
});

/// 本周剩余天数 Provider
final daysUntilWeekEndProvider = Provider.autoDispose<int>((ref) {
  final service = ChallengeService.instance;
  return service.getDaysUntilWeekEnd();
});

/// 待领取奖励的每周挑战数量 Provider
final pendingWeeklyRewardsProvider = Provider.autoDispose<int>((ref) {
  final challengesAsync = ref.watch(weeklyChallengesProvider);
  return challengesAsync.when(
    data: (challenges) {
      return challenges.where((c) {
        final progress = c['progress'] as UserWeeklyChallengeProgress?;
        return progress?.isCompleted == true && progress?.rewardClaimed == false;
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ==================== 挑战状态 Provider ====================

/// 总待领取奖励数量 Provider
final totalPendingRewardsProvider = Provider.autoDispose<int>((ref) {
  final daily = ref.watch(pendingDailyRewardsProvider);
  final weekly = ref.watch(pendingWeeklyRewardsProvider);
  return daily + weekly;
});

// ==================== 挑战操作 StateNotifier ====================

/// 挑战操作状态
class ChallengeNotifier extends StateNotifier<AsyncValue<void>> {
  ChallengeNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  /// 领取每日挑战奖励
  Future<bool> claimDailyReward(int challengeId) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(challengeServiceProvider);
      final success = await service.claimChallengeReward(challengeId);
      state = const AsyncValue.data(null);
      // 刷新挑战列表
      ref.invalidate(todayChallengesProvider);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 领取每周挑战奖励
  Future<bool> claimWeeklyReward(int challengeId) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(challengeServiceProvider);
      final success = await service.claimWeeklyChallengeReward(challengeId);
      state = const AsyncValue.data(null);
      // 刷新挑战列表
      ref.invalidate(weeklyChallengesProvider);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// 挑战操作 Provider
final challengeNotifierProvider = StateNotifierProvider<ChallengeNotifier, AsyncValue<void>>((ref) {
  return ChallengeNotifier(ref);
});
