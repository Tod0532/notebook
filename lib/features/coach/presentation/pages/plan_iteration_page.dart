/// 计划迭代提醒页面
/// 展示计划迭代状态、优化建议、一键迭代功能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/ai/plan_iteration_service.dart';
import 'package:thick_notepad/features/coach/presentation/pages/feedback_page.dart';

/// 计划迭代页面
class PlanIterationPage extends ConsumerStatefulWidget {
  final int? userProfileId;
  final int? workoutPlanId;
  final int? dietPlanId;

  const PlanIterationPage({
    super.key,
    this.userProfileId,
    this.workoutPlanId,
    this.dietPlanId,
  });

  @override
  ConsumerState<PlanIterationPage> createState() => _PlanIterationPageState();
}

class _PlanIterationPageState extends ConsumerState<PlanIterationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isIterating = false;
  String? _error;

  // 计划状态
  Map<String, dynamic>? _workoutPlanStatus;
  Map<String, dynamic>? _dietPlanStatus;

  // 优化建议
  List<Map<String, dynamic>> _workoutSuggestions = [];
  List<Map<String, dynamic>> _dietSuggestions = [];

  // 反馈统计
  Map<String, int> _feedbackStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 并行加载多个数据源
      final results = await Future.wait([
        _loadWorkoutPlanStatus(),
        _loadDietPlanStatus(),
        _loadFeedbackStats(),
        _loadOptimizationSuggestions(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 加载训练计划状态
  Future<void> _loadWorkoutPlanStatus() async {
    if (widget.workoutPlanId == null) {
      _workoutPlanStatus = null;
      return;
    }

    final repo = ref.read(workoutPlanRepositoryProvider);
    final plan = await repo.getPlanById(widget.workoutPlanId!);

    if (plan != null) {
      final status = await PlanIterationService.instance.getPlanStatus(
        planType: 'workout',
        planId: widget.workoutPlanId!,
      );

      _workoutPlanStatus = {
        'plan': plan,
        'status': status,
        'daysSinceUpdate': status != null
            ? DateTime.now().difference(status.lastUpdateDate).inDays
            : 0,
        'progress': status?.progress ?? 0.0,
        'daysUntilReminder': status?.daysUntilReminder ?? 0,
      };
    }
  }

  /// 加载饮食计划状态
  Future<void> _loadDietPlanStatus() async {
    if (widget.dietPlanId == null) {
      _dietPlanStatus = null;
      return;
    }

    // 简化处理，实际项目中需要获取diet plan
    _dietPlanStatus = {
      'planId': widget.dietPlanId,
      'status': null,
      'daysSinceUpdate': 0,
      'progress': 0.0,
      'daysUntilReminder': 0,
    };
  }

  /// 加载反馈统计
  Future<void> _loadFeedbackStats() async {
    if (widget.userProfileId == null) return;

    final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
    final stats = await feedbackRepo.getFeedbackCountByReason(
      userProfileId: widget.userProfileId,
    );

    setState(() {
      _feedbackStats = stats;
    });
  }

  /// 加载优化建议
  Future<void> _loadOptimizationSuggestions() async {
    if (widget.workoutPlanId == null && widget.dietPlanId == null) return;
    if (widget.userProfileId == null) return;

    final iterationService = PlanIterationService.instance;

    if (widget.workoutPlanId != null) {
      try {
        final suggestions = await iterationService.getOptimizationSuggestions(
          planType: 'workout',
          planId: widget.workoutPlanId!,
          userProfileId: widget.userProfileId!,
        );
        setState(() {
          _workoutSuggestions = suggestions;
        });
      } catch (e) {
        debugPrint('加载训练优化建议失败: $e');
      }
    }

    if (widget.dietPlanId != null) {
      try {
        final suggestions = await iterationService.getOptimizationSuggestions(
          planType: 'diet',
          planId: widget.dietPlanId!,
          userProfileId: widget.userProfileId!,
        );
        setState(() {
          _dietSuggestions = suggestions;
        });
      } catch (e) {
        debugPrint('加载饮食优化建议失败: $e');
      }
    }
  }

  /// 执行训练计划迭代
  Future<void> _iterateWorkoutPlan() async {
    if (widget.workoutPlanId == null || widget.userProfileId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI重新生成训练计划'),
        content: const Text('将根据您的反馈数据重新生成训练计划，当前计划将被替换。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始生成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isIterating = true;
    });

    try {
      final iterationService = PlanIterationService.instance;
      final newPlan = await iterationService.executePlanIteration(
        planType: 'workout',
        planId: widget.workoutPlanId!,
        userProfileId: widget.userProfileId!,
      );

      if (newPlan != null && mounted) {
        await HapticHelper.successTap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('训练计划已重新生成！'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() {
        _isIterating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('计划优化'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '概览', icon: Icon(Icons.dashboard_outlined)),
          Tab(text: '建议', icon: Icon(Icons.lightbulb_outlined)),
        ],
      ),
    );
  }

  /// 主体内容
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildSuggestionsTab(),
      ],
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 计划状态卡片
          if (_workoutPlanStatus != null) ...[
            _buildPlanStatusCard(
              title: '训练计划',
              planName: _workoutPlanStatus!['plan']?.name ?? '训练计划',
              daysSinceUpdate: _workoutPlanStatus!['daysSinceUpdate'] ?? 0,
              progress: _workoutPlanStatus!['progress'] ?? 0.0,
              daysUntilReminder: _workoutPlanStatus!['daysUntilReminder'] ?? 0,
              icon: Icons.fitness_center,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
          ],

          // 反馈统计卡片
          _buildFeedbackStatsCard(),
          const SizedBox(height: 16),

          // 快速操作
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  /// 计划状态卡片
  Widget _buildPlanStatusCard({
    required String title,
    required String planName,
    required int daysSinceUpdate,
    required double progress,
    required int daysUntilReminder,
    required IconData icon,
    required Color color,
  }) {
    final isReadyToIterate = daysUntilReminder <= 0;
    final progressText = isReadyToIterate ? '可以更新' : '还需 $daysUntilReminder 天';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: isReadyToIterate ? color : color.withOpacity(0.3),
          width: isReadyToIterate ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      planName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReadyToIterate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Text(
                    '可更新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.schedule,
                  label: '已运行',
                  value: '$daysSinceUpdate 天',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.dividerColor,
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.update,
                  label: '更新状态',
                  value: progressText,
                  valueColor: isReadyToIterate ? color : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条
          ClipRRect(
            borderRadius: AppRadius.smRadius,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textHint),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 反馈统计卡片
  Widget _buildFeedbackStatsCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '反馈统计',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedbackPage(
                        userProfileId: widget.userProfileId,
                        workoutPlanId: widget.workoutPlanId,
                        dietPlanId: widget.dietPlanId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加反馈'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_feedbackStats.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.feedback_outlined, size: 48, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text(
                      '还没有反馈记录',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._feedbackStats.entries.map((entry) {
              final reason = _getFeedbackReasonText(entry.key);
              final count = entry.value;
              return _buildFeedbackStatItem(reason, count);
            }),
        ],
      ),
    );
  }

  /// 反馈统计项
  Widget _buildFeedbackStatItem(String reason, int count) {
    Color color;
    IconData icon;

    switch (reason) {
      case '太难':
        color = AppColors.error;
        icon = Icons.trending_up;
        break;
      case '太简单':
        color = AppColors.warning;
        icon = Icons.trending_down;
        break;
      case '不喜欢':
        color = AppColors.textHint;
        icon = Icons.not_interested;
        break;
      case '买不到':
        color = AppColors.error;
        icon = Icons.shopping_cart_off;
        break;
      case '太难做':
        color = AppColors.warning;
        icon = Icons.restaurant;
        break;
      default:
        color = AppColors.info;
        icon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 快速操作卡片
  Widget _buildQuickActionsCard() {
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
            '快速操作',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            icon: Icons.refresh,
            title: 'AI重新生成',
            description: '根据反馈数据重新生成计划',
            color: AppColors.primary,
            onTap: _iterateWorkoutPlan,
            isLoading: _isIterating,
          ),
          const Divider(height: 24),
          _buildActionItem(
            icon: Icons.feedback,
            title: '添加反馈',
            description: '记录对计划中项目的问题',
            color: AppColors.secondary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackPage(
                    userProfileId: widget.userProfileId,
                    workoutPlanId: widget.workoutPlanId,
                    dietPlanId: widget.dietPlanId,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionItem(
            icon: Icons.history,
            title: '查看反馈历史',
            description: '查看所有反馈记录',
            color: AppColors.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackPage(
                    userProfileId: widget.userProfileId,
                    workoutPlanId: widget.workoutPlanId,
                    dietPlanId: widget.dietPlanId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 操作项
  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: AppRadius.mdRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: color, size: 20),
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
                    description,
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

  /// 建议标签页
  Widget _buildSuggestionsTab() {
    final allSuggestions = [
      ..._workoutSuggestions.map((s) => {...s, 'type': 'workout'}),
      ..._dietSuggestions.map((s) => {...s, 'type': 'diet'}),
    ];

    if (allSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              '暂无优化建议',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '添加更多反馈后，AI将为您生成个性化建议',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allSuggestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final suggestion = allSuggestions[index];
        return _buildSuggestionCard(suggestion);
      },
    );
  }

  /// 建议卡片
  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    final priority = suggestion['priority'] as String? ?? 'medium';
    final title = suggestion['title'] as String? ?? '';
    final description = suggestion['description'] as String? ?? '';
    final type = suggestion['type'] as String? ?? 'workout';

    final priorityColor = _getPriorityColor(priority);
    final priorityText = _getPriorityText(priority);
    final typeIcon = type == 'workout' ? Icons.fitness_center : Icons.restaurant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(typeIcon, color: priorityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Text(
                        priorityText,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 优先级颜色
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.textHint;
    }
  }

  /// 优先级文本
  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return '';
    }
  }

  /// 获取反馈原因文本
  String _getFeedbackReasonText(String reason) {
    const map = {
      'too_hard': '太难',
      'too_easy': '太简单',
      'dislike': '不喜欢',
      'no_equipment': '没器械',
      'injury': '身体不适合',
      'unavailable': '买不到',
      'too_hard': '太难做',
      'allergy': '过敏',
      'too_expensive': '太贵',
    };
    return map[reason] ?? reason;
  }

  /// 浮动操作按钮
  Widget? _buildFloatingActionButton() {
    return null; // 已在快速操作中包含
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
            const Text(
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
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
