/// 运动记录详情页面
/// 显示单次运动的完整信息

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:intl/intl.dart';

/// 获取运动类型对应的图标
IconData _getWorkoutIcon(WorkoutType type) {
  switch (type) {
    case WorkoutType.running:
      return Icons.directions_run;
    case WorkoutType.cycling:
      return Icons.directions_bike;
    case WorkoutType.swimming:
      return Icons.pool;
    case WorkoutType.jumpRope:
      return Icons.sports_gymnastics;
    case WorkoutType.hiit:
      return Icons.fitness_center;
    case WorkoutType.aerobics:
      return Icons.sports_gymnastics;
    case WorkoutType.stairClimbing:
      return Icons.stairs;
    case WorkoutType.chest:
    case WorkoutType.back:
    case WorkoutType.legs:
    case WorkoutType.shoulders:
    case WorkoutType.arms:
    case WorkoutType.core:
    case WorkoutType.fullBody:
      return Icons.fitness_center;
    case WorkoutType.basketball:
      return Icons.sports_basketball;
    case WorkoutType.football:
      return Icons.sports_soccer;
    case WorkoutType.badminton:
    case WorkoutType.tableTennis:
    case WorkoutType.tennis:
    case WorkoutType.volleyball:
      return Icons.sports_tennis;
    case WorkoutType.yoga:
      return Icons.self_improvement;
    case WorkoutType.pilates:
      return Icons.accessibility_new;
    case WorkoutType.hiking:
    case WorkoutType.climbing:
      return Icons.terrain;
    case WorkoutType.meditation:
      return Icons.self_improvement;
    case WorkoutType.stretching:
      return Icons.accessibility_new;
    case WorkoutType.walking:
      return Icons.directions_walk;
    case WorkoutType.other:
      return Icons.sports;
  }
}

/// 运动详情页面
class WorkoutDetailPage extends ConsumerWidget {
  final int workoutId;

  const WorkoutDetailPage({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutProvider(workoutId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('运动详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: workoutAsync.when(
        data: (workout) {
          if (workout == null) {
            return const Center(
              child: Text('运动记录不存在'),
            );
          }
          return _buildContent(context, workout);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('加载失败'),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Workout workout) {
    final dateFormat = DateFormat('M月d日 EEEE', 'zh_CN');
    final timeFormat = DateFormat('HH:mm');
    final typeEnum = WorkoutType.values.firstWhere(
      (t) => t.name == workout.type,
      orElse: () => WorkoutType.other,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 运动类型卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: AppRadius.xxlRadius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _getWorkoutIcon(typeEnum),
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  typeEnum.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (workout.customTypeName != null && workout.customTypeName!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    workout.customTypeName!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 数据卡片
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.timer_outlined,
                  label: '时长',
                  value: '${workout.durationMinutes}分钟',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  label: '日期',
                  value: dateFormat.format(workout.startTime),
                  color: AppColors.info,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.access_time,
                  label: '时间',
                  value: timeFormat.format(workout.startTime),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _InfoCard(
                  icon: Icons.sentiment_satisfied_outlined,
                  label: '感受',
                  value: _getFeelingText(workout.feeling),
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          // 详细数据
          if (workout.sets != null && workout.sets! > 0) ...[
            const SizedBox(height: AppSpacing.xxl),
            _DetailSection(
              title: '力量数据',
              child: Row(
                children: [
                  Expanded(
                    child: _DetailItem(
                      label: '组数',
                      value: '${workout.sets}组',
                    ),
                  ),
                  Expanded(
                    child: _DetailItem(
                      label: '次数',
                      value: '${workout.reps ?? 0}次',
                    ),
                  ),
                  Expanded(
                    child: _DetailItem(
                      label: '重量',
                      value: '${workout.weight ?? 0}kg',
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 备注
          if (workout.notes != null && workout.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            _DetailSection(
              title: '备注',
              child: Text(
                workout.notes!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],

          // 关联计划
          if (workout.linkedPlanId != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            _DetailSection(
              title: '关联计划',
              child: Row(
                children: [
                  const Icon(Icons.link, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '计划 ID: ${workout.linkedPlanId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],

          // 关联笔记
          if (workout.linkedNoteId != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            _DetailSection(
              title: '运动小结',
              child: Row(
                children: [
                  const Icon(Icons.note_outlined, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '笔记 ID: ${workout.linkedNoteId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  String _getFeelingText(String? feeling) {
    switch (feeling) {
      case 'easy':
        return '轻松';
      case 'medium':
        return '适中';
      case 'hard':
        return '较累';
      default:
        return '未记录';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除运动记录'),
        content: const Text('确定要删除这条运动记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final workoutRepo = ref.read(workoutRepositoryProvider);
              await workoutRepo.deleteWorkout(workoutId);
              if (context.mounted) {
                context.pop();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 信息卡片
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情区块
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.mdRadius,
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 详情项
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
