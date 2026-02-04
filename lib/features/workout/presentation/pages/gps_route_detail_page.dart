/// GPS路线详情页 - 显示已保存的运动轨迹
/// 支持：轨迹回放、统计数据展示、地图查看

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/gps/gps_tracking_service.dart' show GpsPoint;
import 'package:thick_notepad/services/gps/gps_route_repository.dart' as repo;

/// GPS路线详情页
class GpsRouteDetailPage extends ConsumerStatefulWidget {
  final int routeId; // 路线ID
  final int? workoutId; // 关联的运动ID（可选）

  const GpsRouteDetailPage({
    super.key,
    required this.routeId,
    this.workoutId,
  });

  @override
  ConsumerState<GpsRouteDetailPage> createState() => _GpsRouteDetailPageState();
}

class _GpsRouteDetailPageState extends ConsumerState<GpsRouteDetailPage> {
  final repo.GpsRouteRepository _routeRepo = repo.GpsRouteRepository.instance;

  GpsRoute? _route;
  List<GpsPoint> _trackPoints = [];
  bool _isLoading = true;
  bool _isReplaying = false;
  int _currentPointIndex = 0;
  Timer? _replayTimer;

  // 地图控制器
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// 加载路线数据
  Future<void> _loadRoute() async {
    setState(() => _isLoading = true);

    try {
      // 根据提供的ID查询路线
      GpsRoute? route;
      if (widget.workoutId != null) {
        route = await _routeRepo.getRouteByWorkoutId(widget.workoutId!);
      }
      route ??= await _routeRepo.getRouteById(widget.routeId);

      if (route != null) {
        final points = _routeRepo.parseRoutePoints(route);
        setState(() {
          _route = route;
          _trackPoints = points;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('加载路线失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 开始回放
  void _startReplay() {
    if (_trackPoints.isEmpty) return;

    setState(() {
      _isReplaying = true;
      _currentPointIndex = 0;
    });

    // 每秒显示一定数量的点（根据总点数调整速度）
    final pointsPerSecond = _trackPoints.length > 100 ? 10 : 5;
    final interval = 1000 ~/ pointsPerSecond;

    _replayTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (_currentPointIndex < _trackPoints.length - 1) {
        setState(() => _currentPointIndex++);
        // 移动地图到当前点
        final currentPoint = _trackPoints[_currentPointIndex];
        _mapController.move(
          LatLng(currentPoint.latitude, currentPoint.longitude),
          17.0,
        );
      } else {
        _stopReplay();
      }
    });
  }

  /// 停止回放
  void _stopReplay() {
    _replayTimer?.cancel();
    setState(() => _isReplaying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('加载中...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_route == null || _trackPoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('路线详情'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: AppColors.textHint),
              SizedBox(height: 16),
              Text(
                '没有找到轨迹数据',
                style: TextStyle(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 地图
          _buildMap(),

          // 顶部信息栏
          _buildTopBar(),

          // 底部统计面板
          _buildBottomPanel(),

          // 回放控制
          if (_isReplaying) _buildReplayControls(),
        ],
      ),
    );
  }

  /// 顶部信息栏
  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Column(
                  children: [
                    Text(
                      _getWorkoutTypeName(_route!.workoutType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatDate(_route!.startTime),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_isReplaying)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                onPressed: _startReplay,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                tooltip: '回放',
              ),
          ],
        ),
      ),
    );
  }

  /// 底部统计面板
  Widget _buildBottomPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 统计数据卡片
        Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.xlRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 主数据 - 距离
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatDistance(_route!.distance ?? 0),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '总距离',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // 次要数据
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.timer_outlined,
                    _formatDuration(_route!.duration ?? 0),
                    '时长',
                  ),
                  _buildStatItem(
                    Icons.speed_outlined,
                    _formatSpeed(_route!.averageSpeed ?? 0),
                    '平均速度',
                  ),
                  if (_route!.calories != null && _route!.calories! > 0)
                    _buildStatItem(
                      Icons.local_fire_department_outlined,
                      '${_route!.calories!.toStringAsFixed(0)}千卡',
                      '消耗',
                    ),
                ],
              ),

              // 更多统计信息（可展开）
              if (_route!.elevationGain != null && _route!.elevationGain! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                        Icons.arrow_upward,
                        '+${_route!.elevationGain!.toStringAsFixed(0)}米',
                        '爬升',
                      ),
                      _buildMiniStat(
                        Icons.arrow_downward,
                        '${_route!.elevationLoss?.toStringAsFixed(0) ?? '0'}米',
                        '下降',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// 回放控制
  Widget _buildReplayControls() {
    final progress = _currentPointIndex / _trackPoints.length;

    return Positioned(
      bottom: 200,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdRadius,
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text('回放进度'),
                const Spacer(),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopReplay,
                  color: AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 地图视图
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _calculateCenter(),
        initialZoom: _calculateInitialZoom(),
        minZoom: 10.0,
        maxZoom: 19.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // OpenStreetMap 图层
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.thick_notepad',
        ),

        // 完整轨迹线（半透明）
        PolylineLayer(
          polylines: [
            Polyline(
              points: _convertToLatLngPoints(),
              strokeWidth: 4.0,
              color: AppColors.primary.withValues(alpha: 0.3),
              pattern: const StrokePattern.solid(),
            ),
          ],
        ),

        // 已走过的轨迹线（回放时）
        if (_isReplaying && _currentPointIndex > 0)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _convertToLatLngPoints().sublist(0, _currentPointIndex + 1),
                strokeWidth: 5.0,
                color: AppColors.primary,
                pattern: const StrokePattern.solid(),
              ),
            ],
          ),

        // 标记
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  /// 计算地图中心点
  LatLng _calculateCenter() {
    if (_trackPoints.isEmpty) {
      return const LatLng(39.9042, 116.4074);
    }

    final latSum = _trackPoints.map((p) => p.latitude).reduce((a, b) => a + b);
    final lonSum = _trackPoints.map((p) => p.longitude).reduce((a, b) => a + b);

    return LatLng(
      latSum / _trackPoints.length,
      lonSum / _trackPoints.length,
    );
  }

  /// 计算初始缩放级别
  double _calculateInitialZoom() {
    if (_trackPoints.length < 2) return 17.0;

    final latitudes = _trackPoints.map((p) => p.latitude).toList();
    final longitudes = _trackPoints.map((p) => p.longitude).toList();

    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLon = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLon = longitudes.reduce((a, b) => a > b ? a : b);

    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.001) return 18.0;
    if (maxDiff < 0.005) return 16.0;
    if (maxDiff < 0.01) return 15.0;
    if (maxDiff < 0.05) return 13.0;
    if (maxDiff < 0.1) return 12.0;
    return 11.0;
  }

  /// 转换GPS点为LatLng列表
  List<LatLng> _convertToLatLngPoints() {
    return _trackPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  /// 构建标记
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_trackPoints.isEmpty) return markers;

    // 起点标记
    markers.add(
      Marker(
        point: LatLng(_trackPoints.first.latitude, _trackPoints.first.longitude),
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );

    // 终点标记
    markers.add(
      Marker(
        point: LatLng(_trackPoints.last.latitude, _trackPoints.last.longitude),
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.flag,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );

    // 回放时的当前位置标记
    if (_isReplaying && _currentPointIndex < _trackPoints.length) {
      final currentPoint = _trackPoints[_currentPointIndex];
      markers.add(
        Marker(
          point: LatLng(currentPoint.latitude, currentPoint.longitude),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ==================== 格式化方法 ====================

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
    return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}米';
    }
    return '${(meters / 1000).toStringAsFixed(2)}公里';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatSpeed(double mps) {
    return '${(mps * 3.6).toStringAsFixed(1)} km/h';
  }
}

// ==================== GPS点定义（与追踪服务共享） ====================
// 使用 GpsRouteRepository 中定义的 GpsPoint
