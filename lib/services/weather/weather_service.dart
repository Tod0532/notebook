/// 天气服务
/// 获取当前位置天气信息，支持缓存
///
/// 使用的免费API：
/// - Open-Meteo: 天气数据（无需API Key）
/// - Open-Meteo Air Quality: 空气质量（无需API Key）
/// - Nominatim (OpenStreetMap): 地理编码（无需API Key）

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/features/weather/data/models/weather_data.dart';

// ==================== 天气服务配置 ====================

/// 天气服务配置
class WeatherServiceConfig {
  /// API Key（使用免费的 Open-Meteo API，无需 Key）
  static const String apiKey = '';

  /// Open-Meteo API 基础 URL
  static const String baseUrl = 'https://api.open-meteo.com/v1';

  /// Nominatim 地理编码 API URL（OpenStreetMap，免费无需Key）
  static const String geocodingUrl = 'https://nominatim.openstreetmap.org/reverse';

  /// 缓存有效期（分钟）
  static const int cacheValidityMinutes = 30;

  /// 位置名称缓存有效期（小时）- 位置变化不频繁，可以缓存更久
  static const int locationCacheValidityHours = 24;

  /// 请求超时时间（秒）
  static const int requestTimeoutSeconds = 10;

  /// 用户代理（Nominatim 要求）
  static const String userAgent = 'ThickNotepad/1.0';
}

// ==================== 天气服务异常 ====================

/// 天气服务异常
class WeatherServiceException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  WeatherServiceException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'WeatherServiceException: $message';
  }
}

// ==================== 天气服务 ====================

/// 天气服务 - 单例模式
class WeatherService {
  // ==================== 单例模式 ====================
  static WeatherService? _instance;
  static final _lock = Object();

