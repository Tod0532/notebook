/// 运动数据统计页面 - 增强版
/// 包含图表可视化功能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/workout/presentation/widgets/workout_bar_chart.dart';
import 'package:thick_notepad/features/workout/presentation/widgets/workout_line_chart.dart';
import 'package:thick_notepad/features/workout/presentation/widgets/workout_pie_chart.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';

/// 运动统计页面
class WorkoutStatsPage extends ConsumerStatefulWidget {
  const WorkoutStatsPage({super.key});

  @override
  ConsumerState<WorkoutStatsPage> createState() => _WorkoutStatsPageState();
}

class _WorkoutStatsPageState extends ConsumerState<WorkoutStatsPage>
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

  /// 显示数据详情对话框
  void _showDataDetail(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.smRadius,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeRange = ref.watch(chartTimeRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运动统计'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // 时间范围选择器
          _buildTimeRangeSelector(timeRange),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '趋势'),
            Tab(text: '分析'),
          ],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(timeRange),
          _buildTrendTab(timeRange),
          _buildAnalysisTab(timeRange),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(ChartTimeRange timeRange) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.smRadius,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ChartTimeRange>(
            value: timeRange,
            dropdownColor: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.mdRadius,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            items: ChartTimeRange.values.map((range) {
              return DropdownMenuItem(
                value: range,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getRangeIcon(range), size: 18),
                    const SizedBox(width: 6),
                    Text(range.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: (range) {
              if (range != null) {
                ref.read(chartTimeRangeProvider.notifier).setRange(range);
              }
            },
          ),
        ),
      ),
    );
  }

  IconData _getRangeIcon(ChartTimeRange range) {
    switch (range) {
      case ChartTimeRange.week:
        return Icons.calendar_view_week;
      case ChartTimeRange.month:
        return Icons.calendar_view_month;
      case ChartTimeRange.quarter:
        return Icons.date_range;
      case ChartTimeRange.year:
        return Icons.event;
    }
  }

  /// 概览标签页
  Widget _buildOverviewTab(ChartTimeRange timeRange) {
    final days = timeRange.days;
    final dailyStatsAsync = ref.watch(dailyStatsProvider(days));
    final typeDistAsync = ref.watch(typeDistributionProvider(days));
    final weekStatsAsync = ref.watch(thisWeekStatsProvider);
    final streakAsync = ref.watch(workoutStreakProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 快速统计卡片
          streakAsync.when(
            data: (streak) => weekStatsAsync.when(
              data: (stats) => _QuickStatsCards(
                streak: streak,
                weekCount: stats['count'] as int? ?? 0,
                weekMinutes: stats['totalMinutes'] as int? ?? 0,
              ),
              loading: () => const _QuickStatsSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const _QuickStatsSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 每日运动柱状图
          dailyStatsAsync.when(
            data: (stats) => WorkoutBarChart(
              data: stats,
              title: '每日运动时长',
              subtitle: '最近${timeRange.displayName}的运动记录',
            ),
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 运动类型分布饼图
          typeDistAsync.when(
            data: (dist) => WorkoutDonutChart(
              data: dist,
              title: '运动类型分布',
            ),
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
        ],
      ),
    );
  }

  /// 趋势标签页
  Widget _buildTrendTab(ChartTimeRange timeRange) {
    final days = timeRange.days;
    final trendDataAsync = ref.watch(trendDataProvider(days));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 趋势折线图
          trendDataAsync.when(
            data: (data) => WorkoutLineChart(
              data: data,
              title: '运动趋势',
              subtitle: '最近${timeRange.displayName}的运动时长变化',
              showArea: true,
            ),
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 趋势统计
          trendDataAsync.when(
            data: (data) {
              if (data.isEmpty) return const SizedBox.shrink();

              final totalMinutes = data.fold<int>(0, (sum, p) => sum + p.minutes);
              final avgMinutes = totalMinutes ~/ data.length;
              final maxMinutes = data.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b);
              final maxDay = data.firstWhere((p) => p.minutes == maxMinutes, orElse: () => data.first);

              return _TrendStatsCard(
                totalMinutes: totalMinutes,
                avgMinutes: avgMinutes,
                maxMinutes: maxMinutes,
                maxDay: maxDay.date,
              );
            },
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
        ],
      ),
    );
  }

  /// 分析标签页
  Widget _buildAnalysisTab(ChartTimeRange timeRange) {
    final days = timeRange.days;
    final typeDistAsync = ref.watch(typeDistributionProvider(days));
    final dailyStatsAsync = ref.watch(dailyStatsProvider(days));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 按类型柱状图
          typeDistAsync.when(
            data: (dist) => WorkoutTypeBarChart(
              data: dist.take(8).toList(), // 只显示前8个
              title: '运动类型时长排行',
            ),
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 运动分类饼图
          dailyStatsAsync.when(
            data: (stats) {
              // 按分类统计
              final categoryMinutes = <String, int>{};
              for (final stat in stats) {
                for (final entry in stat.minutesByType.entries) {
                  final workoutType = WorkoutType.fromString(entry.key);
                  final category = workoutType?.category ?? 'other';
                  categoryMinutes[category] = (categoryMinutes[category] ?? 0) + entry.value;
                }
              }

              final categoryNames = {
                'cardio': '有氧运动',
                'strength': '力量训练',
                'sports': '球类运动',
                'other': '其他运动',
              };

              return WorkoutCategoryPieChart(
                minutesByCategory: categoryMinutes,
                categoryNames: categoryNames,
                title: '运动分类占比',
              );
            },
            loading: () => _buildChartSkeleton(),
            error: (_, __) => _buildChartError(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          // 标题骨架
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: AppRadius.smRadius,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 100,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: AppRadius.smRadius,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 图表骨架
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartError({VoidCallback? onRetry}) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '数据加载失败',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '请检查网络连接或稍后重试',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 快速统计卡片
class _QuickStatsCards extends StatelessWidget {
  final int streak;
  final int weekCount;
  final int weekMinutes;

  const _QuickStatsCards({
    required this.streak,
    required this.weekCount,
    required this.weekMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '连续运动',
            value: '$streak',
            unit: '天',
            icon: Icons.local_fire_department,
            gradient: AppColors.errorGradient,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            title: '本周运动',
            value: '$weekCount',
            unit: '次',
            icon: Icons.fitness_center,
            gradient: AppColors.primaryGradient,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            title: '本周时长',
            value: '${weekMinutes ~/ 60}',
            unit: '小时',
            icon: Icons.timer_outlined,
            gradient: AppColors.successGradient,
          ),
        ),
      ],
    );
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 快速统计骨架屏
class _QuickStatsSkeleton extends StatelessWidget {
  const _QuickStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: Container(
            height: 80,
            margin: EdgeInsets.only(
              right: index < 2 ? AppSpacing.md : 0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.lgRadius,
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ),
    );
  }
}

/// 趋势统计卡片
class _TrendStatsCard extends StatelessWidget {
  final int totalMinutes;
  final int avgMinutes;
  final int maxMinutes;
  final DateTime maxDay;

  const _TrendStatsCard({
    required this.totalMinutes,
    required this.avgMinutes,
    required this.maxMinutes,
    required this.maxDay,
  });

  @override
  Widget build(BuildContext context) {
    final totalHours = totalMinutes / 60;
    final avgDisplay = avgMinutes >= 60
        ? '${(avgMinutes / 60).toStringAsFixed(1)}小时'
        : '$avgMinutes分钟';
    final maxDisplay = maxMinutes >= 60
        ? '${(maxMinutes / 60).toStringAsFixed(1)}小时'
        : '$maxMinutes分钟';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.5),
        ),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '趋势分析',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatRow(
            label: '累计时长',
            value: '${totalHours.toStringAsFixed(1)}小时',
            icon: Icons.timer_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(
            label: '平均每日',
            value: avgDisplay,
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(
            label: '单日最高',
            value: maxDisplay,
            icon: Icons.emoji_events,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: AppRadius.smRadius,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}
