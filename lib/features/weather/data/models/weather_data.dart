/// 天气数据模型
/// 包含天气信息、运动推荐逻辑

import 'package:thick_notepad/features/weather/domain/services/workout_recommender.dart';

// ==================== 天气状况枚举 ====================

/// 天气状况类型
enum WeatherCondition {
  /// 晴朗
  sunny,
  /// 多云
  cloudy,
  /// 阴天
  overcast,
  /// 小雨
  lightRain,
  /// 中雨
  moderateRain,
  /// 大雨/暴雨
  heavyRain,
  /// 雷阵雨
  thunderstorm,
  /// 小雪
  lightSnow,
  /// 大雪
  heavySnow,
  /// 雾霾
  fog,
  /// 沙尘暴
  dust,
  /// 未知/默认
  unknown,
}

/// 天气状况扩展方法
extension WeatherConditionExtension on WeatherCondition {
  /// 获取天气显示名称
  String get displayName {
    switch (this) {
      case WeatherCondition.sunny:
        return '晴朗';
      case WeatherCondition.cloudy:
        return '多云';
      case WeatherCondition.overcast:
        return '阴天';
      case WeatherCondition.lightRain:
        return '小雨';
      case WeatherCondition.moderateRain:
        return '中雨';
      case WeatherCondition.heavyRain:
        return '大雨';
      case WeatherCondition.thunderstorm:
        return '雷阵雨';
      case WeatherCondition.lightSnow:
        return '小雪';
      case WeatherCondition.heavySnow:
        return '大雪';
      case WeatherCondition.fog:
        return '雾霾';
      case WeatherCondition.dust:
        return '沙尘暴';
      case WeatherCondition.unknown:
        return '未知';
    }
  }

  /// 获取天气图标
  String get icon {
    switch (this) {
      case WeatherCondition.sunny:
        return 'assets/icons/weather_sunny.png';
      case WeatherCondition.cloudy:
        return 'assets/icons/weather_cloudy.png';
      case WeatherCondition.overcast:
        return 'assets/icons/weather_overcast.png';
      case WeatherCondition.lightRain:
      case WeatherCondition.moderateRain:
        return 'assets/icons/weather_rain.png';
      case WeatherCondition.heavyRain:
      case WeatherCondition.thunderstorm:
        return 'assets/icons/weather_storm.png';
      case WeatherCondition.lightSnow:
      case WeatherCondition.heavySnow:
        return 'assets/icons/weather_snow.png';
      case WeatherCondition.fog:
      case WeatherCondition.dust:
        return 'assets/icons/weather_fog.png';
      case WeatherCondition.unknown:
        return 'assets/icons/weather_unknown.png';
    }
  }

  /// 获取 Material 图标
  String get materialIcon {
    switch (this) {
      case WeatherCondition.sunny:
        return 'wb_sunny';
      case WeatherCondition.cloudy:
        return 'cloud';
      case WeatherCondition.overcast:
        return 'cloud_queue';
      case WeatherCondition.lightRain:
      case WeatherCondition.moderateRain:
        return 'water_drop';
      case WeatherCondition.heavyRain:
      case WeatherCondition.thunderstorm:
        return 'thunderstorm';
      case WeatherCondition.lightSnow:
      case WeatherCondition.heavySnow:
        return 'ac_unit';
      case WeatherCondition.fog:
      case WeatherCondition.dust:
        return 'foggy';
      case WeatherCondition.unknown:
        return 'help_outline';
    }
  }

  /// 是否为降水天气
  bool get isPrecipitation {
    return this == WeatherCondition.lightRain ||
        this == WeatherCondition.moderateRain ||
        this == WeatherCondition.heavyRain ||
        this == WeatherCondition.thunderstorm ||
        this == WeatherCondition.lightSnow ||
        this == WeatherCondition.heavySnow;
  }

  /// 是否为恶劣天气
  bool get isSevere {
    return this == WeatherCondition.heavyRain ||
        this == WeatherCondition.thunderstorm ||
        this == WeatherCondition.heavySnow ||
        this == WeatherCondition.dust;
  }
}

