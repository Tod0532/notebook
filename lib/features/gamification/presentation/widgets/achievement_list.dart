/// 成就列表组件
/// 显示成就列表及其解锁状态

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:shimmer/shimmer.dart';

/// 成就列表视图
class AchievementListView extends ConsumerStatefulWidget {
  const AchievementListView({super.key});

  @override
  ConsumerState<AchievementListView> createState() => _AchievementListViewState();
}

class _AchievementListViewState extends ConsumerState<AchievementListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AchievementCategory? _selectedCategory;
  AchievementTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 分类标签栏
        _buildCategoryTabs(),
        const SizedBox(height: AppSpacing.md),
        // 稀有度筛选
        _buildTierFilter(),
        const SizedBox(height: AppSpacing.md),
        // 成就列表
        Expanded(
          child: _buildAchievementList(),
        ),
      ],
    );
  }

  /// 分类标签栏
  Widget _buildCategoryTabs() {
    final categories = [
      (null, '全部'),
      (AchievementCategory.workout, '运动'),
      (AchievementCategory.streak, '连续'),
      (AchievementCategory.milestone, '里程碑'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _selectedCategory = categories[index].$1;
          });
        },
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: categories
            .map((cat) => Tab(text: cat.$2))
            .toList(),
      ),
    );
  }

  /// 稀有度筛选
  Widget _buildTierFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _buildTierChip(null, '全部'),
          _buildTierChip(AchievementTier.bronze, '青铜'),
          _buildTierChip(AchievementTier.silver, '白银'),
          _buildTierChip(AchievementTier.gold, '黄金'),
          _buildTierChip(AchievementTier.diamond, '钻石'),
          _buildTierChip(AchievementTier.legendary, '传说'),
        ],
      ),
    );
  }

  Widget _buildTierChip(AchievementTier? tier, String label) {
    final isSelected = _selectedTier == tier;
    Color chipColor;
    Color textColor;

    if (tier == null) {
      chipColor = AppColors.surfaceVariant;
      textColor = AppColors.textSecondary;
    } else {
      chipColor = Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.2);
      textColor = Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF')));
    }

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedTier = selected ? tier : null;
          });
        },
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: chipColor,
        checkmarkColor: textColor,
        labelStyle: TextStyle(
          color: isSelected ? textColor : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? textColor : Colors.transparent,
            width: 1,
          ),
        ),
      ),
    );
  }

  /// 成就列表
  Widget _buildAchievementList() {
    if (_selectedCategory == null && _selectedTier == null) {
      return _buildAllAchievements();
    } else if (_selectedCategory != null && _selectedTier != null) {
      // 需要双重筛选
      return _buildFilteredAchievements();
    } else if (_selectedCategory != null) {
      return _buildCategoryAchievements();
    } else {
      return _buildTierAchievements();
    }
  }

  /// 所有成就
  Widget _buildAllAchievements() {
    final achievementsAsync = ref.watch(allAchievementsProvider);

    return achievementsAsync.when(
      data: (achievements) {
        if (achievements.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return AchievementTile(achievement: achievements[index]);
          },
        );
      },
      loading: () => _buildLoadingList(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 按分类筛选的成就
  Widget _buildCategoryAchievements() {
    final achievementsAsync = ref.watch(
      achievementsByCategoryProvider(_selectedCategory!),
    );

    return achievementsAsync.when(
      data: (achievements) {
        if (achievements.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return AchievementTile(achievement: achievements[index]);
          },
        );
      },
      loading: () => _buildLoadingList(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 按稀有度筛选的成就
  Widget _buildTierAchievements() {
    final achievementsAsync = ref.watch(
      achievementsByTierProvider(_selectedTier!),
    );

    return achievementsAsync.when(
      data: (achievements) {
        if (achievements.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return AchievementTile(achievement: achievements[index]);
          },
        );
      },
      loading: () => _buildLoadingList(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 双重筛选的成就
  Widget _buildFilteredAchievements() {
    final allAsync = ref.watch(allAchievementsProvider);

    return allAsync.when(
      data: (all) {
        final filtered = all
            .where((a) =>
                a.achievement.category == _selectedCategory &&
                a.achievement.tier == _selectedTier)
            .toList();

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return AchievementTile(achievement: filtered[index]);
          },
        );
      },
      loading: () => _buildLoadingList(),
      error: (_, __) => _buildErrorState(),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '暂无成就',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '开始运动、记录笔记来解锁成就吧！',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  /// 加载状态
  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppColors.surfaceVariant,
          highlightColor: AppColors.surface,
          child: Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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

/// 成就卡片
class AchievementTile extends StatelessWidget {
  final AchievementProgress achievement;

  const AchievementTile({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final tier = achievement.achievement.tier;
    final tierColor = Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () => _showAchievementDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUnlocked ? tierColor.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? tierColor.withOpacity(0.3) : AppColors.dividerColor.withOpacity(0.5),
            width: isUnlocked ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 图标
            _buildIcon(context, tierColor, isUnlocked),
            const SizedBox(width: AppSpacing.md),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称和稀有度
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.achievement.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isUnlocked ? tierColor : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      // 稀有度标签
                      _buildTierBadge(tier),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // 描述
                  Text(
                    achievement.achievement.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 进度条
                  if (!isUnlocked) _buildProgressBar(context),
                  if (isUnlocked)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: tierColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '已解锁',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tierColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                        ),
                        const Spacer(),
                        // 奖励信息
                        _buildRewards(context, tierColor),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 图标
  Widget _buildIcon(BuildContext context, Color tierColor, bool isUnlocked) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isUnlocked ? tierColor.withOpacity(0.15) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getIconData(achievement.achievement.icon),
        color: isUnlocked ? tierColor : AppColors.textHint,
        size: 24,
      ),
    );
  }

  /// 稀有度徽章
  Widget _buildTierBadge(AchievementTier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        tier.displayName,
        style: TextStyle(
          color: Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF'))),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 进度条
  Widget _buildProgressBar(BuildContext context) {
    final progress = achievement.progressPercent;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
            ),
            Text(
              '${achievement.currentProgress}/${achievement.achievement.requirement}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 奖励信息
  Widget _buildRewards(BuildContext context, Color tierColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (achievement.achievement.expReward > 0) ...[
          Icon(
            Icons.explore,
            size: 12,
            color: tierColor,
          ),
          const SizedBox(width: 2),
          Text(
            '+${achievement.achievement.expReward}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tierColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        if (achievement.achievement.pointsReward > 0) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.stars,
            size: 12,
            color: AppColors.accent,
          ),
          const SizedBox(width: 2),
          Text(
            '+${achievement.achievement.pointsReward}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

  /// 显示成就详情
  void _showAchievementDetail(BuildContext context) {
    final tier = achievement.achievement.tier;
    final tierColor = Color(int.parse(tier.colorHex.replaceFirst('#', '0xFF')));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: achievement.isUnlocked
                      ? tierColor.withOpacity(0.15)
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(achievement.achievement.icon),
                  color: achievement.isUnlocked ? tierColor : AppColors.textHint,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // 名称
              Text(
                achievement.achievement.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: achievement.isUnlocked ? tierColor : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 稀有度
              _buildTierBadge(tier),
              const SizedBox(height: AppSpacing.md),
              // 描述
              Text(
                achievement.achievement.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              if (!achievement.isUnlocked) ...[
                const SizedBox(height: AppSpacing.lg),
                // 进度
                Text(
                  '进度: ${achievement.currentProgress}/${achievement.achievement.requirement}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: achievement.progressPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              // 奖励
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRewardChip(
                    context,
                    Icons.explore,
                    'EXP',
                    achievement.achievement.expReward,
                    tierColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildRewardChip(
                    context,
                    Icons.stars,
                    '积分',
                    achievement.achievement.pointsReward,
                    AppColors.accent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardChip(
    BuildContext context,
    IconData icon,
    String label,
    int value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '+$value $label',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // 根据图标名称返回对应的 IconData
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'directions_run':
        return Icons.directions_run;
      case 'military_tech':
        return Icons.military_tech;
      case 'timer':
        return Icons.timer;
      case 'schedule':
        return Icons.schedule;
      case 'access_time':
        return Icons.access_time;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'flare':
        return Icons.flare;
      case 'stars':
        return Icons.stars;
      case 'grade':
        return Icons.grade;
      case 'edit_note':
        return Icons.edit_note;
      case 'note':
        return Icons.note;
      case 'description':
        return Icons.description;
      case 'menu_book':
        return Icons.menu_book;
      case 'event_note':
        return Icons.event_note;
      case 'check_circle':
        return Icons.check_circle;
      case 'task_alt':
        return Icons.task_alt;
      case 'fact_check':
        return Icons.fact_check;
      case 'trending_up':
        return Icons.trending_up;
      case 'showchart':
        return Icons.show_chart;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'diamond':
        return Icons.diamond;
      case 'paid':
        return Icons.paid;
      case 'account_balance':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.military_tech;
    }
  }
}
