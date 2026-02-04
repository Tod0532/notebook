/// 情绪洞察卡片 - 显示最近检测到的情绪和推荐运动

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/emotion/presentation/providers/emotion_providers.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/emotion/data/repositories/emotion_repository.dart';

/// 情绪图标组件
class EmotionIcon extends StatelessWidget {
  final EmotionType emotion;
  final double size;

  const EmotionIcon({
    super.key,
    required this.emotion,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getEmotionColor(emotion);
    final iconData = _getEmotionIcon(emotion);

    return Icon(
      iconData,
      color: color,
      size: size,
    );
  }

  Color _getEmotionColor(EmotionType emotion) {
    final colorHex = emotion.colorHex;
    return Color(
      int.parse(colorHex.replaceFirst('#', '0xFF')),
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

/// 情绪标签组件
class EmotionChip extends StatelessWidget {
  final EmotionType emotion;
  final double confidence;
  final VoidCallback? onTap;

  const EmotionChip({
    super.key,
    required this.emotion,
    required this.confidence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(emotion.colorHex.replaceFirst('#', '0xFF')),
    );
    final confidencePercent = (confidence * 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: onTap,
      child: Chip(
        avatar: EmotionIcon(emotion: emotion, size: 18),
        label: Text('${emotion.displayName} $confidencePercent%'),
        backgroundColor: color.withOpacity(0.15),
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

/// 情绪洞察卡片 - 主组件
class EmotionInsightCard extends ConsumerWidget {
  final VoidCallback? onViewTrends;
  final VoidCallback? onViewRecommendations;

  const EmotionInsightCard({
    super.key,
    this.onViewTrends,
    this.onViewRecommendations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(emotionDashboardProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行
            Row(
              children: [
                const Icon(
                  Icons.mood,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '情绪洞察',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (onViewTrends != null)
                  TextButton.icon(
                    onPressed: onViewTrends ?? () => context.push(AppRoutes.emotionTrend),
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('趋势'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 内容区域
            dashboardAsync.when(
              data: (data) {
                if (data.latestRecord == null) {
                  return _buildEmptyState(context);
                }
                return _buildContent(context, ref, data);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _buildErrorState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.edit_note,
            size: 48,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '写下笔记，自动分析情绪',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '加载情绪数据失败',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.error,
            ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    EmotionDashboardData data,
  ) {
    final latestRecord = data.latestRecord!;
    final emotion = EmotionType.fromString(latestRecord.emotionType);
    final color = Color(
      int.parse(emotion.colorHex.replaceFirst('#', '0xFF')),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前情绪
        Row(
          children: [
            EmotionIcon(emotion: emotion, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前情绪：${emotion.displayName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    _formatTime(latestRecord.analyzedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                  ),
                ],
              ),
            ),
            EmotionChip(
              emotion: emotion,
              confidence: latestRecord.confidence,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 情绪建议
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  EmotionAnalyzer.getSuggestion(emotion),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color.withOpacity(0.9),
                      ),
                ),
              ),
            ],
          ),
        ),

        // 推荐运动
        if (latestRecord.recommendedWorkout != null) ...[
          const SizedBox(height: 12),
          _buildRecommendation(context, latestRecord),
        ],

        // 本周统计
        if (data.weekStatistics.totalRecords > 1) ...[
          const SizedBox(height: 16),
          _buildWeeklyStats(context, data.weekStatistics),
        ],
      ],
    );
  }

  Widget _buildRecommendation(BuildContext context, EmotionRecord record) {
    final workoutType = WorkoutType.fromString(record.recommendedWorkout ?? 'other') ?? WorkoutType.other;
    final intensity = record.workoutIntensity ?? 3;

    return InkWell(
      onTap: onViewRecommendations,
      borderRadius: AppRadius.mdRadius,
      child: Container(
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
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '推荐运动：${workoutType.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (record.workoutReason != null)
                    Text(
                      record.workoutReason!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
            _buildIntensityBadge(intensity),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityBadge(int intensity) {
    final color = _getIntensityColor(intensity);
    final label = _getIntensityLabel(intensity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWeeklyStats(BuildContext context, EmotionStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本周情绪统计',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.emotionCounts.entries.map((entry) {
            final emotion = entry.key;
            final count = entry.value;
            final percent = (count / stats.totalRecords * 100).toStringAsFixed(0);

            return EmotionChip(
              emotion: emotion,
              confidence: count.toDouble() / stats.totalRecords,
            );
          }).toList(),
        ),
      ],
    );
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
        return '未知';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}

/// 简版情绪指示器（用于列表项）
class EmotionIndicator extends StatelessWidget {
  final EmotionType emotion;
  final double confidence;

  const EmotionIndicator({
    super.key,
    required this.emotion,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(emotion.colorHex.replaceFirst('#', '0xFF')),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmotionIcon(emotion: emotion, size: 16),
        const SizedBox(width: 4),
        Text(
          emotion.displayName,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
