/// 抽卡系统 Providers
/// 提供抽卡状态管理的 Riverpod providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart' show GachaItem;
import 'package:thick_notepad/services/database/database.dart';

// ==================== 抽卡服务 Provider ====================

/// 抽卡服务 Provider
final gachaServiceProvider = Provider<GachaService>((ref) {
  return GachaService.instance;
});

// ==================== 抽卡状态 Providers ====================

/// 抽卡数据缓存 Provider - 聚合所有抽卡相关数据
/// 使用单一Provider减少请求次数，子Provider使用select派生
final gachaCacheProvider = FutureProvider.autoDispose<GachaCache>((ref) async {
  final service = ref.watch(gachaServiceProvider);

  // 并行获取所有数据以提高性能
  final results = await Future.wait([
    service.getRemainingFreeDraws(),
    service.getPityCount(),
    service.getPityCountdown(),
    service.getDrawHistory(),
    service.getCollectedItems(),
    service.getStatistics(),
  ]);

  return GachaCache(
    remainingFreeDraws: results[0] as int,
    pityCount: results[1] as int,
    pityCountdown: results[2] as int,
    history: results[3] as List<GachaRecord>,
    collectedItems: results[4] as List<GachaItem>,
    statistics: results[5] as Map<String, dynamic>,
  );
});

/// 抽卡数据缓存模型
class GachaCache {
  final int remainingFreeDraws;
  final int pityCount;
  final int pityCountdown;
  final List<GachaRecord> history;
  final List<GachaItem> collectedItems;
  final Map<String, dynamic> statistics;

  const GachaCache({
    required this.remainingFreeDraws,
    required this.pityCount,
    required this.pityCountdown,
    required this.history,
    required this.collectedItems,
    required this.statistics,
  });
}

/// 剩余免费抽卡次数 Provider
/// 使用 select 只监听 remainingFreeDraws 字段
final remainingFreeDrawsProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => cache.remainingFreeDraws,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// 保底计数 Provider
/// 使用 select 只监听 pityCount 字段
final pityCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => cache.pityCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// 距离保底的抽数 Provider
/// 使用 select 只监听 pityCountdown 字段
final pityCountdownProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => cache.pityCountdown,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// 抽卡历史 Provider
/// 监听 gachaCacheProvider 的 history 字段
final gachaHistoryProvider = Provider.autoDispose<AsyncValue<List<GachaRecord>>>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => AsyncValue.data(cache.history),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// 已收集物品 Provider
/// 监听 gachaCacheProvider 的 collectedItems 字段
final collectedItemsProvider = Provider.autoDispose<AsyncValue<List<GachaItem>>>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => AsyncValue.data(cache.collectedItems),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// 抽卡统计 Provider
/// 使用 select 只监听 statistics 字段
final gachaStatisticsProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(gachaCacheProvider).when(
    data: (cache) => cache.statistics,
    loading: () => {},
    error: (_, __) => {},
  );
});

// ==================== 抽卡操作 StateNotifier ====================

/// 抽卡结果
class GachaDrawResult {
  final List<GachaResult> results;
  final bool isNew;
  final GachaRarity? bestRarity;

  const GachaDrawResult({
    required this.results,
    required this.isNew,
    this.bestRarity,
  });
}

/// 抽卡操作状态
class GachaNotifier extends StateNotifier<AsyncValue<GachaDrawResult?>> {
  GachaNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  /// 单次抽卡
  Future<void> drawSingle({bool useFreeDraw = false}) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(gachaServiceProvider);
      final result = await service.drawSingle(useFreeDraw: useFreeDraw);

      // 确定最佳稀有度
      GachaRarity? bestRarity = result.rarity;
      int bestValue = _getRarityValue(result.rarity);

      state = AsyncValue.data(GachaDrawResult(
        results: [result],
        isNew: result.isNew,
        bestRarity: bestRarity,
      ));

      // 只刷新单一缓存Provider，减少invalidate次数
      ref.invalidate(gachaCacheProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 十连抽
  Future<void> drawTen() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(gachaServiceProvider);
      final results = await service.drawTen();

      // 确定最佳稀有度
      GachaRarity? bestRarity;
      int bestValue = 0;
      bool hasNew = false;

      for (final result in results) {
        final value = _getRarityValue(result.rarity);
        if (value > bestValue) {
          bestValue = value;
          bestRarity = result.rarity;
        }
        if (result.isNew) hasNew = true;
      }

      state = AsyncValue.data(GachaDrawResult(
        results: results,
        isNew: hasNew,
        bestRarity: bestRarity,
      ));

      // 只刷新单一缓存Provider，减少invalidate次数
      ref.invalidate(gachaCacheProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 重置结果
  void reset() {
    state = const AsyncValue.data(null);
  }

  /// 获取稀有度权重值
  int _getRarityValue(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return 1;
      case GachaRarity.limited:
        return 5;
      case GachaRarity.rare:
        return 2;
      case GachaRarity.epic:
        return 3;
      case GachaRarity.legendary:
        return 4;
    }
  }
}

/// 抽卡操作 Provider
final gachaNotifierProvider = StateNotifierProvider<GachaNotifier, AsyncValue<GachaDrawResult?>>((ref) {
  return GachaNotifier(ref);
});
