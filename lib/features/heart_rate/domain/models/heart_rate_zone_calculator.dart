/// 心率区间计算工具类
/// 根据年龄和心率值计算当前所在的心率区间

import 'package:flutter/material.dart';

/// 心率区间枚举
enum HeartRateZone {
  warmUp('热身区间', 50, 60, Color(0xFF60A5FA)),      // 蓝色
  fatBurn('燃脂区间', 60, 70, Color(0xFF34D399)),     // 绿色
  aerobic('有氧区间', 70, 80, Color(0xFFFBBF24)),     // 黄色
  anaerobic('无氧区间', 80, 90, Color(0xFFFB923C)),  // 橙色
  maximum('极限区间', 90, 100, Color(0xFFEF4444));   // 红色

  final String displayName;
  final int minPercent;
  final int maxPercent;
  final Color color;

  const HeartRateZone(
    this.displayName,
    this.minPercent,
    this.maxPercent,
    this.color,
  );

  /// 获取区间说明
  String get description {
    switch (this) {
      case HeartRateZone.warmUp:
        return '轻松热身，准备运动';
      case HeartRateZone.fatBurn:
        return '燃脂瘦身，提高耐力';
      case HeartRateZone.aerobic:
        return '有氧训练，增强心肺';
      case HeartRateZone.anaerobic:
        return '无氧训练，提升爆发';
      case HeartRateZone.maximum:
        return '极限挑战，谨慎使用';
    }
  }

  /// 获取区间建议
  String get advice {
    switch (this) {
      case HeartRateZone.warmUp:
        return '适合运动前的热身和运动后的放松';
      case HeartRateZone.fatBurn:
        return '最适合减脂的区间，可以长时间坚持';
      case HeartRateZone.aerobic:
        return '提升心肺功能的有效区间';
      case HeartRateZone.anaerobic:
        return '提升爆发力和速度，注意控制时长';
      case HeartRateZone.maximum:
        return '极限训练区间，建议有专业指导';
    }
  }
}

/// 心率区间信息
class HeartRateZoneInfo {
  final HeartRateZone zone;
  final int minHeartRate;
  final int maxHeartRate;
  final int currentHeartRate;
  final int percentOfMax;

  HeartRateZoneInfo({
    required this.zone,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.currentHeartRate,
    required this.percentOfMax,
  });

  /// 获取当前心率的进度百分比（在当前区间内的位置）
  double get progressInZone {
    final range = maxHeartRate - minHeartRate;
    if (range == 0) return 0.5;
    final position = currentHeartRate - minHeartRate;
    return (position / range).clamp(0.0, 1.0);
  }

  /// 是否在当前区间内
  bool get isInZone =>
      currentHeartRate >= minHeartRate && currentHeartRate < maxHeartRate;
}

/// 心率区间计算器
class HeartRateZoneCalculator {
  /// 计算最大心率（使用公式：220 - 年龄）
  static int calculateMaxHeartRate(int age) {
    return (220 - age).clamp(100, 200);
  }

  /// 根据年龄获取心率区间范围
  static Map<HeartRateZone, HeartRateZoneInfo> getZones(int age) {
    final maxHeartRate = calculateMaxHeartRate(age);

    return {
      HeartRateZone.warmUp: HeartRateZoneInfo(
        zone: HeartRateZone.warmUp,
        minHeartRate: (maxHeartRate * 0.5).round(),
        maxHeartRate: (maxHeartRate * 0.6).round(),
        currentHeartRate: 0,
        percentOfMax: 55,
      ),
      HeartRateZone.fatBurn: HeartRateZoneInfo(
        zone: HeartRateZone.fatBurn,
        minHeartRate: (maxHeartRate * 0.6).round(),
        maxHeartRate: (maxHeartRate * 0.7).round(),
        currentHeartRate: 0,
        percentOfMax: 65,
      ),
      HeartRateZone.aerobic: HeartRateZoneInfo(
        zone: HeartRateZone.aerobic,
        minHeartRate: (maxHeartRate * 0.7).round(),
        maxHeartRate: (maxHeartRate * 0.8).round(),
        currentHeartRate: 0,
        percentOfMax: 75,
      ),
      HeartRateZone.anaerobic: HeartRateZoneInfo(
        zone: HeartRateZone.anaerobic,
        minHeartRate: (maxHeartRate * 0.8).round(),
        maxHeartRate: (maxHeartRate * 0.9).round(),
        currentHeartRate: 0,
        percentOfMax: 85,
      ),
      HeartRateZone.maximum: HeartRateZoneInfo(
        zone: HeartRateZone.maximum,
        minHeartRate: (maxHeartRate * 0.9).round(),
        maxHeartRate: maxHeartRate,
        currentHeartRate: 0,
        percentOfMax: 95,
      ),
    };
  }

  /// 根据当前心率获取所在区间
  static HeartRateZoneInfo? getCurrentZone(int heartRate, int age) {
    final maxHeartRate = calculateMaxHeartRate(age);
    final percent = ((heartRate / maxHeartRate) * 100).round();

    for (final zone in HeartRateZone.values) {
      if (percent >= zone.minPercent && percent < zone.maxPercent) {
        final minHr = (maxHeartRate * zone.minPercent / 100).round();
        final maxHr = (maxHeartRate * zone.maxPercent / 100).round();
        return HeartRateZoneInfo(
          zone: zone,
          minHeartRate: minHr,
          maxHeartRate: maxHr,
          currentHeartRate: heartRate,
          percentOfMax: percent,
        );
      }
    }

    // 如果超过100%，返回极限区间
    if (percent >= 90) {
      final zone = HeartRateZone.maximum;
      return HeartRateZoneInfo(
        zone: zone,
        minHeartRate: (maxHeartRate * 0.9).round(),
        maxHeartRate: maxHeartRate,
        currentHeartRate: heartRate,
        percentOfMax: percent.clamp(0, 100),
      );
    }

    return null;
  }

  /// 根据自定义最大心率获取所在区间
  static HeartRateZoneInfo? getCurrentZoneWithCustomMax(
    int heartRate,
    int maxHeartRate,
  ) {
    if (maxHeartRate <= 0) return null;

    final percent = ((heartRate / maxHeartRate) * 100).round();

    for (final zone in HeartRateZone.values) {
      if (percent >= zone.minPercent && percent < zone.maxPercent) {
        final minHr = (maxHeartRate * zone.minPercent / 100).round();
        final maxHr = (maxHeartRate * zone.maxPercent / 100).round();
        return HeartRateZoneInfo(
          zone: zone,
          minHeartRate: minHr,
          maxHeartRate: maxHr,
          currentHeartRate: heartRate,
          percentOfMax: percent,
        );
      }
    }

    // 如果超过100%，返回极限区间
    if (percent >= 90) {
      final zone = HeartRateZone.maximum;
      return HeartRateZoneInfo(
        zone: zone,
        minHeartRate: (maxHeartRate * 0.9).round(),
        maxHeartRate: maxHeartRate,
        currentHeartRate: heartRate,
        percentOfMax: percent.clamp(0, 100),
      );
    }

    return null;
  }

  /// 获取心率区间颜色
  static Color getZoneColor(int heartRate, int age) {
    final zoneInfo = getCurrentZone(heartRate, age);
    return zoneInfo?.zone.color ?? Colors.grey;
  }
}
