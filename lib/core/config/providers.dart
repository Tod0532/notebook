/// 全局 Providers
/// 提供数据库和仓库实例

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/reminders/data/models/reminder_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';
import 'package:thick_notepad/features/plans/data/models/plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/diet_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/services/ai/plan_iteration_service.dart';
import 'package:thick_notepad/services/heart_rate/heart_rate_service.dart';
import 'package:thick_notepad/services/speech/speech_recognition_service.dart';
import 'package:thick_notepad/services/speech/speech_synthesis_service.dart';
import 'package:thick_notepad/services/speech/intent_parser.dart';
import 'package:thick_notepad/features/heart_rate/data/repositories/heart_rate_repository.dart';
import 'package:thick_notepad/services/weather/weather_service.dart';
import 'package:thick_notepad/features/emotion/data/repositories/emotion_repository.dart';
import 'package:thick_notepad/features/location/data/repositories/geofence_repository.dart';
import 'package:thick_notepad/services/challenge/challenge_service.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';
import 'package:thick_notepad/services/gamification/gamification_service.dart';
import 'package:thick_notepad/services/gamification/shop_service.dart';

// ==================== 数据库 Provider ====================

/// 数据库单例 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return DatabaseProvider.instance;
});

// ==================== 仓库 Providers ====================

/// 笔记仓库 Provider
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final repo = NoteRepository(ref.watch(databaseProvider));
  // 注入挑战服务用于进度更新
  final challengeService = ref.watch(challengeServiceProvider);
  repo.setChallengeService(challengeService);
  return repo;
});

/// 提醒仓库 Provider
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(databaseProvider));
});

/// 运动仓库 Provider
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final repo = WorkoutRepository(ref.watch(databaseProvider));
  // 注入挑战服务用于进度更新
  final challengeService = ref.watch(challengeServiceProvider);
  repo.setChallengeService(challengeService);
  return repo;
});

/// 计划仓库 Provider
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final repo = PlanRepository(ref.watch(databaseProvider));
  // 注入挑战服务用于进度更新
  final challengeService = ref.watch(challengeServiceProvider);
  repo.setChallengeService(challengeService);
  return repo;
});

// ==================== AI教练功能仓库 Providers ====================

/// 用户画像仓库 Provider
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(databaseProvider));
});

/// AI训练计划仓库 Provider
final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>((ref) {
  return WorkoutPlanRepository(ref.watch(databaseProvider));
});

/// AI饮食计划仓库 Provider
final dietPlanRepositoryProvider = Provider<DietPlanRepository>((ref) {
  return DietPlanRepository(ref.watch(databaseProvider));
});

/// 用户反馈仓库 Provider
final userFeedbackRepositoryProvider = Provider<UserFeedbackRepository>((ref) {
  return UserFeedbackRepository(ref.watch(databaseProvider));
});

// ==================== 服务 Providers ====================

/// 计划迭代服务 Provider
final planIterationServiceProvider = Provider<PlanIterationService>((ref) {
  return PlanIterationService.instance;
});

// ==================== 心率监测服务 Providers ====================

/// 心率服务 Provider（单例）
final heartRateServiceProvider = Provider<HeartRateService>((ref) {
  return HeartRateService();
});

/// 心率服务初始化 Provider
final heartRateServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(heartRateServiceProvider);
  final db = ref.watch(databaseProvider);
  service.setDatabase(db);
});

// ==================== 心率数据仓库 Providers ====================

/// 心率数据仓库 Provider（在 heart_rate_providers.dart 中定义更完整的版本）
/// 这里仅作为全局引用导出
// final heartRateRepositoryProvider 在 heart_rate_providers.dart 中定义

// ==================== 天气服务 Providers ====================

/// 天气服务 Provider（单例）
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

// ==================== 情绪分析仓库 Providers ====================

/// 情绪仓库 Provider
final emotionRepositoryProvider = Provider<EmotionRepository>((ref) {
  return EmotionRepository(ref.watch(databaseProvider));
});

// ==================== 语音服务 Providers ====================

/// 语音识别服务 Provider（单例）
final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((ref) {
  return SpeechRecognitionService();
});

/// 语音合成服务 Provider（单例）
final speechSynthesisServiceProvider = Provider<SpeechSynthesisService>((ref) {
  return SpeechSynthesisService();
});

/// 意图解析服务 Provider（单例）
final intentParserProvider = Provider<IntentParser>((ref) {
  return IntentParser();
});

// ==================== 位置提醒服务 Providers ====================

/// 地理围栏仓库 Provider
final geofenceRepositoryProvider = Provider<GeofenceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GeofenceRepository(db);
});

// ==================== 挑战系统服务 Providers ====================

/// 挑战服务 Provider（单例）
/// 注意：使用 Provider 而非单例，以正确处理依赖关系
final challengeServiceProvider = Provider<ChallengeService>((ref) {
  final db = ref.watch(databaseProvider);
  final gamificationService = ref.watch(gamificationServiceProvider);
  final service = ChallengeService.instance;
  service.setDatabase(db);
  service.setGamificationService(gamificationService);
  // 初始化自动刷新
  service.initAutoRefresh();
  return service;
});

// ==================== 抽卡系统服务 Providers ====================

/// 抽卡服务 Provider（单例）
final gachaServiceProvider = Provider<GachaService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = GachaService.instance;
  service.setDatabase(db);
  return service;
});

// ==================== 游戏化系统服务 Providers ====================

/// 游戏化服务 Provider（单例）
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = GamificationService();
  service.setDatabase(db);
  return service;
});

/// 积分商店服务 Provider（单例）
final shopServiceProvider = Provider<ShopService>((ref) {
  final db = ref.watch(databaseProvider);
  final gamificationService = ref.watch(gamificationServiceProvider);
  final service = ShopService();
  service.setDatabase(db, gamificationService);
  return service;
});
