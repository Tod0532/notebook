/// 提醒模块页面 - 现代渐变风格
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:thick_notepad/shared/widgets/empty_state_widget.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/notification/notification_service.dart';
import 'package:drift/drift.dart' as drift;

/// 提醒视图（无 Scaffold，在 ShellRoute 内部）
class RemindersView extends ConsumerWidget {
  const RemindersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(allRemindersProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context, ref),
          // 提醒列表
          Expanded(
            child: remindersAsync.when(
              data: (reminders) {
                if (reminders.isEmpty) {
                  return _EmptyState(onTap: () => _showAddReminderSheet(context, ref));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return AnimatedListItem(
                      index: index,
                      child: _ReminderCard(
                        reminder: reminder,
                        onTap: () => _showReminderDetail(context, reminder),
                        onToggle: () => _toggleComplete(ref, context, reminder),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(allRemindersProvider),
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
            '提醒',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: AppRadius.mdRadius,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              onPressed: () => _showAddReminderSheet(context, ref),
              padding: const EdgeInsets.all(AppSpacing.sm),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddReminderSheet(ref: ref),
    );
  }

  void _showReminderDetail(BuildContext context, dynamic reminder) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('提醒：${reminder.title}')),
    );
  }

  void _toggleComplete(WidgetRef ref, BuildContext context, dynamic reminder) async {
    final reminderRepo = ref.read(reminderRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);

    // 标记当前提醒为完成
    await reminderRepo.updateReminder(
      reminder.copyWith(isDone: true),
    );

    // 如果是重复提醒，创建下一个周期的提醒
    if (reminder.repeatType == 'daily') {
      final nextTime = reminder.remindTime.add(const Duration(days: 1));
      final newReminder = RemindersCompanion.insert(
        title: reminder.title,
        remindTime: nextTime,
        repeatType: drift.Value(reminder.repeatType),
      );
      final newId = await reminderRepo.createReminder(newReminder);

      // 安排下一个周期的通知
      await notificationService.scheduleDailyNotification(
        id: newId,
        title: reminder.title,
        body: '该完成这件事了',
        time: TimeOfDay.fromDateTime(nextTime),
      );
    } else if (reminder.repeatType == 'weekly') {
      final nextTime = reminder.remindTime.add(const Duration(days: 7));
      final newReminder = RemindersCompanion.insert(
        title: reminder.title,
        remindTime: nextTime,
        repeatType: drift.Value(reminder.repeatType),
      );
      final newId = await reminderRepo.createReminder(newReminder);

      // 安排下一个周期的通知
      await notificationService.scheduleWeeklyNotification(
        id: newId,
        title: reminder.title,
        body: '该完成这件事了',
        time: TimeOfDay.fromDateTime(nextTime),
        weekdays: [nextTime.weekday],
      );
    }

    ref.invalidate(allRemindersProvider);

    // 显示提示
    if (reminder.repeatType != 'none' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已完成，已创建下一个${_getRepeatLabel(reminder.repeatType)}提醒'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  String _getRepeatLabel(String repeatType) {
    switch (repeatType) {
      case 'daily':
        return '每日';
      case 'weekly':
        return '每周';
      default:
        return '';
    }
  }
}

/// 提醒卡片
class _ReminderCard extends StatelessWidget {
  final dynamic reminder;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = !reminder.isDone && reminder.remindTime.isBefore(now);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: isOverdue
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.dividerColor.withValues(alpha: 0.5),
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: isOverdue ? AppShadows.light : AppShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // 完成 checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: reminder.isDone ? AppColors.successGradient : null,
                      color: reminder.isDone ? null : AppColors.surfaceVariant,
                      border: Border.all(
                        color: reminder.isDone ? AppColors.success : AppColors.textHint,
                        width: 2,
                      ),
                    ),
                    child: reminder.isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              decoration: reminder.isDone ? TextDecoration.lineThrough : null,
                              color: reminder.isDone ? AppColors.textHint : null,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: isOverdue
                                  ? AppColors.errorGradient
                                  : AppColors.primaryGradient,
                              borderRadius: AppRadius.smRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(reminder.remindTime),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (reminder.repeatType != 'none') ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.repeat, size: 14, color: AppColors.primary),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDay = DateTime(time.year, time.month, time.day);

    String dateStr;
    if (reminderDay == today) {
      dateStr = '今天';
    } else if (reminderDay == tomorrow) {
      dateStr = '明天';
    } else {
      dateStr = '${time.month}月${time.day}日';
    }

