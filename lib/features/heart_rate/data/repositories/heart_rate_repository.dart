/// 心率数据仓库 - 封装所有心率数据访问操作
/// 提供缓存优化和线程安全的数据访问接口

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 心率区间配置模型 ====================

/// 心率区间配置模型
class HeartRateZoneConfig {
  final int? id;
  final int? userProfileId;
  final int restingHeartRate;
  final int? maxHeartRate;
  final HeartZoneRange zone1;
  final HeartZoneRange zone2;
  final HeartZoneRange zone3;
  final HeartZoneRange zone4;
  final HeartZoneRange zone5;
  final String calculationMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const HeartRateZoneConfig({
    this.id,
    this.userProfileId,
    required this.restingHeartRate,
    this.maxHeartRate,
    required this.zone1,
    required this.zone2,
    required this.zone3,
    required this.zone4,
    required this.zone5,
    required this.calculationMethod,
    required this.createdAt,
    this.updatedAt,
  });

  /// 从数据库实体转换
  factory HeartRateZoneConfig.fromDb(HeartRateZone zone) {
    return HeartRateZoneConfig(
      id: zone.id,
      userProfileId: zone.userProfileId,
      restingHeartRate: zone.restingHeartRate,
      maxHeartRate: zone.maxHeartRate,
      zone1: HeartZoneRange(
        name: zone.zone1Name,
        min: zone.zone1Min,
        max: zone.zone1Max,
      ),
      zone2: HeartZoneRange(
        name: zone.zone2Name,
        min: zone.zone2Min,
        max: zone.zone2Max,
      ),
      zone3: HeartZoneRange(
        name: zone.zone3Name,
        min: zone.zone3Min,
        max: zone.zone3Max,
      ),
      zone4: HeartZoneRange(
        name: zone.zone4Name,
        min: zone.zone4Min,
        max: zone.zone4Max,
      ),
      zone5: HeartZoneRange(
        name: zone.zone5Name,
        min: zone.zone5Min,
        max: zone.zone5Max,
      ),
      calculationMethod: zone.calculationMethod,
      createdAt: zone.createdAt,
      updatedAt: zone.updatedAt,
    );
  }

  /// 转换为数据库插入伴侣对象
  HeartRateZonesCompanion toCompanion() {
    return HeartRateZonesCompanion(
      id: id != null ? Value(id!) : const Value.absent(),
      userProfileId: userProfileId != null ? Value(userProfileId!) : const Value.absent(),
      restingHeartRate: Value(restingHeartRate),
      maxHeartRate: maxHeartRate != null ? Value(maxHeartRate!) : const Value.absent(),
      zone1Min: Value(zone1.min),
      zone1Max: Value(zone1.max),
      zone1Name: Value(zone1.name),
      zone2Min: Value(zone2.min),
      zone2Max: Value(zone2.max),
      zone2Name: Value(zone2.name),
      zone3Min: Value(zone3.min),
      zone3Max: Value(zone3.max),
      zone3Name: Value(zone3.name),
      zone4Min: Value(zone4.min),
      zone4Max: Value(zone4.max),
      zone4Name: Value(zone4.name),
      zone5Min: Value(zone5.min),
      zone5Max: Value(zone5.max),
      zone5Name: Value(zone5.name),
      calculationMethod: Value(calculationMethod),
      createdAt: Value(createdAt),
      updatedAt: updatedAt != null ? Value(updatedAt!) : Value(DateTime.now()),
    );
  }

