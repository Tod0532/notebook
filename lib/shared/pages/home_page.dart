/// 首页 - 带底部导航的主框架 (Bento Grid 风格)
/// 使用 ShellRoute 结构，底部导航栏始终可见

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/shared/widgets/recent_activities.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';

/// 底部导航项配置
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

/// 底部导航配置
const List<_NavItem> _navItems = [
  _NavItem(
    label: '首页',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    route: AppRoutes.home,
  ),
  _NavItem(
    label: '笔记',
    icon: Icons.edit_note_outlined,
    activeIcon: Icons.edit_note,
    route: AppRoutes.notes,
  ),
  _NavItem(
    label: '运动',
    icon: Icons.fitness_center_outlined,
    activeIcon: Icons.fitness_center,
    route: AppRoutes.workout,
  ),
  _NavItem(
    label: '计划',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: AppRoutes.plans,
  ),
];

/// 主页框架 - ShellRoute 的 builder
class HomePage extends StatelessWidget {
  final Widget child;

  const HomePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _getCurrentIndex(location);

    // 如果是编辑页或设置页，不显示底部导航
    if (_hideNavBar(location)) {
      return Scaffold(
        body: child,
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNavBar(context, currentIndex, location),
    );
  }

  int _getCurrentIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].route || location.startsWith(_navItems[i].route + '/')) {
        return i;
      }
    }
    return 0;
  }

  bool _hideNavBar(String location) {
    // 编辑页、设置页等隐藏底部导航
    return location.contains('/new') ||
           location.contains('/settings') ||
           location.contains('/:');
  }

  Widget _buildBottomNavBar(BuildContext context, int currentIndex, String location) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: _navItems.map((item) {
          final index = _navItems.indexOf(item);
          final isActive = currentIndex == index;
          return BottomNavigationBarItem(
            icon: _buildNavIcon(item.icon, item.activeIcon, isActive),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, IconData activeIcon, bool isActive) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        isActive ? activeIcon : icon,
        key: ValueKey(isActive),
        size: 24,
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    final item = _navItems[index];
    context.go(item.route);
  }
}

// ==================== 各模块视图（无 Scaffold） ====================

