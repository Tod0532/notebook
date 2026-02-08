/// 心率监测相关 Providers

import 'dart:async';
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

// ==================== 心率监测派生 Providers ====================
/// 使用 select 优化，避免整个 HeartRateMonitorState 变化时所有监听者重建

/// 当前心率 Provider - 只监听 currentHeartRate 字段
final currentHeartRateProvider = Provider<int?>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.currentHeartRate),
  );
});

/// 心率服务状态 Provider - 只监听 serviceState 字段
final heartRateServiceStateProvider = Provider<HeartRateServiceState>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.serviceState),
  );
});

/// 心率历史记录 Provider - 只监听 heartRateHistory 字段
final heartRateHistoryProvider = Provider<List<int>>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.heartRateHistory),
  );
});

/// 平均心率 Provider - 只在 history 变化时重新计算
final averageHeartRateProvider = Provider<int>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.averageHeartRate),
  );
});

/// 最高心率 Provider - 只在 history 变化时重新计算
final maxHeartRateProvider = Provider<int>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.maxHeartRate),
  );
});

/// 最低心率 Provider - 只在 history 变化时重新计算
final minHeartRateProvider = Provider<int>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.minHeartRate),
  );
});

/// 心率会话ID Provider - 只监听 sessionId 字段
final heartRateSessionIdProvider = Provider<String?>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.sessionId),
  );
});

/// 心率会话时长 Provider - 只在 sessionStartTime 变化时重新计算
final heartRateSessionDurationProvider = Provider<Duration>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.sessionDuration),
  );
});

/// 心率错误信息 Provider - 只监听 errorMessage 字段
final heartRateErrorProvider = Provider<String?>((ref) {
  return ref.watch(
    heartRateMonitorProvider.select((state) => state.errorMessage),
  );
});

// ==================== 设备列表状态 ====================

class DeviceListState {
  final bool isScanning;
  final List<ScanResult> devices;
  final String? errorMessage;

  /// 识别后的设备信息（排序后）
  final List<Map<String, dynamic>> identifiedDevices;

  const DeviceListState({
    this.isScanning = false,
    this.devices = const [],
    this.errorMessage,
    this.identifiedDevices = const [],
  });

  DeviceListState copyWith({
    bool? isScanning,
    List<ScanResult>? devices,
    String? errorMessage,
    List<Map<String, dynamic>>? identifiedDevices,
  }) {
    return DeviceListState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      errorMessage: errorMessage ?? this.errorMessage,
      identifiedDevices: identifiedDevices ?? this.identifiedDevices,
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
      // 识别设备
      final identified = devices
          .map((d) => _identifyDevice(d))
          .toList();

      // 排序：心率设备优先，然后按信号强度
      identified.sort((a, b) {
        final aIsHR = a['isHeartRateDevice'] as bool;
        final bIsHR = b['isHeartRateDevice'] as bool;
        if (aIsHR && !bIsHR) return -1;
        if (!aIsHR && bIsHR) return 1;

        final aRssi = a['rssi'] as int;
        final bRssi = b['rssi'] as int;
        return bRssi.compareTo(aRssi);
      });

      state = state.copyWith(
        devices: devices,
        identifiedDevices: identified,
      );
    });
  }

  /// 识别单个设备
  Map<String, dynamic> _identifyDevice(ScanResult result) {
    final localName = result.device.localName.toLowerCase();
    final advName = result.device.advName.toLowerCase();
    final name = localName.isNotEmpty ? localName : advName;

    // 检查心率设备关键词
    const heartRateKeywords = [
      'heart', 'hrm', 'polar', 'wahoo', 'garmin', 'suunto',
      'chest', 'band', 'watch', 'fitbit', 'mi', 'xiaomi',
      'amazfit', 'tickr', 'h10', 'h7', 'oh1', 'cardio',
    ];

    final isHeartRateDevice = heartRateKeywords.any((keyword) =>
        name.contains(keyword.toLowerCase()));

    // 获取显示名称
    String displayName;
    if (result.device.localName.isNotEmpty) {
      displayName = result.device.localName;
    } else if (result.device.advName.isNotEmpty) {
      displayName = result.device.advName;
    } else {
      displayName = '设备 (${result.device.remoteId.str.substring(0, 8)}...)';
    }

    return {
      'scanResult': result,
      'displayName': displayName,
      'isHeartRateDevice': isHeartRateDevice,
      'rssi': result.rssi,
      'deviceId': result.device.remoteId.str,
    };
  }

  Future<void> startScan() async {
    state = state.copyWith(
      isScanning: true,
      errorMessage: null,
      identifiedDevices: [],
    );
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

// ==================== 设备列表派生 Providers ====================
/// 使用 select 优化，避免整个 DeviceListState 变化时所有监听者重建

/// 识别后的设备列表 Provider
final identifiedDevicesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(
    deviceListProvider.select((state) => state.identifiedDevices),
  );
});

/// 是否正在扫描 Provider - 只监听 isScanning 字段
final isScanningProvider = Provider<bool>((ref) {
  return ref.watch(
    deviceListProvider.select((state) => state.isScanning),
  );
});

/// 扫描到的设备列表 Provider - 只监听 devices 字段
final scannedDevicesProvider = Provider<List<ScanResult>>((ref) {
  return ref.watch(
    deviceListProvider.select((state) => state.devices),
  );
});

/// 设备扫描错误信息 Provider - 只监听 errorMessage 字段
final deviceScanErrorProvider = Provider<String?>((ref) {
  return ref.watch(
    deviceListProvider.select((state) => state.errorMessage),
  );
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
