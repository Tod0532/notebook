/// 情绪分析器测试

import 'package:flutter_test/flutter_test.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';
import 'package:thick_notepad/services/database/database.dart';

void main() {
  group('EmotionAnalyzer', () {
    test('应该正确识别开心情绪', () {
      const text = '今天很开心，事情都很顺利，感觉棒极了！';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.happy);
      expect(result.matchedKeywords, isNotEmpty);
      expect(result.confidence, greaterThan(0.0));
    });

    test('应该正确识别悲伤情绪', () {
      const text = '今天很难过，感觉很沮丧，心情不好。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.sad);
      expect(result.matchedKeywords, contains('难过'));
    });

    test('应该正确识别焦虑情绪', () {
      const text = '感觉很焦虑，一直担心明天的事情，心里不安。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.anxious);
      expect(result.matchedKeywords, contains('焦虑'));
    });

    test('应该正确识别疲惫情绪', () {
      const text = '今天好累啊，累死了，完全没精神。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.tired);
      expect(result.matchedKeywords, contains('累'));
    });

    test('应该正确识别压力情绪', () {
      const text = '压力好大，烦死了，感觉快要崩溃了。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.stressed);
      expect(result.matchedKeywords, contains('压力'));
    });

    test('应该正确识别平静情绪', () {
      const text = '今天很平静，感觉很放松，心情很舒适。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.calm);
      expect(result.matchedKeywords, contains('平静'));
    });

    test('应该正确识别兴奋情绪', () {
      const text = '太兴奋了！充满干劲，感觉非常有活力！';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.excited);
      expect(result.matchedKeywords, contains('兴奋'));
    });

    test('空文本应该返回平静情绪', () {
      const text = '';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.emotion, EmotionType.calm);
      expect(result.matchedKeywords, isEmpty);
    });

    test('置信度应该在0到1之间', () {
      const text = '今天很开心，但也有点累。';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });

    test('应该返回所有情绪的分数', () {
      const text = '开心快乐也难过';
      final result = EmotionAnalyzer.analyze(text);

      expect(result.allScores, isNotEmpty);
      expect(result.allScores.keys, contains(EmotionType.happy));
      expect(result.allScores.keys, contains(EmotionType.sad));
    });
  });

  group('EmotionWorkoutMapper', () {
    test('焦虑情绪应该推荐放松类运动', () {
      final recommendations = EmotionWorkoutMapper.getRecommendations(EmotionType.anxious);

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.workoutType, WorkoutType.yoga);
      expect(recommendations.first.intensity, lessThanOrEqualTo(3));
    });

    test('悲伤情绪应该推荐有氧运动', () {
      final recommendations = EmotionWorkoutMapper.getRecommendations(EmotionType.sad);

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.workoutType, WorkoutType.running);
    });

    test('疲惫情绪应该推荐轻度运动', () {
      final recommendations = EmotionWorkoutMapper.getRecommendations(EmotionType.tired);

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.intensity, lessThanOrEqualTo(2));
    });

    test('开心情绪应该推荐高强度运动', () {
      final recommendations = EmotionWorkoutMapper.getRecommendations(EmotionType.happy);

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.intensity, greaterThanOrEqualTo(4));
    });

    test('平静情绪应该推荐各类运动', () {
      final recommendations = EmotionWorkoutMapper.getRecommendations(EmotionType.calm);

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.intensity, equals(3));
    });

    test('根据时间限制应该推荐合适的运动', () {
      final recommendation = EmotionWorkoutMapper.getRecommendationByDuration(
        EmotionType.tired,
        15, // 只有15分钟
      );

      expect(recommendation, isNotNull);
      expect(
        recommendation!.suggestedDuration,
        lessThanOrEqualTo(15),
      );
    });

    test('应该检查运动是否适合情绪', () {
      expect(
        EmotionWorkoutMapper.isWorkoutSuitable(WorkoutType.yoga, EmotionType.anxious),
        isTrue,
      );
      expect(
        EmotionWorkoutMapper.isWorkoutSuitable(WorkoutType.hiit, EmotionType.tired),
        isFalse,
      );
    });
  });

  group('EmotionAnalyzer 工具方法', () {
    test('应该正确计算情绪的积极程度', () {
      expect(EmotionAnalyzer.getSentimentScore(EmotionType.happy), equals(1.0));
      expect(EmotionAnalyzer.getSentimentScore(EmotionType.sad), equals(-1.0));
      expect(EmotionAnalyzer.getSentimentScore(EmotionType.calm), equals(0.5));
      expect(EmotionAnalyzer.getSentimentScore(EmotionType.stressed), equals(-0.7));
    });

    test('应该返回情绪建议', () {
      final suggestion = EmotionAnalyzer.getSuggestion(EmotionType.happy);
      expect(suggestion, isNotEmpty);
      expect(suggestion, contains('好心情'));
    });

    test('应该生成情绪摘要', () {
      final result = EmotionResult(
        emotion: EmotionType.happy,
        confidence: 0.85,
        matchedKeywords: ['开心', '高兴'],
        allScores: {EmotionType.happy: 2.0},
      );

      final summary = EmotionAnalyzer.getSummary(result);
      expect(summary, contains('开心'));
      expect(summary, contains('开心'));
      expect(summary, contains('高兴'));
    });
  });
}