  /// 根据年龄和静息心率计算默认心率区间（使用卡瓦诺公式）
  static HeartRateZoneConfig calculateDefault({
    required int age,
    int? userProfileId,
    int restingHeartRate = 70,
    String calculationMethod = 'age_based',
  }) {
    // 计算最大心率（使用 Tanaka 公式：208 - 0.7 * 年龄）
    final maxHeartRate = (208 - 0.7 * age).round();
    final heartRateReserve = maxHeartRate - restingHeartRate;

    // 计算各区间（基于心率储备百分比）
    return HeartRateZoneConfig(
      userProfileId: userProfileId,
      restingHeartRate: restingHeartRate,
      maxHeartRate: maxHeartRate,
      zone1: HeartZoneRange(
        name: '热身',
        min: (restingHeartRate + heartRateReserve * 0.5).round(),
        max: (restingHeartRate + heartRateReserve * 0.6).round(),
      ),
      zone2: HeartZoneRange(
        name: '燃脂',
        min: (restingHeartRate + heartRateReserve * 0.6).round(),
        max: (restingHeartRate + heartRateReserve * 0.7).round(),
      ),
      zone3: HeartZoneRange(
        name: '有氧',
        min: (restingHeartRate + heartRateReserve * 0.7).round(),
        max: (restingHeartRate + heartRateReserve * 0.8).round(),
      ),
      zone4: HeartZoneRange(
        name: '无氧',
        min: (restingHeartRate + heartRateReserve * 0.8).round(),
        max: (restingHeartRate + heartRateReserve * 0.9).round(),
      ),
      zone5: HeartZoneRange(
        name: '极限',
        min: (restingHeartRate + heartRateReserve * 0.9).round(),
        max: maxHeartRate,
      ),
      calculationMethod: calculationMethod,
      createdAt: DateTime.now(),
    );
  }
}

/// 心率区间范围
class HeartZoneRange {
  final String name;
  final int? min;
  final int? max;

  const HeartZoneRange({
    required this.name,
    this.min,
    this.max,
  });
}

// ==================== 心率会话统计模型 ====================

/// 心率会话统计
class HeartRateSessionSummary {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? averageHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int zone1Duration;
  final int zone2Duration;
  final int zone3Duration;
  final int zone4Duration;
  final int zone5Duration;
  final String? deviceName;
  final String status;
  final int? linkedWorkoutId;

  const HeartRateSessionSummary({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.averageHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.zone1Duration = 0,
    this.zone2Duration = 0,
    this.zone3Duration = 0,
    this.zone4Duration = 0,
    this.zone5Duration = 0,
    this.deviceName,
    this.status = 'active',
    this.linkedWorkoutId,
  });

  /// 从数据库实体转换
  factory HeartRateSessionSummary.fromDb(HeartRateSession session) {
    return HeartRateSessionSummary(
      sessionId: session.sessionId,
      startTime: session.startTime,
      endTime: session.endTime,
      averageHeartRate: session.averageHeartRate,
      minHeartRate: session.minHeartRate,
      maxHeartRate: session.maxHeartRate,
      zone1Duration: session.zone1Duration,
      zone2Duration: session.zone2Duration,
      zone3Duration: session.zone3Duration,
      zone4Duration: session.zone4Duration,
      zone5Duration: session.zone5Duration,
      deviceName: session.deviceName,
      status: session.status,
      linkedWorkoutId: session.linkedWorkoutId,
    );
  }

  /// 获取总时长（秒）
  int get totalDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }

  /// 获取各区间分布百分比
  Map<String, double> get zoneDistribution {
    final total = zone1Duration + zone2Duration + zone3Duration +
        zone4Duration + zone5Duration;
    if (total == 0) return {};
    return {
      'zone1': zone1Duration / total,
      'zone2': zone2Duration / total,
      'zone3': zone3Duration / total,
      'zone4': zone4Duration / total,
      'zone5': zone5Duration / total,
    };
  }
}

// ==================== 心率记录模型 ====================

/// 心率记录点（用于图表展示）
class HeartRateDataPoint {
  final int heartRate;
  final DateTime timestamp;
  final int? rrInterval;
  final String? zone;

  const HeartRateDataPoint({
    required this.heartRate,
    required this.timestamp,
    this.rrInterval,
    this.zone,
  });

  /// 从数据库实体转换
  factory HeartRateDataPoint.fromDb(HeartRateRecord record, {String? zone}) {
    return HeartRateDataPoint(
      heartRate: record.heartRate,
      timestamp: record.timestamp,
      rrInterval: record.rrInterval,
      zone: zone,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'heartRate': heartRate,
      'timestamp': timestamp.toIso8601String(),
      'rrInterval': rrInterval,
      'zone': zone,
    };
  }
}

