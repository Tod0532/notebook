/// 心率异常提醒服务 - 监测心率异常并发出提醒
/// 功能：
/// 1. 检测心率持续超出目标区间
/// 2. 震动提醒
/// 3. 弹窗提醒
/// 4. 通知提醒
/// 5. 记录异常事件到数据库

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 异常检测配置 ====================

/// 异常检测配置
class HeartRateAlertConfig {
  /// 异常检测时长（秒）- 持续超过此时长才触发异常
  final int alertDelaySeconds;

  /// 心率上限阈值倍数 - 超过目标区间上限 * 此倍数视为过高
  final double highThresholdMultiplier;

  /// 心率下限阈值倍数 - 低于目标区间下限 * 此倍数视为过低
  final double lowThresholdMultiplier;

  /// 是否启用震动提醒
  final bool enableVibration;

  /// 是否启用通知提醒
  final bool enableNotification;

  /// 是否启用弹窗提醒
  final bool enableDialog;

  /// 异常提醒冷却时间（秒）- 同一类型异常的间隔时间
  final int alertCooldownSeconds;

  const HeartRateAlertConfig({
    this.alertDelaySeconds = 30,
    this.highThresholdMultiplier = 1.1,
    this.lowThresholdMultiplier = 0.9,
    this.enableVibration = true,
    this.enableNotification = true,
    this.enableDialog = true,
    this.alertCooldownSeconds = 60,
  });

  /// 从 SharedPreferences 加载配置
  static Future<HeartRateAlertConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HeartRateAlertConfig(
      alertDelaySeconds: prefs.getInt('hr_alert_delay') ?? 30,
      highThresholdMultiplier: prefs.getDouble('hr_high_threshold') ?? 1.1,
      lowThresholdMultiplier: prefs.getDouble('hr_low_threshold') ?? 0.9,
      enableVibration: prefs.getBool('hr_alert_vibration') ?? true,
      enableNotification: prefs.getBool('hr_alert_notification') ?? true,
      enableDialog: prefs.getBool('hr_alert_dialog') ?? true,
      alertCooldownSeconds: prefs.getInt('hr_alert_cooldown') ?? 60,
    );
  }

  /// 保存配置到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hr_alert_delay', alertDelaySeconds);
    await prefs.setDouble('hr_high_threshold', highThresholdMultiplier);
    await prefs.setDouble('hr_low_threshold', lowThresholdMultiplier);
    await prefs.setBool('hr_alert_vibration', enableVibration);
    await prefs.setBool('hr_alert_notification', enableNotification);
    await prefs.setBool('hr_alert_dialog', enableDialog);
    await prefs.setInt('hr_alert_cooldown', alertCooldownSeconds);
  }

  /// 创建副本
  HeartRateAlertConfig copyWith({
    int? alertDelaySeconds,
    double? highThresholdMultiplier,
    double? lowThresholdMultiplier,
    bool? enableVibration,
    bool? enableNotification,
    bool? enableDialog,
    int? alertCooldownSeconds,
  }) {
    return HeartRateAlertConfig(
      alertDelaySeconds: alertDelaySeconds ?? this.alertDelaySeconds,
      highThresholdMultiplier: highThresholdMultiplier ?? this.highThresholdMultiplier,
      lowThresholdMultiplier: lowThresholdMultiplier ?? this.lowThresholdMultiplier,
      enableVibration: enableVibration ?? this.enableVibration,
      enableNotification: enableNotification ?? this.enableNotification,
      enableDialog: enableDialog ?? this.enableDialog,
      alertCooldownSeconds: alertCooldownSeconds ?? this.alertCooldownSeconds,
    );
  }
}

// ==================== 异常类型 ====================

/// 心率异常类型
enum HeartRateAlertType {
  /// 心率过高
  high('high', '心率过高', '建议降低动作强度或休息1分钟'),

  /// 心率过低
  low('low', '心率过低', '建议增加动作幅度或加快节奏');

  final String value;
  final String displayName;
  final String defaultAdvice;

  const HeartRateAlertType(this.value, this.displayName, this.defaultAdvice);

