/// 运动折线图组件
/// 使用 fl_chart 展示运动趋势

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/workout/data/models/workout_stats_models.dart';

/// 运动趋势折线图
class WorkoutLineChart extends StatelessWidget {
  final List<WorkoutTrendPoint> data;
  final String title;
  final String? subtitle;
  final bool showArea;

  const WorkoutLineChart({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 计算统计数据
    final totalMinutes = data.fold<int>(0, (sum, p) => sum + p.minutes);
    final avgMinutes = data.isEmpty ? 0 : totalMinutes ~/ data.length;
    final maxMinutes = data.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b);

    final yMax = maxMinutes > 0 ? (maxMinutes * 1.2).ceilToDouble() : 60;

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
          // 标题和统计
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: AppColors.infoGradient,
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
              // 统计信息
              _buildStatChip('总时长', _formatDuration(totalMinutes)),
              const SizedBox(width: AppSpacing.xs),
              _buildStatChip('平均', _formatDuration(avgMinutes)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 图表
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? AppColors.dividerColorDark.withOpacity(0.2)
                          : AppColors.dividerColor.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _calculateInterval(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox.shrink();

                        return _buildBottomTitle(data[index]);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: yMax / 5,
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
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: yMax.toDouble(),
                lineBarsData: [
                  _buildMainLine(),
                  if (avgMinutes > 0) _buildAverageLine(avgMinutes, yMax.toDouble()),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.9),
                    tooltipPadding: const EdgeInsets.all(AppSpacing.sm),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final point = data[spot.x.toInt()];
                        if (point == null) return null;

                        final hours = point.minutes ~/ 60;
                        final minutes = point.minutes % 60;
                        final duration = hours > 0
                            ? '$hours小时$minutes分钟'
                            : '$minutes分钟';

                        return LineTooltipItem(
                          duration,
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
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

  LineChartBarData _buildMainLine() {
    return LineChartBarData(
      spots: List.generate(
        data.length,
        (index) => FlSpot(
          index.toDouble(),
          data[index].minutes.toDouble(),
        ),
      ),
      isCurved: true,
      gradient: AppColors.infoGradient,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppColors.info,
            strokeWidth: 2,
            strokeColor: AppColors.surface,
          );
        },
      ),
      belowBarData: showArea
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.info.withOpacity(0.3),
                  AppColors.info.withOpacity(0.05),
                ],
              ),
            )
          : null,
    );
  }

  LineChartBarData _buildAverageLine(int avgMinutes, double yMax) {
    return LineChartBarData(
      spots: [
        FlSpot(0, avgMinutes.toDouble()),
        FlSpot((data.length - 1).toDouble(), avgMinutes.toDouble()),
      ],
      isCurved: false,
      color: AppColors.warning.withOpacity(0.7),
      barWidth: 2,
      dashArray: [5, 5],
      dotData: const FlDotData(show: false),
    );
  }

  Widget _buildBottomTitle(WorkoutTrendPoint point) {
    final now = DateTime.now();
    final daysDiff = now.difference(point.date).inDays;

    String text;
    if (daysDiff == 0) {
      text = '今天';
    } else if (daysDiff == 1) {
      text = '昨天';
    } else if (daysDiff < 7) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      text = '周${weekdays[point.date.weekday - 1]}';
    } else {
      text = '${point.date.month}/${point.date.day}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textHint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.infoGradient,
        borderRadius: AppRadius.smRadius,
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      children: [
        _buildLegendItem(context, '运动时长', AppColors.infoGradient, true),
        if (showArea) ...[
          const SizedBox(width: AppSpacing.lg),
          _buildLegendItem(context, '平均线', null, false, AppColors.warning),
        ],
      ],
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    LinearGradient? gradient,
    bool isSolid,
    [Color? dashedColor,]
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gradient != null)
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppRadius.xsRadius,
            ),
          )
        else
          Container(
            width: 16,
            height: 2,
            color: dashedColor,
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  double _calculateInterval() {
    if (data.length <= 7) return 1;
    if (data.length <= 14) return 2;
    if (data.length <= 30) return 5;
    return 7;
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours小时$mins分钟';
    }
    return '$mins分钟';
  }
}

/// 多条趋势线的折线图（对比不同类型运动）
class WorkoutMultiLineChart extends StatelessWidget {
  final Map<String, List<WorkoutTrendPoint>> dataByType;
  final Map<String, String> typeNames;
  final String title;

  const WorkoutMultiLineChart({
    super.key,
    required this.dataByType,
    required this.typeNames,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (dataByType.isEmpty) {
      return _buildEmptyChart(context);
    }

    // 找出所有数据点的最大值
    double maxY = 0;
    int maxLength = 0;
    for (final data in dataByType.values) {
      for (final point in data) {
        if (point.minutes > maxY) maxY = point.minutes.toDouble();
      }
      if (data.length > maxLength) maxLength = data.length;
    }

    maxY = maxY > 0 ? (maxY * 1.2).ceilToDouble() : 60;

    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
    ];

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
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AspectRatio(
            aspectRatio: 16 / 9,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.dividerColor.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= maxLength) return const SizedBox.shrink();

                        // 取第一个数据集的日期作为X轴标签
                        final firstData = dataByType.values.first;
                        if (index < firstData.length) {
                          return _buildBottomTitle(firstData[index].date);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) return const SizedBox.shrink();

                        return Text(
                          '${value.toInt()}m',
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
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (maxLength - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: _buildMultiLines(colors),
              ),
            ),
          ),

          // 图例
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: _buildLegendItems(context, colors),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _buildMultiLines(List<Color> colors) {
    final lines = <LineChartBarData>[];
    int colorIndex = 0;

    for (final entry in dataByType.entries) {
      final data = entry.value;
      final color = colors[colorIndex % colors.length];

      lines.add(
        LineChartBarData(
          spots: List.generate(
            data.length,
            (index) => FlSpot(
              index.toDouble(),
              data[index].minutes.toDouble(),
            ),
          ),
          isCurved: true,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1,
                strokeColor: AppColors.surface,
              );
            },
          ),
        ),
      );

      colorIndex++;
    }

    return lines;
  }

  List<Widget> _buildLegendItems(BuildContext context, List<Color> colors) {
    final items = <Widget>[];
    int colorIndex = 0;

    for (final entry in dataByType.keys) {
      final color = colors[colorIndex % colors.length];
      final name = typeNames[entry] ?? entry;

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

      colorIndex++;
    }

    return items;
  }

  Widget _buildBottomTitle(DateTime date) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final text = '周${weekdays[date.weekday - 1]}';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textHint,
          fontWeight: FontWeight.w500,
        ),
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
              Icons.show_chart_outlined,
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
