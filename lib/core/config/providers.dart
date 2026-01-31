/// 全局 Providers
/// 提供数据库和仓库实例

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/reminders/data/models/reminder_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';
import 'package:thick_notepad/features/plans/data/models/plan_repository.dart';

// ==================== 数据库 Provider ====================

/// 数据库单例 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return DatabaseProvider.instance;
});

// ==================== 仓库 Providers ====================

/// 笔记仓库 Provider
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseProvider));
});

/// 提醒仓库 Provider
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(databaseProvider));
});

/// 运动仓库 Provider
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(databaseProvider));
});

/// 计划仓库 Provider
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(databaseProvider));
});
