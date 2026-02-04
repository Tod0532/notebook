/// 等级进度卡片组件
/// 显示当前等级、经验条、升级进度

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';
import 'package:shimmer/shimmer.dart';

/// 等级进度卡片
class LevelProgressCard extends ConsumerWidget {
  const LevelProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameDataAsync = ref.watch(userGameDataProvider);

    return gameDataAsync.when(
      data: (gameData) => _buildCard(context, gameData),
      loading: () => _buildShimmer(context),
      error: (_, __) => _buildErrorCard(context),
    );
  }

  Widget _buildCard(BuildContext context, UserGameDataModel gameData) {
    final levelTitle = LevelConfig.getLevelTitle(gameData.level);
    final levelColor = LevelConfig.getLevelColor(gameData.level);
    final progress = gameData.levelProgress;
    final currentLevelExp = gameData.currentLevelExp;
    final nextLevelRequired = gameData.nextLevelRequiredExp;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：等级徽章和称号
          Row(
            children: [
              // 等级徽章
              _buildLevelBadge(gameData.level, levelColor),
              const SizedBox(width: AppSpacing.md),
              // 等级信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.$levelTitle ${gameData.level}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getLevelMotto(gameData.level),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              // 右上角图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.military_tech,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 经验进度条
          _buildProgressBar(context, progress, currentLevelExp, nextLevelRequired),

          const SizedBox(height: AppSpacing.sm),

          // 经验值文本
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '$currentLevelExp / $nextLevelRequired',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 等级徽章
  Widget _buildLevelBadge(int level, String colorHex) {
    // 根据等级区间选择徽章样式
    Widget badgeIcon;
    Color badgeColor;

    if (level < 10) {
      badgeIcon = const Icon(Icons.fitness_center, size: 28);
      badgeColor = const Color(0xFF94A3B8);
    } else if (level < 25) {
      badgeIcon = const Icon(Icons.emoji_events, size: 28);
      badgeColor = const Color(0xFF22C55E);
    } else if (level < 50) {
      badgeIcon = const Icon(Icons.stars, size: 28);
      badgeColor = const Color(0xFF3B82F6);
    } else if (level < 75) {
      badgeIcon = const Icon(Icons.workspace_premium, size: 28);
      badgeColor = const Color(0xFFFFD700);
    } else {
      badgeIcon = const Icon(Icons.diamond, size: 28);
      badgeColor = const Color(0xFFFF6B6B);
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: badgeIcon,
      ),
    );
  }

  /// 经验进度条
  Widget _buildProgressBar(BuildContext context, double progress, int currentExp, int requiredExp) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // 背景动画效果
            if (progress < 1.0)
              Positioned.fill(
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.3),
                  period: const Duration(milliseconds: 1500),
                  child: Container(),
                ),
              ),
            // 进度
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF0F0F0)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载骨架屏
  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 12,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  /// 错误状态卡片
  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '等级数据加载失败',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ],
      ),
    );
  }

  /// 获取等级格言
  String _getLevelMotto(int level) {
    if (level < 5) return '千里之行，始于足下';
    if (level < 10) return '持之以恒，必有收获';
    if (level < 20) return '不断突破，超越自我';
    if (level < 30) return '汗水浇灌，梦想绽放';
    if (level < 40) return '自律给我自由';
    if (level < 50) return '每一次坚持都是成长';
    if (level < 60) return '你就是自己的传奇';
    if (level < 70) return '无可阻挡的力量';
    if (level < 80) return '登峰造极，无人能敌';
    if (level < 90) return '永恒的荣耀';
    return '至高无上的王者';
  }
}

/// 紧凑型等级进度卡片（用于首页等空间有限的地方）
class CompactLevelCard extends ConsumerWidget {
  final bool showPoints;

  const CompactLevelCard({
    super.key,
    this.showPoints = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameDataAsync = ref.watch(userGameDataProvider);

    return gameDataAsync.when(
      data: (gameData) => _buildCompactCard(context, gameData),
      loading: () => _buildLoadingShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCompactCard(BuildContext context, UserGameDataModel gameData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 等级图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${gameData.level}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 等级信息
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LevelConfig.getLevelTitle(gameData.level),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore,
                    size: 10,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${gameData.currentLevelExp}/${gameData.nextLevelRequiredExp}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (showPoints) ...[
            const SizedBox(width: AppSpacing.md),
            Container(
              height: 20,
              width: 1,
              color: AppColors.dividerColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.stars,
              size: 14,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              '${gameData.points}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        width: 150,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
