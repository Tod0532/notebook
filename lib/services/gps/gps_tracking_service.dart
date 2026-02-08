/// GPS追踪服务 - 用于运动轨迹记录
/// 提供：位置获取、轨迹记录、距离计算、速度计算等功能

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// GPS位置点
class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude; // 海拔（米）
  final double? speed; // 速度（米/秒）
  final double? accuracy; // 精度（米）

  GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.accuracy,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
    };
  }

  /// 从JSON创建
  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    return GpsPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitude: json['altitude'] as double?,
      speed: json['speed'] as double?,
      accuracy: json['accuracy'] as double?,
    );
  }

  /// 计算与另一个点的距离（米）
  double distanceTo(GpsPoint other) {
    return _calculateDistance(
      latitude, longitude,
      other.latitude, other.longitude,
    );
  }

  /// 使用 Haversine 公式计算两点间距离（米）
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
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
}

/// GPS追踪统计
class GpsStatistics {
  final double distance; // 总距离（米）
  final Duration duration; // 总时长
  final double averageSpeed; // 平均速度（米/秒）
  final double maxSpeed; // 最大速度（米/秒）
  final double? averagePace; // 平均配速（分钟/公里）
  final double? elevationGain; // 累计爬升（米）
  final double? elevationLoss; // 累计下降（米）
  final double calories; // 消耗卡路里（千卡）

  GpsStatistics({
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.maxSpeed,
    this.averagePace,
    this.elevationGain,
    this.elevationLoss,
    this.calories = 0,
  });

  /// 格式化距离显示
  String get distanceText {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}米';
    }
    return '${(distance / 1000).toStringAsFixed(2)}公里';
  }

  /// 格式化时长显示
  String get durationText {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化配速显示
  String? get paceText {
    if (averagePace == null || averagePace!.isNaN || averagePace!.isInfinite) {
      return null;
    }
    final minutes = averagePace!.floor();
    final seconds = ((averagePace! - minutes) * 60).round();
    return "${minutes}':${seconds.toString().padLeft(2, '0')}\"";
  }

  /// 格式化速度显示
  String get speedText {
    return '${(averageSpeed * 3.6).toStringAsFixed(1)} km/h'; // 转换为 km/h
  }

  /// 格式化卡路里显示
  String get caloriesText {
    if (calories < 1) {
      return '0 千卡';
    }
    return '${calories.toStringAsFixed(0)} 千卡';
  }

  /// 格式化海拔显示
  String get elevationText {
    if (elevationGain == null || elevationGain! < 1) {
      return '0米';
    }
    return '+${elevationGain!.toStringAsFixed(0)}米';
  }
}

/// GPS追踪状态
enum GpsTrackingStatus {
  idle,      // 空闲
  starting,  // 启动中
  tracking,  // 追踪中
  paused,    // 暂停
  stopped,   // 已停止
}

/// GPS追踪服务 - 单例模式
class GpsTrackingService {
  // ==================== 单例模式 ====================
  GpsTrackingService._();
  static final GpsTrackingService _instance = GpsTrackingService._();
  static GpsTrackingService get instance => _instance;

  // ==================== 状态 ====================
  GpsTrackingStatus _status = GpsTrackingStatus.idle;
  final StreamController<GpsTrackingStatus> _statusController =
      StreamController<GpsTrackingStatus>.broadcast();

  // ==================== 轨迹数据 ====================
  final List<GpsPoint> _trackPoints = [];
  final StreamController<List<GpsPoint>> _trackController =
      StreamController<List<GpsPoint>>.broadcast();

  // ==================== 统计数据 ====================
  final StreamController<GpsStatistics> _statisticsController =
      StreamController<GpsStatistics>.broadcast();

  // ==================== 位置监听 ====================
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  // ==================== 计时器 ====================
  Timer? _timer;
  DateTime? _startTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pausedAt;

