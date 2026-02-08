/// 计划选择器 - 用于运动记录时选择关联的计划
///
/// 功能：
/// - 显示进行中的运动类计划
/// - 显示计划进度（完成度）
/// - 支持不选择计划

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 计划选择器组件
class PlanSelector extends ConsumerStatefulWidget {
  /// 当前选中的计划ID
  final int? selectedPlanId;
  /// 选择回调
  final ValueChanged<int?> onSelected;

  const PlanSelector({
    super.key,
    this.selectedPlanId,
    required this.onSelected,
  });

  @override
  ConsumerState<PlanSelector> createState() => _PlanSelectorState();
}

class _PlanSelectorState extends ConsumerState<PlanSelector> {
  @override
  Widget build(BuildContext context) {
    final activePlansAsync = ref.watch(activePlansProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '关联计划',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '可选',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            activePlansAsync.when(
              data: (plans) {
                // 筛选运动类别的计划
                final workoutPlans = plans
                    .where((p) =>
                        p.status == 'active' &&
                        (p.category == 'workout' || p.category == 'other'))
                    .toList();

                if (workoutPlans.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    _buildOption(
                      context,
                      title: '不关联计划',
                      subtitle: '仅记录运动，不关联任何计划',
                      icon: Icons.do_not_disturb_on_outlined,
                      iconColor: AppColors.textHint,
                      isSelected: widget.selectedPlanId == null,
                      onTap: () => widget.onSelected(null),
                    ),
                    const Divider(),
                    ...workoutPlans.map((plan) => _buildPlanOption(
                          context,
                          plan: plan,
                          isSelected: widget.selectedPlanId == plan.id,
                          onTap: () => widget.onSelected(plan.id),
                        )),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => _buildErrorState(),
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无进行中的运动计划',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '去创建一个计划吧',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            '加载计划失败',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建选项
  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24)
            else
              Icon(Icons.circle_outlined,
                  color: AppColors.textHint, size: 24),
          ],
        ),
      ),
    );
  }

  /// 构建计划选项
  Widget _buildPlanOption(
    BuildContext context, {
    required Plan plan,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final progress = plan.totalTasks > 0
        ? (plan.completedTasks / plan.totalTasks * 100).round()
        : 0;

    final categoryIcon = _getCategoryIcon(plan.category);
    final categoryColor = _getCategoryColor(plan.category);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (plan.streakDays > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: AppRadius.smRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${plan.streakDays}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 进度条
                  if (plan.totalTasks > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.smRadius,
                            child: LinearProgressIndicator(
                              value: plan.completedTasks / plan.totalTasks,
                              backgroundColor:
                                  AppColors.surfaceVariant.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(progress),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$progress%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: _getProgressColor(progress),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(plan.targetDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '${plan.completedTasks}/${plan.totalTasks} 任务',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24)
            else
              Icon(Icons.circle_outlined,
                  color: AppColors.textHint, size: 24),
          ],
        ),
      ),
    );
  }

  /// 获取分类图标
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'workout':
        return Icons.fitness_center_outlined;
      case 'habit':
        return Icons.task_alt_outlined;
      case 'study':
        return Icons.school_outlined;
      case 'work':
        return Icons.work_outline;
      case 'health':
        return Icons.favorite_outline;
      default:
        return Icons.flag_outlined;
    }
  }

  /// 获取分类颜色
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'workout':
        return AppColors.secondary;
      case 'habit':
        return AppColors.success;
      case 'study':
        return AppColors.primary;
      case 'work':
        return AppColors.warning;
      case 'health':
        return const Color(0xFFE91E63);
      default:
        return AppColors.textSecondary;
    }
  }

  /// 获取进度颜色
  Color _getProgressColor(int progress) {
    if (progress >= 80) return AppColors.success;
    if (progress >= 50) return AppColors.primary;
    if (progress >= 20) return AppColors.warning;
    return AppColors.error;
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '明天';
    if (diff.inDays == -1) return '昨天';
    if (diff.inDays > 0 && diff.inDays <= 7) {
      return '${diff.inDays}天后';
    }
    if (diff.inDays < 0 && diff.inDays >= -7) {
      return '已过期${diff.inDays.abs()}天';
    }

    return '${date.month}月${date.day}日';
  }
}
