/// 运动数据统计页面
/// 显示本周/本月运动数据汇总

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:intl/intl.dart';

/// 运动统计页面
class WorkoutStatsPage extends ConsumerWidget {
  const WorkoutStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStatsAsync = ref.watch(thisWeekStatsProvider);
    final monthStatsAsync = ref.watch(thisMonthStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运动统计'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本周统计
            Text(
              '本周运动',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            weekStatsAsync.when(
              data: (stats) => _StatsCard(
                stats: stats,
                period: '本周',
              ),
              loading: () => const _StatsCardSkeleton(),
              error: (_, __) => const _StatsCardError(),
            ),
            const SizedBox(height: 24),

            // 本月统计
            Text(
              '本月运动',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            monthStatsAsync.when(
              data: (stats) => _StatsCard(
                stats: stats,
                period: '本月',
              ),
              loading: () => const _StatsCardSkeleton(),
              error: (_, __) => const _StatsCardError(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计卡片
class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String period;

  const _StatsCard({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final count = stats['count'] as int? ?? 0;
    final totalMinutes = stats['totalMinutes'] as int? ?? 0;
    final uniqueDays = stats['uniqueDays'] as int? ?? 0;
    final byType = stats['byType'] as Map<String, int>? ?? {};

    // 计算小时和分钟
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总时长
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总时长',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hours > 0
                          ? '$hours小时${minutes}分钟'
                          : '$minutes分钟',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 运动次数
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '运动次数',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count 次',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 运动天数
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '运动天数',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$uniqueDays 天',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 运动类型分布
          if (byType.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '运动类型分布',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...byType.entries.map((entry) {
              final workoutMinutes = entry.value;
              final workoutHours = workoutMinutes ~/ 60;
              final workoutMins = workoutMinutes % 60;
              final percentage = totalMinutes > 0
                  ? (workoutMinutes / totalMinutes * 100).toStringAsFixed(1)
                  : '0.0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      workoutHours > 0
                          ? '$workoutHours小时${workoutMins}分'
                          : '$workoutMins分钟',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

/// 骨架屏
class _StatsCardSkeleton extends StatelessWidget {
  const _StatsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// 错误状态
class _StatsCardError extends StatelessWidget {
  const _StatsCardError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 32),
            SizedBox(height: 8),
            Text(
              '加载失败',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}
