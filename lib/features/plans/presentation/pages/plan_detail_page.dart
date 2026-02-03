/// 计划详情页面
/// 显示计划的任务列表，支持添加/编辑/完成任务

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/notification/notification_service.dart';
import 'package:drift/drift.dart' as drift;

/// 计划详情页面
class PlanDetailPage extends ConsumerStatefulWidget {
  final int planId;

  const PlanDetailPage({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage> {
  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planProvider(widget.planId));
    final tasksAsync = ref.watch(planTasksProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeletePlan(context),
          ),
        ],
      ),
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('计划不存在'));
          }
          return Column(
            children: [
              _buildPlanHeader(context, plan),
              Expanded(
                child: tasksAsync.when(
                  data: (tasks) {
                    if (tasks.isEmpty) {
                      return _EmptyTasksState(
                        planId: widget.planId,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return _TaskTile(
                          task: tasks[index],
                          onToggle: () => _toggleTask(tasks[index]),
                          onDelete: () => _confirmDeleteTask(tasks[index]),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('加载任务失败')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('加载计划失败')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context, Plan plan) {
    final progress = plan.totalTasks > 0 ? plan.completedTasks / plan.totalTasks : 0;
    final daysLeft = plan.targetDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.toDouble(),
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${plan.completedTasks}/${plan.totalTasks} 已完成',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: daysLeft < 0 ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysLeft < 0 ? '已超期' : '还剩${daysLeft}天',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: daysLeft < 0 ? AppColors.error : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (plan.streakDays > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    '已连续坚持 ${plan.streakDays} 天',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleTask(PlanTask task) async {
    final notifier = ref.read(updateTaskProvider);
    if (task.isCompleted) {
      await notifier.toggleComplete(task);
    } else {
      await notifier.toggleComplete(task);
    }
  }

  Future<void> _confirmDeleteTask(PlanTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除任务"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(updateTaskProvider).delete(task.id);
    }
  }

  Future<void> _confirmDeletePlan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除计划'),
        content: const Text('删除计划将同时删除所有任务，此操作不可恢复。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(updatePlanProvider).delete(widget.planId);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTaskSheet(planId: widget.planId),
    );
  }
}

/// 任务列表项
class _TaskTile extends StatelessWidget {
  final PlanTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = task.scheduledDate.year == now.year &&
        task.scheduledDate.month == now.month &&
        task.scheduledDate.day == now.day;
    final isPast = task.scheduledDate.isBefore(DateTime(now.year, now.month, now.day));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: task.isCompleted ? AppColors.surfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? AppColors.success : Colors.white,
              border: Border.all(
                color: task.isCompleted ? AppColors.success : AppColors.textHint,
              ),
            ),
            child: task.isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? AppColors.textHint : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 12,
              color: isPast ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isToday
                  ? '今天'
                  : isPast
                      ? '已过期'
                      : DateFormat('M月d日').format(task.scheduledDate),
              style: TextStyle(
                fontSize: 11,
                color: isPast ? AppColors.error : AppColors.primary,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.textHint,
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// 空任务状态
class _EmptyTasksState extends StatelessWidget {
  final int planId;

  const _EmptyTasksState({required this.planId});

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
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有任务',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加第一个任务',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

/// 添加任务底部表单
class _AddTaskSheet extends ConsumerStatefulWidget {
  final int planId;

  const _AddTaskSheet({required this.planId});

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _titleController = TextEditingController();
  DateTime _scheduledDate = DateTime.now();
  bool _enableReminder = false;
  TimeOfDay _reminderTime = TimeOfDay.now();
  String _taskType = 'workout';

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
                '添加任务',
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
              hintText: '任务内容',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 12),
          _buildDateSelector(context),
          const SizedBox(height: 12),
          _buildTaskTypeSelector(context),
          const SizedBox(height: 12),
          _buildReminderSection(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('添加任务'),
            ),
          ),
        ],
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
        leading: const Icon(Icons.calendar_today, color: AppColors.primary),
        title: const Text('计划日期'),
        trailing: Text(
          DateFormat('M月d日').format(_scheduledDate),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: _selectDate,
      ),
    );
  }

  Widget _buildTaskTypeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.category_outlined, color: AppColors.secondary),
        title: const Text('任务类型'),
        trailing: DropdownButton<String>(
          value: _taskType,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'workout', child: Text('运动')),
            DropdownMenuItem(value: 'study', child: Text('学习')),
            DropdownMenuItem(value: 'work', child: Text('工作')),
            DropdownMenuItem(value: 'other', child: Text('其他')),
          ],
          onChanged: (value) => setState(() => _taskType = value!),
        ),
      ),
    );
  }

  Widget _buildReminderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _enableReminder
            ? AppColors.warning.withOpacity(0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('设置提醒'),
            subtitle: const Text('在任务时间前提醒你'),
            value: _enableReminder,
            onChanged: (value) => setState(() => _enableReminder = value),
            activeColor: AppColors.warning,
          ),
          if (_enableReminder) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, size: 20),
              title: const Text('提醒时间'),
              trailing: Text(
                '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _selectReminderTime,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _selectReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务内容')),
      );
      return;
    }

    final planRepo = ref.read(planRepositoryProvider);
    final reminderRepo = ref.read(reminderRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);

    try {
      // 创建任务
      final task = PlanTasksCompanion.insert(
        planId: widget.planId,
        title: _titleController.text.trim(),
        scheduledDate: _scheduledDate,
        taskType: _taskType.toLowerCase(),
      );

      final taskId = await planRepo.createTask(task);

      // 如果需要提醒
      if (_enableReminder && taskId > 0) {
        final reminderDateTime = DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          _reminderTime.hour,
          _reminderTime.minute,
        );

        // 如果提醒时间已过，设置为明天
        final finalReminderTime = reminderDateTime.isBefore(DateTime.now())
            ? reminderDateTime.add(const Duration(days: 1))
            : reminderDateTime;

        final reminder = RemindersCompanion.insert(
          title: _titleController.text.trim(),
          remindTime: finalReminderTime,
          repeatType: const drift.Value('none'),
          linkedPlanId: drift.Value(widget.planId),
        );

        final reminderId = await reminderRepo.createReminder(reminder);
        await planRepo.linkReminderToTask(taskId, reminderId);

        // 安排推送通知
        await notificationService.scheduleNotification(
          id: reminderId,
          title: _titleController.text.trim(),
          body: '该完成任务了',
          scheduledTime: finalReminderTime,
          payload: 'reminder:$reminderId', // 添加 payload 用于点击跳转
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_enableReminder
                ? '任务已添加，提醒已设置'
                : '任务已添加'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