// ==================== 心率数据仓库 ====================

/// 心率数据仓库 - 线程安全单例
class HeartRateRepository {
  final AppDatabase _db;

  // 缓存
  HeartRateZoneConfig? _zoneConfigCache;
  List<HeartRateSessionSummary>? _sessionsCache;
  DateTime? _sessionsCacheTime;

  // 缓存有效期（毫秒）
  static const int _cacheValidDuration = 60000; // 1分钟

  // 锁对象
  final Object _lock = Object();

  HeartRateRepository(this._db);

  // ==================== 心率区间配置操作 ====================

  /// 获取心率区间配置（带缓存）
  Future<HeartRateZoneConfig?> getZoneConfig({bool forceRefresh = false}) async {
    // 检查缓存
    if (!forceRefresh && _zoneConfigCache != null) {
      return _zoneConfigCache;
    }

    try {
      final results = await _db.select(_db.heartRateZones).get();
      if (results.isEmpty) {
        _zoneConfigCache = null;
        return null;
      }

      _zoneConfigCache = HeartRateZoneConfig.fromDb(results.first);
      return _zoneConfigCache;
    } catch (e) {
      debugPrint('获取心率区间配置失败: $e');
      return null;
    }
  }

  /// 保存心率区间配置
  Future<bool> saveZoneConfig(HeartRateZoneConfig config) async {
    try {
      // 删除旧配置
      await _db.delete(_db.heartRateZones).go();

      // 插入新配置
      await _db.into(_db.heartRateZones).insert(config.toCompanion());

      // 更新缓存
      _zoneConfigCache = config;

      return true;
    } catch (e) {
      debugPrint('保存心率区间配置失败: $e');
      return false;
    }
  }

  /// 创建或更新默认心率区间配置
  Future<HeartRateZoneConfig> getOrCreateDefaultZoneConfig({
    required int age,
    int? userProfileId,
    int restingHeartRate = 70,
  }) async {
    // 先尝试获取现有配置
    final existing = await getZoneConfig();
    if (existing != null) {
      return existing;
    }

    // 创建默认配置
    final defaultConfig = HeartRateZoneConfig.calculateDefault(
      age: age,
      userProfileId: userProfileId,
      restingHeartRate: restingHeartRate,
    );

    await saveZoneConfig(defaultConfig);
    return defaultConfig;
  }

  /// 清除区间配置缓存
  void clearZoneConfigCache() {
    _zoneConfigCache = null;
  }

  // ==================== 心率会话操作 ====================

  /// 获取心率会话列表（带缓存）
  Future<List<HeartRateSessionSummary>> getSessions({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // 检查缓存
    final now = DateTime.now();
    if (!forceRefresh &&
        _sessionsCache != null &&
        _sessionsCacheTime != null &&
        now.difference(_sessionsCacheTime!).inMilliseconds < _cacheValidDuration) {
      return _sessionsCache!;
    }

    try {
      final query = _db.select(_db.heartRateSessions)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)])
        ..limit(limit, offset: offset);

      final results = await query.get();
      _sessionsCache = results.map((e) => HeartRateSessionSummary.fromDb(e)).toList();
      _sessionsCacheTime = now;