// ==================== 空气质量等级 ====================

/// 空气质量等级
enum AirQualityLevel {
  /// 优 (0-50)
  excellent,
  /// 良 (51-100)
  good,
  /// 轻度污染 (101-150)
  lightlyPolluted,
  /// 中度污染 (151-200)
  moderatelyPolluted,
  /// 重度污染 (201-300)
  heavilyPolluted,
  /// 严重污染 (>300)
  severelyPolluted,
}

/// 空气质量等级扩展
extension AirQualityLevelExtension on AirQualityLevel {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case AirQualityLevel.excellent:
        return '优';
      case AirQualityLevel.good:
        return '良';
      case AirQualityLevel.lightlyPolluted:
        return '轻度污染';
      case AirQualityLevel.moderatelyPolluted:
        return '中度污染';
      case AirQualityLevel.heavilyPolluted:
        return '重度污染';
      case AirQualityLevel.severelyPolluted:
        return '严重污染';
    }
  }

  /// 获取颜色值（十六进制）
  int get colorValue {
    switch (this) {
      case AirQualityLevel.excellent:
        return 0xFF00E400; // 绿色
      case AirQualityLevel.good:
        return 0xFFFFD700; // 黄色
      case AirQualityLevel.lightlyPolluted:
        return 0xFFFF7E00; // 橙色
      case AirQualityLevel.moderatelyPolluted:
        return 0xFFFF0000; // 红色
      case AirQualityLevel.heavilyPolluted:
        return 0xFF99004C; // 紫色
      case AirQualityLevel.severelyPolluted:
        return 0xFF7E0023; // 褐红
    }
  }

  /// 是否适合户外运动
  bool get isSuitableForOutdoor {
    return this == AirQualityLevel.excellent || this == AirQualityLevel.good;
  }

  /// 从 AQI 数值获取等级
  static AirQualityLevel fromAqi(int aqi) {
    if (aqi <= 50) return AirQualityLevel.excellent;
    if (aqi <= 100) return AirQualityLevel.good;
    if (aqi <= 150) return AirQualityLevel.lightlyPolluted;
    if (aqi <= 200) return AirQualityLevel.moderatelyPolluted;
    if (aqi <= 300) return AirQualityLevel.heavilyPolluted;
    return AirQualityLevel.severelyPolluted;
  }
}

// ==================== 运动场景类型 ====================

/// 运动场景类型
enum WorkoutScenario {
  /// 户外运动
  outdoor,
  /// 室内运动
  indoor,
  /// 混合（都可）
  mixed,
}

// ==================== 天气数据模型 ====================

/// 天气数据模型
class WeatherData {
  /// 天气状况
  final WeatherCondition condition;

  /// 温度（摄氏度）
  final double temperature;

  /// 体感温度（摄氏度）
  final double feelsLike;

  /// 湿度（百分比 0-100）
  final double humidity;

  /// 风速（公里/小时）
  final double windSpeed;

  /// 风向（度 0-360）
  final int? windDirection;

  /// 空气质量指数
  final int airQualityIndex;

  /// 能见度（公里）
  final double? visibility;

  /// 气压（百帕）
  final double? pressure;

  /// 更新时间
  final DateTime updateTime;

  /// 位置名称
  final String? locationName;

  /// 纬度
  final double? latitude;

  /// 经度
  final double? longitude;