    final timeStr = DateFormat('HH:mm').format(time);
    return '$dateStr $timeStr';
  }
}

/// 空状态（使用统一组件）
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget.reminders(onCreate: onTap);
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

/// 添加提醒底部表单
class _AddReminderSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _AddReminderSheet({required this.ref});

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleController = TextEditingController();
  DateTime _selectedTime = DateTime.now();
  String _repeatType = 'none';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
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
                '新提醒',
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
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '提醒事项',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildTimeSelector(context),
          _buildRepeatSelector(context),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveReminder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdRadius,
                ),
              ),
              child: const Text('保存提醒'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: AppRadius.smRadius,
          ),
          child: const Icon(Icons.access_time, color: AppColors.primary),
        ),
        title: const Text('提醒时间'),
        trailing: Text(
          DateFormat('HH:mm').format(_selectedTime),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: _selectTime,
      ),
    );
  }

  Widget _buildRepeatSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: AppRadius.smRadius,
          ),
          child: const Icon(Icons.repeat, color: AppColors.secondary),
        ),
        title: const Text('重复'),
        trailing: Text(
          _getRepeatLabel(),
          style: const TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: _selectRepeat,
      ),
    );
  }

  Future<void> _selectTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _selectRepeat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '重复',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RepeatOption(
              label: '不重复',
              value: 'none',
              selected: _repeatType == 'none',
              onTap: () => _setRepeat('none'),
            ),
            _RepeatOption(
              label: '每天',
              value: 'daily',
              selected: _repeatType == 'daily',
              onTap: () => _setRepeat('daily'),
            ),
            _RepeatOption(
              label: '每周',
              value: 'weekly',
              selected: _repeatType == 'weekly',
              onTap: () => _setRepeat('weekly'),
            ),
          ],
        ),
      ),
    );
  }

  void _setRepeat(String value) {
    setState(() => _repeatType = value);
    Navigator.pop(context);
  }

  String _getRepeatLabel() {
    switch (_repeatType) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      default:
        return '不重复';
    }
  }

  void _saveReminder() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入提醒事项')),
      );
      return;
    }

    final reminderRepo = widget.ref.read(reminderRepositoryProvider);
    final notificationService = widget.ref.read(notificationServiceProvider);

    // 检查通知权限
    final hasPermission = await notificationService.arePermissionsGranted();
    if (!hasPermission) {
      final granted = await notificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要通知权限才能发送提醒')),
        );
        return;
      }
    }

    // 构建提醒数据
    final reminder = RemindersCompanion.insert(
      title: _titleController.text.trim(),
      remindTime: _selectedTime,
      repeatType: drift.Value(_repeatType),
    );

    try {
      // 保存到数据库
      final reminderId = await reminderRepo.createReminder(reminder);

      // 安排推送通知
      if (reminderId > 0) {
        final scheduled = await _scheduleNotification(
          notificationService,
          reminderId,
          _titleController.text.trim(),
          _selectedTime,
          _repeatType,
        );

        widget.ref.invalidate(allRemindersProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(scheduled
                  ? '提醒已设置，届时会收到通知'
                  : '提醒已设置'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置提醒失败: $e')),
        );
      }
    }
  }

  /// 安排推送通知
  Future<bool> _scheduleNotification(
    NotificationService service,
    int id,
    String title,
    DateTime time,
    String repeatType,
  ) async {
    try {
      if (repeatType == 'daily') {
        // 每日重复
        await service.scheduleDailyNotification(
          id: id,
          title: title,
          body: '该完成这件事了',
          time: TimeOfDay.fromDateTime(time),
        );
        return true;
      } else if (repeatType == 'weekly') {
        // 每周重复
        await service.scheduleWeeklyNotification(
          id: id,
          title: title,
          body: '该完成这件事了',
          time: TimeOfDay.fromDateTime(time),
          weekdays: [time.weekday], // 当天重复
          payload: 'reminder:$id', // 添加 payload 用于点击跳转
        );
        return true;
      } else {
        // 单次提醒
        await service.scheduleNotification(
          id: id,
          title: title,
          body: '该完成这件事了',
          scheduledTime: time,
          payload: 'reminder:$id', // 添加 payload 用于点击跳转
        );
        return true;
      }
    } catch (e) {
      debugPrint('安排通知失败: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

/// 重复选项
class _RepeatOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _RepeatOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 18, color: Colors.white),
            )
          : null,
      onTap: onTap,
    );
  }
}
