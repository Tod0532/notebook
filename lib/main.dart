/// 动计笔记 - 应用入口
///
/// 功能：记事 + 提醒 + 运动 + 计划 一站式生活管理APP

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:drift/drift.dart' as drift;
import 'core/config/router.dart';
import 'core/config/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'services/database/database.dart';
import 'services/notification/notification_service.dart';
import 'services/widget/widget_helper.dart';
import 'features/coach/data/repositories/workout_plan_repository.dart';
import 'features/coach/data/repositories/diet_plan_repository.dart';
import 'shared/widgets/animated_theme.dart';

/// 全局导航 Key（用于通知点击跳转）
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期格式化（中文）
  await initializeDateFormatting('zh_CN', null);

  // 立即启动应用，其他服务在后台初始化
  runApp(
    const ProviderScope(
      child: ThickNotepadApp(),
    ),
  );

  // 延迟初始化非关键服务，不影响启动速度
  _initBackgroundServices();
}

/// 后台初始化非关键服务
void _initBackgroundServices() {
  // 使用 Future.microtask 在第一帧后执行
  Future.microtask(() async {
    // 初始化桌面小组件辅助服务
    WidgetHelper.initialize();

    // 初始化通知服务（非阻塞）
    _initNotifications().catchError((e) {
      debugPrint('后台服务初始化失败: $e');
    });

    // 延迟检查计划迭代提醒
    Future.delayed(const Duration(seconds: 5), () async {
      await _checkPlanUpdateReminders();
    });
  });
}

/// 初始化通知服务
///
/// 添加了更详细的调试日志，方便排查通知问题
Future<void> _initNotifications() async {
  try {
    final notificationService = NotificationService();

    // 设置通知点击回调
    notificationService.onNotificationTap = (payload) {
      _handleNotificationTap(payload);
    };

    final initialized = await notificationService.initialize();
    debugPrint('========== 通知服务初始化${initialized ? "成功" : "失败"} ==========');

    // 检查并请求通知权限
    final hasPermission = await notificationService.arePermissionsGranted();
    debugPrint('通知权限状态: $hasPermission');

    if (!hasPermission) {
      debugPrint('通知权限未授予，将在首次使用提醒功能时请求');
    } else {
      debugPrint('通知权限已授予');

      // 打印待发送的通知（恢复前）
      final pendingBefore = await notificationService.getPendingNotifications();
      debugPrint('恢复前待发送通知数量: ${pendingBefore.length}');

      // 恢复数据库中未完成的提醒通知
      await _restoreReminderNotifications(notificationService);

      // 打印待发送的通知（恢复后）
      final pendingAfter = await notificationService.getPendingNotifications();
      debugPrint('恢复后待发送通知数量: ${pendingAfter.length}');
      for (final note in pendingAfter) {
        debugPrint('  - id=${note.id}, title=${note.title}');
      }
    }
  } catch (e) {
    // 通知服务初始化失败不影响应用启动
    debugPrint('通知服务初始化失败: $e');
  }
}

/// 恢复数据库中未完成的提醒通知
///
/// 应用重启或设备重启后，需要重新安排未完成的提醒通知
Future<void> _restoreReminderNotifications(NotificationService notificationService) async {
  try {
    final db = DatabaseProvider.instance;

    // 获取所有未完成且已启用的提醒
    final now = DateTime.now();
    final reminders = await (db.select(db.reminders)
          ..where((tbl) =>
              tbl.isDone.equals(false) &
              tbl.isEnabled.equals(true) &
              tbl.remindTime.isBiggerThanValue(now)))
        .get();

    debugPrint('需要恢复通知的提醒数量: ${reminders.length}');

    for (final reminder in reminders) {
      try {
        final scheduled = await notificationService.scheduleNotification(
          id: reminder.id,
          title: reminder.title,
          body: reminder.description?.isNotEmpty == true ? reminder.description : '该完成这件事了',
          scheduledTime: reminder.remindTime,
          payload: 'reminder:${reminder.id}',
        );

        if (scheduled != null) {
          debugPrint('  ✓ 已恢复提醒 #${reminder.id}: ${reminder.title} @ ${reminder.remindTime}');
        } else {
          debugPrint('  ✗ 恢复提醒失败 #${reminder.id}: ${reminder.title}');
        }
      } catch (e) {
        debugPrint('  ✗ 恢复提醒异常 #${reminder.id}: $e');
      }
    }
  } catch (e) {
    debugPrint('恢复提醒通知失败: $e');
  }
}

