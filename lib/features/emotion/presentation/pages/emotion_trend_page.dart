/// 情绪趋势页面 - 显示历史情绪变化和运动推荐

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/emotion/presentation/providers/emotion_providers.dart';
import 'package:thick_notepad/features/emotion/presentation/widgets/emotion_insight_card.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/features/emotion/data/repositories/emotion_repository.dart';
import 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';

/// 情绪趋势页面
class EmotionTrendPage extends ConsumerStatefulWidget {
  const EmotionTrendPage({super.key});

  @override
  ConsumerState<EmotionTrendPage> createState() => _EmotionTrendPageState();
}

class _EmotionTrendPageState extends ConsumerState<EmotionTrendPage>
    with SingleTickerProviderStateMixin {
  int _selectedPeriod = 7; // 7天或30天

  @override
  Widget build(BuildContext context) {
    final trendAsync = ref.watch(emotionTrendDataProvider(_selectedPeriod));
    final statisticsAsync = ref.watch(emotionStatisticsProvider(_selectedPeriod));

    return Scaffold(
      appBar: AppBar(
        title: const Text('情绪趋势'),
        actions: [
          // 期间切换
          _buildPeriodSelector(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            _buildStatisticsCard(statisticsAsync),
            const SizedBox(height: 16),

            // 趋势图表
            _buildTrendChart(trendAsync),
            const SizedBox(height: 16),

            // 情绪分布
            _buildEmotionDistribution(statisticsAsync),
            const SizedBox(height: 16),

            // 运动推荐
            _buildWorkoutRecommendations(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodButton(
            label: '7天',
            isSelected: _selectedPeriod == 7,
            onTap: () => setState(() => _selectedPeriod = 7),
          ),
          _PeriodButton(
            label: '30天',
            isSelected: _selectedPeriod == 30,
            onTap: () => setState(() => _selectedPeriod = 30),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(AsyncValue<EmotionStatistics> asyncStats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '情绪统计',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            asyncStats.when(
              data: (stats) {
                if (stats.totalRecords == 0) {
                  return const Text('暂无数据');
                }
                return Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: '记录总数',
                        value: stats.totalRecords.toString(),
                        icon: Icons.note,
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        label: '平均置信度',
                        value: '${(stats.avgConfidence * 100).toStringAsFixed(0)}%',
                        icon: Icons.percent,
                        color: AppColors.info,
                      ),
                    ),
                    if (stats.mostCommonEmotion != null)
                      Expanded(
                        child: _StatItem(
                          label: '主要情绪',
                          value: stats.mostCommonEmotion!.displayName,
                          icon: _getEmotionIcon(stats.mostCommonEmotion!),
                          color: Color(
                            int.parse(stats.mostCommonEmotion!.colorHex.replaceFirst('#', '0xFF')),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('加载失败'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(AsyncValue<List<EmotionTrendData>> asyncTrend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '情绪趋势',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: asyncTrend.when(
                data: (trend) {
                  if (trend.isEmpty) {
                    return const Center(child: Text('暂无趋势数据'));
                  }
                  return _EmotionLineChart(trend: trend);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('加载失败')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionDistribution(AsyncValue<EmotionStatistics> asyncStats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '情绪分布',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: asyncStats.when(
                data: (stats) {
                  if (stats.totalRecords == 0) {
                    return const Center(child: Text('暂无数据'));
                  }
                  return _EmotionPieChart(emotionCounts: stats.emotionCounts);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('加载失败')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutRecommendations() {
    final recommendationsAsync = ref.watch(historyBasedRecommendationProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基于历史情绪的运动推荐',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            recommendationsAsync.when(
              data: (recommendations) {
                if (recommendations.isEmpty) {
                  return const Text('暂无推荐');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recommendations.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rec = recommendations[index];
                    return _RecommendationItem(recommendation: rec);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('加载失败'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmotionIcon(EmotionType emotion) {
    switch (emotion) {
      case EmotionType.happy:
        return Icons.sentiment_very_satisfied;
      case EmotionType.sad:
        return Icons.sentiment_very_dissatisfied;
      case EmotionType.anxious:
        return Icons.psychology;
      case EmotionType.tired:
        return Icons.battery_alert;
      case EmotionType.stressed:
        return Icons.error;
      case EmotionType.calm:
        return Icons.self_improvement;
      case EmotionType.excited:
        return Icons.bolt;
    }
  }
}

/// 期间选择按钮
class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
        ),
      ],
    );
  }
}

/// 推荐项
class _RecommendationItem extends StatelessWidget {
  final WorkoutRecommendation recommendation;

  const _RecommendationItem({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_run,
            color: AppColors.success,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.workoutType.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                _getIntensityLabel(recommendation.intensity),
                style: TextStyle(
                  color: _getIntensityColor(recommendation.intensity),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (recommendation.suggestedDuration != null)
                Text(
                  '${recommendation.suggestedDuration}分钟',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getIntensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return '轻松';
      case 2:
        return '轻度';
      case 3:
        return '中等';
      case 4:
        return '较强';
      case 5:
        return '高强度';
      default:
        return '';
    }
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1:
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.info;
      case 4:
      case 5:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// 情绪趋势折线图
class _EmotionLineChart extends StatelessWidget {
  final List<EmotionTrendData> trend;

  const _EmotionLineChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    // 将情绪类型映射为数值（用于Y轴）
    final emotionValues = {
      EmotionType.sad: 0,
      EmotionType.tired: 1,
      EmotionType.stressed: 2,
      EmotionType.anxious: 3,
      EmotionType.calm: 4,
      EmotionType.happy: 5,
      EmotionType.excited: 6,
    };

    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      final value = emotionValues[trend[i].emotion] ?? 4;
      spots.add(FlSpot(i.toDouble(), value.toDouble()));
    }

    final minY = 0.0;
    final maxY = 6.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.dividerColor.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final labels = {
                  0: '悲伤',
                  1: '疲惫',
                  2: '压力',
                  3: '焦虑',
                  4: '平静',
                  5: '开心',
                  6: '兴奋',
                };
                return Text(
                  labels[value.toInt()] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= trend.length) return const Text('');
                final date = trend[value.toInt()].date;
                return Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                );
              },
              interval: trend.length > 7
                  ? (trend.length / 7).ceil().toDouble()
                  : 1,
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
        maxX: (trend.length - 1).toDouble().clamp(1, double.infinity),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: _getEmotionColor(trend[index].emotion),
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColors.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= trend.length) return null;
                final data = trend[index];
                return LineTooltipItem(
                  '${data.date.month}/${data.date.day}\n${data.emotion.displayName}',
                  TextStyle(
                    color: _getEmotionColor(data.emotion),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Color _getEmotionColor(EmotionType emotion) {
    return Color(
      int.parse(emotion.colorHex.replaceFirst('#', '0xFF')),
    );
  }
}

/// 情绪分布饼图
class _EmotionPieChart extends StatelessWidget {
  final Map<EmotionType, int> emotionCounts;

  const _EmotionPieChart({required this.emotionCounts});

  @override
  Widget build(BuildContext context) {
    final total = emotionCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    final sections = <PieChartSectionData>[];
    int colorIndex = 0;

    for (final entry in emotionCounts.entries) {
      final percentage = entry.value / total;
      final color = Color(
        int.parse(entry.key.colorHex.replaceFirst('#', '0xFF')),
      );

      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: '${(percentage * 100).toStringAsFixed(0)}%',
          color: color,
          radius: 80,
          titleStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sections,
              pieTouchData: PieTouchData(
                enabled: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: emotionCounts.entries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(entry.key.colorHex.replaceFirst('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key.displayName} $percentage%',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
