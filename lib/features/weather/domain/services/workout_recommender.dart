/// 运动推荐服务
/// 根据天气条件推荐合适的运动类型

import 'package:thick_notepad/features/weather/data/models/weather_data.dart';

// ==================== 运动推荐服务 ====================

/// 运动推荐服务
class WorkoutRecommender {
  // 私有构造函数，防止实例化
  WorkoutRecommender._();

  /// 户外运动映射表
  static const Map<WeatherCondition, List<String>> _outdoorWorkouts = {
    WeatherCondition.sunny: [
      '跑步',
      '骑行',
      '户外徒步',
      '篮球',
      '足球',
      '网球',
      '登山',
      '户外瑜伽',
      '滑板',
      '飞盘',
    ],
    WeatherCondition.cloudy: [
      '跑步',
      '骑行',
      '户外徒步',
      '羽毛球',
      '乒乓球',
      '户外健身',
      '登山',
      '钓鱼',
      '高尔夫',
    ],
    WeatherCondition.overcast: [
      '跑步',
      '骑行',
      '户外徒步',
      '羽毛球',
      '户外健身',
      '登山',
      '太极',
      '放风筝',
    ],
  };

  /// 室内运动映射表（恶劣天气）
  static const List<String> _indoorWorkouts = [
    '跑步机',
    '室内瑜伽',
    '力量训练',
    '跳绳',
    '动感单车',
    '游泳',
    '健身操',
    '哑铃训练',
    '俯卧撑',
    '仰卧起坐',
    '平板支撑',
    '波比跳',
    '普拉提',
    '室内攀岩',
    '拳击',
    '舞蹈',
  ];

  /// 高温天气运动（>30°C）
  static const List<String> _hotWeatherWorkouts = [
    '游泳',
    '室内瑜伽',
    '室内骑行',
    '健身房训练',
    '室内攀岩',
    '水中健身',
    '早晚散步',
  ];

  /// 低温天气运动（<10°C）
  static const List<String> _coldWeatherWorkouts = [
    '室内跑步',
    '力量训练',
    '室内瑜伽',
    '跳绳',
    '动感单车',
    '滑雪',
    '室内滑冰',
    '健身房训练',
  ];

  /// 获取推荐的运动列表
  ///
  /// 参数：
  /// - [condition] 天气状况
  /// - [temperature] 温度
  /// - [scenario] 运动场景（户外/室内/混合）
  static List<String> getRecommendedWorkouts({
    required WeatherCondition condition,
    required double temperature,
    WorkoutScenario scenario = WorkoutScenario.mixed,
  }) {
    // 根据场景选择运动类型
    if (scenario == WorkoutScenario.indoor) {
      return _getIndoorWorkouts(temperature);
    }

    if (scenario == WorkoutScenario.outdoor) {
      return _getOutdoorWorkouts(condition);
    }

    // 混合场景：根据温度和天气状况推荐
    if (temperature > 30) {
      // 高温天气推荐室内
      return [..._hotWeatherWorkouts.take(5), '早晚散步'];
    } else if (temperature < 10) {
      // 低温天气推荐室内
      return _coldWeatherWorkouts;
    } else if (condition.isSevere || condition.isPrecipitation) {
      // 恶劣天气推荐室内
      return _indoorWorkouts;
    } else {
      // 好天气推荐户外
      return _getOutdoorWorkouts(condition);
    }
  }

  /// 获取户外运动推荐
  static List<String> _getOutdoorWorkouts(WeatherCondition condition) {
    return _outdoorWorkouts[condition] ?? _outdoorWorkouts[WeatherCondition.sunny]!;
  }

  /// 获取室内运动推荐
  static List<String> _getIndoorWorkouts(double temperature) {
    if (temperature > 30) {
      return _hotWeatherWorkouts;
    } else if (temperature < 10) {
      return _coldWeatherWorkouts;
    }
    return _indoorWorkouts;
  }

  /// 获取运动强度建议
  ///
  /// 根据温度返回推荐的运动强度
  static String getIntensityRecommendation(double temperature) {
    if (temperature > 35) {
      return '高温预警，建议低强度运动或休息';
    } else if (temperature > 30) {
      return '温度较高，建议中低强度运动';
    } else if (temperature > 25) {
      return '温度适宜，可进行中等强度运动';
    } else if (temperature > 15) {
      return '温度舒适，适合各种强度运动';
    } else if (temperature > 5) {
      return '温度偏低，建议中等强度热身后再运动';
    } else if (temperature > 0) {
      return '温度较低，建议室内运动或低强度户外活动';
    } else {
      return '严寒天气，建议室内运动';
    }
  }

