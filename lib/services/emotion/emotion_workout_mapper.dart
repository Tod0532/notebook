/// 情绪-运动映射服务
/// 根据用户的情绪状态推荐合适的运动类型

import 'emotion_analyzer.dart';
import '../../services/database/database.dart';

/// 运动推荐结果
class WorkoutRecommendation {
  /// 推荐的运动类型
  final WorkoutType workoutType;

  /// 推荐理由
  final String reason;

  /// 推荐强度 (1-5)
  final int intensity;

  /// 预计时长（分钟）
  final int? suggestedDuration;

  const WorkoutRecommendation({
    required this.workoutType,
    required this.reason,
    required this.intensity,
    this.suggestedDuration,
  });

  @override
  String toString() {
    return 'WorkoutRecommendation(type: ${workoutType.displayName}, reason: $reason, intensity: $intensity)';
  }
}

/// 情绪-运动映射器
class EmotionWorkoutMapper {
  /// 根据情绪获取推荐的运动列表
  static List<WorkoutRecommendation> getRecommendations(EmotionType emotion) {
    switch (emotion) {
      case EmotionType.anxious:
      case EmotionType.stressed:
        return _getAnxietyAndStressRecommendations();

      case EmotionType.sad:
        return _getSadnessRecommendations();

      case EmotionType.tired:
        return _getTiredRecommendations();

      case EmotionType.happy:
      case EmotionType.excited:
        return _getHappyAndExcitedRecommendations();

      case EmotionType.calm:
        return _getCalmRecommendations();
    }
  }

  /// 获取单个最佳推荐
  static WorkoutRecommendation getBestRecommendation(EmotionType emotion) {
    final recommendations = getRecommendations(emotion);
    return recommendations.first;
  }

  /// 焦虑/压力 - 推荐放松类运动
  static List<WorkoutRecommendation> _getAnxietyAndStressRecommendations() {
    return const [
      WorkoutRecommendation(
        workoutType: WorkoutType.yoga,
        reason: '瑜伽可以帮助放松身心，缓解焦虑和压力',
        intensity: 2,
        suggestedDuration: 30,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.meditation,
        reason: '冥想有助于平静内心，减轻焦虑感',
        intensity: 1,
        suggestedDuration: 15,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.stretching,
        reason: '拉伸运动可以释放身体紧张，放松肌肉',
        intensity: 1,
        suggestedDuration: 20,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.pilates,
        reason: '普拉提结合呼吸和动作，有助于缓解压力',
        intensity: 2,
        suggestedDuration: 30,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.walking,
        reason: '轻松散步可以舒缓心情，放松大脑',
        intensity: 1,
        suggestedDuration: 30,
      ),
    ];
  }

  /// 悲伤/低落 - 推荐有氧运动释放内啡肽
  static List<WorkoutRecommendation> _getSadnessRecommendations() {
    return const [
      WorkoutRecommendation(
        workoutType: WorkoutType.running,
        reason: '跑步可以释放内啡肽，改善心情',
        intensity: 3,
        suggestedDuration: 30,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.walking,
        reason: '快走或散步有助于提升情绪',
        intensity: 2,
        suggestedDuration: 45,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.aerobics,
        reason: '有氧操可以促进多巴胺分泌，让人开心',
        intensity: 3,
        suggestedDuration: 30,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.cycling,
        reason: '骑行是很好的户外运动，呼吸新鲜空气',
        intensity: 3,
        suggestedDuration: 40,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.hiking,
        reason: '徒步接近大自然，有助于缓解低落情绪',
        intensity: 2,
        suggestedDuration: 60,
      ),
    ];
  }

