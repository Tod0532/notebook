/// 心率服务 - 蓝牙低功耗(BLE)心率监测服务
/// 支持连接BLE心率设备，实时接收心率数据，并保存到数据库

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 心率服务常量 ====================

/// BLE心率服务UUID (标准Heart Rate Service)
const UUID_HEART_RATE_SERVICE = '0000180d-0000-1000-8000-00805f9b34fb';

/// 心率测量特征UUID
const UUID_HEART_RATE_MEASUREMENT = '00002a37-0000-1000-8000-00805f9b34fb';

/// 心率传感器位置特征UUID
const UUID_BODY_SENSOR_LOCATION = '00002a38-0000-1000-8000-00805f9b34fb';

/// 心率控制点特征UUID
const UUID_HEART_RATE_CONTROL_POINT = '00002a39-0000-1000-8000-00805f9b34fb';

// ==================== 心率数据模型 ====================

/// 心率数据模型
class HeartRateData {
  final int heartRate; // 心率值 (BPM)
  final int? rrInterval; // RR间隔 (毫秒)，用于心率变异性分析
  final DateTime timestamp; // 时间戳
  final int? signalQuality; // 信号质量 (0-100)

  HeartRateData({
    required this.heartRate,
    this.rrInterval,
    required this.timestamp,
    this.signalQuality,
  });

  @override
  String toString() {
    return 'HeartRateData{heartRate: $heartRate bpm, rrInterval: $rrInterval ms, timestamp: $timestamp}';
  }

  Map<String, dynamic> toJson() {
    return {
      'heartRate': heartRate,
      'rrInterval': rrInterval,
      'timestamp': timestamp.toIso8601String(),
      'signalQuality': signalQuality,
    };
  }

  factory HeartRateData.fromJson(Map<String, dynamic> json) {
    return HeartRateData(
      heartRate: json['heartRate'] as int,
      rrInterval: json['rrInterval'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      signalQuality: json['signalQuality'] as int?,
    );
  }
}

/// 心率区间统计
class HeartRateZoneStats {
  final String zoneName;
  final int duration; // 停留时长（秒）
  final double percentage; // 占总时长的百分比

  HeartRateZoneStats({
    required this.zoneName,
    required this.duration,
    required this.percentage,
  });
}

/// 心率会话统计
class HeartRateSessionStats {
  final int averageHeartRate;
  final int minHeartRate;
  final int maxHeartRate;
  final List<HeartRateZoneStats> zoneStats;
  final int totalDuration;

  HeartRateSessionStats({
    required this.averageHeartRate,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.zoneStats,
    required this.totalDuration,
  });
}

// ==================== 心率服务状态 ====================

enum HeartRateServiceState {
  idle, // 空闲
  scanning, // 扫描设备中
  connecting, // 连接中
  connected, // 已连接
  monitoring, // 监测中
  disconnecting, // 断开连接中
  error, // 错误
}

// ==================== 心率服务异常 ====================

class HeartRateServiceException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  HeartRateServiceException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'HeartRateServiceException: $message';
  }
}

// ==================== 心率服务 ====================

/// 心率服务 - 单例模式
class HeartRateService {
  // 单例模式
  static HeartRateService? _instance;
  static final _lock = Object();