  // ==================== 运动类型和体重配置 ====================
  String _workoutType = 'running'; // 默认跑步
  double _userWeight = 70.0; // 默认体重70kg
  static const Map<String, double> _metValues = {
    'running': 9.8,       // 跑步
    'cycling': 7.5,       // 骑行
    'swimming': 8.0,      // 游泳
    'walking': 4.0,       // 散步/步行
    'hiking': 6.0,        // 徒步
    'climbing': 8.0,      // 登山
    'jumpRope': 11.0,     // 跳绳
    'hiit': 11.0,         // HIIT
    'basketball': 8.0,    // 篮球
    'football': 9.0,      // 足球
    'badminton': 5.5,     // 羽毛球
    'other': 5.0,         // 其他运动
  };

  // ==================== Getters ====================
  GpsTrackingStatus get status => _status;
  Stream<GpsTrackingStatus> get statusStream => _statusController.stream;
  List<GpsPoint> get trackPoints => List.unmodifiable(_trackPoints);
  Stream<List<GpsPoint>> get trackStream => _trackController.stream;
  Stream<GpsStatistics> get statisticsStream => _statisticsController.stream;

  /// 获取当前统计
  GpsStatistics get currentStatistics => _calculateStatistics();

  /// 设置运动类型（用于卡路里计算）
  void setWorkoutType(String type) {
    _workoutType = type;
  }

  /// 设置用户体重（用于卡路里计算）
  void setUserWeight(double weight) {
    _userWeight = weight;
  }

  /// 获取运动类型的MET值
  double get _metValue {
    return _metValues[_workoutType] ?? _metValues['other']!;
  }

  /// 计算卡路里消耗
  /// 公式: MET × 体重(kg) × 时间(小时)
  double _calculateCalories(Duration duration) {
    final hours = duration.inSeconds / 3600;
    return _metValue * _userWeight * hours;
  }

  // ==================== 权限检查 ====================

  /// 检查并请求位置权限
  Future<bool> checkPermissions() async {
    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('GPS服务未启用');
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
        // 尝试使用 permission_handler 打开设置
        await openAppSettings();
        return false;
      }

