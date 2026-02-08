/// 抽卡页面
/// 提供抽卡功能、展示抽卡历史和已收集物品

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gacha/presentation/providers/gacha_providers.dart';
import 'package:thick_notepad/features/gacha/presentation/widgets/gacha_animation.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 抽卡页面
class GachaPage extends ConsumerStatefulWidget {
  const GachaPage({super.key});

  @override
  ConsumerState<GachaPage> createState() => _GachaPageState();
}

class _GachaPageState extends ConsumerState<GachaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawResultAsync = ref.watch(gachaNotifierProvider);
    final freeDraws = ref.watch(remainingFreeDrawsProvider);
    final pityCountdown = ref.watch(pityCountdownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('幸运抽卡'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '抽卡'),
            Tab(text: '历史'),
            Tab(text: '收集'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 抽卡页
          _buildDrawTab(drawResultAsync, freeDraws, pityCountdown),
          // 历史页
          _buildHistoryTab(),
          // 收集页
          _buildCollectionTab(),
        ],
      ),
    );
  }

  /// 构建抽卡页
  Widget _buildDrawTab(
    AsyncValue<GachaDrawResult?> drawResultAsync,
    int freeDraws,
    int pityCountdown,
  ) {
    return Stack(
      children: [
        // 背景装饰
        _buildBackgroundDecoration(),

        // 内容
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              // 抽卡按钮区域
              _buildDrawButtons(drawResultAsync, freeDraws, pityCountdown),
              const SizedBox(height: AppSpacing.xl),
              // 保底进度面板
              _buildPityProgressPanel(),
              const SizedBox(height: AppSpacing.xl),
              // 概率说明
              _buildProbabilityInfo(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),

        // 抽卡结果遮罩
        if (drawResultAsync.hasValue && drawResultAsync.value != null)
          _buildDrawResultOverlay(drawResultAsync.value!),
      ],
    );
  }

  /// 构建背景装饰
  Widget _buildBackgroundDecoration() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(
          painter: _StarBackgroundPainter(),
        ),
      ),
    );
  }

  /// 构建抽卡按钮区域
  Widget _buildDrawButtons(
    AsyncValue<GachaDrawResult?> drawResultAsync,
    int freeDraws,
    int pityCountdown,
  ) {
    return Column(
      children: [
        // 标题
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.xxlRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '幸运抽卡',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '抽取稀有称号、主题和徽章',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 抽卡按钮
        Row(
          children: [
            // 免费抽卡按钮
            Expanded(
              child: _buildFreeDrawButton(drawResultAsync, freeDraws),
            ),
            const SizedBox(width: AppSpacing.md),
            // 十连抽按钮
            Expanded(
              child: _buildTenDrawButton(drawResultAsync),
            ),
          ],
        ),
      ],
    );
  }

  /// 免费抽卡按钮
  Widget _buildFreeDrawButton(
    AsyncValue<GachaDrawResult?> drawResultAsync,
    int freeDraws,
  ) {
    final isLoading = drawResultAsync.isLoading;
    final canDrawFree = freeDraws > 0;

    return ElevatedButton(
      onPressed: isLoading || !canDrawFree
          ? null
          : () {
              ref.read(gachaNotifierProvider.notifier).drawSingle(useFreeDraw: true);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: canDrawFree ? AppColors.primary : AppColors.dividerColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.dividerColor,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canDrawFree ? '免费抽取' : '次数用完',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (canDrawFree)
            Text(
              '剩余 $freeDraws 次',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xCCFFFFFF), // 白色 80% 不透明度
              ),
            ),
        ],
      ),
    );
  }

  /// 十连抽按钮
  Widget _buildTenDrawButton(AsyncValue<GachaDrawResult?> drawResultAsync) {
    final isLoading = drawResultAsync.isLoading;

    return ElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              ref.read(gachaNotifierProvider.notifier).drawTen();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.card_giftcard_rounded, size: 24),
          SizedBox(height: AppSpacing.sm),
          Text(
            '十连抽',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            '450 积分',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xCCFFFFFF), // 白色 80% 不透明度
            ),
          ),
        ],
      ),
    );
  }

  /// 构建保底进度面板
  Widget _buildPityProgressPanel() {
    final pityCount = ref.watch(pityCountProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '保底进度',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '当前: 第${pityCount}抽',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 实时概率显示
          _buildCurrentProbabilityDisplay(pityCount),
          const SizedBox(height: AppSpacing.lg),

          // 保底进度条
          _buildPityProgressBar(pityCount, GachaConfig.rarePityThreshold, '稀有保底', const Color(0xFF2196F3)),
          const SizedBox(height: AppSpacing.md),
          _buildPityProgressBar(pityCount, GachaConfig.epicPityThreshold, '史诗保底', const Color(0xFF9C27B0)),
          const SizedBox(height: AppSpacing.md),
          _buildPityProgressBar(pityCount, GachaConfig.legendaryPityThreshold, '传说保底', const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  /// 构建当前概率显示
  Widget _buildCurrentProbabilityDisplay(int pityCount) {
    final probabilities = GachaConfig.getRarityProbabilities(pityCount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 16, color: AppColors.primary.withOpacity(0.7)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '当前概率',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _buildProbabilityChip('普通', probabilities[GachaRarity.common]!, const Color(0xFF9E9E9E)),
              _buildProbabilityChip('稀有', probabilities[GachaRarity.rare]!, const Color(0xFF2196F3)),
              _buildProbabilityChip('史诗', probabilities[GachaRarity.epic]!, const Color(0xFF9C27B0)),
              _buildProbabilityChip('传说', probabilities[GachaRarity.legendary]!, const Color(0xFFFF9800)),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建概率标签
  Widget _buildProbabilityChip(String label, double probability, Color color) {
    final percentage = (probability * 100).toStringAsFixed(1);
    final isZero = probability < 0.001;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isZero ? color.withOpacity(0.1) : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isZero ? color.withOpacity(0.2) : color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isZero ? color.withOpacity(0.5) : color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isZero ? '0%' : '$percentage%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isZero ? color.withOpacity(0.5) : color,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建保底进度条
  Widget _buildPityProgressBar(int pityCount, int target, String label, Color color) {
    final progress = (pityCount / target).clamp(0.0, 1.0);
    final remaining = max(0, target - pityCount);
    final isNearPity = remaining <= 2 && remaining > 0; // 接近保底（剩2抽以内）
    final isPityReached = pityCount >= target; // 已触发保底

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPityReached ? Colors.green : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPityReached ? Colors.green : AppColors.textSecondary,
                  ),
                ),
                if (isNearPity && !isPityReached) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _buildPulsingIndicator(color),
                ],
              ],
            ),
            Text(
              isPityReached ? '保底已触发!' : '$target 抽',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPityReached ? Colors.green : AppColors.textHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // 进度条
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // 背景进度条
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isNearPity
                          ? [color.withOpacity(0.8), color]
                          : [color.withOpacity(0.6), color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isNearPity
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // 保底标记
              if (!isPityReached && remaining <= 3 && remaining > 0)
                Positioned(
                  right: (remaining / target) * MediaQuery.of(context).size.width * 0.8 - 4,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: isNearPity ? Colors.red : Colors.orange,
                      boxShadow: [
                        BoxShadow(
                          color: (isNearPity ? Colors.red : Colors.orange).withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // 进度文本
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度: $pityCount / $target',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
            if (!isPityReached)
              Text(
                '还差 $remaining 抽',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isNearPity ? color : AppColors.textHint,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建脉动指示器（保底预告效果）
  Widget _buildPulsingIndicator(Color color) {
    return _PulsingWidget(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Text(
          '即将触发',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  /// 构建概率说明
  Widget _buildProbabilityInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '概率说明',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildProbabilityItem('普通物品', '60%', const Color(0xFF9E9E9E)),
          const SizedBox(height: 4),
          _buildProbabilityItem('稀有物品', '30%', const Color(0xFF2196F3)),
          const SizedBox(height: 4),
          _buildProbabilityItem('史诗物品', '8%', const Color(0xFF9C27B0)),
          const SizedBox(height: 4),
          _buildProbabilityItem('传说物品', '2%', const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _buildProbabilityItem(String name, String probability, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Text(
          probability,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 构建抽卡结果遮罩
  Widget _buildDrawResultOverlay(GachaDrawResult result) {
    return GestureDetector(
      onTap: () {
        ref.read(gachaNotifierProvider.notifier).reset();
      },
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: result.results.length == 1
              ? GachaCardAnimation(
                  result: result.results.first,
                  onAnimationComplete: () {
                    // 动画完成后自动关闭
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        ref.read(gachaNotifierProvider.notifier).reset();
                      }
                    });
                  },
                )
              : TenDrawResultWidget(
                  results: result.results,
                  onClose: () {
                    ref.read(gachaNotifierProvider.notifier).reset();
                  },
                ),
        ),
      ),
    );
  }

  /// 构建历史页
  Widget _buildHistoryTab() {
    final historyAsync = ref.watch(gachaHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_outlined,
            title: '暂无记录',
            message: '开始抽卡获取物品吧！',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final record = history[index];
            return _buildHistoryItem(record);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        message: '请稍后再试',
      ),
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(GachaRecord record) {
    final rarity = GachaRarity.fromString(record.rarity);
    final color = _getRarityColor(rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          // 稀有度指示器
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // 物品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.itemName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  rarity.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          // 日期
          Text(
            _formatDate(record.drawnAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建收集页
  Widget _buildCollectionTab() {
    final collectedAsync = ref.watch(collectedItemsProvider);

    return collectedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: '暂无收集',
            message: '通过抽卡收集各种物品吧！',
          );
        }

        final groupedItems = <GachaRarity, List<GachaItem>>{};
        for (final item in items) {
          groupedItems.putIfAbsent(item.rarity, () => []).add(item);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: GachaRarity.values.length,
          itemBuilder: (context, index) {
            final rarity = GachaRarity.values[index];
            final items = groupedItems[rarity] ?? [];

            return _buildCollectionSection(rarity, items);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        message: '请稍后再试',
      ),
    );
  }

  /// 构建收集区域
  Widget _buildCollectionSection(GachaRarity rarity, List<GachaItem> items) {
    final color = _getRarityColor(rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 稀有度标题
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${rarity.displayName} (${items.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 物品网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildCollectionItem(item, color);
            },
          ),
        ],
      ),
    );
  }

  /// 构建收集物品
  Widget _buildCollectionItem(GachaItem item, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getItemIcon(item.type),
            color: color.withOpacity(0.7),
            size: 24,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getItemIcon(GachaItemType type) {
    switch (type) {
      case GachaItemType.title:
        return Icons.military_tech_rounded;
      case GachaItemType.theme:
        return Icons.palette_rounded;
      case GachaItemType.icon:
        return Icons.emoji_emotions_rounded;
      case GachaItemType.badge:
        return Icons.workspace_premium_rounded;
    }
  }

  Color _getRarityColor(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return const Color(0xFF9E9E9E);
      case GachaRarity.limited:
        return const Color(0xFFFF1744);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }

  /// 空状态
  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.dividerColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// 星空背景绘制器
class _StarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final random = 42; // 固定种子确保一致性
    for (int i = 0; i < 50; i++) {
      final x = ((i * 137.5) % size.width);
      final y = ((i * 73.3) % size.height);
      final radius = ((i * 5.7) % 3) + 1;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 脉动动画组件（保底预告效果）
class _PulsingWidget extends StatefulWidget {
  final Widget child;

  const _PulsingWidget({required this.child});

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
