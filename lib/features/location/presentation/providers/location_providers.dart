/// 位置提醒功能相关 Providers

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/location/geofence_service.dart';
import 'package:thick_notepad/services/location/background_location_service.dart';
import 'package:thick_notepad/features/location/data/repositories/geofence_repository.dart';

// ==================== 地理围栏仓库 Provider ====================

/// 地理围栏仓库 Provider
final geofenceRepositoryProvider = Provider<GeofenceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GeofenceRepository(db);
});

// ==================== 地理围栏列表状态 ====================

/// 地理围栏列表状态
class GeofenceListState {
  final List<Geofence> geofences;
  final bool isLoading;
  final String? errorMessage;
  final GeofenceStatistics? statistics;

  const GeofenceListState({
    this.geofences = const [],
    this.isLoading = false,
    this.errorMessage,
    this.statistics,
  });

  GeofenceListState copyWith({
    List<Geofence>? geofences,
    bool? isLoading,
    String? errorMessage,
    GeofenceStatistics? statistics,
  }) {
    return GeofenceListState(
      geofences: geofences ?? this.geofences,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      statistics: statistics ?? this.statistics,
    );
  }

  /// 获取启用的围栏
  List<Geofence> get enabledGeofences =>
      geofences.where((g) => g.isEnabled).toList();

  /// 获取禁用的围栏
  List<Geofence> get disabledGeofences =>
      geofences.where((g) => !g.isEnabled).toList();
}

/// 地理围栏列表状态通知器
class GeofenceListNotifier extends StateNotifier<GeofenceListState> {
  final GeofenceRepository _repository;

  GeofenceListNotifier(this._repository)
      : super(const GeofenceListState()) {
    _loadGeofences();
  }

  /// 加载围栏列表
  Future<void> _loadGeofences() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final geofences = await _repository.getAllGeofences();
      final statistics = await _repository.getGeofenceStatistics();

