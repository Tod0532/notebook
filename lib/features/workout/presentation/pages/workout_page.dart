/// 运动模块页面 - 现代渐变风格
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/shared/widgets/empty_state_widget.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/shared/widgets/progress_components.dart';
import 'package:intl/intl.dart';

/// 运动视图（无 Scaffold，在 ShellRoute 内部）
class WorkoutView extends ConsumerWidget {
  const WorkoutView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(allWorkoutsProvider);
    final statsAsync = ref.watch(thisWeekStatsProvider);
    final streakAsync = ref.watch(workoutStreakProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context),
          // 统计卡片
          statsAsync.when(
            data: (stats) {
              final count = stats['count'] as int? ?? 0;
              final minutes = stats['totalMinutes'] as int? ?? 0;
              return streakAsync.when(
                data: (streak) => _WorkoutStatsCard(
                  count: count,
                  minutes: minutes,
                  streak: streak,
                ),
                loading: () => _WorkoutStatsCard(count: count, minutes: minutes, streak: 0),
                error: (_, __) => _WorkoutStatsCard(count: count, minutes: minutes, streak: 0),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // 运动列表
          Expanded(
            child: workoutsAsync.when(
              data: (workouts) {
                if (workouts.isEmpty) {
                  return _EmptyState(onTap: () => context.push(AppRoutes.workoutEdit));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final workout = workouts[index];
                    final workoutType = WorkoutType.fromString(workout.type);
                    return AnimatedListItem(
                      index: index,
                      child: _WorkoutCard(
                        type: workout.type,
                        displayName: workoutType?.displayName ?? workout.type,
                        durationMinutes: workout.durationMinutes,
                        startTime: workout.startTime,
                        notes: workout.notes,
                        onTap: () => _showWorkoutDetail(context, workout),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('加载失败: $e'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(
            '运动',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          // 统计按钮
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: AppRadius.mdRadius,
            ),
            child: IconButton(
              icon: const Icon(Icons.bar_chart, size: 20, color: Colors.white),
              onPressed: () => context.push(AppRoutes.workoutStats),
              padding: const EdgeInsets.all(AppSpacing.sm),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdRadius,
            ),
            child: IconButton(
              icon: const Icon(Icons.calendar_today, size: 20),
              onPressed: () => _showCalendarDialog(context),
              padding: const EdgeInsets.all(AppSpacing.sm),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _showCalendarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('运动日历'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('日历功能开发中'),
          ),
        ],
      ),
    );
  }

  void _showWorkoutDetail(BuildContext context, Workout workout) {
    context.push('/workout/${workout.id}');
  }
}

/// 运动统计卡片 - 现代渐变风格
class _WorkoutStatsCard extends StatelessWidget {
  final int count;
  final int minutes;
  final int streak;

  const _WorkoutStatsCard({
    required this.count,
    required this.minutes,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.light,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.fitness_center,
            label: '次数',
            value: '$count',
          ),
          _StatItem(
            icon: Icons.timer_outlined,
            label: '分钟',
            value: '$minutes',
          ),
          _StatItem(
            icon: Icons.local_fire_department,
            label: '连续',
            value: '$streak',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: AppRadius.lgRadius,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
        ),
      ],
    );
  }
}

/// 运动记录卡片
class _WorkoutCard extends StatelessWidget {
  final String type;
  final String displayName;
  final int durationMinutes;
  final DateTime startTime;
  final String? notes;
  final VoidCallback onTap;

  const _WorkoutCard({
    required this.type,
    required this.displayName,
    required this.durationMinutes,
    required this.startTime,
    this.notes,
    required this.onTap,
  });

  String get _category {
    final workoutType = WorkoutType.fromString(type);
    return workoutType?.category ?? 'other';
  }

  Color get _color {
    switch (_category) {
      case 'cardio':
        return AppColors.cardioColor;
      case 'strength':
        return AppColors.strengthColor;
      case 'sports':
        return AppColors.sportsColor;
      default:
        return AppColors.otherColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M月d日');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _color.withValues(alpha: 0.2),
                        _color.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: Center(
                    child: Icon(_getIcon(), color: _color, size: 26),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: AppRadius.smRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '$durationMinutes分钟',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${dateFormat.format(startTime)} ${timeFormat.format(startTime)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textHint,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (_category) {
      case 'cardio':
        return Icons.directions_run;
      case 'strength':
        return Icons.fitness_center;
      case 'sports':
        return Icons.sports_basketball;
      default:
        return Icons.self_improvement;
    }
  }
}

/// 空状态（使用统一组件）
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget.workouts(onCreate: onTap);
  }
}
