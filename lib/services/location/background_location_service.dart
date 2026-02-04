/// 后台位置服务 - 配置后台位置获取
/// 用于在应用后台时继续获取位置更新

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 后台位置配置
class BackgroundLocationConfig {
  final Duration updateInterval;
  final double distanceFilter;
  final LocationAccuracy accuracy;

  const BackgroundLocationConfig({
    this.updateInterval = const Duration(minutes: 5),
    this.distanceFilter = 100,
    this.accuracy = LocationAccuracy.medium,
  });

  /// 默认配置 - 平衡精度和电池消耗
  static const balanced = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 5),
    distanceFilter: 100,
    accuracy: LocationAccuracy.medium,
  );

  /// 高精度配置 - 更多电池消耗
  static const highAccuracy = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 1),
    distanceFilter: 50,
    accuracy: LocationAccuracy.high,
  );

  /// 省电配置 - 较低精度，最少电池消耗
  static const powerSaver = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 15),
    distanceFilter: 200,
    accuracy: LocationAccuracy.low,
  );
}

/// 后台位置服务 - 单例模式
class BackgroundLocationService {
  // ==================== 单例模式 ====================
  BackgroundLocationService._();
  static final BackgroundLocationService _instance = BackgroundLocationService._();
  static BackgroundLocationService get instance => _instance;

  // ==================== 状态 ====================
  bool _isRunning = false;
  BackgroundLocationConfig _config = BackgroundLocationConfig.balanced;

  // ==================== 位置监听 ====================
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  // ==================== 统计信息 ====================
  int _locationUpdateCount = 0;
  DateTime? _lastUpdateTime;
  Position? _lastPosition;

  // ==================== Getters ====================
  bool get isRunning => _isRunning;
  Stream<Position> get positionStream => _positionController.stream;
  int get locationUpdateCount => _locationUpdateCount;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  Position? get lastPosition => _lastPosition;

  // ==================== 配置 ====================

  /// 设置后台位置配置
  void setConfig(BackgroundLocationConfig config) {
    if (_isRunning) {
      debugPrint('服务运行中无法更改配置，请先停止服务');
      return;
    }
    _config = config;
  }

  /// 获取当前配置
  BackgroundLocationConfig get config => _config;

  // ==================== 权限检查 ====================

  /// 检查后台位置权限
  Future<bool> checkBackgroundPermissions() async {
    try {
      // 检查基础位置权限
      LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
        if (locationPermission == LocationPermission.denied) {
          debugPrint('基础位置权限被拒绝');
          return false;
        }
      }

      // 检查后台位置权限（Android需要always权限）
      if (locationPermission != LocationPermission.always) {
        debugPrint('需要"始终允许"位置权限以支持后台定位');

        // 尝试请求always权限
        final alwaysPermission = await Permission.locationAlways.request();
        if (!alwaysPermission.isGranted) {
          debugPrint('后台位置权限未授予');
          return false;
        }
      }

      // 检查后台运行权限（Android 9+）
      final backgroundPermission = await Permission.locationWhenInUse.status;
      if (!backgroundPermission.isGranted) {
        debugPrint('后台运行权限未授予');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('检查后台位置权限失败: $e');
      return false;
    }
  }

  /// 检查电池优化是否已忽略
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      // Android 特定：检查电池优化
      final isIgnored = await Permission.ignoreBatteryOptimizations.status;
      return isIgnored.isGranted;
    } catch (e) {
      debugPrint('检查电池优化失败: $e');
      return false;
    }
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('请求忽略电池优化失败: $e');
      return false;
    }
  }

  // ==================== 服务控制 ====================

  /// 启动后台位置服务
  Future<bool> start() async {
    if (_isRunning) {
      debugPrint('后台位置服务已在运行');
      return true;
    }

    // 检查权限
    final hasPermission = await checkBackgroundPermissions();
    if (!hasPermission) {
      debugPrint('后台位置权限不足，无法启动服务');
      return false;
    }

    try {
      // 配置位置监听
      final locationSettings = AndroidSettings(
        accuracy: _config.accuracy,
        distanceFilter: _config.distanceFilter.toInt(),
        intervalDuration: _config.updateInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '位置提醒',
          notificationText: '正在后台监控您的位置...',
          setOngoing: true,
          notificationIcon: AndroidResource(
            name: 'launcher',
            defType: 'mipmap',
          ),
        ),
      );

      // 开始位置监听
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          debugPrint('后台位置更新错误: $error');
        },
      );

      _isRunning = true;
      debugPrint('后台位置服务已启动');
      return true;
    } catch (e) {
      debugPrint('启动后台位置服务失败: $e');
      return false;
    }
  }

  /// 停止后台位置服务
  void stop() {
    if (!_isRunning) return;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _isRunning = false;
    debugPrint('后台位置服务已停止');
  }

  /// 重置统计信息
  void resetStats() {
    _locationUpdateCount = 0;
    _lastUpdateTime = null;
    _lastPosition = null;
  }

  // ==================== 位置更新处理 ====================

  void _onPositionUpdate(Position position) {
    _locationUpdateCount++;
    _lastUpdateTime = DateTime.now();
    _lastPosition = position;

    // 发送位置更新
    _positionController.add(position);

    debugPrint('后台位置更新: ${position.latitude}, ${position.longitude}');
  }

  // ==================== 释放资源 ====================
  void dispose() {
    stop();
    _positionController.close();
  }
}

/// 后台位置配置预设
class BackgroundLocationPresets {
  /// 日常使用 - 平衡精度和电池
  static const daily = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 5),
    distanceFilter: 100,
    accuracy: LocationAccuracy.medium,
  );

  /// 运动追踪 - 高精度
  static const workout = BackgroundLocationConfig(
    updateInterval: Duration(seconds: 30),
    distanceFilter: 50,
    accuracy: LocationAccuracy.high,
  );

  /// 省电模式 - 低精度
  static const powerSaving = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 15),
    distanceFilter: 200,
    accuracy: LocationAccuracy.low,
  );

  /// 围栏监控 - 中等精度
  static const geofence = BackgroundLocationConfig(
    updateInterval: Duration(minutes: 2),
    distanceFilter: 50,
    accuracy: LocationAccuracy.high,
  );
}
