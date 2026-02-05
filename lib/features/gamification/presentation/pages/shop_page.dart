/// 积分商店页面
/// 展示可购买的物品、主题、称号等

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';
import 'package:shimmer/shimmer.dart';

/// 积分商店页面
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ShopItemType? _selectedType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：积分余额
            _buildHeader(context),
            // 分类标签
            _buildCategoryTabs(context),
            // 商品列表
            Expanded(
              child: _buildShopItems(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部头部
  Widget _buildHeader(BuildContext context) {
    final pointsAsync = ref.watch(userGameDataProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '积分商店',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 积分余额卡片
          pointsAsync.when(
            data: (gameData) => _buildPointsCard(context, gameData.points),
            loading: () => _buildPointsLoading(context),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 积分余额卡片
  Widget _buildPointsCard(BuildContext context, int points) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent,
            AppColors.accentLight,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的积分',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$points',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 积分加载中
  Widget _buildPointsLoading(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// 分类标签
  Widget _buildCategoryTabs(BuildContext context) {
    final categories = [
      (null, '全部'),
      (ShopItemType.theme, '主题'),
      (ShopItemType.title, '称号'),
      (ShopItemType.icon, '图标'),
      (ShopItemType.badge, '徽章'),
    ];

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: AppRadius.mdRadius,
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        onTap: (index) {
          setState(() {
            _selectedType = categories[index].$1;
          });
        },
        tabs: categories
            .map((cat) => Tab(text: cat.$2))
            .toList(),
      ),
    );
  }

  /// 商品列表
  Widget _buildShopItems(BuildContext context) {
    if (_selectedType == null) {
      return _buildAllItems();
    }
    return _buildItemsByType(_selectedType!);
  }

  /// 所有商品
  Widget _buildAllItems() {
    final itemsAsync = ref.watch(allShopItemsProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(context, '暂无商品');
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return ShopItemCard(item: items[index]);
          },
        );
      },
      loading: () => _buildLoadingGrid(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 按类型筛选的商品
  Widget _buildItemsByType(ShopItemType type) {
    final itemsAsync = ref.watch(shopItemsByTypeProvider(type));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(context, '该分类暂无商品');
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return ShopItemCard(item: items[index]);
          },
        );
      },
      loading: () => _buildLoadingGrid(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  /// 加载状态
  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppColors.surfaceVariant,
          highlightColor: AppColors.surface,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  /// 错误状态
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ],
      ),
    );
  }
}

/// 商店商品卡片
class ShopItemCard extends ConsumerWidget {
  final ShopItemModel item;

  const ShopItemCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPointsAsync = ref.watch(userGameDataProvider);
    final canAfford = userPointsAsync.when(
      data: (data) => data.points >= item.cost,
      loading: () => false,
      error: (_, __) => false,
    );

    return GestureDetector(
      onTap: () => _showItemDetail(context, ref, canAfford),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canAfford
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.dividerColor.withOpacity(0.5),
            width: canAfford ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图标
            Expanded(
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: _getItemGradient(item.type),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: Icon(
                    _getItemIcon(item.type),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 商品名称
            Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // 商品描述
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 价格
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      size: 14,
                      color: canAfford ? AppColors.accent : AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.cost}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: canAfford ? AppColors.accent : AppColors.textHint,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                // 类型标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getItemColor(item.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.type.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getItemColor(item.type),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示商品详情
  void _showItemDetail(BuildContext context, WidgetRef ref, bool canAfford) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xxlRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 商品图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: _getItemGradient(item.type),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getItemIcon(item.type),
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // 商品名称
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 类型标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: _getItemColor(item.type).withOpacity(0.1),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Text(
                  item.type.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getItemColor(item.type),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // 描述
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              // 价格
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stars,
                    size: 24,
                    color: canAfford ? AppColors.accent : AppColors.textHint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.cost} 积分',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: canAfford ? AppColors.accent : AppColors.textHint,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // 购买按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canAfford ? () => _purchaseItem(context, ref) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? AppColors.primary : AppColors.textHint,
                    disabledBackgroundColor: AppColors.surfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                  ),
                  child: Text(
                    canAfford ? '购买' : '积分不足',
                    style: TextStyle(
                      color: canAfford ? Colors.white : AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 购买物品
  Future<void> _purchaseItem(BuildContext context, WidgetRef ref) async {
    final shopService = ref.read(shopServiceProvider);
    final (success, error) = await shopService.purchaseItem(item.id);

    if (context.mounted) {
      Navigator.of(context).pop(); // 关闭详情弹窗

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('购买成功！获得 ${item.name}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? '购买失败'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 获取商品图标
  IconData _getItemIcon(ShopItemType type) {
    switch (type) {
      case ShopItemType.theme:
        return Icons.palette;
      case ShopItemType.title:
        return Icons.military_tech;
      case ShopItemType.icon:
        return Icons.emoji_emotions;
      case ShopItemType.badge:
        return Icons.verified;
    }
  }

  /// 获取商品颜色
  Color _getItemColor(ShopItemType type) {
    switch (type) {
      case ShopItemType.theme:
        return const Color(0xFF8B5CF6);
      case ShopItemType.title:
        return const Color(0xFFFFD700);
      case ShopItemType.icon:
        return const Color(0xFF3B82F6);
      case ShopItemType.badge:
        return const Color(0xFF22C55E);
    }
  }

  /// 获取商品渐变
  LinearGradient _getItemGradient(ShopItemType type) {
    final color = _getItemColor(type);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color,
        color.withOpacity(0.7),
      ],
    );
  }
}
