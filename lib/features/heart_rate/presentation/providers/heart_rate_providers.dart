/// 心率监测相关 Providers

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/heart_rate/heart_rate_service.dart';
import 'package:thick_notepad/features/heart_rate/data/repositories/heart_rate_repository.dart';

// ==================== 心率数据状态 ====================

/// 心率监测状态
class HeartRateMonitorState {
  final HeartRateServiceState serviceState;
  final int? currentHeartRate;
  final List<int> heartRateHistory; // 最近100次心率记录
  final String? sessionId;
  final DateTime? sessionStartTime;
  final String? errorMessage;

  const HeartRateMonitorState({
    required this.serviceState,
    this.currentHeartRate,
    this.heartRateHistory = const [],
    this.sessionId,
    this.sessionStartTime,
    this.errorMessage,
  });

  HeartRateMonitorState copyWith({
    HeartRateServiceState? serviceState,
    int? currentHeartRate,
    List<int>? heartRateHistory,
    String? sessionId,
    DateTime? sessionStartTime,
    String? errorMessage,
  }) {
    return HeartRateMonitorState(
      serviceState: serviceState ?? this.serviceState,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      heartRateHistory: heartRateHistory ?? this.heartRateHistory,
      sessionId: sessionId ?? this.sessionId,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 获取会话时长
  Duration get sessionDuration {
    if (sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(sessionStartTime!);
  }

  /// 获取平均心率
  int get averageHeartRate {
    if (heartRateHistory.isEmpty) return 0;
    final sum = heartRateHistory.reduce((a, b) => a + b);
    return (sum / heartRateHistory.length).round();
  }

  /// 获取最高心率
  int get maxHeartRate {
    if (heartRateHistory.isEmpty) return 0;
    return heartRateHistory.reduce((a, b) => a > b ? a : b);
  }

  /// 获取最低心率
  int get minHeartRate {
    if (heartRateHistory.isEmpty) return 0;
    return heartRateHistory.reduce((a, b) => a < b ? a : b);
  }
}

/// 心率监测状态通知器
class HeartRateMonitorNotifier extends StateNotifier<HeartRateMonitorState> {
  final HeartRateService _service;
  final List<StreamSubscription> _subscriptions = [];

  HeartRateMonitorNotifier(this._service)
      : super(const HeartRateMonitorState(
          serviceState: HeartRateServiceState.idle,
        )) {
    _initListeners();
  }

  void _initListeners() {
    // 监听服务状态
    _subscriptions.add(
      _service.stateStream.listen((newServiceState) {
        state = state.copyWith(serviceState: newServiceState);
      }),
    );

    // 监听心率数据
    _subscriptions.add(
      _service.heartRateStream.listen((data) {
        final updatedHistory = [...state.heartRateHistory, data.heartRate];
        if (updatedHistory.length > 100) {
          updatedHistory.removeAt(0);
        }
        state = state.copyWith(
          currentHeartRate: data.heartRate,
          heartRateHistory: updatedHistory,
          errorMessage: null,
        );
      }),
    );
  }

  /// 开始扫描设备
  Future<void> startScan() async {
    try {
      state = state.copyWith(errorMessage: null);
      await _service.startScan();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await _service.stopScan();
  }

  /// 连接设备
  Future<void> connect(BluetoothDevice device) async {
    try {
      state = state.copyWith(errorMessage: null);
      await _service.connect(device);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _service.disconnect();
    state = const HeartRateMonitorState(
      serviceState: HeartRateServiceState.idle,
    );
  }

  /// 开始监测
  Future<void> startMonitoring({int? linkedWorkoutId}) async {
    try {
      state = state.copyWith(errorMessage: null);
      final sessionId = await _service.startMonitoring(
        linkedWorkoutId: linkedWorkoutId,
      );
      state = state.copyWith(
        sessionId: sessionId,
        sessionStartTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// 停止监测
  Future<void> stopMonitoring() async {
    await _service.stopMonitoring();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// 心率监测状态 Provider
final heartRateMonitorProvider =
    StateNotifierProvider<HeartRateMonitorNotifier, HeartRateMonitorState>((ref) {
  final service = ref.watch(heartRateServiceProvider);
  return HeartRateMonitorNotifier(service);
});

// ==================== 设备列表状态 ====================

class DeviceListState {
  final bool isScanning;
  final List<ScanResult> devices;
  final String? errorMessage;

  const DeviceListState({
    this.isScanning = false,
    this.devices = const [],
    this.errorMessage,
  });

  DeviceListState copyWith({
    bool? isScanning,
    List<ScanResult>? devices,
    String? errorMessage,
  }) {
    return DeviceListState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DeviceListNotifier extends StateNotifier<DeviceListState> {
  final HeartRateService _service;
  StreamSubscription? _devicesSubscription;

  DeviceListNotifier(this._service)
      : super(const DeviceListState()) {
    _initListeners();
  }

  void _initListeners() {
    _devicesSubscription = _service.devicesStream.listen((devices) {
      state = state.copyWith(devices: devices);
    });
  }

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      await _service.startScan();
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    super.dispose();
  }
}

/// 设备列表 Provider
final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, DeviceListState>((ref) {
  final service = ref.watch(heartRateServiceProvider);
  return DeviceListNotifier(service);
});

// ==================== 心率会话列表 Provider ====================

/// 心率会话列表 Provider
final heartRateSessionsProvider = FutureProvider.autoDispose<List<HeartRateSession>>((ref) async {
  final service = ref.watch(heartRateServiceProvider);
  return await service.getHeartRateSessions(limit: 20);
});

// ==================== 心率区间配置 Provider ====================

/// 心率区间配置 Provider
final heartRateZoneProvider = FutureProvider.autoDispose<HeartRateZone?>((ref) async {
  final db = ref.watch(databaseProvider);
  final configs = await db.select(db.heartRateZones).get();
  return configs.isNotEmpty ? configs.first : null;
});

// ==================== 心率仓库 Provider ====================

/// 心率仓库 Provider - 用于设置页面和其他需要访问心率数据的地方
final heartRateRepositoryProvider = Provider<HeartRateRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HeartRateRepository(db);
});

/// 心率设置配置状态 Provider（用于设置页面）
final heartRateSettingsConfigProvider = FutureProvider.autoDispose<HeartRateZoneConfig?>((ref) async {
  final repository = ref.watch(heartRateRepositoryProvider);
  return await repository.getZoneConfig();
});

// ==================== 历史心率数据 Provider ====================

/// 心率历史数据 Provider
final heartRateRecordsProvider =
    FutureProvider.family<List<HeartRateRecord>, String?>((ref, sessionId) async {
  final service = ref.watch(heartRateServiceProvider);
  return await service.getHeartRateRecords(sessionId: sessionId);
});