  static HeartRateAlertType fromString(String value) {
    return HeartRateAlertType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HeartRateAlertType.high,
    );
  }
}

// ==================== 异常事件模型 ====================

/// 心率异常事件
class HeartRateAlertEvent {
  /// 异常ID（时间戳）
  final String id;

  /// 异常类型
  final HeartRateAlertType type;

  /// 触发时的心率
  final int heartRate;

  /// 目标区间
  final int? targetMin;
  final int? targetMax;

  /// 异常开始时间
  final DateTime startTime;

  /// 异常持续时长（秒）
  int durationSeconds;

  /// 关联的会话ID
  final String sessionId;

  /// 调整建议
  final String advice;

  /// 是否已确认
  bool isAcknowledged;

  /// 确认时间
  DateTime? acknowledgedAt;

  /// 是否已记录到数据库
  bool isRecorded;

  HeartRateAlertEvent({
    required this.id,
    required this.type,
    required this.heartRate,
    this.targetMin,
    this.targetMax,
    required this.startTime,
    this.durationSeconds = 0,
    required this.sessionId,
    String? advice,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.isRecorded = false,
  }) : advice = advice ?? type.defaultAdvice;

  /// 检查是否在冷却期内
  bool isInCooldown(int cooldownSeconds) {
    return durationSeconds < cooldownSeconds;
  }

  /// 转换为数据库实体
  HeartRateAlertsCompanion toDbCompanion() {
    return HeartRateAlertsCompanion.insert(
      alertType: type.value,
      alertHeartRate: heartRate,
      targetZoneMin: targetMin != null ? Value(targetMin!) : const Value.absent(),
      targetZoneMax: targetMax != null ? Value(targetMax!) : const Value.absent(),
      alertTime: Value(startTime),
      durationSeconds: Value(durationSeconds),
      sessionId: sessionId,
      advice: advice.isNotEmpty ? Value(advice) : const Value.absent(),
      isAcknowledged: const Value(true),
      acknowledgedAt: acknowledgedAt != null ? Value(acknowledgedAt!) : const Value.absent(),
    );
  }

  /// 从数据库实体创建
  factory HeartRateAlertEvent.fromDb(HeartRateAlert alert) {
    return HeartRateAlertEvent(
      id: alert.id.toString(),
      type: HeartRateAlertType.fromString(alert.alertType),
      heartRate: alert.alertHeartRate,
      targetMin: alert.targetZoneMin,
      targetMax: alert.targetZoneMax,
      startTime: alert.alertTime,
      durationSeconds: alert.durationSeconds,
      sessionId: alert.sessionId,
      advice: alert.advice ?? '',
      isAcknowledged: alert.isAcknowledged,
      acknowledgedAt: alert.acknowledgedAt,
      isRecorded: true,
    );
  }
}

// ==================== 异常状态 ====================

/// 异常检测状态
class _AlertDetectionState {
  /// 当前异常事件（如果存在）
  HeartRateAlertEvent? currentAlert;

  /// 上次提醒时间
  DateTime? lastHighAlertTime;
  DateTime? lastLowAlertTime;

  /// 检测开始时间（用于计算持续时长）
  DateTime? detectionStartTime;

  /// 是否正在检测异常
  bool isDetecting = false;

  void reset() {
    currentAlert = null;
    detectionStartTime = null;
    isDetecting = false;
  }
}

// ==================== 心率异常提醒服务 ====================

/// 心率异常提醒服务 - 单例模式
class HeartRateAlertService {
  // 单例模式
  static HeartRateAlertService? _instance;
  static final _lock = Object();