/// 首页仪表盘视图 (Bento Grid 风格)
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingHeader(context).slideIn(delay: DelayDuration.none),
            const SizedBox(height: AppSpacing.md),
            _buildAIGreeting(context).slideIn(delay: DelayDuration.short),
            const SizedBox(height: AppSpacing.lg),
            _buildBentoGrid(context).slideIn(delay: DelayDuration.short),
            const SizedBox(height: AppSpacing.lg),
            _buildTodaySummary(context).slideIn(delay: DelayDuration.medium),
            const SizedBox(height: AppSpacing.lg),
            _buildRecentActivity(context).slideIn(delay: DelayDuration.long),
          ],
        ),
      ),
    );
  }

  /// 问候语头部 - 更大更醒目
  Widget _buildGreetingHeader(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;
    Color iconColor;

    if (hour < 6) {
      greeting = '夜深了';
      icon = Icons.nights_stay;
      iconColor = AppColors.primary;
    } else if (hour < 12) {
      greeting = '早上好';
      icon = Icons.wb_sunny_outlined;
      iconColor = Colors.orange;
    } else if (hour < 14) {
      greeting = '中午好';
      icon = Icons.wb_twilight;
      iconColor = Colors.deepOrange;
    } else if (hour < 18) {
      greeting = '下午好';
      icon = Icons.wb_sunny;
      iconColor = Colors.orangeAccent;
    } else {
      greeting = '晚上好';
      icon = Icons.bedtime_outlined;
      iconColor = AppColors.primary;
    }

    return Row(
      children: [
        // 大头像图标
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity( 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting，老大',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '今天也是充满活力的一天！',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
        // 设置按钮
        ModernCard(
          onTap: () => context.push(AppRoutes.settings),
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: Icon(
              Icons.settings_outlined,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  /// AI 教练入口卡片
  Widget _buildAIGreeting(BuildContext context) {
    return ModernCard(
      onTap: () => context.push(AppRoutes.userProfileSetup),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.secondary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 教练', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.secondary)),
                const SizedBox(height: 2),
                Text('创建专属训练和饮食计划', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }

  /// 获取 AI 问候语（带超时，避免卡顿）
  Future<String> _getAIGreeting() async {
    try {
      final aiService = DeepSeekService.instance;
      await aiService.init().timeout(const Duration(seconds: 2));

      if (!aiService.isConfigured) {
        return '点击配置 DeepSeek API Key';
      }

      final todayTasks = <String>[];
      final greeting = await aiService.generateMorningGreeting(
        todayTasks: todayTasks,
        userName: '老大',
      ).timeout(const Duration(seconds: 5));

      return greeting;
    } catch (e) {
      return '创建专属训练和饮食计划';
    }
  }

  /// 旧版AI问候（已禁用）
  Widget _buildAIGreetingOld(BuildContext context) {
    return FutureBuilder<String>(
      future: _getAIGreeting(),
      builder: (context, snapshot) {
        return ModernCard(
          onTap: () => context.push(AppRoutes.aiSettings),
          padding: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary.withOpacity( 0.08),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              // AI 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 问候内容
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 助手',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.hasData
                          ? snapshot.data!
                          : '配置 API Key 启用 AI 功能',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 箭头图标
              Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bento Grid 风格快捷操作 - 2x2 网格布局
  Widget _buildBentoGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '快捷操作',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
            ),
            const Spacer(),
            Text(
              '查看全部',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Bento Grid 布局 - 使用固定高度避免溢出
        SizedBox(
          height: 140,
          child: Row(
            children: [
            // 左侧：大卡片（记笔记）
            Expanded(
              flex: 3,
              child: _BentoLargeCard(
                icon: Icons.edit_note_rounded,
                label: '记笔记',
                subtitle: '记录想法',
                gradient: AppColors.primaryGradient,
                onTap: () => context.go(AppRoutes.notes),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // 右侧：两个小卡片
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: _BentoSmallCard(
                      icon: Icons.fitness_center_rounded,
                      label: '记运动',
                      gradient: AppColors.secondaryGradient,
                      onTap: () => context.push(AppRoutes.workoutEdit),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: _BentoSmallCard(
                      icon: Icons.task_alt_rounded,
                      label: '新计划',
                      gradient: AppColors.warningGradient,
                      onTap: () => context.go(AppRoutes.plans),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ],
    );
  }

  Widget _buildTodaySummary(BuildContext context) {
    return _TodaySummarySection();
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近动态',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
            ),
            const Spacer(),
            Icon(
              Icons.timeline_outlined,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const RecentActivitiesList(),
      ],
    );
  }
}

// ==================== Bento Grid 卡片组件 ====================

/// Bento 大卡片 - 占据左侧大部分空间
class _BentoLargeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _BentoLargeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 使用 Expanded 填满可用高度，避免溢出
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity( 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity( 0.85),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bento 小卡片 - 右侧两个小卡片
class _BentoSmallCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _BentoSmallCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity( 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 今日概览数据组件 ====================

/// 今日概览数据区域 (Bento 风格)
class _TodaySummarySection extends ConsumerWidget {
  const _TodaySummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStatsAsync = ref.watch(taskStatsProvider);
    final weekStatsAsync = ref.watch(thisWeekStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日概览',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _TaskSummaryCard(
                taskStatsAsync: taskStatsAsync,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _WorkoutSummaryCard(
                weekStatsAsync: weekStatsAsync,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 任务完成统计卡片 (渐变风格)
class _TaskSummaryCard extends ConsumerWidget {
  final AsyncValue<Map<String, dynamic>> taskStatsAsync;

  const _TaskSummaryCard({required this.taskStatsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return taskStatsAsync.when(
      data: (stats) {
        final completed = stats['todayCompleted'] as int? ?? 0;
        final total = stats['todayTotal'] as int? ?? 0;
        final remaining = stats['todayRemaining'] as int? ?? 0;

        return _GradientStatCard(
          gradient: AppColors.successGradient,
          icon: Icons.check_circle_rounded,
          label: '完成任务',
          value: '$completed/$total',
          subtitle: remaining > 0 ? '还剩$remaining项' : '全部完成',
          isEmpty: total == 0,
        );
      },
      loading: () => const _GradientStatCard(
        gradient: AppColors.successGradient,
        icon: Icons.check_circle_rounded,
        label: '完成任务',
        value: '-',
        isEmpty: true,
      ),
      error: (_, __) => _GradientStatCard(
        gradient: AppColors.errorGradient,
        icon: Icons.error_outline,
        label: '完成任务',
        value: '-',
        isEmpty: true,
      ),
    );
  }
}

/// 运动时长统计卡片 (渐变风格)
class _WorkoutSummaryCard extends ConsumerWidget {
  final AsyncValue<Map<String, dynamic>> weekStatsAsync;

  const _WorkoutSummaryCard({required this.weekStatsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return weekStatsAsync.when(
      data: (stats) {
        final totalMinutes = stats['totalMinutes'] as int? ?? 0;
        final count = stats['count'] as int? ?? 0;

        // 计算今日运动时长（近似值：本周平均/天数）
        final todayMinutes = totalMinutes > 0
            ? (totalMinutes / (stats['uniqueDays'] as int? ?? 1)).round()
            : 0;

        return _GradientStatCard(
          gradient: AppColors.secondaryGradient,
          icon: Icons.timer_rounded,
          label: '运动时长',
          value: '${todayMinutes}分钟',
          subtitle: count > 0 ? '本周$count次运动' : '本周暂无运动',
          isEmpty: totalMinutes == 0,
        );
      },
      loading: () => const _GradientStatCard(
        gradient: AppColors.secondaryGradient,
        icon: Icons.timer_rounded,
        label: '运动时长',
        value: '-',
        isEmpty: true,
      ),
      error: (_, __) => _GradientStatCard(
        gradient: AppColors.errorGradient,
        icon: Icons.error_outline,
        label: '运动时长',
        value: '-',
        isEmpty: true,
      ),
    );
  }
}

/// 渐变统计卡片 - 统一风格（更立体的设计）
class _GradientStatCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool isEmpty;

  const _GradientStatCard({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: isEmpty ? null : gradient,
        color: isEmpty ? AppColors.surfaceVariant : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isEmpty
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: gradient.colors.first.withOpacity( 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: gradient.colors.first.withOpacity( 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? AppColors.textHint.withOpacity( 0.15)
                          : Colors.white.withOpacity( 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isEmpty ? AppColors.textHint : Colors.white,
                      size: 18,
                    ),
                  ),
                  if (!isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '今天',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                      ),
                    ),
                ],
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isEmpty ? AppColors.textHint : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isEmpty
                          ? AppColors.textHint.withOpacity( 0.7)
                          : Colors.white.withOpacity( 0.85),
                      fontSize: 10,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEmpty
                            ? AppColors.textHint
                            : Colors.white.withOpacity( 0.7),
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
