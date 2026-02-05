/// 统一的空状态组件
/// 用于各模块的空数据展示和引导

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';

/// 空状态组件
class EmptyStateWidget extends StatelessWidget {
  /// 图标
  final IconData icon;
  /// 标题
  final String title;
  /// 描述
  final String? description;
  /// 操作按钮文本
  final String? actionLabel;
  /// 操作回调
  final VoidCallback? onAction;
  /// 是否紧凑模式
  final bool isCompact;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.isCompact = false,
  });

  /// 笔记模块空状态
  factory EmptyStateWidget.notes({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.edit_note_outlined,
      title: '还没有笔记',
      description: '记录你的想法和灵感',
      actionLabel: '创建笔记',
      onAction: onCreate,
    );
  }

  /// 提醒模块空状态
  factory EmptyStateWidget.reminders({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.notifications_outlined,
      title: '还没有提醒',
      description: '设置提醒，不再错过重要事项',
      actionLabel: '添加提醒',
      onAction: onCreate,
    );
  }

  /// 运动模块空状态
  factory EmptyStateWidget.workouts({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.fitness_center_outlined,
      title: '还没有运动记录',
      description: '开始记录你的运动历程',
      actionLabel: '记运动',
      onAction: onCreate,
    );
  }

  /// 计划模块空状态
  factory EmptyStateWidget.plans({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.flag_outlined,
      title: '还没有计划',
      description: '制定目标，追踪进度',
      actionLabel: '创建计划',
      onAction: onCreate,
    );
  }

  /// 任务空状态（紧凑版）
  factory EmptyStateWidget.tasks({VoidCallback? onCreate}) {
    return EmptyStateWidget(
      icon: Icons.check_circle_outline,
      title: '还没有任务',
      description: '添加第一个任务吧',
      actionLabel: '添加任务',
      onAction: onCreate,
      isCompact: true,
    );
  }

  /// 搜索结果空状态
  const EmptyStateWidget.search({
    super.key,
    String? query,
  }) : icon = Icons.search_off,
       title = '没有找到结果',
       description = query != null ? '尝试搜索其他关键词' : null,
       actionLabel = null,
       onAction = null,
       isCompact = true;

  @override
  Widget build(BuildContext context) {
    final size = isCompact ? 40.0 : 64.0;
    final padding = isCompact ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isCompact ? null : AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(isCompact ? AppRadius.md : AppRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: size,
              color: AppColors.primary,
            ),
          ),
          if (!isCompact) const SizedBox(height: AppSpacing.xl),
          if (isCompact) const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.xlRadius,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 首次使用引导卡片
class OnboardingCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<OnboardingStep> steps;
  final VoidCallback? onGetStarted;

  const OnboardingCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),  // 简化：使用纯色替代微弱渐变
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return _OnboardingStepItem(
                step: step,
                stepNumber: index + 1,
              );
            }),
          ],
          if (onGetStarted != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGetStarted,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
                child: const Text('开始使用'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingStepItem extends StatelessWidget {
  final OnboardingStep step;
  final int stepNumber;

  const _OnboardingStepItem({
    required this.step,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (step.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    step.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 引导步骤
class OnboardingStep {
  final String title;
  final String? description;

  const OnboardingStep({
    required this.title,
    this.description,
  });
}