      state = state.copyWith(
        geofences: geofences,
        statistics: statistics,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新列表
  Future<void> refresh() async {
    await _loadGeofences();
  }

  /// 添加围栏
  Future<bool> addGeofence({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    double radius = GeofenceConfig.defaultRadius,
    String triggerType = 'enter',
    int? linkedReminderId,
    int? iconCode,
    int? colorHex,
  }) async {
    try {
      await _repository.createGeofenceWithData(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        triggerType: triggerType,
        linkedReminderId: linkedReminderId,
        isEnabled: true,
        iconCode: iconCode,
        colorHex: colorHex,
      );
      await _loadGeofences();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// 更新围栏
  Future<bool> updateGeofence(Geofence geofence) async {
    try {
      final success = await _repository.updateGeofence(geofence);
      if (success) {
        await _loadGeofences();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// 切换围栏启用状态
  Future<bool> toggleGeofenceEnabled(int id, bool isEnabled) async {
    try {
      final success = await _repository.updateGeofenceEnabled(id, isEnabled);
      if (success) {
        await _loadGeofences();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// 删除围栏
  Future<bool> deleteGeofence(int id) async {
    try {
      final success = await _repository.deleteGeofence(id);
      if (success) {
        await _loadGeofences();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// 批量删除围栏
  Future<bool> deleteMultipleGeofences(List<int> ids) async {
    try {
      await _repository.deleteMultipleGeofences(ids);
      await _loadGeofences();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

/// 地理围栏列表 Provider
final geofenceListProvider =
    StateNotifierProvider<GeofenceListNotifier, GeofenceListState>((ref) {
  final repository = ref.watch(geofenceRepositoryProvider);
  return GeofenceListNotifier(repository);
});

// ==================== 地理围栏服务状态 ====================

/// 地理围栏监控状态
class GeofenceMonitoringState {
  final GeofenceServiceState serviceState;
  final bool isMonitoring;
  final String? errorMessage;
  final List<GeofenceEvent> recentEvents;

  const GeofenceMonitoringState({
    required this.serviceState,
    this.isMonitoring = false,
    this.errorMessage,
    this.recentEvents = const [],
  });

  GeofenceMonitoringState copyWith({
    GeofenceServiceState? serviceState,
    bool? isMonitoring,
    String? errorMessage,
    List<GeofenceEvent>? recentEvents,
  }) {
    return GeofenceMonitoringState(
      serviceState: serviceState ?? this.serviceState,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      errorMessage: errorMessage,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }
}

/// 地理围栏监控状态通知器
class GeofenceMonitoringNotifier extends StateNotifier<GeofenceMonitoringState> {
  final GeofenceService _service;
  final List<StreamSubscription> _subscriptions = [];
  final List<GeofenceEvent> _recentEvents = [];

  GeofenceMonitoringNotifier(this._service)
      : super(const GeofenceMonitoringState(
          serviceState: GeofenceServiceState.idle,
        )) {
    _initListeners();
  }

  void _initListeners() {
    // 监听服务状态
    _subscriptions.add(
      _service.stateStream.listen((newState) {
        state = state.copyWith(
          serviceState: newState,
          isMonitoring: newState == GeofenceServiceState.monitoring,
        );
      }),
    );

    // 监听围栏事件
    _subscriptions.add(
      _service.eventStream.listen((event) {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 50) {
          _recentEvents.removeLast();
        }
        state = state.copyWith(recentEvents: List.unmodifiable(_recentEvents));
      }),
    );
  }

  /// 开始监控
  Future<bool> startMonitoring() async {
    try {
      state = state.copyWith(errorMessage: null);
      return await _service.startMonitoring();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// 停止监控
  void stopMonitoring() {
    _service.stopMonitoring();
  }

  /// 检查位置权限
  Future<bool> checkPermissions() async {
    return await _service.checkPermissions();
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    return await _service.getCurrentPosition();
  }

  /// 手动检查是否在围栏内
  Future<bool> isInsideGeofence(int geofenceId) async {
    return await _service.isInsideGeofence(geofenceId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// 地理围栏监控状态 Provider
final geofenceMonitoringProvider =
    StateNotifierProvider<GeofenceMonitoringNotifier, GeofenceMonitoringState>((ref) {
  final service = ref.watch(geofenceServiceProvider);
  return GeofenceMonitoringNotifier(service);
});

// ==================== 地理围栏服务 Provider ====================

/// 地理围栏服务 Provider（单例）
final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  return GeofenceService.instance;
});

/// 地理围栏服务初始化 Provider
final geofenceServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(geofenceServiceProvider);
  final db = ref.watch(databaseProvider);
  service.setDatabase(db);
});

// ==================== 后台位置服务 Provider ====================

/// 后台位置服务 Provider（单例）
final backgroundLocationServiceProvider = Provider<BackgroundLocationService>((ref) {
  return BackgroundLocationService.instance;
});

// ==================== 围栏详情状态 ====================

/// 围栏详情 Provider
final geofenceDetailProvider =
    FutureProvider.family<GeofenceDetailStatistics?, int>((ref, id) async {
  final repository = ref.watch(geofenceRepositoryProvider);
  return await repository.getGeofenceDetailStatistics(id);
});

// ==================== 围栏事件历史 Provider ====================

/// 围栏事件历史 Provider
final geofenceEventsProvider =
    FutureProvider.family<List<LocationEvent>, int>((ref, geofenceId) async {
  final repository = ref.watch(geofenceRepositoryProvider);
  return await repository.getEventsByGeofenceId(geofenceId);
});

// ==================== 权限状态 Provider ====================

/// 位置权限状态 Provider
final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(geofenceServiceProvider);
  return await service.checkPermissions();
});

// ==================== 常用地点 Provider ====================

/// 常用地点列表 Provider
final commonLocationsProvider = Provider<List<CommonLocation>>((ref) {
  return CommonLocation.locations;
});