  /// 疲惫 - 推荐轻度运动恢复体力
  static List<WorkoutRecommendation> _getTiredRecommendations() {
    return const [
      WorkoutRecommendation(
        workoutType: WorkoutType.walking,
        reason: '轻度散步可以促进血液循环，帮助恢复',
        intensity: 1,
        suggestedDuration: 20,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.stretching,
        reason: '温和的拉伸可以放松紧绷的肌肉',
        intensity: 1,
        suggestedDuration: 15,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.meditation,
        reason: '冥想可以帮助身心放松，恢复精力',
        intensity: 1,
        suggestedDuration: 10,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.yoga,
        reason: '恢复性瑜伽可以放松身心，缓解疲劳',
        intensity: 1,
        suggestedDuration: 20,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.pilates,
        reason: '轻度普拉提可以帮助身体恢复活力',
        intensity: 2,
        suggestedDuration: 20,
      ),
    ];
  }

  /// 开心/兴奋 - 推荐高强度运动释放能量
  static List<WorkoutRecommendation> _getHappyAndExcitedRecommendations() {
    return const [
      WorkoutRecommendation(
        workoutType: WorkoutType.hiit,
        reason: 'HIIT高强度训练，释放你的能量',
        intensity: 5,
        suggestedDuration: 25,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.running,
        reason: '跑步让你尽情释放活力和热情',
        intensity: 4,
        suggestedDuration: 40,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.basketball,
        reason: '篮球等球类运动让你的快乐加倍',
        intensity: 4,
        suggestedDuration: 60,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.football,
        reason: '足球是释放能量的绝佳选择',
        intensity: 4,
        suggestedDuration: 60,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.badminton,
        reason: '羽毛球运动有趣且充满活力',
        intensity: 3,
        suggestedDuration: 45,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.jumpRope,
        reason: '跳绳是简单高效的有氧运动',
        intensity: 4,
        suggestedDuration: 20,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.stairClimbing,
        reason: '爬楼梯挑战你的体能极限',
        intensity: 4,
        suggestedDuration: 30,
      ),
    ];
  }

  /// 平静 - 适合各类运动
  static List<WorkoutRecommendation> _getCalmRecommendations() {
    return const [
      WorkoutRecommendation(
        workoutType: WorkoutType.running,
        reason: '状态不错，跑步是很好的选择',
        intensity: 3,
        suggestedDuration: 35,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.yoga,
        reason: '瑜伽让身心更加协调',
        intensity: 2,
        suggestedDuration: 40,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.cycling,
        reason: '骑行享受运动的同时欣赏风景',
        intensity: 3,
        suggestedDuration: 45,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.swimming,
        reason: '游泳是全身性的优质运动',
        intensity: 3,
        suggestedDuration: 40,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.fullBody,
        reason: '全身训练让你保持良好状态',
        intensity: 3,
        suggestedDuration: 45,
      ),
      WorkoutRecommendation(
        workoutType: WorkoutType.hiking,
        reason: '徒步亲近自然，放松身心',
        intensity: 2,
        suggestedDuration: 90,
      ),
    ];
  }

  /// 获取运动推荐文本描述
  static String getRecommendationText(EmotionType emotion) {
    final recommendation = getBestRecommendation(emotion);
    return '推荐运动：${recommendation.workoutType.displayName}\n${recommendation.reason}';
  }

  /// 获取运动强度描述
  static String getIntensityDescription(int intensity) {
    switch (intensity) {
      case 1:
        return '轻松';
      case 2:
        return '轻度';
      case 3:
        return '中等';
      case 4:
        return '较强';
      case 5:
        return '高强度';
      default:
        return '未知';
    }
  }

  /// 根据时间和情绪获取推荐
  static WorkoutRecommendation? getRecommendationByDuration(
    EmotionType emotion,
    int availableMinutes,
  ) {
    final recommendations = getRecommendations(emotion);

    // 找到在可用时间内的推荐
    for (final rec in recommendations) {
      if (rec.suggestedDuration != null && rec.suggestedDuration! <= availableMinutes) {
        return rec;
      }
    }

    // 如果没有找到，返回第一个推荐
    return recommendations.first;
  }

  /// 检查运动是否适合当前情绪
  static bool isWorkoutSuitable(WorkoutType workoutType, EmotionType emotion) {
    final recommendations = getRecommendations(emotion);
    return recommendations.any((r) => r.workoutType == workoutType);
  }
}
