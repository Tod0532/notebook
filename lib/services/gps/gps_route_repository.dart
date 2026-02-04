/// GPS路线仓库 - 处理GPS轨迹数据的持久化
/// 提供：保存轨迹、查询轨迹、删除轨迹等功能

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/gps/gps_tracking_service.dart';

/// GPS路线仓库 - 单例模式
class GpsRouteRepository {
  // ==================== 单例模式 ====================
  GpsRouteRepository._();
  static final GpsRouteRepository _instance = GpsRouteRepository._();
  static GpsRouteRepository get instance => _instance;

  // ==================== 数据库 ====================
  final AppDatabase _db = AppDatabase(
    LazyDatabase(() async {
      // 使用与主数据库相同的配置
      final dbDir = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(dbDir.path, 'thick_notepad.db'),
      );
      return NativeDatabase.createInBackground(file);
    }),
  );

  // ==================== 保存轨迹 ====================

  /// 保存GPS轨迹到数据库
  /// 返回保存的路线ID
  Future<int> saveRoute({
    required int? workoutId,
    required String workoutType,
    required DateTime startTime,
    DateTime? endTime,
    required int duration,
    required double distance,
    required double averageSpeed,
    required double maxSpeed,
    double? averagePace,
    double? elevationGain,
    double? elevationLoss,
    required double calories,
    required List<GpsPoint> points,
  }) async {
    try {
      // 将轨迹点转换为JSON字符串
      final pointsJson = jsonEncode(
        points.map((p) => p.toJson()).toList(),
      );

      final route = GpsRoutesCompanion.insert(
        workoutId: Value(workoutId),
        workoutType: workoutType,
        startTime: startTime,
        endTime: Value(endTime),
        duration: Value(duration),
        distance: Value(distance),
        averageSpeed: Value(averageSpeed),
        maxSpeed: Value(maxSpeed),
        averagePace: Value(averagePace),
        elevationGain: Value(elevationGain),
        elevationLoss: Value(elevationLoss),
        calories: Value(calories),
        points: pointsJson,
        pointCount: Value(points.length),
      );

      final id = await _db.into(_db.gpsRoutes).insert(route);
      return id;
    } catch (e) {
      debugPrint('保存GPS路线失败: $e');
      return -1;
    }
  }

  /// 从GPS追踪服务保存当前轨迹
  Future<int> saveCurrentTracking({
    required int? workoutId,
    required String workoutType,
  }) async {
    final service = GpsTrackingService.instance;
    final stats = service.currentStatistics;
    final points = service.trackPoints;

    if (points.isEmpty) {
      debugPrint('没有轨迹点可以保存');
      return -1;
    }

    return saveRoute(
      workoutId: workoutId,
      workoutType: workoutType,
      startTime: points.first.timestamp,
      endTime: points.last.timestamp,
      duration: stats.duration.inSeconds,
      distance: stats.distance,
      averageSpeed: stats.averageSpeed,
      maxSpeed: stats.maxSpeed,
      averagePace: stats.averagePace,
      elevationGain: stats.elevationGain,
      elevationLoss: stats.elevationLoss,
      calories: stats.calories,
      points: points,
    );
  }

  // ==================== 查询轨迹 ====================

  /// 根据运动ID获取GPS路线
  Future<GpsRoute?> getRouteByWorkoutId(int workoutId) async {
    try {
      final query = _db.select(_db.gpsRoutes)
        ..where((tbl) => tbl.workoutId.equals(workoutId))
        ..limit(1);

      final results = await query.get();
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('查询GPS路线失败: $e');
      return null;
    }
  }

  /// 根据ID获取GPS路线
  Future<GpsRoute?> getRouteById(int routeId) async {
    try {
      final query = _db.select(_db.gpsRoutes)
        ..where((tbl) => tbl.id.equals(routeId))
        ..limit(1);

      final results = await query.get();
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('查询GPS路线失败: $e');
      return null;
    }
  }

  /// 获取所有GPS路线
  Future<List<GpsRoute>> getAllRoutes() async {
    try {
      final query = _db.select(_db.gpsRoutes)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]);

      return await query.get();
    } catch (e) {
      debugPrint('查询所有GPS路线失败: $e');
      return [];
    }
  }

  /// 根据运动类型获取路线
  Future<List<GpsRoute>> getRoutesByType(String workoutType) async {
    try {
      final query = _db.select(_db.gpsRoutes)
        ..where((tbl) => tbl.workoutType.equals(workoutType))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]);

      return await query.get();
    } catch (e) {
      debugPrint('查询GPS路线失败: $e');
      return [];
    }
  }

  /// 根据日期范围获取路线
  Future<List<GpsRoute>> getRoutesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final query = _db.select(_db.gpsRoutes)
        ..where((tbl) => tbl.startTime.isBiggerOrEqualValue(start))
        ..where((tbl) => tbl.startTime.isSmallerOrEqualValue(end))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]);

      return await query.get();
    } catch (e) {
      debugPrint('查询GPS路线失败: $e');
      return [];
    }
  }

  // ==================== 轨迹点解析 ====================

  /// 从路线中解析GPS点列表
  List<GpsPoint> parseRoutePoints(GpsRoute route) {
    try {
      final pointsJson = jsonDecode(route.points) as List;
      return pointsJson
          .map((json) => GpsPoint.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('解析GPS点失败: $e');
      return [];
    }
  }

  // ==================== 统计查询 ====================

  /// 获取总运动距离（按运动类型）
  Future<Map<String, double>> getTotalDistanceByType() async {
    try {
      final routes = await getAllRoutes();
      final result = <String, double>{};

      for (final route in routes) {
        final type = route.workoutType;
        final distance = route.distance ?? 0;
        result[type] = (result[type] ?? 0) + distance;
      }

      return result;
    } catch (e) {
      debugPrint('统计总距离失败: $e');
      return {};
    }
  }

  /// 获取指定日期范围内的总距离
  Future<double> getTotalDistanceInRange(DateTime start, DateTime end) async {
    try {
      final routes = await getRoutesByDateRange(start, end);
      return routes.fold<double>(
        0,
        (sum, route) => sum + (route.distance ?? 0),
      );
    } catch (e) {
      debugPrint('统计总距离失败: $e');
      return 0;
    }
  }

  /// 获取路线数量统计
  Future<int> getRouteCount() async {
    try {
      final query = _db.selectOnly(_db.gpsRoutes)
        ..addColumns([_db.gpsRoutes.id.count()]);
      final result = await query.get();
      return result.firstOrNull?.read(_db.gpsRoutes.id.count()) ?? 0;
    } catch (e) {
      debugPrint('统计路线数量失败: $e');
      return 0;
    }
  }

  // ==================== 删除轨迹 ====================

  /// 删除指定路线
  Future<bool> deleteRoute(int routeId) async {
    try {
      final query = _db.delete(_db.gpsRoutes)
        ..where((tbl) => tbl.id.equals(routeId));
      await query.go();
      return true;
    } catch (e) {
      debugPrint('删除GPS路线失败: $e');
      return false;
    }
  }

  /// 删除运动关联的路线
  Future<bool> deleteRouteByWorkoutId(int workoutId) async {
    try {
      final query = _db.delete(_db.gpsRoutes)
        ..where((tbl) => tbl.workoutId.equals(workoutId));
      await query.go();
      return true;
    } catch (e) {
      debugPrint('删除GPS路线失败: $e');
      return false;
    }
  }

  /// 删除所有路线
  Future<bool> deleteAllRoutes() async {
    try {
      await _db.delete(_db.gpsRoutes).go();
      return true;
    } catch (e) {
      debugPrint('删除所有GPS路线失败: $e');
      return false;
    }
  }

  // ==================== 更新路线 ====================

  /// 更新路线关联的运动ID
  Future<bool> updateRouteWorkoutId(int routeId, int workoutId) async {
    try {
      final query = _db.update(_db.gpsRoutes)
        ..where((tbl) => tbl.id.equals(routeId));
      await query.write(GpsRoutesCompanion(
        workoutId: Value(workoutId),
      ));
      return true;
    } catch (e) {
      debugPrint('更新GPS路线失败: $e');
      return false;
    }
  }

  // ==================== 导出功能 ====================

  /// 导出路线为GPX格式（用于与其他应用兼容）
  String exportRouteToGpx(GpsRoute route) {
    final points = parseRoutePoints(route);
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="ThickNotepad">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${route.workoutType} - ${route.startTime}</name>');
    buffer.writeln('    <trkseg>');

    for (final point in points) {
      buffer.writeln(
        '      <trkpt lat="${point.latitude}" lon="${point.longitude}">',
      );
      if (point.altitude != null) {
        buffer.writeln('        <ele>${point.altitude}</ele>');
      }
      buffer.writeln('        <time>${point.timestamp.toIso8601String()}</time>');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  // ==================== 释放资源 ====================

  /// 关闭数据库连接
  Future<void> close() async {
    await _db.close();
  }
}
