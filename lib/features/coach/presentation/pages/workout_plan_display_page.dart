/// AI训练计划展示页面
/// 显示训练计划详情、日程列表和动作详情

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/ai/plan_integration_service.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

/// 训练计划展示页面
class WorkoutPlanDisplayPage extends ConsumerStatefulWidget {
  final int planId;

  const WorkoutPlanDisplayPage({
    super.key,
    required this.planId,
  });

  @override
  ConsumerState<WorkoutPlanDisplayPage> createState() => _WorkoutPlanDisplayPageState();
}

class _WorkoutPlanDisplayPageState extends ConsumerState<WorkoutPlanDisplayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WorkoutPlanWithDetails? _planDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载计划数据
  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(workoutPlanRepositoryProvider);
      final details = await repo.getPlanWithDetails(widget.planId);
      if (details == null) {
        setState(() {
          _error = '计划不存在';
          _isLoading = false;
        });
      } else {
        setState(() {
          _planDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 激活训练计划 - 创建每日提醒
  Future<void> _activatePlan() async {
    final plan = _planDetails!.plan;
    final userProfileId = plan.userProfileId;

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('激活训练计划'),
        content: Text('将为这个${plan.totalDays}天的训练计划创建每日提醒，每天早上9点提醒您训练。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('激活计划'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final integrationService = PlanIntegrationService.instance;

      // 检查用户画像ID
      final actualProfileId = userProfileId ?? await _getLatestProfileId();
      if (actualProfileId == null) {
        throw Exception('未找到用户画像');
      }

      // 调用整合服务激活计划
      await integrationService.activateWorkoutPlan(widget.planId, actualProfileId);

      // 更新计划状态为 active
      final repo = ref.read(workoutPlanRepositoryProvider);
      await repo.updatePlanStatus(widget.planId, 'active');

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('训练计划已激活！已创建${plan.totalDays}条每日提醒'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('激活失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 获取最新的用户画像ID
  Future<int?> _getLatestProfileId() async {
    try {
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final profile = await profileRepo.getLatestProfile();
      return profile?.id;
    } catch (e) {
      debugPrint('获取用户画像失败: $e');
      return null;
    }
  }

  /// 完成训练日程
  Future<void> _completeDay(int dayId) async {
    try {
      final repo = ref.read(workoutPlanRepositoryProvider);
      await repo.completeDay(dayId);

      // 更新计划进度
      final plan = _planDetails!.plan;
      final newCompletedDays = plan.currentDay + 1;
      await repo.updatePlanProgress(plan.id, newCompletedDays);

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('训练完成！继续加油！'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 替换动作
  Future<void> _replaceExercise(
    WorkoutPlanExercise exercise,
    String dayTrainingFocus,
  ) async {
    // 显示替换原因选择对话框
    final reason = await _showReplaceReasonDialog();
    if (reason == null) return;

    // 保存原始名称
    final originalName = exercise.exerciseName;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final aiService = DeepSeekService.instance;
      await aiService.init();

      // 转换原因为英文值
      final reasonValue = _convertReasonToValue(reason);

      // 调用AI生成替代动作
      final replacement = await aiService.replaceExercise(
        currentExerciseName: exercise.exerciseName,
        exerciseType: exercise.exerciseType,
        targetMuscle: dayTrainingFocus,
        equipmentType: exercise.equipment ?? '无',
        reason: reasonValue,
        difficulty: exercise.difficulty,
      );

      final replacementName = replacement['name'] as String;

      // 更新数据库 - 逐个字段更新
      final repo = ref.read(workoutPlanRepositoryProvider);

      // 获取当前动作数据
      final currentExercise = (await repo.getExerciseById(exercise.id))!;

      // 创建更新后的动作对象
      final updatedExercise = WorkoutPlanExercise(
        id: currentExercise.id,
        workoutPlanDayId: currentExercise.workoutPlanDayId,
        exerciseOrder: currentExercise.exerciseOrder,
        exerciseName: replacementName,
        description: replacement['description'] as String?,
        sets: replacement['sets'] as int?,
        reps: currentExercise.reps,
        repsDescription: replacement['reps'] as String?,
        weight: currentExercise.weight,
        restSeconds: replacement['restSeconds'] as int?,
        equipment: replacement['equipment'] as String?,
        difficulty: replacement['difficulty'] as String?,
        exerciseType: currentExercise.exerciseType,
        isCompleted: currentExercise.isCompleted,
        alternativeExercise: currentExercise.alternativeExercise,
      );

      await repo.updateExercise(updatedExercise);

      // 记录用户反馈数据
      try {
        final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
        await feedbackRepo.createFeedback(
          feedbackType: FeedbackType.exercise,
          itemId: exercise.id,
          itemType: exercise.exerciseType,
          reason: reasonValue,
          originalName: originalName,
          replacementName: replacementName,
          userProfileId: _planDetails!.plan.userProfileId,
        );
      } catch (e) {
        // 反馈记录失败不影响替换功能
        debugPrint('记录反馈失败: $e');
      }

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已替换为：$replacementName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('替换失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 将中文原因转换为英文值
  String _convertReasonToValue(String chineseReason) {
    switch (chineseReason) {
      case '太难了':
        return 'too_hard';
      case '太简单了':
        return 'too_easy';
      case '不喜欢这个动作':
        return 'dislike';
      case '没有相关器械':
        return 'no_equipment';
      default:
        return 'dislike';
    }
  }

  /// 显示替换原因选择对话框
  Future<String?> _showReplaceReasonDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择替换原因'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReplaceReasonTile(
              icon: Icons.trending_up,
              title: '太难了',
              subtitle: '降低动作难度',
              value: '太难了',
              onTap: () => Navigator.pop(context, '太难了'),
            ),
            const Divider(),
            _ReplaceReasonTile(
              icon: Icons.trending_down,
              title: '太简单了',
              subtitle: '增加动作难度',
              value: '太简单了',
              onTap: () => Navigator.pop(context, '太简单了'),
            ),
            const Divider(),
            _ReplaceReasonTile(
              icon: Icons.not_interested,
              title: '不喜欢这个动作',
              subtitle: '换一个训练相同部位的',
              value: '不喜欢这个动作',
              onTap: () => Navigator.pop(context, '不喜欢这个动作'),
            ),
            const Divider(),
            _ReplaceReasonTile(
              icon: Icons.fitness_center,
              title: '没有相关器械',
              subtitle: '换一个不需要器械的',
              value: '没有相关器械',
              onTap: () => Navigator.pop(context, '没有相关器械'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// AI重新生成计划
  Future<void> _regeneratePlan() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI重新生成计划'),
        content: const Text('将根据您的反馈数据重新生成整个训练计划，当前计划将被替换。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI正在根据您的反馈重新生成计划...'),
          ],
        ),
      ),
    );

    try {
      // 获取用户画像和反馈数据
      final userProfileId = _planDetails!.plan.userProfileId;
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
      final workoutRepo = ref.read(workoutPlanRepositoryProvider);

      final userProfile = userProfileId != null
          ? await profileRepo.getProfileById(userProfileId)
          : await profileRepo.getLatestProfile();

      if (userProfile == null) {
        throw Exception('未找到用户画像，请先创建用户画像');
      }

      // 获取用户反馈偏好
      final preferenceSummary = userProfileId != null
          ? await feedbackRepo.getUserPreferenceSummary(userProfileId)
          : <String, dynamic>{};

      // 解析用户画像数据
      final dislikedExercises = preferenceSummary['disliked_exercises'] as List<String>? ?? [];
      final difficultyPreference = preferenceSummary['difficulty_preference'] as String? ?? 'balanced';

      // 调用AI重新生成计划
      final aiService = DeepSeekService.instance;
      await aiService.init();

      final newPlanData = await aiService.generateCoachWorkoutPlan(
        goalType: userProfile.goalType,
        durationDays: _planDetails!.plan.totalDays,
        gender: userProfile.gender,
        age: userProfile.age,
        height: userProfile.height,
        weight: userProfile.weight,
        fitnessLevel: userProfile.fitnessLevel,
        equipmentType: userProfile.equipmentType,
        dietType: userProfile.dietType != 'none' ? userProfile.dietType : null,
        dietaryRestrictions: UserProfileRepository.parseJsonList(userProfile.dietaryRestrictions),
        injuries: UserProfileRepository.parseJsonList(userProfile.injuries),
        dailyWorkoutMinutes: userProfile.dailyWorkoutMinutes,
        preferredWorkouts: UserProfileRepository.parseJsonList(userProfile.preferredWorkouts),
        dislikedWorkouts: [
          ...UserProfileRepository.parseJsonList(userProfile.dislikedWorkouts),
          ...dislikedExercises,
        ],
      );

      // 删除旧计划数据（日程和动作）
      final oldDays = await workoutRepo.getPlanDays(widget.planId);
      for (final day in oldDays) {
        await workoutRepo.deletePlanDay(day.id);
      }

      // 根据AI返回的数据创建新的日程和动作
      final days = newPlanData['days'] as List<dynamic>? ?? [];
      final baseDate = _planDetails!.plan.startDate ?? DateTime.now();

      for (final dayData in days) {
        final dayNumber = dayData['day'] as int? ?? 1;
        final dayName = dayData['dayName'] as String? ?? '第$dayNumber天';
        final trainingFocus = dayData['trainingFocus'] as String? ?? '';
        final estimatedMinutes = dayData['estimatedMinutes'] as int? ?? 30;
        final exercisesList = dayData['exercises'] as List<dynamic>? ?? [];

        // 计算计划日期
        final dayScheduledDate = baseDate.add(Duration(days: dayNumber - 1));

        // 创建日程
        final dayId = await workoutRepo.createDay(
          WorkoutPlanDaysCompanion(
            workoutPlanId: drift.Value(widget.planId),
            dayNumber: drift.Value(dayNumber),
            dayName: drift.Value(dayName),
            trainingFocus: drift.Value(trainingFocus),
            estimatedMinutes: drift.Value(estimatedMinutes),
            scheduledDate: drift.Value(dayScheduledDate),
          ),
        );

        // 创建动作
        for (final exerciseData in exercisesList) {
          final order = exerciseData['order'] as int? ?? 1;
          final name = exerciseData['name'] as String? ?? '';
          final description = exerciseData['description'] as String?;
          final sets = exerciseData['sets'] as int?;
          final reps = exerciseData['reps'] as String?;
          final restSeconds = exerciseData['restSeconds'] as int?;
          final equipment = exerciseData['equipment'] as String?;
          final difficulty = exerciseData['difficulty'] as String?;
          final exerciseType = exerciseData['exerciseType'] as String? ?? 'main';

          await workoutRepo.createExercise(
            WorkoutPlanExercisesCompanion(
              workoutPlanDayId: drift.Value(dayId),
              exerciseOrder: drift.Value(order),
              exerciseName: drift.Value(name),
              description: drift.Value(description),
              sets: drift.Value(sets ?? 3),
              repsDescription: drift.Value(reps),
              restSeconds: drift.Value(restSeconds ?? 60),
              equipment: drift.Value(equipment),
              difficulty: drift.Value(difficulty),
              exerciseType: drift.Value(exerciseType),
            ),
          );
        }
      }

      // 更新计划的创建时间（表示已重新生成）
      await workoutRepo.updatePlanProgress(widget.planId, 0);

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('计划已重新生成！'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重新生成失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_planDetails == null) {
      return const Center(child: Text('计划不存在'));
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(),
          _buildTabs(),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildScheduleTab(),
        ],
      ),
    );
  }

  /// AppBar
  Widget _buildAppBar() {
    final plan = _planDetails!.plan;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      actions: [
        IconButton(
          icon: const Icon(Icons.feedback_outlined, color: Colors.white),
          onPressed: () {
            context.push('/coach/feedback?userProfileId=${plan.userProfileId}&workoutPlanId=${plan.id}');
          },
          tooltip: '反馈',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if (value == 'regenerate') {
              await _regeneratePlan();
            } else if (value == 'iteration') {
              context.push('/coach/iteration?userProfileId=${plan.userProfileId}&workoutPlanId=${plan.id}');
            } else if (value == 'feedback') {
              context.push('/coach/feedback?userProfileId=${plan.userProfileId}&workoutPlanId=${plan.id}');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'iteration',
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20),
                  SizedBox(width: 12),
                  Text('计划优化'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'feedback',
              child: Row(
                children: [
                  Icon(Icons.feedback_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('添加反馈'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'regenerate',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Text('AI重新生成'),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          plan.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(plan.status).withOpacity(0.2),
                      borderRadius: AppRadius.smRadius,
                      border: Border.all(color: _getStatusColor(plan.status), width: 1),
                    ),
                    child: Text(
                      _getStatusText(plan.status),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.description ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tab栏
  Widget _buildTabs() {
    return SliverPersistentHeader(
      delegate: _TabHeaderDelegate(
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: '日程', icon: Icon(Icons.calendar_today_outlined)),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      pinned: true,
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab() {
    final plan = _planDetails!.plan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度卡片
          _buildProgressCard(),
          const SizedBox(height: 16),

          // 统计卡片
          _buildStatsCards(),
          const SizedBox(height: 16),

          // 目标信息
          _buildGoalInfoCard(plan),
          const SizedBox(height: 16),

          // 今日训练
          _buildTodayWorkoutCard(),
        ],
      ),
    );
  }

  /// 进度卡片
  Widget _buildProgressCard() {
    final plan = _planDetails!.plan;
    final progress = _planDetails!.progress;
    final completedDays = plan.currentDay;
    final totalDays = plan.totalDays;
    final isNotActive = plan.status != 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '训练进度',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completedDays/$totalDays 天',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.smRadius,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% 完成',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              // 激活计划按钮
              if (isNotActive)
                TextButton.icon(
                  onPressed: _activatePlan,
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                  label: const Text(
                    '激活计划',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCards() {
    final plan = _planDetails!.plan;
    final totalWorkouts = plan.totalWorkouts ?? _planDetails!.days.length;
    final completedWorkouts = _planDetails!.days.where((d) => d.day.isCompleted).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.fitness_center,
            title: '总训练',
            value: '$totalWorkouts',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            title: '已完成',
            value: '$completedWorkouts',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.schedule,
            title: '剩余',
            value: '${totalWorkouts - completedWorkouts}',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// 目标信息卡片
  Widget _buildGoalInfoCard(WorkoutPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '目标信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('目标类型', _getGoalTypeText(plan.goalType)),
          _buildInfoRow('训练天数', '${plan.totalDays} 天'),
          if (plan.startDate != null)
            _buildInfoRow('开始日期', _formatDate(plan.startDate!)),
          if (plan.targetEndDate != null)
            _buildInfoRow('目标结束', _formatDate(plan.targetEndDate!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 今日训练卡片
  Widget _buildTodayWorkoutCard() {
    final todayWorkout = _planDetails!.getTodayWorkout();

    if (todayWorkout == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: 12),
            const Text(
              '今天没有安排训练',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    final day = todayWorkout.day;
    final isCompleted = day.isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isCompleted ? AppColors.successGradient : AppColors.primaryGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                '今日训练',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Text(
                    '已完成',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            day.dayName ?? '第 ${day.dayNumber} 天',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (day.trainingFocus != null) ...[
            const SizedBox(height: 4),
            Text(
              day.trainingFocus!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.fitness_center, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${todayWorkout.exercises.length} 个动作',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              if (day.estimatedMinutes != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${day.estimatedMinutes} 分钟',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _completeDay(day.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('开始训练', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 日程标签页
  Widget _buildScheduleTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _planDetails!.days.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dayWithExercises = _planDetails!.days[index];
        return _buildDayCard(dayWithExercises, index + 1);
      },
    );
  }

  /// 日程卡片
  Widget _buildDayCard(WorkoutPlanDayWithExercises dayWithExercises, int displayNumber) {
    final day = dayWithExercises.day;
    final isCompleted = day.isCompleted;
    final exercises = dayWithExercises.exercises;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          // 日程头部
          InkWell(
            onTap: () => _showDayDetail(dayWithExercises),
            borderRadius: AppRadius.lgRadius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 完成状态图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? AppColors.successGradient
                          : AppColors.primaryGradient,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.calendar_today,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 日程信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.dayName ?? '第 ${day.dayNumber} 天',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (day.trainingFocus != null)
                          Text(
                            day.trainingFocus!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 统计信息
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${exercises.length} 动作',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (day.estimatedMinutes != null)
                        Text(
                          '${day.estimatedMinutes} 分钟',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          // 动作列表预览
          if (exercises.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: exercises.take(4).map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: Text(
                      e.exerciseName,
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// 显示日程详情
  void _showDayDetail(WorkoutPlanDayWithExercises dayWithExercises) {
    final day = dayWithExercises.day;
    final exercises = dayWithExercises.exercises;
    final exercisesByType = dayWithExercises.exercisesByType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖动条
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 头部
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: day.isCompleted
                            ? AppColors.successGradient
                            : AppColors.primaryGradient,
                        borderRadius: AppRadius.mdRadius,
                      ),
                      child: Icon(
                        day.isCompleted ? Icons.check : Icons.fitness_center,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day.dayName ?? '第 ${day.dayNumber} 天',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (day.trainingFocus != null)
                            Text(
                              day.trainingFocus!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!day.isCompleted)
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _completeDay(day.id);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        color: AppColors.success,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 动作列表
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: exercisesByType.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final entry = exercisesByType.entries.elementAt(index);
                    return _buildExerciseTypeGroup(entry.key, entry.value, day.trainingFocus ?? '综合训练');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 按类型分组的动作列表
  Widget _buildExerciseTypeGroup(
    String type,
    List<WorkoutPlanExercise> exercises,
    String dayTrainingFocus,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getExerciseTypeText(type),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final exercise = entry.value;
          return _buildExerciseItem(exercise, index + 1, dayTrainingFocus);
        }),
      ],
    );
  }

  /// 动作项
  Widget _buildExerciseItem(
    WorkoutPlanExercise exercise,
    int order,
    String dayTrainingFocus,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.smRadius,
                ),
                child: Center(
                  child: Text(
                    '$order',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (exercise.difficulty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(exercise.difficulty!).withOpacity(0.15),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Text(
                    _getDifficultyText(exercise.difficulty!),
                    style: TextStyle(
                      color: _getDifficultyColor(exercise.difficulty!),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // 替换按钮
              InkWell(
                onTap: () async {
                  await HapticHelper.lightTap();
                  _replaceExercise(exercise, dayTrainingFocus);
                },
                borderRadius: AppRadius.smRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync_alt,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '替换',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (exercise.description != null) ...[
            const SizedBox(height: 8),
            Text(
              exercise.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              if (exercise.sets != null)
                _buildTag(Icons.repeat, '${exercise.sets} 组'),
              if (exercise.repsDescription != null)
                _buildTag(Icons.format_list_numbered, exercise.repsDescription!),
              if (exercise.restSeconds != null)
                _buildTag(Icons.timer_outlined, '${exercise.restSeconds}s'),
              if (exercise.equipment != null)
                _buildTag(Icons.build_outlined, exercise.equipment!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error ?? '未知错误'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPlan,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 辅助方法 ====================

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'paused':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'paused':
        return '已暂停';
      default:
        return status;
    }
  }

  String _getGoalTypeText(String goalType) {
    switch (goalType) {
      case 'fat_loss':
        return '减脂';
      case 'muscle_gain':
        return '增肌';
      case 'shape':
        return '塑形';
      case 'maintain':
        return '保持';
      case 'fitness':
        return '健身';
      default:
        return goalType;
    }
  }

  String _getExerciseTypeText(String type) {
    switch (type) {
      case 'warmup':
        return '热身';
      case 'strength':
        return '力量训练';
      case 'cardio':
        return '有氧运动';
      case 'hiit':
        return 'HIIT';
      case 'stretching':
        return '拉伸';
      case 'cooldown':
        return '放松';
      default:
        return type;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return '简单';
      case 'medium':
        return '中等';
      case 'hard':
        return '困难';
      default:
        return difficulty;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 替换原因选择项
class _ReplaceReasonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _ReplaceReasonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab栏头部代理
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabHeaderDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}
