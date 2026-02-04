/// 连续打卡显示组件
/// 显示当前连续打卡天数和火焰动画

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';
import 'package:thick_notepad/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:thick_notepad/features/gamification/presentation/widgets/points_balance.dart';
import 'package:shimmer/shimmer.dart';

/// 连续打卡显示组件
class StreakDisplay extends ConsumerWidget {
  final bool isCompact;
  final VoidCallback? onTap;

  const StreakDisplay({
    super.key,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(currentStreakProvider);
    final pointsAsync = ref.watch(userGameDataProvider);

    return streakAsync.when(
      data: (streak) {
        final points = pointsAsync.when(
          data: (data) => data.points,
          loading: () => 0,
          error: (_, __) => 0,
        );

        if (isCompact) {
          return _buildCompact(context, streak, points);
        }
        return _buildFull(context, streak, points);
      },
      loading: () => _buildLoading(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 完整版本
  Widget _buildFull(BuildContext context, int streak, int points) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: _getStreakGradient(streak),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _getStreakColor(streak).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 火焰图标
            _buildFireIcon(streak),
            const SizedBox(width: AppSpacing.sm),
            // 连续天数
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续打卡',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                ),
                Text(
                  '$streak 天',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                ),
              ],
            ),
            if (streak >= 7) ...[
              const SizedBox(width: AppSpacing.sm),
              // 徽章
              _buildStreakBadge(streak),
            ],
          ],
        ),
      ),
    );
  }

  /// 紧凑版本
  Widget _buildCompact(BuildContext context, int streak, int points) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 连续打卡
        _buildCompactStreak(context, streak),
        const SizedBox(width: AppSpacing.md),
        // 积分
        PointsBalanceWidget(
          isCompact: true,
        ),
      ],
    );
  }

  /// 紧凑型连续打卡
  Widget _buildCompactStreak(BuildContext context, int streak) {
    final color = _getStreakColor(streak);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }

  /// 火焰图标（带动画）
  Widget _buildFireIcon(int streak) {
    final color = _getStreakColor(streak);
    final size = streak >= 30 ? 36.0 : streak >= 7 ? 32.0 : 28.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                color,
                color.withOpacity(0.6),
                Colors.orange,
              ],
            ).createShader(bounds),
            child: Icon(
              _getFireIcon(streak),
              size: size,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// 连续打卡徽章
  Widget _buildStreakBadge(int streak) {
    String badgeText;
    Color badgeColor;

    if (streak >= 100) {
      badgeText = '百日';
      badgeColor = const Color(0xFFFF6B6B);
    } else if (streak >= 30) {
      badgeText = '月度';
      badgeColor = const Color(0xFFFFD700);
    } else if (streak >= 14) {
      badgeText = '双周';
      badgeColor = const Color(0xFF8B5CF6);
    } else {
      badgeText = '一周';
      badgeColor = const Color(0xFF22C55E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 加载状态
  Widget _buildLoading(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        width: 120,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  /// 根据连续天数获取颜色
  Color _getStreakColor(int streak) {
    if (streak >= 100) return const Color(0xFFFF6B6B); // 传说红
    if (streak >= 30) return const Color(0xFFFFD700); // 金色
    if (streak >= 14) return const Color(0xFF8B5CF6); // 紫色
    if (streak >= 7) return const Color(0xFFFF9500); // 橙色
    if (streak >= 3) return const Color(0xFFFF6B00); // 深橙色
    return const Color(0xFFFFB6C1); // 浅粉色
  }

  /// 根据连续天数获取渐变
  LinearGradient _getStreakGradient(int streak) {
    final baseColor = _getStreakColor(streak);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
    );
  }

  /// 根据连续天数获取火焰图标
  IconData _getFireIcon(int streak) {
    if (streak >= 100) return Icons.whatshot;
    if (streak >= 30) return Icons.local_fire_department;
    if (streak >= 7) return Icons.flare;
    return Icons.mode_night_rounded;
  }
}

/// 每日打卡按钮组件
class DailyCheckInButton extends ConsumerWidget {
  final VoidCallback? onCheckIn;

  const DailyCheckInButton({
    super.key,
    this.onCheckIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInState = ref.watch(dailyCheckInProvider);
    final streakAsync = ref.watch(currentStreakProvider);

    return streakAsync.when(
      data: (streak) {
        final isCheckedIn = checkInState.isSuccess;
        final isLoading = checkInState.isLoading;

        return GestureDetector(
          onTap: isLoading || isCheckedIn ? null : () => _performCheckIn(ref, context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: isCheckedIn
                  ? AppColors.successGradient
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isCheckedIn ? AppColors.success : AppColors.primary).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else
                  Icon(
                    isCheckedIn ? Icons.check_circle : Icons.today,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckedIn ? '已签到' : '每日签到',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                    ),
                    if (!isCheckedIn && streak > 0)
                      Text(
                        '已连续 $streak 天',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => _buildLoadingButton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _performCheckIn(WidgetRef ref, BuildContext context) async {
    final notifier = ref.read(dailyCheckInProvider.notifier);
    await notifier.performCheckIn();

    final state = ref.read(dailyCheckInProvider);
    if (state.isSuccess && context.mounted) {
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '签到成功！连续 ${state.streakDays} 天，获得 ${state.pointsEarned} 积分，${state.expEarned} 经验',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // 如果升级了，显示升级动画
      if (state.newLevel != null && state.newLevel! > 1) {
        _showLevelUpDialog(context, state.newLevel!);
      }
    } else if (state.hasError && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message ?? '签到失败'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLevelUpDialog(BuildContext context, int newLevel) {
    showDialog(
      context: context,
      builder: (context) => _LevelUpDialog(level: newLevel),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      width: 140,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// 升级对话框
class _LevelUpDialog extends StatelessWidget {
  final int level;

  const _LevelUpDialog({required this.level});

  @override
  Widget build(BuildContext context) {
    final levelTitle = LevelConfig.getLevelTitle(level);
    final levelColor = LevelConfig.getLevelColor(level);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 升级图标
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 升级文本
            Text(
              '升级啦！',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '达到 $levelTitle',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lv.$level',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 48,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 关闭按钮
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '太棒了！',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
