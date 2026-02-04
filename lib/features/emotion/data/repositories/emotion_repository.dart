/// 情绪数据仓库 - 封装情绪记录相关的数据库操作

import 'dart:convert';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';
import 'package:drift/drift.dart' as drift;

/// 情绪统计数据
class EmotionStatistics {
  final Map<EmotionType, int> emotionCounts;
  final EmotionType? mostCommonEmotion;
  final int totalRecords;
  final double avgConfidence;

  const EmotionStatistics({
    required this.emotionCounts,
    this.mostCommonEmotion,
    required this.totalRecords,
    required this.avgConfidence,
  });
}

/// 情绪趋势数据
class EmotionTrendData {
  final DateTime date;
  final EmotionType emotion;
  final double confidence;

  const EmotionTrendData({
    required this.date,
    required this.emotion,
    required this.confidence,
  });
}

class EmotionRepository {
  final AppDatabase _db;

  EmotionRepository(this._db);

  /// 根据笔记内容创建情绪记录
  Future<int> createEmotionRecordFromNote(
    int noteId,
    String noteContent,
  ) async {
    // 分析情绪
    final result = EmotionAnalyzer.analyze(noteContent);

    // 获取运动推荐
    final recommendation = EmotionWorkoutMapper.getBestRecommendation(result.emotion);

    // 创建记录
    final companion = EmotionRecordsCompanion.insert(
      noteId: drift.Value(noteId),
      emotionType: result.emotion.name,
      confidence: result.confidence,
      analyzedText: noteContent,
      matchedKeywords: drift.Value(jsonEncode(result.matchedKeywords)),
      recommendedWorkout: drift.Value(recommendation.workoutType.name),
      workoutReason: drift.Value(recommendation.reason),
      workoutIntensity: drift.Value(recommendation.intensity),
    );

    return await _db.into(_db.emotionRecords).insert(companion);
  }

  /// 获取所有情绪记录
  Future<List<EmotionRecord>> getAllRecords() async {
    return await (_db.select(_db.emotionRecords)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.analyzedAt)]))
        .get();
  }

  /// 根据笔记ID获取情绪记录
  Future<EmotionRecord?> getRecordByNoteId(int noteId) async {
    return await (_db.select(_db.emotionRecords)
          ..where((tbl) => tbl.noteId.equals(noteId)))
        .getSingleOrNull();
  }

  /// 获取最近的情绪记录
  Future<List<EmotionRecord>> getRecentRecords(int limit) async {
    return await (_db.select(_db.emotionRecords)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.analyzedAt)])
          ..limit(limit))
        .get();
  }

  /// 获取指定日期范围内的情绪记录
  Future<List<EmotionRecord>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await (_db.select(_db.emotionRecords)
          ..where((tbl) =>
              tbl.analyzedAt.isBiggerOrEqualValue(start) &
              tbl.analyzedAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.analyzedAt)]))
        .get();
  }

  /// 获取指定情绪类型的记录
  Future<List<EmotionRecord>> getRecordsByEmotion(String emotionType) async {
    return await (_db.select(_db.emotionRecords)
          ..where((tbl) => tbl.emotionType.equals(emotionType))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.analyzedAt)]))
        .get();
  }

  /// 获取情绪统计（最近N天）
  Future<EmotionStatistics> getStatistics({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final records = await getRecordsByDateRange(since, DateTime.now());

    if (records.isEmpty) {
      return const EmotionStatistics(
        emotionCounts: {},
        mostCommonEmotion: null,
        totalRecords: 0,
        avgConfidence: 0.0,
      );
    }

    // 统计每种情绪的数量
    final emotionCounts = <EmotionType, int>{};
    double totalConfidence = 0;

    for (final record in records) {
      final emotion = EmotionType.fromString(record.emotionType);
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
      totalConfidence += record.confidence;
    }

    // 找出最常见的情绪
    EmotionType? mostCommon;
    int maxCount = 0;
    emotionCounts.forEach((emotion, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = emotion;
      }
    });

    return EmotionStatistics(
      emotionCounts: emotionCounts,
      mostCommonEmotion: mostCommon,
      totalRecords: records.length,
      avgConfidence: totalConfidence / records.length,
    );
  }

  /// 获取情绪趋势数据（按天聚合）
  Future<List<EmotionTrendData>> getTrendData({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final records = await getRecordsByDateRange(since, DateTime.now());

    // 按天聚合，每天取主要情绪
    final dailyData = <DateTime, List<EmotionRecord>>{};

    for (final record in records) {
      final date = DateTime(
        record.analyzedAt.year,
        record.analyzedAt.month,
        record.analyzedAt.day,
      );
      dailyData[date] = [...dailyData[date] ?? [], record];
    }

    // 转换为趋势数据
    final trendData = <EmotionTrendData>[];
    for (final entry in dailyData.entries) {
      if (entry.value.isNotEmpty) {
        // 取当天最主要的情绪
        final emotionCounts = <String, int>{};
        for (final r in entry.value) {
          emotionCounts[r.emotionType] = (emotionCounts[r.emotionType] ?? 0) + 1;
        }

        final topEmotionType = emotionCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        final avgConfidence = entry.value
                .map((r) => r.confidence)
                .reduce((a, b) => a + b) /
            entry.value.length;

        trendData.add(EmotionTrendData(
          date: entry.key,
          emotion: EmotionType.fromString(topEmotionType),
          confidence: avgConfidence,
        ));
      }
    }

    trendData.sort((a, b) => a.date.compareTo(b.date));
    return trendData;
  }

  /// 删除笔记相关的情绪记录
  Future<int> deleteByNoteId(int noteId) async {
    return await (_db.delete(_db.emotionRecords)
          ..where((tbl) => tbl.noteId.equals(noteId)))
        .go();
  }

  /// 更新情绪记录
  Future<bool> updateRecord(EmotionRecord record) async {
    return await _db.update(_db.emotionRecords).replace(record);
  }

  /// 获取推荐运动列表（基于历史情绪）
  Future<List<WorkoutRecommendation>> getRecommendationsBasedOnHistory() async {
    final recentRecords = await getRecentRecords(7);

    if (recentRecords.isEmpty) {
      // 没有历史记录，返回平静情绪的推荐
      return EmotionWorkoutMapper.getRecommendations(EmotionType.calm);
    }

    // 统计最近的情绪
    final emotionCounts = <EmotionType, int>{};
    for (final record in recentRecords) {
      final emotion = EmotionType.fromString(record.emotionType);
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }

    // 获取最常见的情绪
    final mostCommonEmotion = emotionCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return EmotionWorkoutMapper.getRecommendations(mostCommonEmotion);
  }

  /// 获取情绪与运动的关联分析
  Future<Map<String, dynamic>> getEmotionWorkoutCorrelation() async {
    final records = await getAllRecords();

    // 统计每种情绪对应的推荐运动
    final emotionWorkoutMap = <String, Map<String, int>>{};

    for (final record in records) {
      final emotion = record.emotionType;
      final workout = record.recommendedWorkout ?? 'unknown';

      emotionWorkoutMap[emotion] ??= {};
      emotionWorkoutMap[emotion]![workout] =
          (emotionWorkoutMap[emotion]![workout] ?? 0) + 1;
    }

    return emotionWorkoutMap;
  }

  /// 清空所有情绪记录
  Future<int> clearAllRecords() async {
    return await _db.delete(_db.emotionRecords).go();
  }
}