  factory HeartRateService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= HeartRateService._internal();
      });
    }
    return _instance!;
  }

  HeartRateService._internal() {
    _initBluePlus();
  }

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 成员变量 ====================

  final _uuid = const Uuid();
  final _stateController = StreamController<HeartRateServiceState>.broadcast();
  final _heartRateController = StreamController<HeartRateData>.broadcast();
  final _devicesController = StreamController<List<ScanResult>>.broadcast();

  // 当前状态
  HeartRateServiceState _currentState = HeartRateServiceState.idle;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _heartRateSubscription;

  // 监测会话
  String? _currentSessionId;
  List<HeartRateData> _sessionData = [];
  DateTime? _sessionStartTime;
  Timer? _scanTimer;
  Timer? _saveTimer;

  // 数据库
  AppDatabase? _db;

  // 心率区间配置
  HeartRateZone? _zoneConfig;

  // ==================== 初始化 ====================

  /// 初始化 FlutterBluePlus
  void _initBluePlus() {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  }

  /// 设置数据库实例
  void setDatabase(AppDatabase db) {
    _db = db;
  }

  /// 加载心率区间配置
  Future<void> _loadZoneConfig() async {
    if (_db == null) return;
    try {
      final configs = await _db!.select(_db!.heartRateZones).get();
      if (configs.isNotEmpty) {
        _zoneConfig = configs.first;
      }
    } catch (e) {
      debugPrint('加载心率区间配置失败: $e');
    }
  }

  // ==================== 权限检查 ====================

  /// 检查并请求蓝牙权限
  Future<bool> checkAndRequestPermissions() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
      ].request();

      final allGranted = statuses.values.every((status) =>
          status.isGranted || status.isLimited);

      if (!allGranted) {
        final permanentlyDenied = statuses.values.any((status) =>
            status.isPermanentlyDenied);
        if (permanentlyDenied) {
          throw HeartRateServiceException(
              '蓝牙权限被永久拒绝，请在设置中开启');
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('检查权限失败: $e');
      rethrow;
    }
  }

  /// 检查蓝牙是否开启
  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isAvailable;
    } catch (e) {
      debugPrint('检查蓝牙可用性失败: $e');
      return false;
    }
  }

  /// 检查蓝牙是否已开启
  Future<bool> isBluetoothEnabled() async {
    try {
      if (await isBluetoothAvailable()) {
        final state = await FlutterBluePlus.bluetoothState.first;
        return state == BluetoothState.on;
      }
      return false;
    } catch (e) {
      debugPrint('检查蓝牙状态失败: $e');
      return false;
    }
  }

  // ==================== 设备扫描 ====================

  /// 开始扫描心率设备
  Future<List<ScanResult>> startScan({int timeoutSeconds = 10}) async {
    try {
      // 检查权限
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        throw HeartRateServiceException('缺少蓝牙权限');
      }

      // 检查蓝牙状态
      if (!await isBluetoothEnabled()) {
        throw HeartRateServiceException('蓝牙未开启，请先开启蓝牙');
      }

      _updateState(HeartRateServiceState.scanning);

      // 开始扫描
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        androidUsesFineLocation: true,
      );

      // 监听扫描结果
      final results = <ScanResult>[];
      final subscription = FlutterBluePlus.scanResults.listen((r) {
        results.clear();
        results.addAll(r.where((r) =>
            r.device.localName.isNotEmpty ||
            r.device.advName.isNotEmpty));
        _devicesController.add(results);
      });

      // 等待扫描完成
      await Future.delayed(Duration(seconds: timeoutSeconds));

      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      _updateState(HeartRateServiceState.idle);

      return results;
    } catch (e, st) {
      _updateState(HeartRateServiceState.error);
      debugPrint('扫描设备失败: $e');
      throw HeartRateServiceException('扫描设备失败', e, st);
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _updateState(HeartRateServiceState.idle);
    } catch (e) {
      debugPrint('停止扫描失败: $e');
    }
  }

  // ==================== 设备连接 ====================

  /// 连接设备
  Future<void> connect(BluetoothDevice device) async {
    try {
      _updateState(HeartRateServiceState.connecting);

      // 监听连接状态
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint('连接状态: ${state.name}');
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // 连接设备
      await device.connect(
        timeout: Duration(seconds: 15),
        autoConnect: false,
      );

      // 等待连接完成
      await device.connectionState
          .firstWhere((s) => s == BluetoothConnectionState.connected);

      _connectedDevice = device;
      _updateState(HeartRateServiceState.connected);

      // 发现服务
      await _discoverServices(device);

      debugPrint('设备连接成功: ${device.platformName}');
    } catch (e, st) {
      _updateState(HeartRateServiceState.error);
      debugPrint('连接设备失败: $e');
      throw HeartRateServiceException('连接设备失败', e, st);
    }
  }

  /// 发现服务并订阅心率特征
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      debugPrint('发现 ${services.length} 个服务');

      for (final service in services) {
        debugPrint('服务UUID: ${service.uuid}');

        if (service.uuid.toString().toLowerCase() ==
            UUID_HEART_RATE_SERVICE.toLowerCase()) {
          // 找到心率服务
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                UUID_HEART_RATE_MEASUREMENT.toLowerCase()) {
              _heartRateCharacteristic = characteristic;

              // 检查是否需要通知
              final properties = characteristic.properties;
              if (properties.notify || properties.indicate) {
                await characteristic.setNotifyValue(true);
                _startListeningToHeartRate(characteristic);
                debugPrint('已订阅心率特征');
              }
              break;
            }
          }
        }
      }

      if (_heartRateCharacteristic == null) {
        throw HeartRateServiceException('设备不支持心率服务');
      }
    } catch (e, st) {
      debugPrint('发现服务失败: $e');
      throw HeartRateServiceException('发现服务失败', e, st);
    }
  }

  /// 开始监听心率数据
  void _startListeningToHeartRate(BluetoothCharacteristic characteristic) {
    _heartRateSubscription = characteristic.onValueReceived.listen((data) {
      _parseHeartRateData(data);
    });
  }

  /// 解析心率数据 (根据Bluetooth标准)
  void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;

    try {
      // 心率测量数据格式
      // Byte 0: Flags
      //   - Bit 0: 0 = Heart Rate Value is 8 bit, 1 = 16 bit
      //   - Bit 1: 0 = Sensor Contact not supported, 1 = Sensor Contact supported
      //   - Bit 2: 0 = Sensor Contact not detected, 1 = Sensor Contact detected
      //   - Bit 3: 0 = Energy Expended not present, 1 = Energy Expended present
      //   - Bit 4: 0 = RR-Interval not present, 1 = RR-Interval present

      final flags = data[0];
      final is16Bit = (flags & 0x01) == 0x01;
      final hasRRInterval = (flags & 0x10) == 0x10;

      int heartRate = 0;
      int offset = 1;

      // 解析心率值
      if (is16Bit) {
        heartRate = data[offset] | (data[offset + 1] << 8);
        offset += 2;
      } else {
        heartRate = data[offset];
        offset += 1;
      }

      // 解析能量消耗 (2 bytes, 如果存在则跳过)
      if ((flags & 0x08) == 0x08) {
        offset += 2;
      }

      // 解析RR间隔
      int? rrInterval;
      if (hasRRInterval && data.length > offset + 1) {
        rrInterval = data[offset] | (data[offset + 1] << 8);
        // RR间隔单位是1/1024秒，转换为毫秒
        rrInterval = (rrInterval! * 1000 / 1024).round();
      }

      final heartRateData = HeartRateData(
        heartRate: heartRate,
        rrInterval: rrInterval,
        timestamp: DateTime.now(),
      );

      // 添加到会话数据
      _sessionData.add(heartRateData);

      // 发送到流
      _heartRateController.add(heartRateData);

      debugPrint('心率: $heartRate bpm, RR: $rrInterval ms');
    } catch (e) {
      debugPrint('解析心率数据失败: $e, data: $data');
    }
  }

  /// 处理设备断开连接
  void _handleDisconnection() {
    debugPrint('设备已断开连接');
    _connectedDevice = null;
    _heartRateCharacteristic = null;
    _updateState(HeartRateServiceState.idle);

    // 如果正在监测，则停止监测
    if (_currentState == HeartRateServiceState.monitoring) {
      stopMonitoring();
    }
  }

  // ==================== 监测控制 ====================

  /// 开始监测
  Future<String> startMonitoring({int? linkedWorkoutId}) async {
    try {
      if (_connectedDevice == null) {
        throw HeartRateServiceException('请先连接设备');
      }

      // 加载心率区间配置
      await _loadZoneConfig();

      // 创建新会话
      _currentSessionId = _uuid.v4();
      _sessionStartTime = DateTime.now();
      _sessionData.clear();

      // 保存会话到数据库
      if (_db != null) {
        await _db!.into(_db!.heartRateSessions).insert(
          HeartRateSessionsCompanion.insert(
            sessionId: _currentSessionId!,
            startTime: _sessionStartTime!,
            linkedWorkoutId: linkedWorkoutId != null
                ? drift.Value(linkedWorkoutId)
                : const drift.Value.absent(),
            deviceId: drift.Value(_connectedDevice!.remoteId.str),
            deviceName: drift.Value(_connectedDevice?.platformName),
            status: const drift.Value('active'),
          ),
        );
      }

      // 启动定时保存（每5秒保存一次数据）
      _startSaveTimer();

      _updateState(HeartRateServiceState.monitoring);
      debugPrint('开始监测心率，会话ID: $_currentSessionId');

      return _currentSessionId!;
    } catch (e, st) {
      debugPrint('开始监测失败: $e');
      throw HeartRateServiceException('开始监测失败', e, st);
    }
  }

  /// 停止监测
  Future<HeartRateSessionStats?> stopMonitoring() async {
    try {
      _stopSaveTimer();

      if (_currentSessionId == null) {
        return null;
      }

      // 保存剩余数据
      if (_sessionData.isNotEmpty) {
        await _saveSessionData();
      }

      // 计算统计数据
      final stats = _calculateSessionStats();

      // 更新会话状态
      if (_db != null && stats != null) {
        final now = DateTime.now();
        await (_db!.update(_db!.heartRateSessions)
              ..where((tbl) => tbl.sessionId.equals(_currentSessionId!)))
            .write(
          HeartRateSessionsCompanion(
            endTime: drift.Value(now),
            averageHeartRate: drift.Value(stats.averageHeartRate),
            minHeartRate: drift.Value(stats.minHeartRate),
            maxHeartRate: drift.Value(stats.maxHeartRate),
            zone1Duration: drift.Value(_getZoneDuration('zone1')),
            zone2Duration: drift.Value(_getZoneDuration('zone2')),
            zone3Duration: drift.Value(_getZoneDuration('zone3')),
            zone4Duration: drift.Value(_getZoneDuration('zone4')),
            zone5Duration: drift.Value(_getZoneDuration('zone5')),
            status: const drift.Value('completed'),
          ),
        );
      }

      _updateState(HeartRateServiceState.connected);

      debugPrint('监测已停止，会话ID: $_currentSessionId');
      final sessionId = _currentSessionId;
      _currentSessionId = null;

      return stats;
    } catch (e, st) {
      debugPrint('停止监测失败: $e');
      throw HeartRateServiceException('停止监测失败', e, st);
    }
  }

  /// 获取区间时长
  int _getZoneDuration(String zone) {
    if (_zoneConfig == null) return 0;
    switch (zone) {
      case 'zone1':
        return _zoneConfig!.zone1Duration ?? 0;
      case 'zone2':
        return _zoneConfig!.zone2Duration ?? 0;
      case 'zone3':
        return _zoneConfig!.zone3Duration ?? 0;
      case 'zone4':
        return _zoneConfig!.zone4Duration ?? 0;
      case 'zone5':
        return _zoneConfig!.zone5Duration ?? 0;
      default:
        return 0;
    }
  }

  /// 启动定时保存
  void _startSaveTimer() {
    _saveTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _saveSessionData();
    });
  }

  /// 停止定时保存
  void _stopSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// 保存会话数据到数据库
  Future<void> _saveSessionData() async {
    if (_db == null || _sessionData.isEmpty) return;

    try {
      // 批量插入心率记录
      final companions = _sessionData.map((data) {
        return HeartRateRecordsCompanion.insert(
          heartRate: data.heartRate,
          rrInterval: drift.Value(data.rrInterval),
          timestamp: data.timestamp,
          sessionId: _currentSessionId!,
          deviceId: drift.Value(_connectedDevice?.remoteId.str),
          deviceName: drift.Value(_connectedDevice?.platformName),
          signalQuality: drift.Value(data.signalQuality),
        );
      }).toList();

      await _db!.batch((batch) {
        for (final companion in companions) {
          batch.insert(_db!.heartRateRecords, companion);
        }
      });

      // 更新区间时长统计
      await _updateZoneDurations();

      // 清空已保存的数据
      _sessionData.clear();

      debugPrint('已保存心率记录');
    } catch (e) {
      debugPrint('保存心率数据失败: $e');
    }
  }

  /// 更新区间时长统计
  Future<void> _updateZoneDurations() async {
    if (_db == null || _currentSessionId == null) return;

    try {
      // 获取会话的所有心率记录
      final records = await (_db!.select(_db!.heartRateRecords)
            ..where((tbl) => tbl.sessionId.equals(_currentSessionId!)))
          .get();

      if (records.isEmpty) return;

      // 计算最大心率（使用公式或配置）
      final maxHeartRate = await _getMaxHeartRate();

      // 统计各区间时长
      final durations = <String, int>{
        'zone1': 0,
        'zone2': 0,
        'zone3': 0,
        'zone4': 0,
        'zone5': 0,
      };

      for (int i = 1; i < records.length; i++) {
        final heartRate = records[i].heartRate;
        final zone = HeartRateZoneEnum.getZone(heartRate, maxHeartRate);
        if (zone != null) {
          final timeDiff = records[i].timestamp
              .difference(records[i - 1].timestamp)
              .inSeconds;
          durations[zone.name] = (durations[zone.name] ?? 0) + timeDiff;
        }
      }

      // 更新数据库
      await (_db!.update(_db!.heartRateSessions)
            ..where((tbl) => tbl.sessionId.equals(_currentSessionId!)))
          .write(
        HeartRateSessionsCompanion(
          zone1Duration: drift.Value(durations['zone1']),
          zone2Duration: drift.Value(durations['zone2']),
          zone3Duration: drift.Value(durations['zone3']),
          zone4Duration: drift.Value(durations['zone4']),
          zone5Duration: drift.Value(durations['zone5']),
        ),
      );
    } catch (e) {
      debugPrint('更新区间时长失败: $e');
    }
  }

  /// 计算会话统计数据
  HeartRateSessionStats? _calculateSessionStats() {
    if (_db == null || _currentSessionId == null) return null;

    // 这里应该从数据库读取所有数据进行统计
    // 简化实现：使用内存中的数据
    if (_sessionData.isEmpty) {
      final heartRate = _heartRateController.stream.lastOrNull;
      if (heartRate == null) return null;
    }

    final heartRates = _sessionData.map((d) => d.heartRate).toList();
    if (heartRates.isEmpty) return null;

    final avg = heartRates.reduce((a, b) => a + b) / heartRates.length;
    final min = heartRates.reduce((a, b) => a < b ? a : b);
    final max = heartRates.reduce((a, b) => a > b ? a : b);

    // 计算区间统计
    final zoneStats = <HeartRateZoneStats>[];
    final totalDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    return HeartRateSessionStats(
      averageHeartRate: avg.round(),
      minHeartRate: min,
      maxHeartRate: max,
      zoneStats: zoneStats,
      totalDuration: totalDuration,
    );
  }

  /// 获取最大心率
  Future<int> _getMaxHeartRate() async {
    if (_zoneConfig?.maxHeartRate != null && _zoneConfig!.maxHeartRate! > 0) {
      return _zoneConfig!.maxHeartRate!;
    }

    // 使用默认公式：220 - 年龄
    // 这里简化处理，返回一个默认值
    return 180; // 默认值
  }

  // ==================== 断开连接 ====================

  /// 断开设备连接
  Future<void> disconnect() async {
    try {
      _updateState(HeartRateServiceState.disconnecting);

      // 停止监测
      if (_currentState == HeartRateServiceState.monitoring) {
        await stopMonitoring();
      }

      // 取消订阅
      await _heartRateSubscription?.cancel();
      _heartRateSubscription = null;

      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      // 断开连接
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      _heartRateCharacteristic = null;
      _updateState(HeartRateServiceState.idle);

      debugPrint('已断开设备连接');
    } catch (e) {
      debugPrint('断开连接失败: $e');
    }
  }

  // ==================== 数据查询 ====================

  /// 获取心率记录
  Future<List<HeartRateRecord>> getHeartRateRecords(
      {String? sessionId, int? workoutId, int limit = 100}) async {
    if (_db == null) return [];

    try {
      final query = _db!.select(_db!.heartRateRecords);

      if (sessionId != null) {
        query.where((tbl) => tbl.sessionId.equals(sessionId));
      }

      if (workoutId != null) {
        query.where((tbl) => tbl.linkedWorkoutId.equals(workoutId));
      }

      query.limit(limit);
      query.order([(tbl) => drift.OrderingTerm.desc(tbl.timestamp)]);

      return await query.get();
    } catch (e) {
      debugPrint('获取心率记录失败: $e');
      return [];
    }
  }

  /// 获取心率会话列表
  Future<List<HeartRateSession>> getHeartRateSessions({int limit = 20}) async {
    if (_db == null) return [];

    try {
      return await (_db!.select(_db!.heartRateSessions)
            ..limit(limit)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.startTime)]))
          .get();
    } catch (e) {
      debugPrint('获取心率会话失败: $e');
      return [];
    }
  }

  /// 获取心率会话详情
  Future<Map<String, dynamic>> getSessionDetails(String sessionId) async {
    if (_db == null) return {};

    try {
      // 获取会话信息
      final sessions = await (_db!.select(_db!.heartRateSessions)
            ..where((tbl) => tbl.sessionId.equals(sessionId)))
          .get();

      if (sessions.isEmpty) return {};

      final session = sessions.first;

      // 获取心率记录
      final records = await (_db!.select(_db!.heartRateRecords)
            ..where((tbl) => tbl.sessionId.equals(sessionId))
            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.timestamp)]))
          .get();

      return {
        'session': session,
        'records': records,
      };
    } catch (e) {
      debugPrint('获取会话详情失败: $e');
      return {};
    }
  }

  // ==================== Streams ====================

  /// 状态流
  Stream<HeartRateServiceState> get stateStream => _stateController.stream;

  /// 心率数据流
  Stream<HeartRateData> get heartRateStream => _heartRateController.stream;

  /// 设备列表流
  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;

  /// 当前状态
  HeartRateServiceState get currentState => _currentState;

  /// 当前连接的设备
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 当前会话ID
  String? get currentSessionId => _currentSessionId;

  // ==================== 清理资源 ====================

  /// 释放资源
  void dispose() {
    _stopSaveTimer();
    _scanTimer?.cancel();
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();

    _stateController.close();
    _heartRateController.close();
    _devicesController.close();

    _instance = null;
  }

  // ==================== 私有方法 ====================

  void _updateState(HeartRateServiceState state) {
    _currentState = state;
    _stateController.add(state);
    debugPrint('心率服务状态: ${state.name}');
  }
}
