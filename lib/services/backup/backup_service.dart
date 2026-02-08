/// 数据备份恢复服务
/// 支持导出和导入 JSON 格式的数据

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/reminders/data/models/reminder_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';
import 'package:thick_notepad/features/plans/data/models/plan_repository.dart';

/// 备份数据模型
class BackupData {
  final int version;
  final DateTime backupTime;
  final String appVersion;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> planTasks;

  const BackupData({
    required this.version,
    required this.backupTime,
    required this.appVersion,
    required this.notes,
    required this.reminders,
    required this.workouts,
    required this.plans,
    required this.planTasks,
  });

  /// 从 JSON 创建备份对象
  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] as int,
      backupTime: DateTime.parse(json['backupTime'] as String),
      appVersion: json['appVersion'] as String,
      notes: List<Map<String, dynamic>>.from(json['notes'] as List),
      reminders: List<Map<String, dynamic>>.from(json['reminders'] as List),
      workouts: List<Map<String, dynamic>>.from(json['workouts'] as List),
      plans: List<Map<String, dynamic>>.from(json['plans'] as List),
      planTasks: List<Map<String, dynamic>>.from(json['planTasks'] as List),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'backupTime': backupTime.toIso8601String(),
      'appVersion': appVersion,
      'notes': notes,
      'reminders': reminders,
      'workouts': workouts,
      'plans': plans,
      'planTasks': planTasks,
    };
  }

  /// 转换为 JSON 字符串
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// 备份服务
class BackupService {
  static const int _currentBackupVersion = 1;
  static const String _backupKey = 'data_backup';

  final NoteRepository _noteRepo;
  final ReminderRepository _reminderRepo;
  final WorkoutRepository _workoutRepo;
  final PlanRepository _planRepo;

  BackupService({
    required NoteRepository noteRepo,
    required ReminderRepository reminderRepo,
    required WorkoutRepository workoutRepo,
    required PlanRepository planRepo,
  })  : _noteRepo = noteRepo,
        _reminderRepo = reminderRepo,
        _workoutRepo = workoutRepo,
        _planRepo = planRepo;

  /// 创建数据备份
  Future<BackupData> createBackup() async {
    // 并行获取所有数据
    final results = await Future.wait([
      _noteRepo.getAllNotes(),
      _reminderRepo.getAllReminders(),
      _workoutRepo.getAllWorkouts(),
      _planRepo.getAllPlans(),
    ]);

    final notes = results[0] as List;
    final reminders = results[1] as List;
    final workouts = results[2] as List;
    final plans = results[3] as List;

    // 获取所有任务
    final planTasks = <Map<String, dynamic>>[];
    for (final plan in plans) {
      final tasks = await _planRepo.getPlanTasks(plan.id);
      planTasks.addAll(tasks.map((t) => t.toJson()).toList());
    }

    return BackupData(
      version: _currentBackupVersion,
      backupTime: DateTime.now(),
      appVersion: '1.0.1',
      notes: notes.map((n) => n.toJson() as Map<String, dynamic>).toList(),
      reminders: reminders.map((r) => r.toJson() as Map<String, dynamic>).toList(),
      workouts: workouts.map((w) => w.toJson() as Map<String, dynamic>).toList(),
      plans: plans.map((p) => p.toJson() as Map<String, dynamic>).toList(),
      planTasks: planTasks,
    );
  }

  /// 导出备份为 JSON 字符串
  Future<String> exportToJson() async {
    final backup = await createBackup();
    return backup.toJsonString();
  }

