/// 提醒模块 Providers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/provider_invalidator.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/notification/notification_service.dart';

// ==================== 提醒列表 Providers ====================

/// 所有提醒 Provider
final allRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final repository = ref.watch(reminderRepositoryProvider);
  return await repository.getAllReminders();
});

/// 未完成提醒 Provider
final pendingRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final repository = ref.watch(reminderRepositoryProvider);
  return await repository.getPendingReminders();
});

/// 已完成提醒 Provider
final completedRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final repository = ref.watch(reminderRepositoryProvider);
  return await repository.getCompletedReminders();
});

/// 今日提醒 Provider
final todayRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final repository = ref.watch(reminderRepositoryProvider);
  return await repository.getTodayReminders();
});

/// 单个提醒 Provider 族
final reminderProvider = FutureProvider.autoDispose.family<Reminder?, int>((ref, id) async {
  final repository = ref.watch(reminderRepositoryProvider);
  return await repository.getReminderById(id);
});

// ==================== 通知服务 Provider ====================

/// 通知服务 Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ==================== 提醒操作 Providers ====================

/// 更新提醒 Provider
final updateReminderProvider = Provider.autoDispose((ref) {
  return UpdateReminderNotifier(ref);
});

class UpdateReminderNotifier {
  final Ref ref;
  UpdateReminderNotifier(this.ref);

  Future<void> toggleComplete(Reminder reminder) async {
    final repo = ref.read(reminderRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);

    if (reminder.isDone) {
      await repo.markAsIncomplete(reminder.id);
    } else {
      await repo.markAsComplete(reminder.id);
      // 检查是否需要创建下一个重复提醒
      if (reminder.repeatType != 'none' && reminder.repeatType != null) {
        final nextId = await repo.createNextReminder(reminder);
        // 如果创建了下一个提醒，安排推送通知
        if (nextId != null && nextId > 0) {
          final nextReminder = await repo.getReminderById(nextId);
          if (nextReminder != null) {
            await notificationService.scheduleNotification(
              id: nextId,
              title: nextReminder.title,
              body: '该完成任务了',
              scheduledTime: nextReminder.remindTime,
            );
          }
        }
      }
      // 取消已完成的通知
      await notificationService.cancelNotification(reminder.id);
    }

    ProviderInvalidator.invalidateAfterReminderRef(ref);
  }

  Future<void> delete(int id) async {
    await ref.read(reminderRepositoryProvider).deleteReminder(id);
    await ref.read(notificationServiceProvider).cancelNotification(id);
    ProviderInvalidator.invalidateAfterReminderRef(ref);
  }
}