  /// 获取运动时长建议
  ///
  /// 根据天气条件返回推荐的运动时长（分钟）
  static int getDurationRecommendation(WeatherData weather) {
    // 恶劣天气建议短时间
    if (weather.condition.isSevere) {
      return 30;
    }

    // 高温或低温建议短时间
    if (weather.temperature > 32 || weather.temperature < 5) {
      return 30;
    }

    // 空气质量差建议短时间
    if (weather.airQualityIndex > 150) {
      return 30;
    }

    // 舒适天气可以长时间运动
    if (weather.temperature >= 15 && weather.temperature <= 28) {
      return 60;
    }

    // 其他情况中等时长
    return 45;
  }

  /// 获取运动装备建议
  ///
  /// 根据天气条件返回需要的运动装备
  static List<String> getGearRecommendation(WeatherData weather) {
    final recommendations = <String>[];

    // 温度相关装备
    if (weather.temperature < 5) {
      recommendations.addAll(['保暖服', '手套', '帽子']);
    } else if (weather.temperature < 15) {
      recommendations.addAll(['长袖运动服', '轻薄外套']);
    } else if (weather.temperature > 28) {
      recommendations.addAll(['透气运动服', '防晒霜']);
    } else if (weather.temperature > 32) {
      recommendations.addAll(['透气运动服', '防晒霜', '太阳镜', '遮阳帽']);
    }

    // 降水相关装备
    if (weather.condition == WeatherCondition.lightRain) {
      recommendations.addAll(['轻便雨衣', '防水鞋']);
    } else if (weather.condition == WeatherCondition.moderateRain ||
        weather.condition == WeatherCondition.heavyRain) {
      recommendations.addAll(['防水外套', '防水鞋', '换洗衣物']);
    }

    // 空气质量相关装备
    if (weather.airQualityIndex > 100) {
      recommendations.add('防护口罩');
    }

    // 风力相关装备
    if (weather.windSpeed > 30) {
      recommendations.add('防风外套');
    }

    return recommendations;
  }

  /// 获取运动时间建议
  ///
  /// 返回推荐的户外运动时间段
  static List<String> getTimeRecommendation(WeatherData weather) {
    if (weather.temperature > 30) {
      return ['清晨 6:00-8:00', '傍晚 18:00-20:00'];
    } else if (weather.temperature < 5) {
      return ['下午 14:00-16:00'];
    } else if (weather.condition == WeatherCondition.fog ||
        weather.condition == WeatherCondition.dust) {
      return ['等待天气好转'];
    }

    return ['上午 8:00-10:00', '下午 16:00-18:00', '傍晚 18:00-20:00'];
  }

  /// 获取详细的运动建议报告
  static String getDetailedReport(WeatherData weather) {
    final buffer = StringBuffer();

    // 天气概况
    buffer.writeln('📍 ${weather.locationName ?? "当前位置"}');
    buffer.writeln('🌡️ ${weather.condition.displayName} ${weather.temperature.toStringAsFixed(0)}°C');
    buffer.writeln('💨 风速 ${weather.windSpeed.toStringAsFixed(0)} km/h');
    buffer.writeln('🌫️ 空气质量 ${weather.airQualityLevel.displayName} (AQI ${weather.airQualityIndex})');
    buffer.writeln();

    // 运动场景
    final scenario = weather.getRecommendedScenario();
    buffer.writeln('🏃 推荐场景：${scenario == WorkoutScenario.outdoor ? "户外运动" : "室内运动"}');
    buffer.writeln();

    // 运动推荐
    buffer.writeln('💪 推荐运动：');
    final workouts = getRecommendedWorkouts(
      condition: weather.condition,
      temperature: weather.temperature,
      scenario: scenario,
    );
    for (final workout in workouts.take(5)) {
      buffer.writeln('   • $workout');
    }
    buffer.writeln();

    // 强度建议
    buffer.writeln('⚡ ${getIntensityRecommendation(weather.temperature)}');
    buffer.writeln();

    // 时长建议
    final duration = getDurationRecommendation(weather);
    buffer.writeln('⏱️ 建议时长：$duration 分钟');
    buffer.writeln();

    // 时间段建议
    if (scenario == WorkoutScenario.outdoor) {
      buffer.writeln('🕐 推荐时段：');
      final times = getTimeRecommendation(weather);
      for (final time in times) {
        buffer.writeln('   $time');
      }
      buffer.writeln();
    }

    // 装备建议
    final gears = getGearRecommendation(weather);
    if (gears.isNotEmpty) {
      buffer.writeln('🎒 建议装备：');
      for (final gear in gears) {
        buffer.writeln('   • $gear');
      }
    }

    return buffer.toString();
  }
}