  factory HeartRateAlertService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= HeartRateAlertService._internal();
      });
    }
    return _instance!;
  }

  HeartRateAlertService._internal();

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 成员变量 ====================

  /// 配置
  HeartRateAlertConfig _config = const HeartRateAlertConfig();

  /// 数据库
  AppDatabase? _db;

  /// 检测状态
  final _AlertDetectionState _state = _AlertDetectionState();

  /// 检测定时器
  Timer? _checkTimer;

  /// 事件流控制器
  final _alertController = StreamController<HeartRateAlertEvent>.broadcast();

  /// 当前监测会话ID
  String? _currentSessionId;

  /// 当前目标心率区间
  int? _targetMin;
  int? _targetMax;

  /// 是否已启动
  bool _isStarted = false;

  // ==================== 公共方法 ====================

  /// 初始化配置
  Future<void> init({AppDatabase? db}) async {
    _db = db;
    _config = await HeartRateAlertConfig.load();
    debugPrint('心率异常提醒服务已初始化');
  }

  /// 设置数据库
  void setDatabase(AppDatabase db) {
    _db = db;
  }

  /// 更新配置
  Future<void> updateConfig(HeartRateAlertConfig config) async {
    _config = config;
    await config.save();
    debugPrint('心率异常提醒配置已更新: $_config');
  }

  /// 获取当前配置
  HeartRateAlertConfig get config => _config;

  /// 开始异常监测
  void startMonitoring({
    required String sessionId,
    int? targetMin,
    int? targetMax,
  }) {
    if (_isStarted) {
      stopMonitoring();
    }

    _currentSessionId = sessionId;
    _targetMin = targetMin;
    _targetMax = targetMax;
    _isStarted = true;
    _state.reset();

    debugPrint('开始心率异常监测: sessionId=$sessionId, target=[$targetMin-$targetMax]');
  }

  /// 停止异常监测
  Future<void> stopMonitoring() async {
    if (!_isStarted) return;

    // 保存当前异常（如果存在）
    if (_state.currentAlert != null && !_state.currentAlert!.isRecorded) {
      await _recordAlert(_state.currentAlert!);
    }

    _checkTimer?.cancel();
    _state.reset();
    _currentSessionId = null;
    _isStarted = false;

    debugPrint('停止心率异常监测');
  }

  /// 处理心率数据（由心率服务调用）
  Future<void> processHeartRate(int heartRate) async {
    if (!_isStarted || _currentSessionId == null) return;

    // 如果没有设置目标区间，不进行检测
    if (_targetMin == null || _targetMax == null) return;

    final now = DateTime.now();

    // 检查是否异常
    final alertType = _checkHeartRate(heartRate);

    if (alertType != null) {
      // 心率异常
      if (!_state.isDetecting) {
        // 开始检测
        _state.isDetecting = true;
        _state.detectionStartTime = now;

        // 创建新的异常事件
        _state.currentAlert = HeartRateAlertEvent(
          id: now.millisecondsSinceEpoch.toString(),
          type: alertType,
          heartRate: heartRate,
          targetMin: _targetMin,
          targetMax: _targetMax,
          startTime: now,
          sessionId: _currentSessionId!,
        );

        debugPrint('检测到心率异常: ${alertType.displayName},心率=$heartRate');
      } else {
        // 更新当前异常事件
        if (_state.currentAlert != null) {
          _state.currentAlert!.durationSeconds =
              now.difference(_state.detectionStartTime!).inSeconds;
        }
      }

      // 检查是否需要触发提醒
      await _checkAndTriggerAlert(now);
    } else {
      // 心率正常
      if (_state.isDetecting && _state.currentAlert != null) {
        // 保存异常记录
        await _recordAlert(_state.currentAlert!);
      }
      _state.reset();
    }
  }

  /// 确认异常事件
  Future<void> acknowledgeAlert(String alertId) async {
    if (_state.currentAlert?.id == alertId) {
      _state.currentAlert!.isAcknowledged = true;
      _state.currentAlert!.acknowledgedAt = DateTime.now();
    }

    // 更新数据库记录
    if (_db != null) {
      try {
        final id = int.tryParse(alertId);
        if (id != null) {
          await (_db!.update(_db!.heartRateAlerts)
                ..where((tbl) => tbl.id.equals(id)))
              .write(
            HeartRateAlertsCompanion(
              isAcknowledged: const Value(true),
              acknowledgedAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (e) {
        debugPrint('确认异常失败: $e');
      }
    }
  }

  /// 获取异常历史记录
  Future<List<HeartRateAlertEvent>> getAlertHistory({
    String? sessionId,
    int limit = 50,
  }) async {
    if (_db == null) return [];

    try {
      var query = _db!.select(_db!.heartRateAlerts)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.alertTime)])
        ..limit(limit);

      if (sessionId != null) {
        query = query..where((tbl) => tbl.sessionId.equals(sessionId));
      }

      final results = await query.get();
      return results.map((e) => HeartRateAlertEvent.fromDb(e)).toList();
    } catch (e) {
      debugPrint('获取异常历史失败: $e');
      return [];
    }
  }

  /// 获取当前会话的异常统计
  Future<Map<String, int>> getSessionAlertStats(String sessionId) async {
    if (_db == null) return {};

    try {
      final alerts = await (_db!.select(_db!.heartRateAlerts)
          ..where((tbl) => tbl.sessionId.equals(sessionId)))
          .get();

      return {
        'total': alerts.length,
        'high': alerts.where((a) => a.alertType == 'high').length,
        'low': alerts.where((a) => a.alertType == 'low').length,
      };
    } catch (e) {
      debugPrint('获取异常统计失败: $e');
      return {};
    }
  }

  // ==================== Streams ====================

  /// 异常事件流
  Stream<HeartRateAlertEvent> get alertStream => _alertController.stream;

  /// 是否正在监测
  bool get isMonitoring => _isStarted;

  /// 当前异常事件
  HeartRateAlertEvent? get currentAlert => _state.currentAlert;

  // ==================== 私有方法 ====================

  /// 检查心率是否异常
  HeartRateAlertType? _checkHeartRate(int heartRate) {
    final highThreshold = (_targetMax! * _config.highThresholdMultiplier).round();
    final lowThreshold = (_targetMin! * _config.lowThresholdMultiplier).round();

    if (heartRate > highThreshold) {
      return HeartRateAlertType.high;
    } else if (heartRate < lowThreshold) {
      return HeartRateAlertType.low;
    }

    return null;
  }

  /// 检查并触发提醒
  Future<void> _checkAndTriggerAlert(DateTime now) async {
    if (_state.currentAlert == null) return;

    final durationSeconds = now.difference(_state.detectionStartTime!).inSeconds;

    // 检查是否达到触发时长
    if (durationSeconds < _config.alertDelaySeconds) {
      return;
    }

    // 检查冷却期
    final lastAlertTime = _state.currentAlert!.type == HeartRateAlertType.high
        ? _state.lastHighAlertTime
        : _state.lastLowAlertTime;

    if (lastAlertTime != null) {
      final timeSinceLastAlert = now.difference(lastAlertTime).inSeconds;
      if (timeSinceLastAlert < _config.alertCooldownSeconds) {
        return; // 在冷却期内，不触发提醒
      }
    }

    // 触发提醒
    await _triggerAlert(_state.currentAlert!);

    // 更新上次提醒时间
    if (_state.currentAlert!.type == HeartRateAlertType.high) {
      _state.lastHighAlertTime = now;
    } else {
      _state.lastLowAlertTime = now;
    }
  }

  /// 触发提醒
  Future<void> _triggerAlert(HeartRateAlertEvent alert) async {
    debugPrint('触发心率异常提醒: ${alert.type.displayName}, 心率=${alert.heartRate}');

    // 发送到流
    _alertController.add(alert);

    // 震动提醒
    if (_config.enableVibration) {
      await _vibrate();
    }

    // 通知和弹窗由 UI 层处理
  }

  /// 震动提醒
  Future<void> _vibrate() async {
    try {
      // 使用 HapticFeedback 进行震动反馈
      await HapticFeedback.heavyImpact();
      // 连续震动3次
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('震动提醒失败: $e');
    }
  }

  /// 记录异常到数据库
  Future<void> _recordAlert(HeartRateAlertEvent alert) async {
    if (_db == null || alert.isRecorded) return;

    try {
      await _db!.into(_db!.heartRateAlerts).insert(alert.toDbCompanion());
      alert.isRecorded = true;
      debugPrint('已记录心率异常: ${alert.type.displayName}');
    } catch (e) {
      debugPrint('记录异常失败: $e');
    }
  }

  // ==================== 清理资源 ====================

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _alertController.close();
    _instance = null;
  }
}
