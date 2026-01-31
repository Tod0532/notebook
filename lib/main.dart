/// 动计笔记 - 应用入口
///
/// 功能：记事 + 提醒 + 运动 + 计划 一站式生活管理APP

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'services/notification/notification_service.dart';

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
}

/// 初始化通知服务
Future<void> _initNotifications() async {
  try {
    final notificationService = NotificationService();
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

/// 应用主 Widget
class ThickNotepadApp extends ConsumerWidget {
  const ThickNotepadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);

    return MaterialApp.router(
      title: '动计笔记',
      debugShowCheckedModeBanner: false,
      theme: getThemeData(currentTheme),
      routerConfig: appRouter,
    );
  }
}
