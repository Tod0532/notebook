/// 地理围栏仓库 - 处理地理围栏的CRUD操作
/// 提供：围栏增删改查、围栏列表查询、围栏状态管理等功能
/// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart';

/// 地理围栏仓库异常类
class GeofenceRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  GeofenceRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'GeofenceRepositoryException: $message';
  }
}

/// 地理围栏仓库
class GeofenceRepository {
  final AppDatabase _database;

  GeofenceRepository(this._database);

  // ==================== 围栏 CRUD 操作 ====================

  /// 获取所有围栏
  Future<List<Geofence>> getAllGeofences({bool? isEnabled}) async {
    try {
      final query = _database.select(_database.geofences);
      if (isEnabled != null) {
        query.where((tbl) => tbl.isEnabled.equals(isEnabled));
      }
      query.orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
      return await query.get();
    } catch (e, st) {
      debugPrint('获取所有围栏失败: $e');
      throw GeofenceRepositoryException('获取所有围栏失败', e, st);
    }
  }

  /// 获取启用的围栏
  Future<List<Geofence>> getEnabledGeofences() async {
    try {
      return await getAllGeofences(isEnabled: true);
    } catch (e, st) {
      debugPrint('获取启用围栏失败: $e');
      throw GeofenceRepositoryException('获取启用围栏失败', e, st);
    }
  }

  /// 根据ID获取围栏
  Future<Geofence?> getGeofenceById(int id) async {
    try {
      final query = _database.select(_database.geofences)
        ..where((tbl) => tbl.id.equals(id));
      return await query.getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取围栏详情失败: $e');
      throw GeofenceRepositoryException('获取围栏详情失败', e, st);
    }
  }

  /// 创建围栏
  Future<int> createGeofence(GeofencesCompanion geofence) async {
    try {
      return await _database.into(_database.geofences).insert(geofence);
    } catch (e, st) {
      debugPrint('创建围栏失败: $e');
      throw GeofenceRepositoryException('创建围栏失败', e, st);
    }
  }

  /// 快速创建围栏
  Future<int> createGeofenceWithData({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    double radius = GeofenceConfig.defaultRadius,
    String triggerType = 'enter',
    int? linkedReminderId,
    bool isEnabled = true,
    int? iconCode,
    int? colorHex,
  }) async {
    try {
      return await _database.into(_database.geofences).insert(
        GeofencesCompanion.insert(
          name: name,
          address: address,
          latitude: latitude,
          longitude: longitude,
          radius: Value(radius),
          triggerType: triggerType,
          linkedReminderId: Value(linkedReminderId),
          isEnabled: Value(isEnabled),
          iconCode: Value(iconCode ?? 0),
          colorHex: Value(colorHex),
        ),
      );
    } catch (e, st) {
      debugPrint('创建围栏失败: $e');
      throw GeofenceRepositoryException('创建围栏失败', e, st);
    }
  }

  /// 更新围栏
  Future<bool> updateGeofence(Geofence geofence) async {
    try {
      final result = await (_database.update(_database.geofences)..where((tbl) => tbl.id.equals(geofence.id))).write(GeofencesCompanion(
        name: Value(geofence.name),
        address: Value(geofence.address),
        latitude: Value(geofence.latitude),
        longitude: Value(geofence.longitude),
        radius: Value(geofence.radius),
        triggerType: Value(geofence.triggerType),
        linkedReminderId: Value(geofence.linkedReminderId),
        isEnabled: Value(geofence.isEnabled),
        iconCode: Value(geofence.iconCode),
        colorHex: Value(geofence.colorHex),
      ));
      return result > 0;
    } catch (e, st) {
      debugPrint('更新围栏失败: $e');
      throw GeofenceRepositoryException('更新围栏失败', e, st);
    }
  }

  /// 更新围栏启用状态
  Future<bool> updateGeofenceEnabled(int id, bool isEnabled) async {
    try {
      final result = await (_database.update(_database.geofences)
        ..where((tbl) => tbl.id.equals(id)))
        .write(GeofencesCompanion(isEnabled: Value(isEnabled)));
      return result > 0;
    } catch (e, st) {
      debugPrint('更新围栏启用状态失败: $e');
      throw GeofenceRepositoryException('更新围栏启用状态失败', e, st);
    }
  }

