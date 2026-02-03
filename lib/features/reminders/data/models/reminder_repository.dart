/// 提醒仓库 - 封装提醒相关的数据库操作

import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class ReminderRepository {
  final AppDatabase _db;

  ReminderRepository(this._db);

  /// 获取所有提醒
  Future<List<Reminder>> getAllReminders() async {
    return await (_db.select(_db.reminders)
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.remindTime)]))
        .get();
  }

  /// 获取未完成的提醒
  Future<List<Reminder>> getPendingReminders() async {
    final now = DateTime.now();
    return await (_db.select(_db.reminders)
          ..where((tbl) =>
              tbl.isDone.equals(false) &
              tbl.isEnabled.equals(true) &
              tbl.remindTime.isSmallerThanValue(now.add(const Duration(hours: 24))))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.remindTime)]))
        .get();
  }

  /// 获取已完成的提醒
  Future<List<Reminder>> getCompletedReminders() async {
    return await (_db.select(_db.reminders)
          ..where((tbl) => tbl.isDone.equals(true))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.completedAt)]))
        .get();
  }

  /// 获取今日提醒
  Future<List<Reminder>> getTodayReminders() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return await (_db.select(_db.reminders)
          ..where((tbl) =>
              tbl.remindTime.isBiggerOrEqualValue(todayStart) &
              tbl.remindTime.isSmallerThanValue(todayEnd)))
        .get();
  }

  /// 获取单个提醒
  Future<Reminder?> getReminderById(int id) async {
    return await (_db.select(_db.reminders)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建提醒
  Future<int> createReminder(RemindersCompanion reminder) async {
    return await _db.into(_db.reminders).insert(reminder);
  }

  /// 更新提醒
  Future<bool> updateReminder(Reminder reminder) async {
    return await _db.update(_db.reminders).replace(reminder);
  }

  /// 删除提醒
  Future<int> deleteReminder(int id) async {
    return await (_db.delete(_db.reminders)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 标记提醒为完成
  Future<void> markAsComplete(int id) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.id.equals(id))).write(
      RemindersCompanion(
        isDone: const drift.Value(true),
        completedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 标记提醒为未完成
  Future<void> markAsIncomplete(int id) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.id.equals(id))).write(
      RemindersCompanion(
        isDone: const drift.Value(false),
        completedAt: const drift.Value(null),
      ),
    );
  }

  /// 切换启用状态
  Future<void> toggleEnabled(Reminder reminder) async {
    await updateReminder(reminder.copyWith(isEnabled: !reminder.isEnabled));
  }

  /// 获取需要重复的提醒
  Future<List<Reminder>> getRepeatableReminders() async {
    return await (_db.select(_db.reminders)
          ..where((tbl) =>
              tbl.isDone.equals(true) &
              tbl.repeatType.isNotIn(['none']) &
              tbl.isEnabled.equals(true)))
        .get();
  }

  /// 创建重复提醒的下一个实例
  Future<int?> createNextReminder(Reminder completed) {
    final repeatType = RepeatType.fromString(completed.repeatType);
    DateTime nextTime = completed.remindTime;

    switch (repeatType) {
      case RepeatType.daily:
        nextTime = nextTime.add(const Duration(days: 1));
        break;
      case RepeatType.weekly:
        nextTime = nextTime.add(const Duration(days: 7));
        break;
      case RepeatType.monthly:
        nextTime = DateTime(nextTime.year, nextTime.month + 1, nextTime.day);
        break;
      default:
        return Future.value(null);
    }

    // 检查是否超过结束日期
    if (completed.repeatEndDate != null && nextTime.isAfter(completed.repeatEndDate!)) {
      return Future.value(null);
    }

    return createReminder(
      RemindersCompanion.insert(
        title: completed.title,
        remindTime: nextTime,
        description: drift.Value(completed.description),
        repeatType: drift.Value(completed.repeatType),
        repeatDays: drift.Value(completed.repeatDays),
        repeatEndDate: drift.Value(completed.repeatEndDate),
        linkedPlanId: drift.Value(completed.linkedPlanId),
        linkedWorkoutId: drift.Value(completed.linkedWorkoutId),
      ),
    );
  }

  /// 删除所有提醒
  Future<void> deleteAllReminders() async {
    await _db.delete(_db.reminders).go();
  }

  /// 从 JSON 数据创建提醒（用于备份恢复）
  Future<int> createReminderFromData(Map<String, dynamic> data) async {
    final companion = RemindersCompanion.insert(
      title: data['title'] as String,
      remindTime: DateTime.parse(data['remind_time'] as String),
      description: drift.Value(data['description'] as String? ?? ''),
      repeatType: drift.Value(data['repeat_type'] as String? ?? 'none'),
      repeatDays: drift.Value(data['repeat_days'] as String? ?? ''),
      repeatEndDate: data['repeat_end_date'] != null
          ? drift.Value(DateTime.parse(data['repeat_end_date'] as String))
          : const drift.Value.absent(),
      linkedPlanId: drift.Value(data['linked_plan_id'] as int?),
      linkedWorkoutId: drift.Value(data['linked_workout_id'] as int?),
      isEnabled: data['is_enabled'] as bool? ?? true ? const drift.Value(true) : const drift.Value(false),
      isDone: data['is_done'] as bool? ?? false ? const drift.Value(true) : const drift.Value(false),
      completedAt: data['completed_at'] != null
          ? drift.Value(DateTime.parse(data['completed_at'] as String))
          : const drift.Value.absent(),
    );
    return await _db.into(_db.reminders).insert(companion);
  }
}