  /// 将备份保存到 SharedPreferences
  Future<bool> saveBackupLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = await exportToJson();
      await prefs.setString(_backupKey, json);
      return true;
    } catch (e) {
      debugPrint('保存备份失败: $e');
      return false;
    }
  }

  /// 从 SharedPreferences 获取本地备份
  Future<BackupData?> getLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_backupKey);
      if (json == null || json.isEmpty) return null;
      return BackupData.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint('获取本地备份失败: $e');
      return null;
    }
  }

  /// 从 JSON 字符串恢复数据
  Future<BackupRestoreResult> restoreFromJson(String jsonString) async {
    try {
      final backup = BackupData.fromJson(jsonDecode(jsonString));

      // 检查版本兼容性
      if (backup.version > _currentBackupVersion) {
        return BackupRestoreResult.failure('备份版本过高，不支持恢复');
      }

      // 清空现有数据
      await clearAllData();

      // 恢复数据
      final results = await Future.wait([
        _restoreNotes(backup.notes),
        _restoreReminders(backup.reminders),
        _restoreWorkouts(backup.workouts),
        _restorePlans(backup.plans),
      ]);

      final restoredNotes = results[0] as int;
      final restoredReminders = results[1] as int;
      final restoredWorkouts = results[2] as int;
      final restoredPlans = results[3] as int;

      // 恢复任务
      final restoredTasks = await _restorePlanTasks(backup.planTasks);

      return BackupRestoreResult.success(
        notes: restoredNotes,
        reminders: restoredReminders,
        workouts: restoredWorkouts,
        plans: restoredPlans,
        tasks: restoredTasks,
      );
    } catch (e) {
      return BackupRestoreResult.failure('恢复失败: $e');
    }
  }

  /// 从本地备份恢复
  Future<BackupRestoreResult> restoreFromLocal() async {
    final backup = await getLocalBackup();
    if (backup == null) {
      return BackupRestoreResult.failure('没有找到本地备份');
    }
    return restoreFromJson(jsonEncode(backup.toJson()));
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    await Future.wait([
      _noteRepo.deleteAllNotes(),
      _reminderRepo.deleteAllReminders(),
      _workoutRepo.deleteAllWorkouts(),
      _planRepo.deleteAllPlans(),
    ]);
  }

  /// 恢复笔记
  Future<int> _restoreNotes(List<Map<String, dynamic>> data) async {
    int count = 0;
    for (final item in data) {
      try {
        await _noteRepo.createNoteFromData(item);
        count++;
      } catch (e) {
        debugPrint('恢复笔记失败: $e');
      }
    }
    return count;
  }

  /// 恢复提醒
  Future<int> _restoreReminders(List<Map<String, dynamic>> data) async {
    int count = 0;
    for (final item in data) {
      try {
        await _reminderRepo.createReminderFromData(item);
        count++;
      } catch (e) {
        debugPrint('恢复提醒失败: $e');
      }
    }
    return count;
  }

  /// 恢复运动记录
  Future<int> _restoreWorkouts(List<Map<String, dynamic>> data) async {
    int count = 0;
    for (final item in data) {
      try {
        await _workoutRepo.createWorkoutFromData(item);
        count++;
      } catch (e) {
        debugPrint('恢复运动记录失败: $e');
      }
    }
    return count;
  }

  /// 恢复计划
  Future<int> _restorePlans(List<Map<String, dynamic>> data) async {
    int count = 0;
    for (final item in data) {
      try {
        await _planRepo.createPlanFromData(item);
        count++;
      } catch (e) {
        debugPrint('恢复计划失败: $e');
      }
    }
    return count;
  }

  /// 恢复计划任务
  Future<int> _restorePlanTasks(List<Map<String, dynamic>> data) async {
    int count = 0;
    for (final item in data) {
      try {
        await _planRepo.createTaskFromData(item);
        count++;
      } catch (e) {
        debugPrint('恢复任务失败: $e');
      }
    }
    return count;
  }

  /// 获取备份统计信息
  Future<BackupStats> getBackupStats() async {
    final results = await Future.wait([
      _noteRepo.getAllNotes(),
      _reminderRepo.getAllReminders(),
      _workoutRepo.getAllWorkouts(),
      _planRepo.getAllPlans(),
    ]);

    int taskCount = 0;
    for (final plan in results[3] as List) {
      final tasks = await _planRepo.getPlanTasks(plan.id);
      taskCount += tasks.length;
    }

    return BackupStats(
      notesCount: (results[0] as List).length,
      remindersCount: (results[1] as List).length,
      workoutsCount: (results[2] as List).length,
      plansCount: (results[3] as List).length,
      tasksCount: taskCount,
    );
  }
}

/// 备份恢复结果
class BackupRestoreResult {
  final bool success;
  final String? error;
  final int notes;
  final int reminders;
  final int workouts;
  final int plans;
  final int tasks;

  const BackupRestoreResult({
    required this.success,
    this.error,
    this.notes = 0,
    this.reminders = 0,
    this.workouts = 0,
    this.plans = 0,
    this.tasks = 0,
  });

  factory BackupRestoreResult.success({
    int notes = 0,
    int reminders = 0,
    int workouts = 0,
    int plans = 0,
    int tasks = 0,
  }) {
    return BackupRestoreResult(
      success: true,
      notes: notes,
      reminders: reminders,
      workouts: workouts,
      plans: plans,
      tasks: tasks,
    );
  }

  factory BackupRestoreResult.failure(String error) {
    return BackupRestoreResult(
      success: false,
      error: error,
    );
  }

  String get message {
    if (success) {
      return '恢复成功: 笔记 $notes 条, 提醒 $reminders 条, 运动 $workouts 条, 计划 $plans 个, 任务 $tasks 个';
    }
    return error ?? '恢复失败';
  }
}

/// 备份统计信息
class BackupStats {
  final int notesCount;
  final int remindersCount;
  final int workoutsCount;
  final int plansCount;
  final int tasksCount;

  const BackupStats({
    required this.notesCount,
    required this.remindersCount,
    required this.workoutsCount,
    required this.plansCount,
    required this.tasksCount,
  });

  int get total => notesCount + remindersCount + workoutsCount + plansCount + tasksCount;
}
