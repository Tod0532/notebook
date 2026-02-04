/// 计划日历 Provider
/// 提供日历视图所需的数据

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/provider_invalidator.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 日历事件模型 ====================

/// 任务完成状态枚举
enum TaskCompletionStatus {
  /// 待完成
  pending,
  /// 已完成
  completed,
  /// 已逾期
  overdue,
}

/// 日历事件
class CalendarEvent {
  /// 事件ID（任务ID）
  final int id;
  /// 事件标题
  final String title;
  /// 关联的计划标题
  final String? planTitle;
  /// 计划ID
  final int? planId;
  /// 完成状态
  final TaskCompletionStatus status;
  /// 计划分类
  final String? category;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.planTitle,
    this.planId,
    required this.status,
    this.category,
  });

  /// 从任务创建事件
  factory CalendarEvent.fromTask(PlanTask task, Plan? plan) {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    TaskCompletionStatus status;
    if (task.isCompleted) {
      status = TaskCompletionStatus.completed;
    } else if (scheduledDate.isBefore(today)) {
      status = TaskCompletionStatus.overdue;
    } else {
      status = TaskCompletionStatus.pending;
    }

    return CalendarEvent(
      id: task.id,
      title: task.title,
      planTitle: plan?.title,
      planId: task.planId,
      status: status,
      category: plan?.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ==================== 日历事件 Providers ====================

/// 日历事件 Provider
/// 返回按日期分组的事件映射
final calendarEventsProvider = FutureProvider.autoDispose<Map<DateTime, List<CalendarEvent>>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);

  // 获取前后3个月范围内的任务
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - 3, 1);
  final endDate = DateTime(now.year, now.month + 4, 0);

  // 使用新增的按日期范围获取任务方法
  final allTasks = await repository.getTasksByDateRange(startDate, endDate);

  // 获取所有计划用于显示计划名称
  final plans = await repository.getAllPlans();
  final planMap = {for (var plan in plans) plan.id: plan};

  // 转换为日历事件
  final events = allTasks.map((task) {
    final plan = planMap[task.planId];
    return CalendarEvent.fromTask(task, plan);
  }).toList();

  // 按日期分组
  final eventsMap = <DateTime, List<CalendarEvent>>{};
  for (final event in events) {
    final task = allTasks.firstWhere((t) => t.id == event.id);
    final date = DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
    );

    eventsMap.putIfAbsent(date, () => []).add(event);
  }

  return eventsMap;
});

/// 指定日期的事件 Provider
final selectedDateEventsProvider = FutureProvider.autoDispose.family<List<CalendarEvent>, DateTime>(
  (ref, date) async {
    final eventsMap = await ref.watch(calendarEventsProvider.future);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return eventsMap[normalizedDate] ?? [];
  },
);

/// 月度任务统计 Provider
/// 返回指定月份的任务统计信息
final monthlyStatsProvider = FutureProvider.autoDispose
    .family<MonthlyTaskStats, DateTime>((ref, date) async {
  final repository = ref.watch(planRepositoryProvider);

  final monthStart = DateTime(date.year, date.month, 1);
  final monthEnd = date.month < 12
      ? DateTime(date.year, date.month + 1, 0, 23, 59, 59)
      : DateTime(date.year + 1, 1, 0, 23, 59, 59);

  // 使用新增的按日期范围获取任务方法
  final allTasks = await repository.getTasksByDateRange(monthStart, monthEnd);

  final totalTasks = allTasks.length;
  final completedTasks = allTasks.where((t) => t.isCompleted).length;
  final pendingTasks = totalTasks - completedTasks;

  // 计算逾期任务
  final now = DateTime.now();
  final overdueTasks = allTasks.where((task) {
    return !task.isCompleted && task.scheduledDate.isBefore(DateTime(now.year, now.month, now.day));
  }).length;

  return MonthlyTaskStats(
    totalTasks: totalTasks,
    completedTasks: completedTasks,
    pendingTasks: pendingTasks,
    overdueTasks: overdueTasks,
    completionRate: totalTasks > 0 ? completedTasks / totalTasks : 0,
  );
});

/// 月度任务统计模型
class MonthlyTaskStats {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionRate;

  const MonthlyTaskStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionRate,
  });
}

// ==================== 日历视图状态 Provider ====================

/// 日历视图模式 Provider
enum CalendarViewMode {
  /// 月视图
  month,
  /// 周视图
  week,
  /// 日视图
  day,
}

/// 日历视图模式 Provider
final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) {
  return CalendarViewMode.month;
});

/// 切换日历视图模式
class CalendarViewModeNotifier extends StateNotifier<CalendarViewMode> {
  CalendarViewModeNotifier() : super(CalendarViewMode.month);

  void setMode(CalendarViewMode mode) {
    state = mode;
  }

  void toggle() {
    state = CalendarViewMode.values[(state.index + 1) % CalendarViewMode.values.length];
  }
}

final calendarViewModeNotifierProvider =
    StateNotifierProvider<CalendarViewModeNotifier, CalendarViewMode>((ref) {
  return CalendarViewModeNotifier();
});

// ==================== 日历筛选 Provider ====================

/// 日历筛选选项
class CalendarFilterOptions {
  final bool showCompleted;
  final bool showPending;
  final bool showOverdue;
  final Set<String> categories;

  const CalendarFilterOptions({
    this.showCompleted = true,
    this.showPending = true,
    this.showOverdue = true,
    this.categories = const {'workout', 'study', 'work', 'habit'},
  });

  CalendarFilterOptions copyWith({
    bool? showCompleted,
    bool? showPending,
    bool? showOverdue,
    Set<String>? categories,
  }) {
    return CalendarFilterOptions(
      showCompleted: showCompleted ?? this.showCompleted,
      showPending: showPending ?? this.showPending,
      showOverdue: showOverdue ?? this.showOverdue,
      categories: categories ?? this.categories,
    );
  }
}

/// 日历筛选 Provider
final calendarFilterProvider = StateProvider<CalendarFilterOptions>((ref) {
  return const CalendarFilterOptions();
});

/// 切换筛选选项
class CalendarFilterNotifier extends StateNotifier<CalendarFilterOptions> {
  CalendarFilterNotifier() : super(const CalendarFilterOptions());

  void toggleCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }

  void togglePending() {
    state = state.copyWith(showPending: !state.showPending);
  }

  void toggleOverdue() {
    state = state.copyWith(showOverdue: !state.showOverdue);
  }

  void toggleCategory(String category) {
    final newCategories = Set<String>.from(state.categories);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    state = state.copyWith(categories: newCategories);
  }

  void reset() {
    state = const CalendarFilterOptions();
  }
}

final calendarFilterNotifierProvider =
    StateNotifierProvider<CalendarFilterNotifier, CalendarFilterOptions>((ref) {
  return CalendarFilterNotifier();
});