  /// 删除围栏
  Future<bool> deleteGeofence(int id) async {
    try {
      final result = await (_database.delete(_database.geofences)
        ..where((tbl) => tbl.id.equals(id)))
        .go();
      return result > 0;
    } catch (e, st) {
      debugPrint('删除围栏失败: $e');
      throw GeofenceRepositoryException('删除围栏失败', e, st);
    }
  }

  /// 批量删除围栏
  Future<int> deleteMultipleGeofences(List<int> ids) async {
    try {
      if (ids.isEmpty) return 0;
      final result = await (_database.delete(_database.geofences)
        ..where((tbl) => tbl.id.isIn(ids)))
        .go();
      return result;
    } catch (e, st) {
      debugPrint('批量删除围栏失败: $e');
      throw GeofenceRepositoryException('批量删除围栏失败', e, st);
    }
  }

  // ==================== 围栏查询 ====================

  /// 根据名称搜索围栏
  Future<List<Geofence>> searchGeofencesByName(String keyword) async {
    try {
      return await (_database.select(_database.geofences)
            ..where((tbl) => tbl.name.contains(keyword) | tbl.address.contains(keyword))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('搜索围栏失败: $e');
      throw GeofenceRepositoryException('搜索围栏失败', e, st);
    }
  }

  /// 获取围栏数量
  Future<int> getGeofenceCount({bool? enabledOnly}) async {
    try {
      final query = _database.selectOnly(_database.geofences)
        ..addColumns([countAll()]);

      if (enabledOnly == true) {
        query.where(_database.geofences.isEnabled.equals(true));
      }

      final result = await query.getSingle();
      return result.read(countAll()) ?? 0;
    } catch (e, st) {
      debugPrint('获取围栏数量失败: $e');
      throw GeofenceRepositoryException('获取围栏数量失败', e, st);
    }
  }

  // ==================== 事件记录操作 ====================

  /// 获取围栏的所有事件
  Future<List<LocationEvent>> getEventsByGeofenceId(int geofenceId, {int limit = 100}) async {
    try {
      final query = _database.select(_database.locationEvents)
        ..where((tbl) => tbl.geofenceId.equals(geofenceId))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)])
        ..limit(limit);
      return await query.get();
    } catch (e, st) {
      debugPrint('获取围栏事件失败: $e');
      throw GeofenceRepositoryException('获取围栏事件失败', e, st);
    }
  }

  /// 获取最近的围栏事件
  Future<List<LocationEvent>> getRecentEvents({int limit = 50}) async {
    try {
      final query = _database.select(_database.locationEvents)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)])
        ..limit(limit);
      return await query.get();
    } catch (e, st) {
      debugPrint('获取最近事件失败: $e');
      throw GeofenceRepositoryException('获取最近事件失败', e, st);
    }
  }

  /// 标记事件为已处理
  Future<bool> markEventAsProcessed(int eventId) async {
    try {
      final result = await (_database.update(_database.locationEvents)
        ..where((tbl) => tbl.id.equals(eventId)))
        .write(const LocationEventsCompanion(isProcessed: Value(true)));
      return result > 0;
    } catch (e, st) {
      debugPrint('标记事件已处理失败: $e');
      throw GeofenceRepositoryException('标记事件已处理失败', e, st);
    }
  }

  /// 批量标记事件为已处理
  Future<int> markMultipleEventsAsProcessed(List<int> eventIds) async {
    try {
      if (eventIds.isEmpty) return 0;
      final result = await (_database.update(_database.locationEvents)
        ..where((tbl) => tbl.id.isIn(eventIds)))
        .write(const LocationEventsCompanion(isProcessed: Value(true)));
      return result;
    } catch (e, st) {
      debugPrint('批量标记事件已处理失败: $e');
      throw GeofenceRepositoryException('批量标记事件已处理失败', e, st);
    }
  }

  /// 清理旧的事件记录
  Future<int> cleanOldEvents({Duration? olderThan}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan ?? const Duration(days: 30));

      final result = await (_database.delete(_database.locationEvents)
        ..where((tbl) => tbl.occurredAt.isSmallerThanValue(cutoffDate)))
        .go();
      return result;
    } catch (e, st) {
      debugPrint('清理旧事件失败: $e');
      throw GeofenceRepositoryException('清理旧事件失败', e, st);
    }
  }

  // ==================== 统计信息 ====================

  /// 获取围栏统计信息
  Future<GeofenceStatistics> getGeofenceStatistics() async {
    try {
      final allGeofences = await getAllGeofences();
      final enabledCount = allGeofences.where((g) => g.isEnabled).length;

      final recentEvents = await getRecentEvents(limit: 100);
      final today = DateTime.now();
      final todayEvents = recentEvents.where((e) {
        return e.occurredAt.year == today.year &&
            e.occurredAt.month == today.month &&
            e.occurredAt.day == today.day;
      }).length;

      final enteredCount = recentEvents.where((e) => e.eventType == 'entered').length;
      final exitedCount = recentEvents.where((e) => e.eventType == 'exited').length;

      return GeofenceStatistics(
        totalGeofences: allGeofences.length,
        enabledGeofences: enabledCount,
        todayEvents: todayEvents,
        totalEvents: recentEvents.length,
        enteredCount: enteredCount,
        exitedCount: exitedCount,
      );
    } catch (e, st) {
      debugPrint('获取围栏统计失败: $e');
      throw GeofenceRepositoryException('获取围栏统计失败', e, st);
    }
  }

  /// 获取指定围栏的统计信息
  Future<GeofenceDetailStatistics?> getGeofenceDetailStatistics(int geofenceId) async {
    try {
      final geofence = await getGeofenceById(geofenceId);
      if (geofence == null) return null;

      final events = await getEventsByGeofenceId(geofenceId, limit: 1000);
      final today = DateTime.now();
      final todayEvents = events.where((e) {
        return e.occurredAt.year == today.year &&
            e.occurredAt.month == today.month &&
            e.occurredAt.day == today.day;
      }).length;

      final enteredCount = events.where((e) => e.eventType == 'entered').length;
      final exitedCount = events.where((e) => e.eventType == 'exited').length;

      return GeofenceDetailStatistics(
        geofence: geofence,
        totalEvents: events.length,
        todayEvents: todayEvents,
        enteredCount: enteredCount,
        exitedCount: exitedCount,
        lastEvent: events.isNotEmpty ? events.first : null,
      );
    } catch (e, st) {
      debugPrint('获取围栏详细统计失败: $e');
      throw GeofenceRepositoryException('获取围栏详细统计失败', e, st);
    }
  }
}

