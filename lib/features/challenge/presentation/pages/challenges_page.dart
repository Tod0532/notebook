/// 挑战页面
/// 展示每日挑战和每周挑战

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/features/challenge/presentation/providers/challenge_providers.dart';
import 'package:thick_notepad/features/challenge/presentation/widgets/challenge_card.dart';

/// 挑战页面
class ChallengesPage extends ConsumerStatefulWidget {
  const ChallengesPage({super.key});

  @override
  ConsumerState<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends ConsumerState<ChallengesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countdownAsync = ref.watch(challengeRefreshCountdownProvider);
    final todayChallengesAsync = ref.watch(todayChallengesProvider);
    final weeklyChallengesAsync = ref.watch(weeklyChallengesProvider);
    final daysUntilWeekEnd = ref.watch(daysUntilWeekEndProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日挑战'),
        actions: [
          // 倒计时显示
          countdownAsync.when(
            data: (countdown) {
              final hours = countdown.inHours;
              final minutes = countdown.inMinutes % 60;
              final seconds = countdown.inSeconds % 60;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '每日挑战'),
            Tab(text: '每周挑战'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 每日挑战
          _buildDailyChallenges(todayChallengesAsync),
          // 每周挑战
          _buildWeeklyChallenges(weeklyChallengesAsync, daysUntilWeekEnd),
        ],
      ),
    );
  }

  /// 构建每日挑战列表
  Widget _buildDailyChallenges(AsyncValue<List<Map<String, dynamic>>> challengesAsync) {
    return challengesAsync.when(
      data: (challenges) {
        if (challenges.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.emoji_events_outlined,
            title: '暂无挑战',
            message: '今日挑战正在加载中...',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayChallengesProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: challenges.length,
            itemBuilder: (context, index) {
              return ChallengeCard(
                key: ValueKey(challenges[index]['challenge'].id),
                challengeData: challenges[index],
              ).slideIn(delay: index == 0 ? DelayDuration.none : DelayDuration.short);
            },
          ),
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(error.toString()),
    );
  }

  /// 构建每周挑战列表
  Widget _buildWeeklyChallenges(
    AsyncValue<List<Map<String, dynamic>>> challengesAsync,
    int daysUntilWeekEnd,
  ) {
    return Column(
      children: [
        // 本周信息卡片
        Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本周剩余',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                    ),
                    Text(
                      '$daysUntilWeekEnd 天',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 挑战列表
        Expanded(
          child: challengesAsync.when(
            data: (challenges) {
              if (challenges.isEmpty) {
                return _buildEmptyState(
                  context,
                  icon: Icons.emoji_events_outlined,
                  title: '暂无挑战',
                  message: '本周挑战正在加载中...',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(weeklyChallengesProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: challenges.length,
                  itemBuilder: (context, index) {
                    return ChallengeCard(
                      key: ValueKey('weekly_${challenges[index]['challenge'].id}'),
                      challengeData: challenges[index],
                      isWeekly: true,
                    ).slideIn(delay: index == 0 ? DelayDuration.none : DelayDuration.short);
                  },
                ),
              );
            },
            loading: () => _buildLoadingState(),
            error: (error, _) => _buildErrorState(error.toString()),
          ),
        ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String title, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.dividerColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  /// 加载状态
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// 错误状态
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            '加载失败',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}
