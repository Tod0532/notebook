/// GPS导出服务 - 导出GPS轨迹为各种格式
/// 支持：GPX、KML、JSON等格式

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/gps/gps_route_repository.dart';

/// GPS导出格式
enum GpsExportFormat {
  gpx('GPX', 'gpx'),
  kml('KML', 'kml'),
  json('JSON', 'json'),
  csv('CSV', 'csv');

  final String displayName;
  final String extension;

  const GpsExportFormat(this.displayName, this.extension);
}

/// GPS导出服务
class GpsExportService {
  static final GpsExportService _instance = GpsExportService._();
  static GpsExportService get instance => _instance;

  GpsExportService._();

  final GpsRouteRepository _routeRepo = GpsRouteRepository.instance;

  /// 导出路线为指定格式并分享
  Future<bool> exportAndShareRoute(
    GpsRoute route, {
    GpsExportFormat format = GpsExportFormat.gpx,
  }) async {
    try {
      String content;
      String mimeType;
      String fileName;

      switch (format) {
        case GpsExportFormat.gpx:
          content = _exportToGpx(route);
          mimeType = 'application/gpx+xml';
          fileName = 'route_${route.id}.gpx';
          break;

        case GpsExportFormat.kml:
          content = _exportToKml(route);
          mimeType = 'application/vnd.google-earth.kml+xml';
          fileName = 'route_${route.id}.kml';
          break;

        case GpsExportFormat.json:
          content = _exportToJson(route);
          mimeType = 'application/json';
          fileName = 'route_${route.id}.json';
          break;

        case GpsExportFormat.csv:
          content = _exportToCsv(route);
          mimeType = 'text/csv';
          fileName = 'route_${route.id}.csv';
          break;
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: '分享GPS轨迹',
      );

      return true;
    } catch (e) {
      print('导出失败: $e');
      return false;
    }
  }

  /// 导出为GPX格式
  String _exportToGpx(GpsRoute route) {
    final points = _routeRepo.parseRoutePoints(route);
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="ThickNotepad" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_getWorkoutTypeName(route.workoutType)} - ${_formatDate(route.startTime)}</name>');
    buffer.writeln('    <time>${route.startTime.toIso8601String()}</time>');
    if (route.distance != null) {
      buffer.writeln('    <extensions>');
      buffer.writeln('      <distance>${route.distance!.toStringAsFixed(2)}</distance>');
      buffer.writeln('      <duration>${route.duration}</duration>');
      if (route.calories != null) {
        buffer.writeln('      <calories>${route.calories!.toStringAsFixed(0)}</calories>');
      }
      buffer.writeln('    </extensions>');
    }
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_getWorkoutTypeName(route.workoutType)}</name>');
    buffer.writeln('    <trkseg>');

    for (final point in points) {
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      if (point.altitude != null) {
        buffer.writeln('        <ele>${point.altitude!.toStringAsFixed(2)}</ele>');
      }
      buffer.writeln('        <time>${point.timestamp.toIso8601String()}</time>');
      if (point.speed != null) {
        buffer.writeln('        <speed>${point.speed!.toStringAsFixed(2)}</speed>');
      }
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// 导出为KML格式
  String _exportToKml(GpsRoute route) {
    final points = _routeRepo.parseRoutePoints(route);
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${_getWorkoutTypeName(route.workoutType)} - ${_formatDate(route.startTime)}</name>');
    buffer.writeln('    <Placemark>');
    buffer.writeln('      <name>运动轨迹</name>');
    buffer.writeln('      <LineString>');
    buffer.writeln('        <coordinates>');

    for (final point in points) {
      buffer.writeln('          ${point.longitude},${point.latitude},${point.altitude ?? 0}');
    }

    buffer.writeln('        </coordinates>');
    buffer.writeln('      </LineString>');
    buffer.writeln('      <ExtendedData>');
    if (route.distance != null) {
      buffer.writeln('        <Data name="distance"><value>${route.distance!.toStringAsFixed(2)}</value></Data>');
    }
    buffer.writeln('        <Data name="duration"><value>${route.duration}</value></Data>');
    if (route.calories != null) {
      buffer.writeln('        <Data name="calories"><value>${route.calories!.toStringAsFixed(0)}</value></Data>');
    }
    buffer.writeln('      </ExtendedData>');
    buffer.writeln('    </Placemark>');
    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    return buffer.toString();
  }

  /// 导出为JSON格式
  String _exportToJson(GpsRoute route) {
    final points = _routeRepo.parseRoutePoints(route);

    final data = {
      'type': 'Feature',
      'properties': {
        'id': route.id,
        'workoutType': route.workoutType,
        'workoutTypeName': _getWorkoutTypeName(route.workoutType),
        'startTime': route.startTime.toIso8601String(),
        'endTime': route.endTime?.toIso8601String(),
        'duration': route.duration,
        'distance': route.distance,
        'averageSpeed': route.averageSpeed,
        'maxSpeed': route.maxSpeed,
        'averagePace': route.averagePace,
        'elevationGain': route.elevationGain,
        'elevationLoss': route.elevationLoss,
        'calories': route.calories,
        'pointCount': route.pointCount,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': points.map((p) => [p.longitude, p.latitude, p.altitude]).toList(),
      },
    };

    return data.toString();
  }

  /// 导出为CSV格式
  String _exportToCsv(GpsRoute route) {
    final points = _routeRepo.parseRoutePoints(route);
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('timestamp,latitude,longitude,altitude,speed,accuracy');

    // 数据行
    for (final point in points) {
      buffer.writeln(
        '${point.timestamp.toIso8601String()},'
        '${point.latitude},'
        '${point.longitude},'
        '${point.altitude ?? ''},'
        '${point.speed ?? ''},'
        '${point.accuracy ?? ''}',
      );
    }

    return buffer.toString();
  }

  // ==================== 辅助方法 ====================

  String _getWorkoutTypeName(String type) {
    const names = {
      'running': '跑步',
      'cycling': '骑行',
      'swimming': '游泳',
      'walking': '步行',
      'hiking': '徒步',
      'climbing': '登山',
      'jumpRope': '跳绳',
      'hiit': 'HIIT',
      'basketball': '篮球',
      'football': '足球',
      'badminton': '羽毛球',
    };
    return names[type] ?? type;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
