/// 计划模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/provider_invalidator.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/plans/data/models/plan_template.dart';
import 'package:thick_notepad/features/plans/data/services/plan_template_service.dart';

// ==================== 计划列表 Providers ====================

/// 所有计划 Provider
final allPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getAllPlans();
});

/// 进行中的计划 Provider
final activePlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getActivePlans();
});

/// 已完成的计划 Provider
final completedPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getCompletedPlans();
});

/// 单个计划 Provider 族
final planProvider = FutureProvider.autoDispose.family<Plan?, int>((ref, id) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getPlanById(id);
});

// ==================== 计划任务 Providers ====================

/// 今日任务 Provider
final todayTasksProvider = FutureProvider.autoDispose<List<PlanTask>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getTodayTasks();
});

/// 本周任务 Provider
final thisWeekTasksProvider = FutureProvider.autoDispose<List<PlanTask>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getThisWeekTasks();
});

/// 计划的任务列表 Provider 族
final planTasksProvider = FutureProvider.autoDispose.family<List<PlanTask>, int>((ref, planId) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getPlanTasks(planId);
});

/// 任务统计 Provider
final taskStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  return await repository.getTaskStats();
});

// ==================== 计划操作 Providers ====================

/// 创建计划 Provider
final createPlanProvider = ProviderFamily<void, PlansCompanion>((ref, plan) {
  ref.listenSelf((_, __) {
    // 创建计划
    ref.read(planRepositoryProvider).createPlan(plan).then((_) {
      ProviderInvalidator.invalidateAfterPlanRef(ref);
    });
  });
});

/// 更新计划 Provider
final updatePlanProvider = Provider.autoDispose((ref) {
  return UpdatePlanNotifier(ref);
});

class UpdatePlanNotifier {
  final Ref ref;
  UpdatePlanNotifier(this.ref);

  Future<void> update(Plan plan) async {
    await ref.read(planRepositoryProvider).updatePlan(plan);
    ProviderInvalidator.invalidateAfterPlanRef(ref);
  }

  Future<void> delete(int id) async {
    await ref.read(planRepositoryProvider).deletePlan(id);
    ProviderInvalidator.invalidateAfterPlanRef(ref);
  }

  Future<void> updateProgress(int planId) async {
    await ref.read(planRepositoryProvider).updatePlanProgress(planId);
    ProviderInvalidator.invalidatePlansRef(ref);
  }
}

// ==================== 任务操作 Providers ====================

/// 创建任务 Provider
final createTaskProvider = ProviderFamily<void, PlanTasksCompanion>((ref, task) {
  ref.listenSelf((_, __) {
    ref.read(planRepositoryProvider).createTask(task).then((_) {
      ProviderInvalidator.invalidateAfterTaskRef(ref);
    });
  });
});

/// 更新任务 Provider
final updateTaskProvider = Provider.autoDispose((ref) {
  return UpdateTaskNotifier(ref);
});

class UpdateTaskNotifier {
  final Ref ref;
  UpdateTaskNotifier(this.ref);

  Future<void> toggleComplete(PlanTask task) async {
    final repo = ref.read(planRepositoryProvider);
    if (task.isCompleted) {
      await repo.markTaskIncomplete(task.id);
    } else {
      await repo.markTaskComplete(task.id);
    }
    ProviderInvalidator.invalidateAfterTaskRef(ref);
  }

  Future<void> delete(int id) async {
    await ref.read(planRepositoryProvider).deleteTask(id);
    ProviderInvalidator.invalidateAfterTaskRef(ref);
  }
}

// ==================== 计划模板 Providers ====================

/// 所有模板 Provider
final allTemplatesProvider = Provider<List<PlanTemplate>>((ref) {
  return PlanTemplateService.getAllTemplates();
});

/// 推荐模板 Provider
final recommendedTemplatesProvider = Provider<List<PlanTemplate>>((ref) {
  return PlanTemplateService.getRecommendedTemplates();
});

/// 按分类筛选模板 Provider 族
final templatesByCategoryProvider = Provider.family<List<PlanTemplate>, PlanTemplateCategory>((ref, category) {
  return PlanTemplateService.getTemplatesByCategory(category);
});

/// 搜索模板 Provider 族
final searchTemplatesProvider = Provider.family<List<PlanTemplate>, String>((ref, query) {
  return PlanTemplateService.searchTemplates(query);
});

/// 根据ID获取模板 Provider 族
final templateByIdProvider = Provider.family<PlanTemplate?, String>((ref, id) {
  return PlanTemplateService.getTemplateById(id);
});

/// 从模板创建计划 Provider
final createPlanFromTemplateProvider = Provider.family<Future<int>, PlanTemplate>((ref, template) async {
  final repo = ref.read(planRepositoryProvider);

  // 从模板创建计划
  final planData = PlanTemplateService.createPlanFromTemplate(template);
  final planId = await repo.createPlan(planData);

  // 创建模板任务
  final tasksData = PlanTemplateService.createTasksFromTemplate(template, planId);
  for (final task in tasksData) {
    await repo.createTask(task);
  }

  // 更新计划进度
  await repo.updatePlanProgress(planId);

  // 使相关缓存失效
  ProviderInvalidator.invalidateAfterPlanRef(ref);

  return planId;
});
