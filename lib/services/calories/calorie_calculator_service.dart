/// 卡路里计算服务
/// 基于 MET (代谢当量) 值计算运动消耗的卡路里
///
/// 计算公式: 卡路里 = MET × 体重(kg) × 时间(小时)

import 'package:flutter/foundation.dart';

/// MET值表（代谢当量 - Metabolic Equivalent of Task）
/// 表示运动强度相对于静息代谢率的倍数
const MET_VALUES = <String, double>{
  // 有氧类
  'running': 9.8,      // 跑步
  'cycling': 7.5,     // 骑行
  'swimming': 8.0,    // 游泳
  'jumpRope': 11.8,   // 跳绳
  'hiit': 11.0,       // HIIT
  'aerobics': 6.0,    // 有氧操
  'stairClimbing': 8.0, // 爬楼梯

  // 力量类
  'chest': 3.0,       // 胸肌训练
  'back': 4.0,        // 背部训练
  'legs': 5.0,        // 腿部训练
  'shoulders': 3.0,   // 肩部训练
  'arms': 3.0,        // 手臂训练
  'core': 4.0,        // 核心训练
  'fullBody': 5.5,    // 全身训练

  // 球类
  'basketball': 8.0,  // 篮球
  'football': 7.0,    // 足球
  'badminton': 5.5,   // 羽毛球
  'tableTennis': 4.0, // 乒乓球
  'tennis': 7.0,      // 网球
  'volleyball': 4.0,  // 排球

  // 其他
  'yoga': 2.5,        // 瑜伽
  'pilates': 3.0,     // 普拉提
  'hiking': 6.0,      // 徒步
  'climbing': 8.0,    // 登山
  'meditation': 1.0,  // 冥想
  'stretching': 2.5,  // 拉伸
  'walking': 3.5,     // 散步
  'other': 3.0,       // 其他（默认值）
};

/// 卡路里计算服务
class CalorieCalculatorService {
  /// 单例模式
  static final CalorieCalculatorService instance = CalorieCalculatorService._internal();
  factory CalorieCalculatorService() => instance;
  CalorieCalculatorService._internal();

  /// 用户体重（公斤）- 用于计算卡路里
  /// 默认值 70kg，实际应用中应从用户画像获取
  double _userWeight = 70.0;

  /// 获取当前设置的体重
  double get userWeight => _userWeight;

  /// 设置用户体重
  void setUserWeight(double weight) {
    if (weight > 0 && weight < 300) {
      _userWeight = weight;
      debugPrint('卡路里计算: 用户体重已更新为 $_userWeight kg');
    }
  }

  /// 获取运动类型的 MET 值
  double getMetValue(String workoutType) {
    return MET_VALUES[workoutType] ?? MET_VALUES['other']!;
  }

  /// 计算运动消耗的卡路里
  ///
  /// 参数:
  /// - [workoutType] 运动类型（如 'running', 'cycling'）
  /// - [durationMinutes] 运动时长（分钟）
  /// - [weight] 体重（公斤），如果为 null 则使用预设的用户体重
  ///
  /// 返回值: 消耗的卡路里（千卡/kcal）
  double calculateCalories({
    required String workoutType,
    required int durationMinutes,
    double? weight,
  }) {
    final met = getMetValue(workoutType);
    final effectiveWeight = weight ?? _userWeight;
    final hours = durationMinutes / 60.0;

    final calories = met * effectiveWeight * hours;
    return calories;
  }

  /// 计算运动消耗的卡路里（带距离修正）
  /// 适用于有氧运动，距离越长消耗越大
  ///
  /// 参数:
  /// - [workoutType] 运动类型
  /// - [durationMinutes] 运动时长（分钟）
  /// - [distanceMeters] 运动距离（米）
  /// - [weight] 体重（公斤）
  ///
  /// 返回值: 消耗的卡路里（千卡/kcal）
  double calculateCaloriesWithDistance({
    required String workoutType,
    required int durationMinutes,
    required double distanceMeters,
    double? weight,
  }) {
    // 基础卡路里计算
    double baseCalories = calculateCalories(
      workoutType: workoutType,
      durationMinutes: durationMinutes,
      weight: weight,
    );

    // 对于有氧运动，考虑距离因素
    final effectiveWeight = weight ?? _userWeight;
    final distanceKm = distanceMeters / 1000;

    // 距离加成：每公里额外消耗约 0.5-1 kcal/kg（取决于运动类型）
    double distanceBonus = 0;
    switch (workoutType) {
      case 'running':
        distanceBonus = distanceKm * effectiveWeight * 1.0;
        break;
      case 'cycling':
        distanceBonus = distanceKm * effectiveWeight * 0.3;
        break;
      case 'walking':
        distanceBonus = distanceKm * effectiveWeight * 0.5;
        break;
      case 'hiking':
        distanceBonus = distanceKm * effectiveWeight * 0.7;
        break;
      default:
        // 其他运动类型不额外加成
        break;
    }

    return baseCalories + distanceBonus;
  }

