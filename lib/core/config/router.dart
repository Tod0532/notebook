/// 应用路由配置
/// 使用 go_router 的 ShellRoute 实现底部导航栏保持可见

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/shared/pages/home_page.dart';
import 'package:thick_notepad/features/notes/presentation/pages/notes_page.dart';
import 'package:thick_notepad/features/notes/presentation/pages/note_edit_page.dart';
import 'package:thick_notepad/features/reminders/presentation/pages/reminders_page.dart';
import 'package:thick_notepad/features/workout/presentation/pages/workout_page.dart';
import 'package:thick_notepad/features/workout/presentation/pages/workout_edit_page.dart';
import 'package:thick_notepad/features/workout/presentation/pages/workout_stats_page.dart';
import 'package:thick_notepad/features/workout/presentation/pages/workout_detail_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plans_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plan_edit_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plan_detail_page.dart';
import 'package:thick_notepad/shared/pages/settings_page.dart';
import 'package:thick_notepad/shared/pages/theme_selection_page.dart';

// ==================== 路由路径定义 ====================

class AppRoutes {
  static const String home = '/';
  static const String notes = '/notes';
  static const String noteDetail = '/notes/:id';
  static const String noteEdit = '/notes/new';
  static const String reminders = '/reminders';
  static const String reminderDetail = '/reminders/:id';
  static const String reminderEdit = '/reminders/new';
  static const String workout = '/workout';
  static const String workoutDetail = '/workout/:id';
  static const String workoutEdit = '/workout/new';
  static const String workoutStats = '/workout/stats';  // 运动统计
  static const String plans = '/plans';
  static const String planDetail = '/plans/:id';
  static const String planEdit = '/plans/new';
  static const String settings = '/settings';
  static const String themeSelection = '/settings/theme';  // 完整路径，用于外部跳转
}

// ==================== 路由配置 ====================

/// 自定义页面过渡动画
class _FadeTransition extends CustomTransitionPage {
  _FadeTransition({required super.child})
      : super(
          transitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        );
}

/// 应用路由器 - 使用 ShellRoute 保持底部导航栏
final appRouter = GoRouter(
  debugLogDiagnostics: false,
  initialLocation: AppRoutes.notes,
  routes: [
    // ShellRoute 包裹底部导航栏
    ShellRoute(
      builder: (context, state, child) => HomePage(child: child),
      routes: [
        // 首页/仪表盘
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(child: DashboardView()),
        ),

        // 笔记模块 - new 必须在 :id 之前
        GoRoute(
          path: AppRoutes.notes,
          pageBuilder: (context, state) => const NoTransitionPage(child: NotesView()),
        ),
        GoRoute(
          path: AppRoutes.noteEdit,
          pageBuilder: (context, state) => _FadeTransition(child: const NoteEditPage()),
        ),
        GoRoute(
          path: AppRoutes.noteDetail,
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _FadeTransition(child: NoteEditPage(noteId: id));
          },
        ),

        // 提醒模块
        GoRoute(
          path: AppRoutes.reminders,
          pageBuilder: (context, state) => const NoTransitionPage(child: RemindersView()),
        ),

        // 运动模块 - new 和 stats 必须在 :id 之前
        GoRoute(
          path: AppRoutes.workout,
          pageBuilder: (context, state) => const NoTransitionPage(child: WorkoutView()),
        ),
        GoRoute(
          path: AppRoutes.workoutStats,
          pageBuilder: (context, state) => _FadeTransition(child: const WorkoutStatsPage()),
        ),
        GoRoute(
          path: AppRoutes.workoutEdit,
          pageBuilder: (context, state) => _FadeTransition(child: const WorkoutEditPage()),
        ),
        GoRoute(
          path: AppRoutes.workoutDetail,
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _FadeTransition(child: WorkoutDetailPage(workoutId: id));
          },
        ),

        // 计划模块 - new 必须在 :id 之前
        GoRoute(
          path: AppRoutes.plans,
          pageBuilder: (context, state) => const NoTransitionPage(child: PlansView()),
        ),
        GoRoute(
          path: AppRoutes.planEdit,
          pageBuilder: (context, state) => _FadeTransition(child: const PlanEditPage()),
        ),
        GoRoute(
          path: AppRoutes.planDetail,
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _FadeTransition(child: PlanDetailPage(planId: id));
          },
        ),
      ],
    ),

    // 设置页面（独立路由，不显示底部导航）
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => _FadeTransition(child: const SettingsPage()),
      routes: [
        // 主题选择子路由（使用相对路径）
        GoRoute(
          path: 'theme',  // 相对路径，完整路径为 /settings/theme
          pageBuilder: (context, state) => _FadeTransition(child: const ThemeSelectionPage()),
        ),
      ],
    ),
  ],
);

// 视图组件在各模块页面中定义