      // 检查后台定位权限（Android）
      if (permission != LocationPermission.always) {
        // 尝试请求始终允许权限
        final alwaysPermission = await Permission.locationAlways.request();
        if (!alwaysPermission.isGranted) {
          debugPrint('后台定位权限未授予');
        }
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
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      debugPrint('获取当前位置失败: $e');
      return null;
    }
  }

  // ==================== 追踪控制 ====================

  /// 开始追踪
  Future<bool> startTracking() async {
    if (_status == GpsTrackingStatus.tracking) {
      debugPrint('追踪已在进行中');
      return true;
    }

    _updateStatus(GpsTrackingStatus.starting);

    // 检查权限
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      _updateStatus(GpsTrackingStatus.idle);
      debugPrint('❌ GPS追踪失败: 权限未授予');
      return false;
    }

    try {
      debugPrint('🔍 开始获取GPS位置...');

      // 分阶段获取位置：先尝试快速定位，再尝试高精度定位，最后使用低精度
      Position? position;

      // 第一步：尝试快速获取位置（5秒超时）
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        debugPrint('✓ 快速定位成功');
      } catch (e) {
        debugPrint('⚠️ 快速定位失败($e)，尝试高精度定位...');
        // 第二步：尝试高精度定位（60秒超时，适合室内环境）
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 60),
          );
          debugPrint('✓ 高精度定位成功');
        } catch (e2) {
          debugPrint('⚠️ 高精度定位失败($e2)，尝试低精度定位...');
          // 第三步：尝试低精度定位
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 10),
            );
            debugPrint('✓ 低精度定位成功');
          } catch (e3) {
            debugPrint('⚠️ 低精度定位失败($e3)，尝试最后已知位置...');
            // 第四步：尝试最后已知位置
            try {
              position = await Geolocator.getLastKnownPosition();
              if (position != null) {
                debugPrint('✓ 使用最后已知位置');
              } else {
                throw e3;
              }
            } catch (e4) {
              debugPrint('❌ 获取位置完全失败: $e4');
              _updateStatus(GpsTrackingStatus.idle);
              return false;
            }
          }
        }
      }

      if (position == null ||
          (position.latitude == 0 && position.longitude == 0)) {
        debugPrint('❌ 获取的位置无效');
        _updateStatus(GpsTrackingStatus.idle);
        return false;
      }

      debugPrint('✅ 成功获取位置: ${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}, 精度: ${position.accuracy.toStringAsFixed(0)}米');

      // 清空旧数据
      _trackPoints.clear();
      _pausedDuration = Duration.zero;

      // 添加起始点
      _addTrackPoint(position);

      // 开始计时
      _startTime = DateTime.now();
      _startTimer();

      // 开始位置监听
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // 5米距离过滤，减少噪音
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '运动追踪中',
          notificationText: '正在记录您的运动轨迹...',
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
          debugPrint('❌ 位置更新错误: $error');
        },
      );

      _updateStatus(GpsTrackingStatus.tracking);
      debugPrint('✅ GPS追踪已成功开始');
      return true;
    } catch (e) {
      debugPrint('❌ 开始追踪失败: $e');
      _updateStatus(GpsTrackingStatus.idle);
      return false;
    }
  }

  /// 暂停追踪
  void pauseTracking() {
    if (_status != GpsTrackingStatus.tracking) return;

    _pausedAt = DateTime.now();
    _updateStatus(GpsTrackingStatus.paused);
    debugPrint('GPS追踪已暂停');
  }

  /// 恢复追踪
  void resumeTracking() {
    if (_status != GpsTrackingStatus.paused) return;

    if (_pausedAt != null) {
      _pausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }

    _updateStatus(GpsTrackingStatus.tracking);
    debugPrint('GPS追踪已恢复');
  }

  /// 停止追踪
  void stopTracking() {
    if (_status == GpsTrackingStatus.idle) return;

    // 取消位置监听
    _positionSubscription?.cancel();
    _positionSubscription = null;

    // 停止计时器
    _timer?.cancel();
    _timer = null;

    _updateStatus(GpsTrackingStatus.stopped);
    debugPrint('GPS追踪已停止');
  }

  /// 清除追踪数据
  void clearTracking() {
    stopTracking();
    _trackPoints.clear();
    _startTime = null;
    _pausedDuration = Duration.zero;
    _pausedAt = null;
    _lastPosition = null;
    _updateStatus(GpsTrackingStatus.idle);
    _notifyTrackUpdate();
  }

  // ==================== 位置更新处理 ====================

  void _onPositionUpdate(Position position) {
    if (_status != GpsTrackingStatus.tracking) return;

    // 检查位置是否有效
    if (_isInvalidPosition(position)) {
      debugPrint('忽略无效位置: ${position.latitude}, ${position.longitude}');
      return;
    }

    // 检查是否与上一个位置重复（GPS抖动）
    if (_lastPosition != null && _isDuplicatePosition(_lastPosition!, position)) {
      return;
    }

    _addTrackPoint(position);
    _lastPosition = position;
  }

  /// 检查位置是否无效
  bool _isInvalidPosition(Position position) {
    // 纬度范围: -90 到 90
    // 经度范围: -180 到 180
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
      return true;
    }

    // 精度过低（大于100米）
    if (position.accuracy > 100) {
      return true;
    }

    return false;
  }

  /// 检查是否是重复位置（用于过滤GPS抖动）
  bool _isDuplicatePosition(Position pos1, Position pos2) {
    const double threshold = 3.0; // 3米阈值

    final latDiff = (pos1.latitude - pos2.latitude).abs();
    final lonDiff = (pos1.longitude - pos2.longitude).abs();

    return latDiff < 0.00001 && lonDiff < 0.00001;
  }

  /// 添加轨迹点
  void _addTrackPoint(Position position) {
    final point = GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
    );

    _trackPoints.add(point);
    _notifyTrackUpdate();
    _notifyStatisticsUpdate();
  }

  // ==================== 统计计算 ====================

  GpsStatistics _calculateStatistics() {
    if (_trackPoints.isEmpty) {
      return GpsStatistics(
        distance: 0,
        duration: _currentDuration,
        averageSpeed: 0,
        maxSpeed: 0,
        calories: _calculateCalories(_currentDuration),
      );
    }

    // 计算总距离
    double totalDistance = 0;
    double maxSpeed = 0;
    double? elevationGain = 0;
    double? elevationLoss = 0;

    for (int i = 1; i < _trackPoints.length; i++) {
      final prev = _trackPoints[i - 1];
      final curr = _trackPoints[i];

      totalDistance += prev.distanceTo(curr);

      // 计算最大速度
      if (curr.speed != null && curr.speed! > maxSpeed) {
        maxSpeed = curr.speed!;
      }

      // 计算海拔变化
      if (prev.altitude != null && curr.altitude != null) {
        final elevChange = curr.altitude! - prev.altitude!;
        if (elevChange > 0) {
          elevationGain = (elevationGain ?? 0) + elevChange;
        } else {
          elevationLoss = (elevationLoss ?? 0) + elevChange.abs();
        }
      }
    }

    final duration = _currentDuration;
    final averageSpeed = duration.inSeconds > 0
        ? totalDistance / duration.inSeconds
        : 0;

    // 计算配速（分钟/公里）
    double? averagePace;
    if (totalDistance > 0) {
      averagePace = (duration.inSeconds / 60) / (totalDistance / 1000);
    }

    // 计算卡路里
    final calories = _calculateCalories(duration);

    return GpsStatistics(
      distance: totalDistance,
      duration: duration,
      averageSpeed: averageSpeed.toDouble(),
      maxSpeed: maxSpeed,
      averagePace: averagePace,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      calories: calories,
    );
  }

  /// 获取当前运动时长
  Duration get _currentDuration {
    if (_startTime == null) return Duration.zero;

    final elapsed = DateTime.now().difference(_startTime!);
    return elapsed - _pausedDuration;
  }

  // ==================== 计时器 ====================

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == GpsTrackingStatus.tracking) {
        _notifyStatisticsUpdate();
      }
    });
  }

  // ==================== 通知 ====================

  void _updateStatus(GpsTrackingStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  void _notifyTrackUpdate() {
    _trackController.add(List.unmodifiable(_trackPoints));
  }

  void _notifyStatisticsUpdate() {
    _statisticsController.add(_calculateStatistics());
  }

  // ==================== 数据导出 ====================

  /// 导出轨迹为JSON字符串
  String exportTrackToJson() {
    final data = {
      'startTime': _startTime?.toIso8601String(),
      'points': _trackPoints.map((p) => p.toJson()).toList(),
      'statistics': _calculateStatistics().toJson(),
    };
    return data.toString();
  }

  /// 从JSON导入轨迹
  Future<bool> importTrackFromJson(String jsonStr) async {
    try {
      // 简化实现，实际项目中需要更完善的解析
      debugPrint('导入轨迹: $jsonStr');
      return true;
    } catch (e) {
      debugPrint('导入轨迹失败: $e');
      return false;
    }
  }

  // ==================== 释放资源 ====================
  void dispose() {
    stopTracking();
    _statusController.close();
    _trackController.close();
    _statisticsController.close();
  }
}

/// GpsStatistics 扩展
extension GpsStatisticsExtension on GpsStatistics {
  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'duration': duration.inSeconds,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'averagePace': averagePace,
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'calories': calories,
    };
  }
}
