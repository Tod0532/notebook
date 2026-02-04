/// 计划模块页面 - 现代渐变风格
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/shared/widgets/progress_components.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// 计划视图（无 Scaffold，在 ShellRoute 内部）
class PlansView extends ConsumerWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansProvider);
    final todayTasksAsync = ref.watch(todayTasksProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context, ref),
          // 今日任务卡片
          todayTasksAsync.when(
            data: (tasks) {
              final totalTasks = tasks.length;
              final completedTasks = tasks.where((t) => t.isCompleted).length;
              return _TodayTasksCard(
                totalTasks: totalTasks,
                completedTasks: completedTasks,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // 计划列表
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return _EmptyState(onTap: () => _showCreatePlanSheet(context, ref));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return AnimatedListItem(
                      index: index,
                      child: _PlanCard(
                        plan: plan,
                        onTap: () => _showPlanDetail(context, plan),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(allPlansProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '计划',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Row(
            children: [
              // 日历视图切换按钮
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_month, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _switchToCalendarView(context),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  constraints: const BoxConstraints(),
                  tooltip: '日历视图',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.warningGradient,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                  onPressed: () => _showCreatePlanSheet(context, ref),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _switchToCalendarView(BuildContext context) {
    context.push('/plans/calendar');
  }

  void _showCreatePlanSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePlanSheet(ref: ref),
    );
  }

  void _showPlanDetail(BuildContext context, dynamic plan) {
    context.push('/plans/${plan.id}');
  }
}

/// 今日任务卡片 - 现代渐变风格
class _TodayTasksCard extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;

  const _TodayTasksCard({
    required this.totalTasks,
    required this.completedTasks,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalTasks - completedTasks;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.infoGradient,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: AppRadius.lgRadius,
                ),
                child: const Icon(Icons.today_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '今日任务',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (totalTasks > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已完成 $completedTasks / $totalTasks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                if (remaining > 0)
                  Text(
                    '剩余 $remaining 项',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.smRadius,
              child: LinearProgressIndicator(
                value: (progress > 1.0 ? 1.0 : (progress < 0.0 ? 0.0 : progress)).toDouble(),
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '今天还没有安排任务',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 计划卡片
class _PlanCard extends StatelessWidget {
  final dynamic plan;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.onTap,
  });

  double get progress => plan.totalTasks > 0 ? plan.completedTasks / plan.totalTasks : 0;

  Color get _categoryColor {
    switch (plan.category) {
      case 'workout':
        return AppColors.primary;
      case 'study':
        return const Color(0xFF6C5CE7);
      case 'work':
        return const Color(0xFF0984E3);
      case 'habit':
        return const Color(0xFF00B894);
      default:
        return AppColors.textSecondary;
    }
  }

  String get _categoryName {
    switch (plan.category) {
      case 'workout':
        return '运动';
      case 'study':
        return '学习';
      case 'work':
        return '工作';
      case 'habit':
        return '习惯';
      default:
        return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = plan.targetDate.difference(DateTime.now()).inDays;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标签行
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _categoryColor.withValues(alpha: 0.2),
                            _categoryColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Text(
                        _categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _categoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (plan.streakDays > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.warningGradient,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${plan.streakDays}天',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // 标题
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (plan.description != null && plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // 进度条和日期
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: AppRadius.smRadius,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(_categoryColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${plan.completedTasks}/${plan.totalTasks} 已完成',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textHint,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: daysLeft < 0 ? AppColors.error : _categoryColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          daysLeft < 0 ? '已超期' : '还剩${daysLeft}天',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: daysLeft < 0 ? AppColors.error : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '制定计划，达成目标',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '将大目标分解为每日任务',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('创建计划'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误视图
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 创建计划底部表单
class _CreatePlanSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreatePlanSheet({required this.ref});

  @override
  ConsumerState<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends ConsumerState<_CreatePlanSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'workout';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '创建计划',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '计划目标（如：减重5公斤）',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: '描述（可选）',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _buildCategorySelector(context),
          _buildDateSelector(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createPlan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('创建计划'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.category_outlined, color: AppColors.primary),
        ),
        title: const Text('分类'),
        trailing: DropdownButton<String>(
          value: _category,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'workout', child: Text('运动')),
            DropdownMenuItem(value: 'study', child: Text('学习')),
            DropdownMenuItem(value: 'work', child: Text('工作')),
            DropdownMenuItem(value: 'habit', child: Text('习惯')),
          ],
          onChanged: (value) => setState(() => _category = value!),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.event_outlined, color: AppColors.secondary),
        ),
        title: const Text('目标日期'),
        trailing: Text(
          DateFormat('M月d日').format(_targetDate),
          style: const TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: _selectDate,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _createPlan() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入计划目标')),
      );
      return;
    }

    final now = DateTime.now();
    final plan = PlansCompanion.insert(
      title: _titleController.text.trim(),
      category: _category,
      startDate: DateTime(now.year, now.month, now.day),
      targetDate: DateTime(_targetDate.year, _targetDate.month, _targetDate.day),
      description: _descriptionController.text.trim().isEmpty
          ? const drift.Value.absent()
          : drift.Value(_descriptionController.text.trim()),
    );

    widget.ref.read(planRepositoryProvider).createPlan(plan).then((id) {
      if (id > 0 && mounted) {
        widget.ref.invalidate(allPlansProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划已创建')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建失败，请重试')),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
