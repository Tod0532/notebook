/// 情绪模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';
import 'package:thick_notepad/features/emotion/data/repositories/emotion_repository.dart';

// ==================== 情绪分析 Providers ====================

/// 情绪分析结果 Provider 族 - 分析给定文本
final emotionAnalysisProvider = FutureProvider.family<EmotionResult, String>(
  (ref, text) async {
    // 模拟异步分析（实际是同步的，但为了保持一致性）
    return Future.value(EmotionAnalyzer.analyze(text));
  },
);

/// 情绪运动推荐 Provider 族 - 根据情绪获取推荐
final emotionWorkoutRecommendationProvider = Provider.family<WorkoutRecommendation, EmotionType>(
  (ref, emotion) {
    return EmotionWorkoutMapper.getBestRecommendation(emotion);
  },
);

// ==================== 情绪记录 Providers ====================

/// 所有情绪记录 Provider
final allEmotionRecordsProvider = FutureProvider.autoDispose<List<EmotionRecord>>((ref) async {
  final repository = ref.watch(emotionRepositoryProvider);
  return await repository.getAllRecords();
});

/// 最近情绪记录 Provider
final recentEmotionRecordsProvider = FutureProvider.autoDispose.family<List<EmotionRecord>, int>(
  (ref, limit) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getRecentRecords(limit);
  },
);

/// 根据笔记ID获取情绪记录 Provider
final emotionRecordByNoteProvider = FutureProvider.autoDispose.family<EmotionRecord?, int>(
  (ref, noteId) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getRecordByNoteId(noteId);
  },
);

/// 情绪统计 Provider（最近N天）
final emotionStatisticsProvider = FutureProvider.autoDispose.family<EmotionStatistics, int>(
  (ref, days) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getStatistics(days: days);
  },
);

/// 情绪趋势数据 Provider（最近N天）
final emotionTrendDataProvider = FutureProvider.autoDispose.family<List<EmotionTrendData>, int>(
  (ref, days) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getTrendData(days: days);
  },
);

/// 基于历史的运动推荐 Provider
final historyBasedRecommendationProvider = FutureProvider.autoDispose<List<WorkoutRecommendation>>(
  (ref) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getRecommendationsBasedOnHistory();
  },
);

/// 情绪与运动关联分析 Provider
final emotionWorkoutCorrelationProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final repository = ref.watch(emotionRepositoryProvider);
    return await repository.getEmotionWorkoutCorrelation();
  },
);

// ==================== 情绪操作 Providers ====================

/// 创建情绪记录状态
class CreateEmotionRecordState extends StateNotifier<AsyncValue<void>> {
  CreateEmotionRecordState(this.repository) : super(const AsyncValue.data(null));

  final EmotionRepository repository;

  /// 根据笔记创建情绪记录
  Future<void> createFromNote(int noteId, String content) async {
    state = const AsyncValue.loading();
    try {
      await repository.createEmotionRecordFromNote(noteId, content);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 删除笔记相关的情绪记录
  Future<void> deleteByNote(int noteId) async {
    state = const AsyncValue.loading();
    try {
      await repository.deleteByNoteId(noteId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final createEmotionRecordProvider = StateNotifierProvider<CreateEmotionRecordState, AsyncValue<void>>(
  (ref) {
    final repository = ref.watch(emotionRepositoryProvider);
    return CreateEmotionRecordState(repository);
  },
);

// ==================== 情绪仪表盘数据 Provider ====================

/// 情绪仪表盘数据 - 聚合多个数据源
class EmotionDashboardData {
  final EmotionRecord? latestRecord;
  final EmotionStatistics weekStatistics;
  final List<EmotionTrendData> trendData;
  final List<WorkoutRecommendation> recommendations;

  const EmotionDashboardData({
    this.latestRecord,
    required this.weekStatistics,
    required this.trendData,
    required this.recommendations,
  });
}

final emotionDashboardProvider = FutureProvider.autoDispose<EmotionDashboardData>((ref) async {
  // 并行获取所有数据
  final results = await Future.wait([
    ref.watch(recentEmotionRecordsProvider(1).future),
    ref.watch(emotionStatisticsProvider(7).future),
    ref.watch(emotionTrendDataProvider(7).future),
    ref.watch(historyBasedRecommendationProvider.future),
  ]);

  final latestRecords = results[0] as List<EmotionRecord>;
  final statistics = results[1] as EmotionStatistics;
  final trendData = results[2] as List<EmotionTrendData>;
  final recommendations = results[3] as List<WorkoutRecommendation>;

  return EmotionDashboardData(
    latestRecord: latestRecords.isNotEmpty ? latestRecords.first : null,
    weekStatistics: statistics,
    trendData: trendData,
    recommendations: recommendations,
  );
});

// ==================== 快速访问 Providers ====================

/// 当前主要情绪 Provider（基于最近的记录）
final currentEmotionProvider = Provider.autoDispose<EmotionType?>((ref) {
  final dashboard = ref.watch(emotionDashboardProvider);
  return dashboard.value?.latestRecord != null
      ? EmotionType.fromString(dashboard.value!.latestRecord!.emotionType)
      : null;
});

/// 今日情绪摘要 Provider
final todayEmotionSummaryProvider = Provider.autoDispose<String>((ref) {
  final dashboard = ref.watch(emotionDashboardProvider);
  final data = dashboard.value;

  if (data == null || data.latestRecord == null) {
    return '暂无情绪数据';
  }

  final emotion = EmotionType.fromString(data.latestRecord!.emotionType);
  final confidence = (data.latestRecord!.confidence * 100).toStringAsFixed(0);
  final suggestion = EmotionAnalyzer.getSuggestion(emotion);

  return '当前情绪：${emotion.displayName}（置信度 $confidence%）\n$suggestion';
});