/// 移除旧的延迟检查函数（已在_initBackgroundServices中处理）
void _schedulePlanUpdateCheck() {
  // 此功能已整合到 _initBackgroundServices 中
}

/// 处理通知点击
void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;

  debugPrint('通知被点击: $payload');

  // 解析 payload 格式: "reminder:{id}" 或 "note:{id}" 等
  final parts = payload.split(':');
  if (parts.length != 2) return;

  final type = parts[0];
  final id = int.tryParse(parts[1]);

  // 使用 go_router 进行导航
  final router = GoRouter.of(navigatorKey.currentContext!);

  switch (type) {
    case 'reminder':
      // 跳转到提醒页面
      router.go(AppRoutes.reminders);
      break;
    case 'note':
      if (id != null) {
        // 跳转到笔记详情
        router.go('/notes/$id');
      } else {
        router.go(AppRoutes.notes);
      }
      break;
    case 'plan':
      if (id != null) {
        // 跳转到计划详情
        router.go('/plans/$id');
      } else {
        router.go(AppRoutes.plans);
      }
      break;
    case 'workout':
      // 跳转到运动页面
      router.go(AppRoutes.workout);
      break;
  }
}

/// 检查计划更新提醒
Future<void> _checkPlanUpdateReminders() async {
  try {
    final db = DatabaseProvider.instance;
    final notificationService = NotificationService();

    // 检查训练计划
    final workoutPlans = await (db.select(db.workoutPlans)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]))
        .get();

    for (final plan in workoutPlans) {
      if (plan.createdAt == null) continue;

      final daysSinceUpdate = DateTime.now().difference(plan.createdAt!).inDays;

      // 每7天或14天提醒（整除）
      if (daysSinceUpdate >= 7 && daysSinceUpdate % 7 == 0) {
        await notificationService.checkAndSendPlanUpdateReminder(
          daysSinceUpdate: daysSinceUpdate,
          userProfileId: plan.userProfileId,
          planType: 'workout',
          planName: plan.name,
        );
      }
    }

    // 检查饮食计划
    final dietPlans = await (db.select(db.dietPlans)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]))
        .get();

    for (final plan in dietPlans) {
      if (plan.createdAt == null) continue;

      final daysSinceUpdate = DateTime.now().difference(plan.createdAt!).inDays;

      // 每7天或14天提醒（整除）
      if (daysSinceUpdate >= 7 && daysSinceUpdate % 7 == 0) {
        await notificationService.checkAndSendPlanUpdateReminder(
          daysSinceUpdate: daysSinceUpdate,
          userProfileId: plan.userProfileId,
          planType: 'diet',
          planName: plan.name,
        );
      }
    }
  } catch (e) {
    debugPrint('检查计划更新提醒失败: $e');
  }
}

/// 应用主 Widget
/// 优化：添加主题切换过渡动画和深色模式支持
class ThickNotepadApp extends ConsumerWidget {
  const ThickNotepadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColorMode = ref.watch(currentColorModeProvider);
    final customColor = ref.watch(currentCustomColorProvider);

    return SimpleThemeTransition(
      key: ValueKey('theme_${currentColorMode.name}_${customColor.name}'),
      child: Builder(
        builder: (context) {
          // 获取系统亮度
          final systemBrightness = MediaQuery.of(context).platformBrightness;

          // 确定是否使用深色模式
          final bool useDarkMode = switch (currentColorMode) {
            AppColorMode.dark => true,
            AppColorMode.light => false,
            AppColorMode.system => systemBrightness == Brightness.dark,
          };

          return MaterialApp.router(
            title: '动计笔记',
            debugShowCheckedModeBanner: false,
            theme: getThemeDataWithCustomColor(
              customColor,
              isDark: false,
            ),
            darkTheme: getThemeDataWithCustomColor(
              customColor,
              isDark: true,
            ),
            themeMode: useDarkMode
                ? ThemeMode.dark
                : (currentColorMode == AppColorMode.system
                    ? ThemeMode.system
                    : ThemeMode.light),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
