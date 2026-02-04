/// 地理围栏服务 - 处理位置围栏监控和事件触发
/// 提供：位置流监听、围栏检查、进入/离开事件检测等功能

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart';

/// 地理围栏事件
class GeofenceEvent {
  final int geofenceId;
  final String geofenceName;
  final LocationEventType eventType;
  final DateTime occurredAt;
  final Position position;

  GeofenceEvent({
    required this.geofenceId,
    required this.geofenceName,
    required this.eventType,
    required this.occurredAt,
    required this.position,
  });
}

/// 地理围栏状态
enum GeofenceServiceState {
  idle,       // 空闲
  starting,   // 启动中
  monitoring, // 监控中
  stopped,    // 已停止
}

/// 地理围栏服务 - 单例模式
class GeofenceService {
  // ==================== 单例模式 ====================
  GeofenceService._();
  static final GeofenceService _instance = GeofenceService._();
  static GeofenceService get instance => _instance;

  // ==================== 状态 ====================
  GeofenceServiceState _state = GeofenceServiceState.idle;
  final StreamController<GeofenceServiceState> _stateController =
      StreamController<GeofenceServiceState>.broadcast();

  // ==================== 事件流 ====================
  final StreamController<GeofenceEvent> _eventController =
      StreamController<GeofenceEvent>.broadcast();

  // ==================== 位置监听 ====================
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  // ==================== 围栏状态追踪 ====================
  /// 记录每个围栏的当前状态（true表示在围栏内）
  final Map<int, bool> _geofenceStates = {};

  // ==================== 数据库 ====================
  AppDatabase? _database;

  // ==================== Getters ====================
  GeofenceServiceState get state => _state;
  Stream<GeofenceServiceState> get stateStream => _stateController.stream;
  Stream<GeofenceEvent> get eventStream => _eventController.stream;

  /// 设置数据库
  void setDatabase(AppDatabase database) {
    _database = database;
  }

  // ==================== 权限检查 ====================