  const WeatherData({
    required this.condition,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    this.windDirection,
    required this.airQualityIndex,
    this.visibility,
    this.pressure,
    required this.updateTime,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  /// 从 JSON 创建
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: _parseCondition(json['condition'] as String?),
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feelsLike'] as num?)?.toDouble() ?? (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble() ?? 50.0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      windDirection: json['windDirection'] as int?,
      airQualityIndex: json['airQualityIndex'] as int? ?? 50,
      visibility: (json['visibility'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      updateTime: DateTime.parse(json['updateTime'] as String),
      locationName: json['locationName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// 解析天气状况字符串
  static WeatherCondition _parseCondition(String? condition) {
    if (condition == null) return WeatherCondition.unknown;

    switch (condition.toLowerCase()) {
      case 'sunny':
      case 'clear':
      case '晴':
      case '晴朗':
        return WeatherCondition.sunny;
      case 'cloudy':
      case 'partly':
      case '多云':
        return WeatherCondition.cloudy;
      case 'overcast':
      case '阴':
      case '阴天':
        return WeatherCondition.overcast;
      case 'lightrain':
      case 'drizzle':
      case '小雨':
        return WeatherCondition.lightRain;
      case 'moderaterain':
      case 'rain':
      case '中雨':
      case '雨':
        return WeatherCondition.moderateRain;
      case 'heavyrain':
      case '大雨':
      case '暴雨':
        return WeatherCondition.heavyRain;
      case 'thunderstorm':
      case '雷阵雨':
        return WeatherCondition.thunderstorm;
      case 'lightsnow':
      case '小雪':
        return WeatherCondition.lightSnow;
      case 'heavysnow':
      case '大雪':
      case '暴雪':
        return WeatherCondition.heavySnow;
      case 'fog':
      case 'haze':
      case 'mist':
      case '雾霾':
      case '雾':
        return WeatherCondition.fog;
      case 'dust':
      case 'sand':
      case '沙尘暴':
        return WeatherCondition.dust;
      default:
        return WeatherCondition.unknown;
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'condition': condition.name,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'airQualityIndex': airQualityIndex,
      'visibility': visibility,
      'pressure': pressure,
      'updateTime': updateTime.toIso8601String(),
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// 获取空气质量等级
  AirQualityLevel get airQualityLevel =>
      AirQualityLevelExtension.fromAqi(airQualityIndex);

  /// 判断是否适合户外运动
  bool isSuitableForOutdoor() {
    // 恶劣天气不适合
    if (condition.isSevere) return false;

    // 降水天气不适合
    if (condition.isPrecipitation) return false;

    // 温度过高或过低不适合（>35°C 或 <0°C）
    if (temperature > 35 || temperature < 0) return false;

    // 空气质量差不适合
    if (!airQualityLevel.isSuitableForOutdoor) return false;

    // 风速过大不适合（>50 km/h）
    if (windSpeed > 50) return false;

    // 能见度过低不适合（<1 km）
    if (visibility != null && visibility! < 1) return false;

    return true;
  }

  /// 获取推荐的运动场景
  WorkoutScenario getRecommendedScenario() {
    if (isSuitableForOutdoor()) {
      return WorkoutScenario.outdoor;
    }
    return WorkoutScenario.indoor;
  }

  /// 获取推荐的运动类型列表
  List<String> getRecommendedWorkouts() {
    final scenario = getRecommendedScenario();
    return WorkoutRecommender.getRecommendedWorkouts(
      condition: condition,
      temperature: temperature,
      scenario: scenario,
    );
  }

  /// 获取天气描述
  String getWeatherDescription() {
    final tempDesc = _getTemperatureDescription();
    final conditionDesc = condition.displayName;
    final aqiDesc = _getAirQualityDescription();

    return '$conditionDesc，$tempDesc，空气质量${airQualityLevel.displayName}$aqiDesc';
  }

  /// 获取温度描述
  String _getTemperatureDescription() {
    if (temperature >= 35) {
      return '酷热${temperature.toStringAsFixed(0)}°C';
    } else if (temperature >= 30) {
      return '炎热${temperature.toStringAsFixed(0)}°C';
    } else if (temperature >= 25) {
      return '温暖${temperature.toStringAsFixed(0)}°C';
    } else if (temperature >= 18) {
      return '舒适${temperature.toStringAsFixed(0)}°C';
    } else if (temperature >= 10) {
      return '凉爽${temperature.toStringAsFixed(0)}°C';
    } else if (temperature >= 0) {
      return '寒冷${temperature.toStringAsFixed(0)}°C';
    } else {
      return '严寒${temperature.toStringAsFixed(0)}°C';
    }
  }

  /// 获取空气质量描述
  String _getAirQualityDescription() {
    final level = airQualityLevel;
    if (level == AirQualityLevel.excellent) {
      return '，空气清新';
    } else if (level == AirQualityLevel.good) {
      return '，空气不错';
    } else if (level == AirQualityLevel.lightlyPolluted) {
      return '，敏感人群减少户外活动';
    } else if (level == AirQualityLevel.moderatelyPolluted) {
      return '，建议减少户外活动';
    } else {
      return '，避免户外活动';
    }
  }

  /// 获取运动建议
  String getWorkoutAdvice() {
    if (isSuitableForOutdoor()) {
      return '天气不错，适合户外运动！推荐：${getRecommendedWorkouts().take(3).join('、')}';
    } else {
      final reasons = <String>[];
      if (condition.isSevere || condition.isPrecipitation) {
        reasons.add('天气不好');
      }
      if (temperature > 35 || temperature < 0) {
        reasons.add('温度不适');
      }
      if (!airQualityLevel.isSuitableForOutdoor) {
        reasons.add('空气质量差');
      }
      if (windSpeed > 50) {
        reasons.add('风力过大');
      }

      final reason = reasons.isNotEmpty ? reasons.join('、') : '条件不佳';
      return '$reason，建议室内运动。推荐：${getRecommendedWorkouts().take(3).join('、')}';
    }
  }

  /// 复制并修改部分字段
  WeatherData copyWith({
    WeatherCondition? condition,
    double? temperature,
    double? feelsLike,
    double? humidity,
    double? windSpeed,
    int? windDirection,
    int? airQualityIndex,
    double? visibility,
    double? pressure,
    DateTime? updateTime,
    String? locationName,
    double? latitude,
    double? longitude,
  }) {
    return WeatherData(
      condition: condition ?? this.condition,
      temperature: temperature ?? this.temperature,
      feelsLike: feelsLike ?? this.feelsLike,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      airQualityIndex: airQualityIndex ?? this.airQualityIndex,
      visibility: visibility ?? this.visibility,
      pressure: pressure ?? this.pressure,
      updateTime: updateTime ?? this.updateTime,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() {
    return 'WeatherData{condition: $condition, temperature: $temperature°C, '
        'humidity: $humidity%, windSpeed: $windSpeed km/h, '
        'aqi: $airQualityIndex, updateTime: $updateTime}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WeatherData &&
        other.condition == condition &&
        other.temperature == temperature &&
        other.feelsLike == feelsLike &&
        other.humidity == humidity &&
        other.windSpeed == windSpeed &&
        other.airQualityIndex == airQualityIndex;
  }

  @override
  int get hashCode {
    return condition.hashCode ^
        temperature.hashCode ^
        feelsLike.hashCode ^
        humidity.hashCode ^
        windSpeed.hashCode ^
        airQualityIndex.hashCode;
  }
}

// ==================== 天气缓存数据 ====================

/// 带有缓存过期时间的天气数据
class CachedWeatherData {
  /// 天气数据
  final WeatherData data;

  /// 缓存时间戳
  final DateTime cacheTime;

  /// 缓存有效期（分钟）
  final int validityMinutes;

  const CachedWeatherData({
    required this.data,
    required this.cacheTime,
    this.validityMinutes = 30,
  });

  /// 判断缓存是否有效
  bool get isValid {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    return difference.inMinutes < validityMinutes;
  }

  /// 获取剩余缓存时间（分钟）
  int get remainingMinutes {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    final remaining = validityMinutes - difference.inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// 创建新的缓存实例
  factory CachedWeatherData.create(WeatherData data, {int validityMinutes = 30}) {
    return CachedWeatherData(
      data: data,
      cacheTime: DateTime.now(),
      validityMinutes: validityMinutes,
    );
  }
}
