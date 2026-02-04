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

/// 剩余免费抽卡次数 Provider
final remainingFreeDrawsProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getRemainingFreeDraws();
});

/// 保底计数 Provider
final pityCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getPityCount();
});

/// 距离保底的抽数 Provider
final pityCountdownProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getPityCountdown();
});

/// 抽卡历史 Provider
final gachaHistoryProvider = FutureProvider.autoDispose<List<GachaRecord>>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getDrawHistory();
});

/// 已收集物品 Provider
final collectedItemsProvider = FutureProvider.autoDispose<List<GachaItem>>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getCollectedItems();
});

/// 抽卡统计 Provider
final gachaStatisticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.watch(gachaServiceProvider);
  return await service.getStatistics();
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

      // 刷新相关状态
      ref.invalidate(remainingFreeDrawsProvider);
      ref.invalidate(pityCountProvider);
      ref.invalidate(gachaHistoryProvider);
      ref.invalidate(collectedItemsProvider);
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

      // 刷新相关状态
      ref.invalidate(pityCountProvider);
      ref.invalidate(gachaHistoryProvider);
      ref.invalidate(collectedItemsProvider);
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