  factory WeatherService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= WeatherService._internal();
      });
    }
    return _instance!;
  }

  WeatherService._internal() {
    _initDio();
  }

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 成员变量 ====================
  late final Dio _dio;
  late final Dio _geoDio; // 地理编码专用 Dio 实例
  CachedWeatherData? _cachedWeather;
  CachedLocationData? _cachedLocation; // 位置名称缓存
  StreamController<WeatherData?>? _weatherController;
  bool _isInitialized = false;

  // ==================== 初始化 ====================

  /// 初始化 Dio 实例
  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
      receiveTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
      sendTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('天气API请求: ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('天气API响应: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('天气API错误: ${error.message}');
        handler.next(error);
      },
    ));

    // 初始化地理编码 Dio 实例（Nominatim 需要特定的 User-Agent）
    _geoDio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
      receiveTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
      sendTimeout: Duration(seconds: WeatherServiceConfig.requestTimeoutSeconds),
      headers: {
        'User-Agent': WeatherServiceConfig.userAgent,
      },
    ));

    _geoDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('地理编码API请求: ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('地理编码API错误: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 加载缓存的天气数据
      await _loadCachedWeather();

      // 加载缓存的位置名称
      await _loadCachedLocation();

      // 初始化流控制器
      _weatherController = StreamController<WeatherData?>.broadcast();

      _isInitialized = true;
      debugPrint('天气服务初始化成功');
    } catch (e) {
      debugPrint('天气服务初始化失败: $e');
    }
  }

  /// 从 SharedPreferences 加载缓存的天气数据
  Future<void> _loadCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_weather');

      if (cachedJson != null) {
        final json = jsonDecode(cachedJson) as Map<String, dynamic>;
        final weatherData = WeatherData.fromJson(json['data'] as Map<String, dynamic>);
        final cacheTime = DateTime.parse(json['cacheTime'] as String);

        _cachedWeather = CachedWeatherData(
          data: weatherData,
          cacheTime: cacheTime,
          validityMinutes: WeatherServiceConfig.cacheValidityMinutes,
        );

        debugPrint('已加载缓存的天气数据');
      }
    } catch (e) {
      debugPrint('加载缓存天气数据失败: $e');
    }
  }

  /// 从 SharedPreferences 加载缓存的位置名称
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_location');

      if (cachedJson != null) {
        final json = jsonDecode(cachedJson) as Map<String, dynamic>;
        final locationName = json['locationName'] as String?;
        final cacheTime = DateTime.parse(json['cacheTime'] as String);
        final lat = (json['latitude'] as num?)?.toDouble();
        final lon = (json['longitude'] as num?)?.toDouble();

        if (locationName != null && lat != null && lon != null) {
          _cachedLocation = CachedLocationData(
            locationName: locationName,
            latitude: lat,
            longitude: lon,
            cacheTime: cacheTime,
            validityHours: WeatherServiceConfig.locationCacheValidityHours,
          );
          debugPrint('已加载缓存的位置名称: $locationName');
        }
      }
    } catch (e) {
      debugPrint('加载缓存位置名称失败: $e');
    }
  }

  /// 保存天气数据到缓存
  Future<void> _saveCachedWeather(WeatherData weather) async {
    try {
      _cachedWeather = CachedWeatherData.create(weather);

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = jsonEncode({
        'data': weather.toJson(),
        'cacheTime': DateTime.now().toIso8601String(),
      });

      await prefs.setString('cached_weather', cachedJson);
      debugPrint('已缓存天气数据');
    } catch (e) {
      debugPrint('缓存天气数据失败: $e');
    }
  }

  // ==================== 权限检查 ====================

  /// 检查位置权限
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 检查是否启用位置服务
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw WeatherServiceException('位置服务未开启，请在设置中开启');
    }

    // 检查权限
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw WeatherServiceException('位置权限被拒绝');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw WeatherServiceException('位置权限被永久拒绝，请在设置中开启');
    }

    return true;
  }

  /// 获取当前位置
  Future<Position> getCurrentPosition() async {
    try {
      await checkLocationPermission();

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw WeatherServiceException('获取位置失败: $e');
    }
  }

  // ==================== 天气数据获取 ====================

  /// 获取天气数据（优先使用缓存）
  Future<WeatherData?> getWeather({bool forceRefresh = false}) async {
    try {
      // 如果不强制刷新，先检查缓存
      if (!forceRefresh && _cachedWeather != null && _cachedWeather!.isValid) {
        debugPrint('使用缓存的天气数据，剩余 ${_cachedWeather!.remainingMinutes} 分钟');
        return _cachedWeather!.data;
      }

      // 获取当前位置
      final position = await getCurrentPosition();

      // 获取天气数据
      final weatherData = await fetchWeather(
        position.latitude,
        position.longitude,
      );

      // 缓存天气数据
      await _saveCachedWeather(weatherData);

      // 通知监听者
      _weatherController?.add(weatherData);

      return weatherData;
    } catch (e) {
      debugPrint('获取天气失败: $e');

      // 如果请求失败但有缓存，返回缓存
      if (_cachedWeather != null) {
        debugPrint('使用过期的缓存数据');
        return _cachedWeather!.data;
      }

      rethrow;
    }
  }

  /// 从 Open-Meteo API 获取天气数据
  Future<WeatherData> fetchWeather(double lat, double lon) async {
    try {
      // 获取位置名称（并行获取，不阻塞天气数据）
      final locationName = await getLocationName(lat, lon);

      // Open-Meteo API 请求参数
      final params = {
        'latitude': lat,
        'longitude': lon,
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'apparent_temperature',
          'weather_code',
          'wind_speed_10m',
          'wind_direction_10m',
        ],
        'hourly': [
          'temperature_2m',
          'relative_humidity_2m',
          'weather_code',
        ],
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
        ],
        'timezone': 'auto',
      };

      // 并行获取天气数据和空气质量
      final results = await Future.wait([
        _dio.get(
          '${WeatherServiceConfig.baseUrl}/forecast',
          queryParameters: params,
        ),
        getAirQuality(lat, lon).catchError((_) => 50), // 空气质量获取失败时使用默认值
      ]);

      final response = results[0] as Response;
      final aqi = results[1] as int;

      if (response.statusCode == 200) {
        return _parseOpenMeteoResponse(response.data, lat, lon, locationName: locationName, airQualityIndex: aqi);
      } else {
        throw WeatherServiceException('API 请求失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw WeatherServiceException('网络请求失败: ${e.message}', e);
    }
  }

  /// 解析 Open-Meteo API 响应
  WeatherData _parseOpenMeteoResponse(
    dynamic data,
    double lat,
    double lon, {
    String? locationName,
    int airQualityIndex = 50,
  }) {
    try {
      final current = data['current'] as Map<String, dynamic>;

      // 获取当前天气数据
      final temperature = (current['temperature_2m'] as num).toDouble();
      final feelsLike = (current['apparent_temperature'] as num).toDouble();
      final humidity = (current['relative_humidity_2m'] as num).toDouble();
      final windSpeed = (current['wind_speed_10m'] as num).toDouble();
      final windDirection = current['wind_direction_10m'] as int?;
      final weatherCode = current['weather_code'] as int;

      // 解析天气代码
      final condition = _parseWeatherCode(weatherCode);

      return WeatherData(
        condition: condition,
        temperature: temperature,
        feelsLike: feelsLike,
        humidity: humidity,
        windSpeed: windSpeed,
        windDirection: windDirection,
        airQualityIndex: airQualityIndex,
        updateTime: DateTime.now(),
        locationName: locationName,
        latitude: lat,
        longitude: lon,
      );
    } catch (e) {
      throw WeatherServiceException('解析天气数据失败: $e');
    }
  }

  /// 解析 Open-Meteo 天气代码
  /// 参考: https://open-meteo.com/en/docs
  WeatherCondition _parseWeatherCode(int code) {
    switch (code) {
      // 0: 晴天
      case 0:
        return WeatherCondition.sunny;
      // 1-3: 多云
      case 1:
      case 2:
      case 3:
        return WeatherCondition.cloudy;
      // 45, 48: 雾
      case 45:
      case 48:
        return WeatherCondition.fog;
      // 51-55: 毛毛雨
      case 51:
      case 53:
      case 55:
        return WeatherCondition.lightRain;
      // 56-57: 冻雨
      case 56:
      case 57:
        return WeatherCondition.lightRain;
      // 61-65: 雨
      case 61:
      case 63:
      case 65:
        return WeatherCondition.moderateRain;
      // 66-67: 冻雨
      case 66:
      case 67:
        return WeatherCondition.moderateRain;
      // 71-77: 雪
      case 71:
      case 73:
      case 75:
      case 77:
        return WeatherCondition.lightSnow;
      // 80-82: 阵雨
      case 80:
      case 81:
      case 82:
        return WeatherCondition.moderateRain;
      // 85-86: 阵雪
      case 85:
      case 86:
        return WeatherCondition.lightSnow;
      // 95-99: 雷阵雨
      case 95:
      case 96:
      case 99:
        return WeatherCondition.thunderstorm;
      default:
        return WeatherCondition.unknown;
    }
  }

  // ==================== 空气质量 ====================

  /// 获取空气质量（使用 Open-Meteo Air Quality API）
  Future<int> getAirQuality(double lat, double lon) async {
    try {
      final params = {
        'latitude': lat,
        'longitude': lon,
        'current': [
          'us_aqi',
          'pm10',
          'pm2_5',
          'carbon_monoxide',
          'nitrogen_dioxide',
          'sulphur_dioxide',
          'ozone',
        ],
        'timezone': 'auto',
      };

      final response = await _dio.get(
        '${WeatherServiceConfig.baseUrl}/air-quality',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final aqi = response.data['current']?['us_aqi'] as int?;
        return aqi ?? 50;
      }

      return 50; // 默认值
    } catch (e) {
      debugPrint('获取空气质量失败: $e');
      return 50; // 默认值
    }
  }

  // ==================== 流订阅 ====================

  /// 天气数据流
  Stream<WeatherData?> get weatherStream {
    if (_weatherController == null) {
      _weatherController = StreamController<WeatherData?>.broadcast();
    }
    return _weatherController!.stream;
  }

  /// 当前缓存的天气数据
  WeatherData? get currentWeather => _cachedWeather?.data;

  /// 缓存是否有效
  bool get isCacheValid => _cachedWeather?.isValid ?? false;

  // ==================== 地理编码 ====================

  /// 获取位置名称（使用 Nominatim API）
  ///
  /// 将经纬度转换为可读的位置名称（如：北京市朝阳区）
  /// 使用缓存机制减少 API 调用
  Future<String?> getLocationName(double lat, double lon) async {
    try {
      // 检查缓存（位置名称变化不频繁，可以缓存更久）
      if (_cachedLocation != null &&
          _cachedLocation!.isValid &&
          _cachedLocation!.isNearby(lat, lon)) {
        debugPrint('使用缓存的位置名称: ${_cachedLocation!.locationName}');
        return _cachedLocation!.locationName;
      }

      // 调用 Nominatim API
      final response = await _geoDio.get(
        WeatherServiceConfig.geocodingUrl,
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
          'accept-language': 'zh-CN,en',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        String? locationName;

        // 优先使用显示名称（包含完整地址）
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // 提取主要部分（城市、区县等）
          locationName = _extractLocationName(displayName);
        }

        // 备用方案：使用地址组件
        if (locationName == null || locationName.isEmpty) {
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            // 尝试获取城市或区县名称
            final city = address['city'] as String? ??
                address['town'] as String? ??
                address['district'] as String? ??
                address['county'] as String? ??
                address['state'] as String?;
            if (city != null) {
              locationName = city;
            }
          }
        }

        // 缓存位置名称
        if (locationName != null && locationName.isNotEmpty) {
          await _saveCachedLocation(locationName, lat, lon);
          debugPrint('获取位置名称: $locationName');
          return locationName;
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取位置名称失败: $e');
      return _cachedLocation?.locationName; // 失败时返回缓存
    }
  }

  /// 从完整地址中提取主要位置名称
  String _extractLocationName(String displayName) {
    // 移除邮政编码等无用信息
    final cleanName = displayName.replaceAll(RegExp(r',\s*\d{5,6},.*'), '');

    // 尝试提取主要部分（通常是城市或区县）
    final parts = cleanName.split(RegExp('[,，]'));

    // 优先返回前几个有意义的部分
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && trimmed.length > 1 && !_isPostCode(trimmed)) {
        return trimmed;
      }
    }

    return cleanName.trim();
  }

  /// 判断是否是邮政编码
  bool _isPostCode(String s) {
    return RegExp(r'^\d{5,6}$').hasMatch(s);
  }

  /// 保存位置名称到缓存
  Future<void> _saveCachedLocation(String locationName, double lat, double lon) async {
    try {
      _cachedLocation = CachedLocationData.create(locationName, lat, lon);

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = jsonEncode({
        'locationName': locationName,
        'latitude': lat,
        'longitude': lon,
        'cacheTime': DateTime.now().toIso8601String(),
      });

      await prefs.setString('cached_location', cachedJson);
      debugPrint('已缓存位置名称');
    } catch (e) {
      debugPrint('缓存位置名称失败: $e');
    }
  }

  // ==================== 清理 ====================

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      _cachedWeather = null;
      _cachedLocation = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_weather');
      await prefs.remove('cached_location');
      debugPrint('已清除天气缓存');
    } catch (e) {
      debugPrint('清除缓存失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _weatherController?.close();
    _weatherController = null;
    _instance = null;
  }
}

