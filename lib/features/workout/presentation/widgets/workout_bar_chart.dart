/// 运动柱状图组件
/// 使用 fl_chart 展示每日/每周运动时长

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';

/// 运动柱状图
class WorkoutBarChart extends StatelessWidget {
  final List<DailyWorkoutStats> data;
  final String title;
  final String? subtitle;

  const WorkoutBarChart({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 找出最大值用于 Y 轴缩放
    final maxValue = data.map((e) => e.totalMinutes).fold<int>(0, (a, b) => a > b ? a : b);
    final yMax = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 60;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: isDark
              ? AppColors.dividerColorDark.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.5),
        ),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
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
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // 图表
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: yMax.toDouble(),
                minY: 0,
                groupsSpace: 12,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.9),
                    tooltipPadding: const EdgeInsets.all(AppSpacing.sm),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final stat = data[group.x.toInt()];
                      if (stat == null) return null;

                      final hours = stat.totalMinutes ~/ 60;
                      final minutes = stat.totalMinutes % 60;
                      final duration = hours > 0
                          ? '$hours小时$minutes分钟'
                          : '$stat.totalMinutes分钟';

                      return BarTooltipItem(
                        '${stat.weekdayText}\n',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: duration,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox.shrink();

                        // 根据数据点数量决定显示密度
                        final showEvery = data.length > 14 ? 3 : (data.length > 7 ? 2 : 1);
                        if (index % showEvery != 0) return const SizedBox.shrink();

                        return _buildBottomTitle(data[index]);
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) return const SizedBox.shrink();

                        final hours = value ~/ 60;
                        final minutes = value % 60;

                        return Text(
                          hours > 0 ? '${hours}h' : '${value.toInt()}m',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? AppColors.dividerColorDark.withOpacity(0.2)
                          : AppColors.dividerColor.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarGroups(yMax.toDouble()),
              ),
            ),
          ),

          // 图例
          const SizedBox(height: AppSpacing.md),
          _buildLegend(context),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(double yMax) {
    return List.generate(data.length, (index) {
      final stat = data[index];
      final value = stat.totalMinutes.toDouble();

      // 根据运动类型选择颜色
      final primaryType = stat.minutesByType.keys.isNotEmpty
          ? stat.minutesByType.keys.first
          : 'other';

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                WorkoutCategoryColors.getColorByType(primaryType).withOpacity(0.7),
                WorkoutCategoryColors.getColorByType(primaryType),
              ],
            ),
            width: data.length > 14 ? 8 : 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBottomTitle(DailyWorkoutStats stat) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        stat.weekdayText,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textHint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    // 汇总各类型运动时长
    final typeSummary = <String, int>{};
    for (final stat in data) {
      for (final entry in stat.minutesByType.entries) {
        typeSummary[entry.key] = (typeSummary[entry.key] ?? 0) + entry.value;
      }
    }

    // 按时长排序，取前4
    final sortedTypes = typeSummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = sortedTypes.take(4).toList();

    if (topTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: topTypes.map((entry) {
        final workoutType = WorkoutType.fromString(entry.key);
        final displayName = workoutType?.displayName ?? entry.key;
        final color = WorkoutCategoryColors.getColorByType(entry.key);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: AppRadius.smRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// 按运动类型分组的柱状图
class WorkoutTypeBarChart extends StatelessWidget {
  final List<WorkoutTypeDistribution> data;
  final String title;

  const WorkoutTypeBarChart({
    super.key,
    required this.data,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    final maxValue = data.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b);
    final yMax = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 60;
    final totalMinutes = data.fold<int>(0, (sum, d) => sum + d.minutes);

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
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: AppColors.secondaryGradient,
                  borderRadius: AppRadius.smRadius,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 横向柱状图
          SizedBox(
            height: data.length * 50.0,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: yMax.toDouble(),
                minY: 0,
                barGroups: _buildHorizontalBarGroups(yMax.toDouble()),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 80,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox.shrink();

                        return SizedBox(
                          width: 75,
                          child: Text(
                            data[index].displayName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max) return const SizedBox.shrink();

                        final hours = value ~/ 60;
                        final minutes = value % 60;

                        return Text(
                          hours > 0 ? '${hours}h${minutes}m' : '${value.toInt()}m',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.9),
                    tooltipPadding: const EdgeInsets.all(AppSpacing.sm),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dist = data[group.x.toInt()];
                      if (dist == null) return null;

                      final hours = dist.minutes ~/ 60;
                      final minutes = dist.minutes % 60;
                      final percentage = totalMinutes > 0
                          ? (dist.minutes / totalMinutes * 100).toStringAsFixed(1)
                          : '0.0';

                      return BarTooltipItem(
                        '${dist.displayName}\n',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: '${hours}h${minutes}m ($percentage%)\n',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${dist.count}次',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildHorizontalBarGroups(double yMax) {
    return List.generate(data.length, (index) {
      final dist = data[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dist.minutes.toDouble(),
            color: dist.color,
            width: 16,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '暂无数据',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
