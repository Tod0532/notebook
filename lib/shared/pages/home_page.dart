/// 首页 - 带底部导航的主框架 (现代渐变风格)
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
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

/// 首页仪表盘视图 (现代渐变风格)
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
            _buildGreeting(context).fadeIn(delay: DelayDuration.none),
            const SizedBox(height: AppSpacing.xxl),
            _buildQuickActions(context).fadeIn(delay: DelayDuration.short),
            const SizedBox(height: AppSpacing.lg),
            _buildTodaySummary(context).fadeIn(delay: DelayDuration.medium),
            const SizedBox(height: AppSpacing.lg),
            _buildRecentActivity(context).fadeIn(delay: DelayDuration.long),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;
    Gradient gradient;

    if (hour < 6) {
      greeting = '夜深了';
      icon = Icons.nights_stay;
      gradient = AppColors.infoGradient;
    } else if (hour < 12) {
      greeting = '早上好';
      icon = Icons.wb_sunny_outlined;
      gradient = AppColors.primaryGradient;
    } else if (hour < 14) {
      greeting = '中午好';
      icon = Icons.wb_twilight;
      gradient = AppColors.warningGradient;
    } else if (hour < 18) {
      greeting = '下午好';
      icon = Icons.wb_sunny;
      gradient = AppColors.secondaryGradient;
    } else {
      greeting = '晚上好';
      icon = Icons.bedtime_outlined;
      gradient = AppColors.infoGradient;
    }

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppRadius.xlRadius,
            boxShadow: AppShadows.light,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting，老大',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '今天也是充满活力的一天！',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        // 设置按钮
        InkWell(
          onTap: () => context.push(AppRoutes.settings),
          borderRadius: AppRadius.lgRadius,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadius.lgRadius,
              boxShadow: AppShadows.light,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GradientCard.primary(
            onTap: () => context.go(AppRoutes.notes),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: const Icon(
                    Icons.edit_note_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '记笔记',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GradientCard.secondary(
            onTap: () => context.push(AppRoutes.workoutEdit),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: const Icon(
                    Icons.fitness_center_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '记运动',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GradientCard(
            gradient: AppColors.warningGradient,
            onTap: () => context.go(AppRoutes.plans),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: const Icon(
                    Icons.add_task_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '新计划',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
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
        Text(
          '最近动态',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        const RecentActivitiesList(),
      ],
    );
  }
}

// ==================== 今日概览数据组件 ====================

/// 今日概览数据区域 (现代渐变风格)
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
                fontWeight: FontWeight.w700,
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
          icon: Icons.check_circle_outline,
          label: '完成任务',
          value: '$completed/$total',
          subtitle: remaining > 0 ? '还剩$remaining项' : '全部完成',
          isEmpty: total == 0,
        );
      },
      loading: () => const _GradientStatCard(
        gradient: AppColors.successGradient,
        icon: Icons.check_circle_outline,
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
          icon: Icons.timer_outlined,
          label: '运动时长',
          value: '${todayMinutes}分钟',
          subtitle: count > 0 ? '本周$count次运动' : '本周暂无运动',
          isEmpty: totalMinutes == 0,
        );
      },
      loading: () => const _GradientStatCard(
        gradient: AppColors.secondaryGradient,
        icon: Icons.timer_outlined,
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

/// 渐变统计卡片 - 统一风格
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
      decoration: BoxDecoration(
        gradient: isEmpty ? null : gradient,
        color: isEmpty ? AppColors.surfaceVariant : null,
        borderRadius: AppRadius.xlRadius,
        boxShadow: isEmpty ? AppShadows.subtle : AppShadows.light,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xlRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? AppColors.textHint.withOpacity(0.2)
                          : Colors.white.withOpacity(0.25),
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Icon(
                      icon,
                      color: isEmpty ? AppColors.textHint : Colors.white,
                      size: 22,
                    ),
                  ),
                  if (!isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Text(
                        '今天',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isEmpty ? AppColors.textHint : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isEmpty
                          ? AppColors.textHint.withOpacity(0.8)
                          : Colors.white.withOpacity(0.9),
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEmpty
                            ? AppColors.textHint
                            : Colors.white.withOpacity(0.7),
                        fontSize: 10,
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
