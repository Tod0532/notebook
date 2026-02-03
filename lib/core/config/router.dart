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
import 'package:thick_notepad/features/workout/presentation/pages/gps_tracking_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plans_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plan_edit_page.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plan_detail_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/user_profile_setup_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/coach_plan_generation_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/workout_plan_display_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/diet_plan_display_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/feedback_page.dart';
import 'package:thick_notepad/features/coach/presentation/pages/plan_iteration_page.dart';
import 'package:thick_notepad/features/heart_rate/presentation/pages/heart_rate_monitor_page.dart';
import 'package:thick_notepad/shared/pages/settings_page.dart';
import 'package:thick_notepad/shared/pages/theme_selection_page.dart';
import 'package:thick_notepad/shared/pages/ai_settings_page.dart';

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
  static const String workoutGpsTracking = '/workout/gps';  // GPS追踪
  static const String plans = '/plans';
  static const String planDetail = '/plans/:id';
  static const String planEdit = '/plans/new';
  static const String heartRateMonitor = '/heart-rate';  // 心率监测
  static const String settings = '/settings';
  static const String themeSelection = '/settings/theme';  // 完整路径，用于外部跳转
  static const String aiSettings = '/settings/ai';  // AI 设置页面
  static const String userProfileSetup = '/coach/profile/setup';  // 用户画像采集
  static const String coachPlanGeneration = '/coach/generation/:profileId';  // 计划生成
  static const String workoutPlanDisplay = '/coach/workout/:planId';  // 训练计划展示
  static const String dietPlanDisplay = '/coach/diet/:planId';  // 饮食计划展示
  static const String feedback = '/coach/feedback';  // 用户反馈页面
  static const String planIteration = '/coach/iteration';  // 计划迭代页面
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
          path: AppRoutes.workoutGpsTracking,
          pageBuilder: (context, state) {
            final workoutType = state.uri.queryParameters['type'] ?? '跑步';
            return _FadeTransition(child: GpsTrackingPage(workoutType: workoutType));
          },
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
        // AI 设置子路由
        GoRoute(
          path: 'ai',  // 相对路径，完整路径为 /settings/ai
          pageBuilder: (context, state) => _FadeTransition(child: const AISettingsPage()),
        ),
      ],
    ),

    // AI教练功能页面（独立路由，不显示底部导航）
    GoRoute(
      path: AppRoutes.userProfileSetup,
      pageBuilder: (context, state) => _FadeTransition(child: const UserProfileSetupPage()),
    ),
    GoRoute(
      path: AppRoutes.coachPlanGeneration,
      pageBuilder: (context, state) {
        final profileId = int.parse(state.pathParameters['profileId']!);
        return _FadeTransition(child: CoachPlanGenerationPage(userProfileId: profileId));
      },
    ),
    GoRoute(
      path: AppRoutes.workoutPlanDisplay,
      pageBuilder: (context, state) {
        final planId = int.parse(state.pathParameters['planId']!);
        return _FadeTransition(child: WorkoutPlanDisplayPage(planId: planId));
      },
    ),
    GoRoute(
      path: AppRoutes.dietPlanDisplay,
      pageBuilder: (context, state) {
        final planId = int.parse(state.pathParameters['planId']!);
        return _FadeTransition(child: DietPlanDisplayPage(planId: planId));
      },
    ),
    GoRoute(
      path: AppRoutes.feedback,
      pageBuilder: (context, state) {
        final userProfileId = state.uri.queryParameters['userProfileId'] != null
            ? int.tryParse(state.uri.queryParameters['userProfileId']!)
            : null;
        final workoutPlanId = state.uri.queryParameters['workoutPlanId'] != null
            ? int.tryParse(state.uri.queryParameters['workoutPlanId']!)
            : null;
        final dietPlanId = state.uri.queryParameters['dietPlanId'] != null
            ? int.tryParse(state.uri.queryParameters['dietPlanId']!)
            : null;
        return _FadeTransition(child: FeedbackPage(
          userProfileId: userProfileId,
          workoutPlanId: workoutPlanId,
          dietPlanId: dietPlanId,
        ));
      },
    ),
    GoRoute(
      path: AppRoutes.planIteration,
      pageBuilder: (context, state) {
        final userProfileId = state.uri.queryParameters['userProfileId'] != null
            ? int.tryParse(state.uri.queryParameters['userProfileId']!)
            : null;
        final workoutPlanId = state.uri.queryParameters['workoutPlanId'] != null
            ? int.tryParse(state.uri.queryParameters['workoutPlanId']!)
            : null;
        final dietPlanId = state.uri.queryParameters['dietPlanId'] != null
            ? int.tryParse(state.uri.queryParameters['dietPlanId']!)
            : null;
        return _FadeTransition(child: PlanIterationPage(
          userProfileId: userProfileId,
          workoutPlanId: workoutPlanId,
          dietPlanId: dietPlanId,
        ));
      },
    ),

    // 心率监测页面（独立路由，不显示底部导航）
    GoRoute(
      path: AppRoutes.heartRateMonitor,
      pageBuilder: (context, state) => _FadeTransition(child: const HeartRateMonitorPage()),
    ),
  ],
);

// 视图组件在各模块页面中定义
