/// 挑战卡片组件
/// 显示单个挑战的进度、奖励和操作按钮

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/challenge/presentation/providers/challenge_providers.dart';

/// 挑战卡片
class ChallengeCard extends ConsumerWidget {
  final Map<String, dynamic> challengeData;
  final bool isWeekly;

  const ChallengeCard({
    super.key,
    required this.challengeData,
    this.isWeekly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = challengeData['challenge'] as DailyChallenge;
    final progress = challengeData['progress'] as UserChallengeProgress?;
    final progressPercent = challengeData['progressPercent'] as double;

    final isCompleted = progress?.isCompleted ?? false;
    final rewardClaimed = progress?.rewardClaimed ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withOpacity(0.1),
                  AppColors.success.withOpacity(0.05),
                ],
              )
            : null,
        color: isCompleted ? null : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和状态
          Row(
            children: [
              // 类型图标
              _buildTypeIcon(challenge.type),
              const SizedBox(width: AppSpacing.sm),
              // 标题
              Expanded(
                child: Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              // 状态标签
              if (rewardClaimed)
                _buildStatusBadge('已领取', AppColors.success)
              else if (isCompleted)
                _buildStatusBadge('已完成', AppColors.warning)
              else
                _buildStatusBadge('进行中', AppColors.info),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 描述
          Text(
            challenge.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 进度条
          _buildProgressBar(context, progressPercent, challenge.targetCount, progress?.currentCount ?? 0),
          const SizedBox(height: AppSpacing.md),
          // 奖励和操作
          Row(
            children: [
              // 奖励预览
              _buildRewardChip(context, challenge.expReward, challenge.pointsReward),
              const Spacer(),
              // 操作按钮
              if (isCompleted && !rewardClaimed)
                _buildClaimButton(context, ref, challenge.id)
              else if (rewardClaimed)
                _buildClaimedButton(context),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建类型图标
  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'workout':
        icon = Icons.fitness_center_rounded;
        color = AppColors.secondary;
        break;
      case 'note':
        icon = Icons.edit_note_rounded;
        color = AppColors.primary;
        break;
      case 'plan':
        icon = Icons.task_alt_rounded;
        color = AppColors.warning;
        break;
      case 'streak':
        icon = Icons.local_fire_department_rounded;
        color = AppColors.error;
        break;
      case 'total_minutes':
        icon = Icons.timer_rounded;
        color = AppColors.info;
        break;
      default:
        icon = Icons.emoji_events_rounded;
        color = AppColors.textHint;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  /// 构建状态标签
  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(
    BuildContext context,
    double progressPercent,
    int targetCount,
    int currentCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            Text(
              '$currentCount/$targetCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progressPercent / 100,
            backgroundColor: AppColors.dividerColor.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progressPercent >= 100 ? AppColors.success : AppColors.primary,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// 构建奖励芯片
  Widget _buildRewardChip(BuildContext context, int expReward, int pointsReward) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (expReward > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '+$expReward EXP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        if (pointsReward > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  '+$pointsReward',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 构建领取按钮
  Widget _buildClaimButton(BuildContext context, WidgetRef ref, int challengeId) {
    return ElevatedButton.icon(
      onPressed: () async {
        final notifier = ref.read(challengeNotifierProvider.notifier);
        if (isWeekly) {
          await notifier.claimWeeklyReward(challengeId);
        } else {
          await notifier.claimDailyReward(challengeId);
        }
      },
      icon: const Icon(Icons.card_giftcard_rounded, size: 18),
      label: const Text('领取'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// 构建已领取按钮
  Widget _buildClaimedButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dividerColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(
            '已领取',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

/// 挑战进度卡片（小尺寸）
class ChallengeProgressCard extends ConsumerWidget {
  final String title;
  final String description;
  final int current;
  final int target;
  final int expReward;
  final int pointsReward;
  final IconData icon;
  final Color color;

  const ChallengeProgressCard({
    super.key,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.expReward,
    required this.pointsReward,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = (current / target).clamp(0.0, 1.0);
    final isCompleted = current >= target;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.dividerColor.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '$current/$target',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              if (expReward > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 12, color: AppColors.warning),
                    const SizedBox(width: 2),
                    Text(
                      '+$expReward',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
