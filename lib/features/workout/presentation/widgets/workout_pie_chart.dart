/// 运动饼图组件
/// 使用 fl_chart 展示运动类型分布

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';

/// 运动类型分布饼图
class WorkoutPieChart extends StatelessWidget {
  final List<WorkoutTypeDistribution> data;
  final String title;
  final String? subtitle;

  const WorkoutPieChart({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    final totalMinutes = data.fold<int>(0, (sum, d) => sum + d.minutes);
    final totalCount = data.fold<int>(0, (sum, d) => sum + d.count);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                  ],
                ),
              ),
              // 总计
              _buildTotalChip(totalCount, totalMinutes),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 图表内容
          Row(
            children: [
              // 饼图
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildSections(totalMinutes),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                        enabled: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // 图例
              Expanded(
                flex: 2,
                child: _buildLegend(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int totalMinutes) {
    return List.generate(data.length, (index) {
      final dist = data[index];
      final percentage = dist.getPercentage(totalMinutes);
      final isLarge = percentage >= 10;

      return PieChartSectionData(
        value: dist.minutes.toDouble(),
        title: isLarge ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isLarge ? 60 : 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        color: dist.color,
        badgeWidget: percentage >= 5
            ? null
            : _buildSmallBadge(percentage),
        badgePositionPercentageOffset: .98,
      );
    });
  }

  Widget _buildSmallBadge(double percentage) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          data.length > 6 ? 6 : data.length,
          (index) {
            final dist = data[index];
            final percentage = dist.getPercentage(
              data.fold<int>(0, (sum, d) => sum + d.minutes),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LegendItem(
                color: dist.color,
                name: dist.displayName,
                minutes: dist.minutes,
                percentage: percentage,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalChip(int count, int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$count次',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            hours > 0 ? '$hours小时$mins分' : '$mins分钟',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
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
              Icons.pie_chart_outlined,
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String name;
  final int minutes;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.name,
    required this.minutes,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final durationText = hours > 0 ? '$hours小时$mins分' : '$mins分';

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
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$durationText · ${percentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 环形图（Donut Chart）版本
class WorkoutDonutChart extends StatelessWidget {
  final List<WorkoutTypeDistribution> data;
  final String title;
  final Widget? centerWidget;

  const WorkoutDonutChart({
    super.key,
    required this.data,
    required this.title,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    final totalMinutes = data.fold<int>(0, (sum, d) => sum + d.minutes);
    final totalCount = data.fold<int>(0, (sum, d) => sum + d.count);

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
          // 标题
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 图表
          Row(
            children: [
              // 环形图
              Expanded(
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 70,
                          sections: _buildSections(totalMinutes),
                          startDegreeOffset: 270,
                          pieTouchData: PieTouchData(
                            enabled: true,
                          ),
                        ),
                      ),
                      // 中心内容
                      centerWidget ?? _buildCenterContent(totalCount, totalMinutes),
                    ],
                  ),
                ),
              ),

              // 图例
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildCompactLegend(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int totalMinutes) {
    return List.generate(data.length, (index) {
      final dist = data[index];
      final percentage = dist.getPercentage(totalMinutes);

      return PieChartSectionData(
        value: dist.minutes.toDouble(),
        title: '',
        radius: 50,
        color: dist.color,
        showTitle: false,
      );
    });
  }

  Widget _buildCenterContent(int count, int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '次运动',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hours > 0 ? '$hours小时$mins分' : '$mins分钟',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLegend(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(data.length, (index) {
          final dist = data[index];
          final percentage = dist.getPercentage(
            data.fold<int>(0, (sum, d) => sum + d.minutes),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dist.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dist.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );
        }),
      ),
    );
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
      child: const Center(
        child: Column(
          children: [
            Icon(
              Icons.donut_large_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 按分类的饼图（有氧/力量/球类/其他）
class WorkoutCategoryPieChart extends StatelessWidget {
  final Map<String, int> minutesByCategory;
  final Map<String, String> categoryNames;
  final String title;

  const WorkoutCategoryPieChart({
    super.key,
    required this.minutesByCategory,
    required this.categoryNames,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (minutesByCategory.isEmpty) {
      return _buildEmptyChart(context);
    }

    final totalMinutes = minutesByCategory.values.fold<int>(0, (a, b) => a + b);

    // 转换为分布数据
    final distributions = minutesByCategory.entries.map((entry) {
      return WorkoutTypeDistribution(
        type: entry.key,
        displayName: categoryNames[entry.key] ?? entry.key,
        minutes: entry.value,
        count: 1,
        color: WorkoutCategoryColors.getColor(entry.key),
      );
    }).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
        ),
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
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              // 环形图
              SizedBox(
                height: 160,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 45,
                        sections: _buildCategorySections(distributions, totalMinutes),
                        startDegreeOffset: 270,
                      ),
                    ),
                    // 中心文字
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_formatMinutes(totalMinutes)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '总时长',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.lg),

              // 图例
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: distributions.map((dist) {
                    final percentage = dist.getPercentage(totalMinutes);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: dist.color,
                              borderRadius: AppRadius.xsRadius,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dist.displayName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildCategorySections(
    List<WorkoutTypeDistribution> distributions,
    int totalMinutes,
  ) {
    return distributions.map((dist) {
      final percentage = dist.getPercentage(totalMinutes);

      return PieChartSectionData(
        value: dist.minutes.toDouble(),
        title: percentage >= 15 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        color: dist.color,
      );
    }).toList();
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours小时$mins分';
    }
    return '$mins分';
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
      child: const Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: AppColors.textHint,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