// ==================== 位置名称缓存数据 ====================

/// 带有缓存过期时间的位置名称数据
class CachedLocationData {
  /// 位置名称
  final String locationName;

  /// 纬度
  final double latitude;

  /// 经度
  final double longitude;

  /// 缓存时间戳
  final DateTime cacheTime;

  /// 缓存有效期（小时）
  final int validityHours;

  /// 位置变化阈值（公里）- 超过此距离则重新获取
  static const double proximityThresholdKm = 5.0;

  const CachedLocationData({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.cacheTime,
    this.validityHours = 24,
  });

  /// 判断缓存是否有效
  bool get isValid {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    return difference.inHours < validityHours;
  }

  /// 判断是否在附近位置（使用简单的距离计算）
  bool isNearby(double lat, double lon) {
    // 使用简化的距离计算（对于小范围足够准确）
    final latDiff = (lat - latitude).abs();
    final lonDiff = (lon - longitude).abs();

    // 纬度1度约111公里，经度1度约111公里（在赤道附近）
    // 使用更保守的估计
    final distanceKm = (latDiff * 111 + lonDiff * 111);

    return distanceKm <= proximityThresholdKm;
  }

  /// 创建新的缓存实例
  factory CachedLocationData.create(String locationName, double lat, double lon, {int validityHours = 24}) {
    return CachedLocationData(
      locationName: locationName,
      latitude: lat,
      longitude: lon,
      cacheTime: DateTime.now(),
      validityHours: validityHours,
    );
  }
}