  /// 检查并请求位置权限
  Future<bool> checkPermissions() async {
    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('位置服务未启用');
        return false;
      }

      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('位置权限被拒绝');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('位置权限被永久拒绝');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('检查位置权限失败: $e');
      return false;
    }
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      debugPrint('获取当前位置失败: $e');
      return null;
    }
  }

  // ==================== 围栏监控 ====================

  /// 开始监控所有启用的围栏
  Future<bool> startMonitoring() async {
    if (_state == GeofenceServiceState.monitoring) {
      debugPrint('围栏监控已在进行中');
      return true;
    }

    _updateState(GeofenceServiceState.starting);

    // 检查权限
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      _updateState(GeofenceServiceState.idle);
      return false;
    }

    // 检查数据库
    if (_database == null) {
      debugPrint('数据库未设置');
      _updateState(GeofenceServiceState.idle);
      return false;
    }

    try {
      // 获取初始位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = position;

      // 初始化所有启用围栏的状态
      await _initializeGeofenceStates(position);

      // 开始位置监听
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: GeofenceConfig.locationUpdateDistance.toInt(),
        intervalDuration: const Duration(seconds: GeofenceConfig.locationUpdateInterval),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '位置提醒',
          notificationText: '正在监控您的位置...',
          setOngoing: true,
          notificationIcon: AndroidResource(
            name: 'launcher',
            defType: 'mipmap',
          ),
        ),
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _onPositionUpdate(position);
        },
        onError: (error) {
          debugPrint('位置更新错误: $error');
        },
      );

      _updateState(GeofenceServiceState.monitoring);
      debugPrint('围栏监控已开始');
      return true;
    } catch (e) {
      debugPrint('开始监控失败: $e');
      _updateState(GeofenceServiceState.idle);
      return false;
    }
  }

  /// 停止监控
  void stopMonitoring() {
    if (_state == GeofenceServiceState.idle) return;

    // 取消位置监听
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _updateState(GeofenceServiceState.stopped);
    debugPrint('围栏监控已停止');
  }

  // ==================== 位置更新处理 ====================

  /// 初始化围栏状态
  Future<void> _initializeGeofenceStates(Position position) async {
    if (_database == null) return;

    try {
      final geofences = await (_database!.select(_database!.geofences)
            ..where((tbl) => tbl.isEnabled.equals(true))
          ).get();

      for (final geofence in geofences) {
        final isInside = _isInsideGeofence(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
          geofence.radius,
        );
        _geofenceStates[geofence.id] = isInside;
      }
    } catch (e) {
      debugPrint('初始化围栏状态失败: $e');
    }
  }

  /// 处理位置更新
  void _onPositionUpdate(Position position) {
    if (_state != GeofenceServiceState.monitoring) return;
    if (_database == null) return;

    // 检查位置是否有效
    if (_isInvalidPosition(position)) {
      debugPrint('忽略无效位置: ${position.latitude}, ${position.longitude}');
      return;
    }

    // 检查所有启用的围栏
    _checkGeofences(position);

    _lastPosition = position;
  }

  /// 检查所有围栏
  Future<void> _checkGeofences(Position position) async {
    if (_database == null) return;

    try {
      final geofences = await (_database!.select(_database!.geofences)
            ..where((tbl) => tbl.isEnabled.equals(true))
          ).get();

      for (final geofence in geofences) {
        final isInside = _isInsideGeofence(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
          geofence.radius,
        );

        final wasInside = _geofenceStates[geofence.id] ?? false;

        // 检查状态变化
        if (isInside != wasInside) {
          _geofenceStates[geofence.id] = isInside;

          // 检查触发类型
          final triggerType = GeofenceTriggerType.fromString(geofence.triggerType);

          if (isInside && (triggerType == GeofenceTriggerType.enter || triggerType == GeofenceTriggerType.both)) {
            // 进入围栏
            _triggerEvent(
              geofence: geofence,
              eventType: LocationEventType.entered,
              position: position,
            );
          } else if (!isInside && (triggerType == GeofenceTriggerType.exit || triggerType == GeofenceTriggerType.both)) {
            // 离开围栏
            _triggerEvent(
              geofence: geofence,
              eventType: LocationEventType.exited,
              position: position,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('检查围栏失败: $e');
    }
  }

  /// 触发围栏事件
  void _triggerEvent({
    required Geofence geofence,
    required LocationEventType eventType,
    required Position position,
  }) {
    final event = GeofenceEvent(
      geofenceId: geofence.id,
      geofenceName: geofence.name,
      eventType: eventType,
      occurredAt: DateTime.now(),
      position: position,
    );

    // 发送事件到流
    _eventController.add(event);

    // 记录到数据库
    _recordEvent(event, geofence);

    debugPrint('触发围栏事件: ${geofence.name} - ${eventType.displayName}');
  }

  /// 记录事件到数据库
  Future<void> _recordEvent(GeofenceEvent event, Geofence geofence) async {
    if (_database == null) return;

    try {
      await _database!.into(_database!.locationEvents).insert(
        LocationEventsCompanion.insert(
          geofenceId: geofence.id,
          eventType: event.eventType.value,
          occurredAt: Value(event.occurredAt),
        ),
      );
    } catch (e) {
      debugPrint('记录事件失败: $e');
    }
  }

  // ==================== 围栏检查工具 ====================

  /// 检查位置是否在围栏内
  bool _isInsideGeofence(
    double userLat,
    double userLon,
    double fenceLat,
    double fenceLon,
    double radius,
  ) {
    final distance = _calculateDistance(
      userLat,
      userLon,
      fenceLat,
      fenceLon,
    );
    return distance <= radius;
  }

  /// 使用 Haversine 公式计算两点间距离（米）
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // 地球半径（米）

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// 检查位置是否无效
  bool _isInvalidPosition(Position position) {
    // 纬度范围: -90 到 90
    // 经度范围: -180 到 180
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
      return true;
    }

    // 精度过低（大于500米）
    if (position.accuracy > 500) {
      return true;
    }

    return false;
  }

  // ==================== 手动检查 ====================

  /// 手动检查当前位置是否在指定围栏内
  Future<bool> isInsideGeofence(int geofenceId) async {
    final position = await getCurrentPosition();
    if (position == null || _database == null) return false;

    try {
      final geofence = await (_database!.select(_database!.geofences)
            ..where((tbl) => tbl.id.equals(geofenceId))
          ).getSingleOrNull();

      if (geofence == null) return false;

      return _isInsideGeofence(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
        geofence.radius,
      );
    } catch (e) {
      debugPrint('检查围栏失败: $e');
      return false;
    }
  }

  // ==================== 状态更新 ====================

  void _updateState(GeofenceServiceState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  // ==================== 释放资源 ====================
  void dispose() {
    stopMonitoring();
    _stateController.close();
    _eventController.close();
  }
}
