/// 成就页面
/// 展示所有成就及其解锁进度

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:thick_notepad/features/gamification/presentation/widgets/achievement_list.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';

/// 成就页面
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(achievementStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部统计卡片
            _buildHeader(context, ref, statsAsync),
            // 成就列表
            const Expanded(
              child: AchievementListView(),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部统计头部
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AchievementStats? stats,
  ) {
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
                    borderRadius: BorderRadius.circular(12),
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
                  '成就系统',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 统计卡片
          if (stats != null)
            _buildStatsCard(context, stats)
          else
            _buildStatsLoading(context),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCard(BuildContext context, AchievementStats stats) {
    final unlockedCount = stats.unlocked;
    final totalCount = stats.total;
    final progress = stats.progress;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部：总数和解锁数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成就进度',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unlockedCount / $totalCount',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                  ),
                ],
              ),
              // 进度环形图
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 进度条
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 分类统计
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildStatChip(
                context,
                Icons.fitness_center,
                '运动',
                stats.categoryStats[AchievementCategory.workout] ?? 0,
                AchievementCategory.workout,
              ),
              _buildStatChip(
                context,
                Icons.local_fire_department,
                '连续',
                stats.categoryStats[AchievementCategory.streak] ?? 0,
                AchievementCategory.streak,
              ),
              _buildStatChip(
                context,
                Icons.edit_note,
                '笔记',
                stats.categoryStats[AchievementCategory.note] ?? 0,
                AchievementCategory.note,
              ),
              _buildStatChip(
                context,
                Icons.event_note,
                '计划',
                stats.categoryStats[AchievementCategory.plan] ?? 0,
                AchievementCategory.plan,
              ),
              _buildStatChip(
                context,
                Icons.workspace_premium,
                '里程碑',
                stats.categoryStats[AchievementCategory.milestone] ?? 0,
                AchievementCategory.milestone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 统计小标签
  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String label,
    int count,
    AchievementCategory category,
  ) {
    final categoryColor = _getCategoryColor(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$label $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  /// 加载状态
  Widget _buildStatsLoading(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 获取分类颜色
  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.workout:
        return const Color(0xFF4ECDC4);
      case AchievementCategory.streak:
        return const Color(0xFFFF6B6B);
      case AchievementCategory.note:
        return const Color(0xFF8B5CF6);
      case AchievementCategory.plan:
        return const Color(0xFFFBBF24);
      case AchievementCategory.social:
        return const Color(0xFF3B82F6);
      case AchievementCategory.milestone:
        return const Color(0xFFFFD700);
      case AchievementCategory.other:
        return const Color(0xFF94A3B8);
    }
  }
}