  /// 计算力量训练的卡路里（考虑组数）
  ///
  /// 参数:
  /// - [workoutType] 力量训练类型（如 'chest', 'back'）
  /// - [durationMinutes] 运动时长（分钟）
  /// - [sets] 组数
  /// - [weight] 体重（公斤）
  ///
  /// 返回值: 消耗的卡路里（千卡/kcal）
  double calculateStrengthCalories({
    required String workoutType,
    required int durationMinutes,
    int? sets,
    double? weight,
  }) {
    double baseCalories = calculateCalories(
      workoutType: workoutType,
      durationMinutes: durationMinutes,
      weight: weight,
    );

    // 如果有组数信息，每组额外消耗约 5 kcal
    if (sets != null && sets > 0) {
      baseCalories += sets * 5;
    }

    return baseCalories;
  }

  /// 格式化卡路里显示
  static String formatCalories(double calories) {
    if (calories < 1) {
      return '0 千卡';
    }
    return '${calories.toStringAsFixed(0)} 千卡';
  }

  /// 批量计算多个运动的卡路里
  ///
  /// 参数:
  /// - [workouts] 运动列表，每个运动包含 type 和 durationMinutes
  ///
  /// 返回值: 总卡路里消耗
  double calculateTotalCalories(List<Map<String, dynamic>> workouts) {
    return workouts.fold<double>(0, (sum, workout) {
      final type = workout['type'] as String? ?? 'other';
      final duration = workout['durationMinutes'] as int? ?? 0;
      final distance = workout['distance'] as double?;
      final sets = workout['sets'] as int?;

      double workoutCalories;
      if (distance != null && distance > 0) {
        workoutCalories = calculateCaloriesWithDistance(
          workoutType: type,
          durationMinutes: duration,
          distanceMeters: distance,
        );
      } else if (sets != null && sets > 0) {
        workoutCalories = calculateStrengthCalories(
          workoutType: type,
          durationMinutes: duration,
          sets: sets,
        );
      } else {
        workoutCalories = calculateCalories(
          workoutType: type,
          durationMinutes: duration,
        );
      }

      return sum + workoutCalories;
    });
  }

  /// 获取运动类型对应的消耗等级描述
  static String getCalorieLevel(String workoutType, int durationMinutes) {
    final met = MET_VALUES[workoutType] ?? MET_VALUES['other']!;
    final estimatedCalories = met * 70 * (durationMinutes / 60); // 按70kg估算

    if (estimatedCalories < 100) {
      return '轻度';
    } else if (estimatedCalories < 200) {
      return '中度';
    } else if (estimatedCalories < 400) {
      return '高度';
    } else {
      return '极高';
    }
  }
}

/// 卡路里计算结果
class CalorieResult {
  final double calories;
  final String formatted;
  final String level;

  CalorieResult({
    required this.calories,
    required this.formatted,
    required this.level,
  });

  factory CalorieResult.calculate({
    required String workoutType,
    required int durationMinutes,
    double? distance,
    int? sets,
    double? weight,
  }) {
    final service = CalorieCalculatorService();

    double calories;
    if (distance != null && distance > 0) {
      calories = service.calculateCaloriesWithDistance(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        distanceMeters: distance,
        weight: weight,
      );
    } else if (sets != null && sets > 0) {
      calories = service.calculateStrengthCalories(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        sets: sets,
        weight: weight,
      );
    } else {
      calories = service.calculateCalories(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        weight: weight,
      );
    }

    return CalorieResult(
      calories: calories,
      formatted: CalorieCalculatorService.formatCalories(calories),
      level: CalorieCalculatorService.getCalorieLevel(workoutType, durationMinutes),
    );
  }

  @override
  String toString() => formatted;
}