      return _sessionsCache!;
    } catch (e) {
      debugPrint('获取心率会话列表失败: $e');
      return [];
    }
  }

  /// 获取最新会话
  Future<HeartRateSessionSummary?> getLatestSession() async {
    try {
      final results = await (_db.select(_db.heartRateSessions)
            ..limit(1)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]))
          .get();

      if (results.isEmpty) return null;
      return HeartRateSessionSummary.fromDb(results.first);
    } catch (e) {
      debugPrint('获取最新心率会话失败: $e');
      return null;
    }
  }

  /// 根据ID获取会话详情
  Future<HeartRateSessionSummary?> getSessionById(String sessionId) async {
    try {
      final results = await (_db.select(_db.heartRateSessions)
            ..where((tbl) => tbl.sessionId.equals(sessionId)))
          .get();

      if (results.isEmpty) return null;
      return HeartRateSessionSummary.fromDb(results.first);
    } catch (e) {
      debugPrint('获取会话详情失败: $e');
      return null;
    }
  }

  /// 获取指定运动关联的心率会话
  Future<List<HeartRateSessionSummary>> getSessionsByWorkout(int workoutId) async {
    try {
      final results = await (_db.select(_db.heartRateSessions)
            ..where((tbl) => tbl.linkedWorkoutId.equals(workoutId))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]))
          .get();

      return results.map((e) => HeartRateSessionSummary.fromDb(e)).toList();
    } catch (e) {
      debugPrint('获取运动关联的心率会话失败: $e');
      return [];
    }
  }

  /// 清除会话缓存
  void clearSessionsCache() {
    _sessionsCache = null;
    _sessionsCacheTime = null;
  }

  // ==================== 心率记录操作 ====================

  /// 获取指定会话的心率记录
  Future<List<HeartRateDataPoint>> getSessionRecords({
    required String sessionId,
    int? limit,
    HeartRateZoneConfig? zoneConfig,
  }) async {
    try {
      var query = _db.select(_db.heartRateRecords)
        ..where((tbl) => tbl.sessionId.equals(sessionId))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.timestamp)]);

      if (limit != null) {
        query..limit(limit);
      }

      final records = await query.get();

      // 获取区间配置用于确定每个心率点所在区间
      final config = zoneConfig ?? await getZoneConfig();

      return records.map((record) {
        String? zone;
        if (config != null && config.maxHeartRate != null) {
          zone = _getZoneForHeartRate(record.heartRate, config.maxHeartRate!);
        }
        return HeartRateDataPoint.fromDb(record, zone: zone);
      }).toList();
    } catch (e) {
      debugPrint('获取心率记录失败: $e');
      return [];
    }
  }

  /// 获取最近的心率记录（用于实时图表）
  Future<List<HeartRateDataPoint>> getRecentRecords({
    required String sessionId,
    int seconds = 60,
    HeartRateZoneConfig? zoneConfig,
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(seconds: seconds));

      final records = await (_db.select(_db.heartRateRecords)
            ..where((tbl) =>
                tbl.sessionId.equals(sessionId) &
                tbl.timestamp.isBiggerOrEqualValue(cutoffTime))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.timestamp)]))
          .get();

      final config = zoneConfig ?? await getZoneConfig();

      return records.map((record) {
        String? zone;
        if (config != null && config.maxHeartRate != null) {
          zone = _getZoneForHeartRate(record.heartRate, config.maxHeartRate!);
        }
        return HeartRateDataPoint.fromDb(record, zone: zone);
      }).toList();
    } catch (e) {
      debugPrint('获取最近心率记录失败: $e');
      return [];
    }
  }

  /// 批量插入心率记录（优化性能）
  Future<bool> batchInsertRecords(List<HeartRateDataPoint> points, String sessionId) async {
    try {
      await _db.batch((batch) {
        for (final point in points) {
          batch.insert(
            _db.heartRateRecords,
            HeartRateRecordsCompanion.insert(
              heartRate: point.heartRate,
              rrInterval: point.rrInterval != null
                  ? Value(point.rrInterval!)
                  : const Value.absent(),
              timestamp: Value(point.timestamp),
              sessionId: sessionId,
            ),
          );
        }
      });
      return true;
    } catch (e) {
      debugPrint('批量插入心率记录失败: $e');
      return false;
    }
  }

  // ==================== 统计操作 ====================

  /// 获取会话统计数据
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return {};

      final records = await getSessionRecords(sessionId: sessionId);
      if (records.isEmpty) return {};

      // 计算详细统计
      final heartRates = records.map((e) => e.heartRate).toList();
      final avg = heartRates.reduce((a, b) => a + b) / heartRates.length;
      final min = heartRates.reduce((a, b) => a < b ? a : b);
      final max = heartRates.reduce((a, b) => a > b ? a : b);

      // 计算区间分布
      final zoneCounts = <String, int>{'zone1': 0, 'zone2': 0, 'zone3': 0, 'zone4': 0, 'zone5': 0};
      for (final record in records) {
        if (record.zone != null) {
          zoneCounts[record.zone!] = (zoneCounts[record.zone!] ?? 0) + 1;
        }
      }

      return {
        'averageHeartRate': avg.round(),
        'minHeartRate': min,
        'maxHeartRate': max,
        'totalRecords': records.length,
        'zoneCounts': zoneCounts,
        'duration': session.totalDuration,
      };
    } catch (e) {
      debugPrint('获取会话统计失败: $e');
      return {};
    }
  }

  /// 获取指定日期范围的心率统计
  Future<Map<String, dynamic>> getDateRangeStats(DateTime start, DateTime end) async {
    try {
      final sessions = await (_db.select(_db.heartRateSessions)
            ..where((tbl) =>
                tbl.startTime.isBiggerOrEqualValue(start) &
                tbl.startTime.isSmallerOrEqualValue(end)))
          .get();

      if (sessions.isEmpty) {
        return {
          'totalSessions': 0,
          'totalDuration': 0,
          'averageHeartRate': 0,
        };
      }

      final totalDuration = sessions.fold<int>(
        0,
        (sum, session) {
          final end = session.endTime ?? DateTime.now();
          return sum + end.difference(session.startTime).inSeconds;
        },
      );

      final allAverageRates =
          sessions.where((s) => s.averageHeartRate != null).map((s) => s.averageHeartRate!);
      final avgHeartRate = allAverageRates.isNotEmpty
          ? (allAverageRates.reduce((a, b) => a + b) / allAverageRates.length).round()
          : 0;

      return {
        'totalSessions': sessions.length,
        'totalDuration': totalDuration,
        'averageHeartRate': avgHeartRate,
        'sessions': sessions.map((s) => HeartRateSessionSummary.fromDb(s)).toList(),
      };
    } catch (e) {
      debugPrint('获取日期范围统计失败: $e');
      return {};
    }
  }

  // ==================== 清理操作 ====================

  /// 删除指定会话及其所有记录
  Future<bool> deleteSession(String sessionId) async {
    try {
      // 删除心率记录
      await (_db.delete(_db.heartRateRecords)
            ..where((tbl) => tbl.sessionId.equals(sessionId)))
          .go();

      // 删除会话
      await (_db.delete(_db.heartRateSessions)
            ..where((tbl) => tbl.sessionId.equals(sessionId)))
          .go();

      // 清除缓存
      clearSessionsCache();

      return true;
    } catch (e) {
      debugPrint('删除会话失败: $e');
      return false;
    }
  }

  /// 删除所有会话（危险操作）
  Future<bool> deleteAllSessions() async {
    try {
      await _db.delete(_db.heartRateRecords).go();
      await _db.delete(_db.heartRateSessions).go();

      // 清除缓存
      clearSessionsCache();

      return true;
    } catch (e) {
      debugPrint('删除所有会话失败: $e');
      return false;
    }
  }

  /// 清除所有缓存
  void clearAllCache() {
    _zoneConfigCache = null;
    _sessionsCache = null;
    _sessionsCacheTime = null;
  }

  // ==================== 私有辅助方法 ====================

  /// 根据心率值获取所在区间
  String? _getZoneForHeartRate(int heartRate, int maxHeartRate) {
    final percent = (heartRate / maxHeartRate * 100).round();

    if (percent >= 50 && percent < 60) return 'zone1';
    if (percent >= 60 && percent < 70) return 'zone2';
    if (percent >= 70 && percent < 80) return 'zone3';
    if (percent >= 80 && percent < 90) return 'zone4';
    if (percent >= 90) return 'zone5';

    return null;
  }
}