/// 围栏统计信息
class GeofenceStatistics {
  final int totalGeofences;
  final int enabledGeofences;
  final int todayEvents;
  final int totalEvents;
  final int enteredCount;
  final int exitedCount;

  GeofenceStatistics({
    required this.totalGeofences,
    required this.enabledGeofences,
    required this.todayEvents,
    required this.totalEvents,
    required this.enteredCount,
    required this.exitedCount,
  });
}

/// 围栏详细统计信息
class GeofenceDetailStatistics {
  final Geofence geofence;
  final int totalEvents;
  final int todayEvents;
  final int enteredCount;
  final int exitedCount;
  final LocationEvent? lastEvent;

  GeofenceDetailStatistics({
    required this.geofence,
    required this.totalEvents,
    required this.todayEvents,
    required this.enteredCount,
    required this.exitedCount,
    this.lastEvent,
  });

  /// 获取最后进入时间
  DateTime? get lastEnteredTime {
    if (lastEvent?.eventType == 'entered') {
      return lastEvent?.occurredAt;
    }
    return null;
  }

  /// 获取最后离开时间
  DateTime? get lastExitedTime {
    if (lastEvent?.eventType == 'exited') {
      return lastEvent?.occurredAt;
    }
    return null;
  }

  /// 获取状态描述
  String get statusDescription {
    if (lastEvent == null) return '从未触发';
    return '最后触发: ${_formatDateTime(lastEvent!.occurredAt)}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
