/// 抽卡页面
/// 提供抽卡功能、展示抽卡历史和已收集物品

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
    final freeDrawsAsync = ref.watch(remainingFreeDrawsProvider);
    final pityCountdownAsync = ref.watch(pityCountdownProvider);

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
          _buildDrawTab(drawResultAsync, freeDrawsAsync, pityCountdownAsync),
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
    AsyncValue<int> freeDrawsAsync,
    AsyncValue<int> pityCountdownAsync,
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
              _buildDrawButtons(drawResultAsync, freeDrawsAsync, pityCountdownAsync),
              const SizedBox(height: AppSpacing.xxl),
              // 保底信息
              _buildPityInfo(pityCountdownAsync),
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
    AsyncValue<int> freeDrawsAsync,
    AsyncValue<int> pityCountdownAsync,
  ) {
    return Column(
      children: [
        // 标题
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
              child: _buildFreeDrawButton(drawResultAsync, freeDrawsAsync),
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
    AsyncValue<int> freeDrawsAsync,
  ) {
    final isLoading = drawResultAsync.isLoading;

    return freeDrawsAsync.when(
      data: (freeDraws) {
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
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xCCFFFFFF), // 白色 80% 不透明度
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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

  /// 构建保底信息
  Widget _buildPityInfo(AsyncValue<int> pityCountdownAsync) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: pityCountdownAsync.when(
              data: (countdown) {
                return Text(
                  '再抽 $countdown 次必出稀有以上物品',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                );
              },
              loading: () => Text(
                '加载中...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              error: (_, __) => Text(
                '保底计算中...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
        ],
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
