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
import 'features/coach/data/repositories/workout_plan_repository.dart';
import 'features/coach/data/repositories/diet_plan_repository.dart';
import 'shared/widgets/animated_theme.dart';

/// 全局导航 Key（用于通知点击跳转）
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期格式化（中文）
  await initializeDateFormatting('zh_CN', null);

  // 初始化通知服务
  await _initNotifications();

  runApp(
    const ProviderScope(
      child: ThickNotepadApp(),
    ),
  );

  // 启动后检查计划迭代提醒（延迟执行，不影响启动速度）
  _schedulePlanUpdateCheck();
}

/// 延迟检查计划更新提醒
void _schedulePlanUpdateCheck() {
  // 延迟5秒后检查，避免影响应用启动
  Future.delayed(const Duration(seconds: 5), () async {
    await _checkPlanUpdateReminders();
  });
}

/// 初始化通知服务
Future<void> _initNotifications() async {
  try {
    final notificationService = NotificationService();

    // 设置通知点击回调
    notificationService.onNotificationTap = (payload) {
      _handleNotificationTap(payload);
    };

    await notificationService.initialize();

    // 检查并请求通知权限
    final hasPermission = await notificationService.arePermissionsGranted();
    if (!hasPermission) {
      // 不在启动时请求，让用户在需要时再授权
      debugPrint('通知权限未授予，将在首次使用提醒功能时请求');
    } else {
      debugPrint('通知服务初始化成功，权限已授予');
    }
  } catch (e) {
    // 通知服务初始化失败不影响应用启动
    debugPrint('通知服务初始化失败: $e');
  }
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
/// 优化：添加主题切换过渡动画
class ThickNotepadApp extends ConsumerWidget {
  const ThickNotepadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);

    return SimpleThemeTransition(
      child: MaterialApp.router(
        title: '动计笔记',
        debugShowCheckedModeBanner: false,
        theme: getThemeData(currentTheme),
        routerConfig: appRouter,
      ),
    );
  }
}
