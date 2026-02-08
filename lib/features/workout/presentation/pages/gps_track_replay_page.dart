/// GPS轨迹回放页面
/// 用于回放已保存的运动轨迹，支持速度控制和进度显示

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/gps/gps_tracking_service.dart';

/// GPS轨迹回放页面
class GpsTrackReplayPage extends StatefulWidget {
  final List<GpsPoint> trackPoints;
  final String workoutType;
  final double distance; // 米
  final Duration duration;
  final double calories;

  const GpsTrackReplayPage({
    super.key,
    required this.trackPoints,
    required this.workoutType,
    required this.distance,
    required this.duration,
    required this.calories,
  });

  @override
  State<GpsTrackReplayPage> createState() => _GpsTrackReplayPageState();
}

class _GpsTrackReplayPageState extends State<GpsTrackReplayPage> {
  // 回放控制
  bool _isPlaying = false;
  double _playbackSpeed = 1.0; // 回放速度倍数
  int _currentPointIndex = 0;
  Timer? _replayTimer;

  // 地图控制器
  final MapController _mapController = MapController();

  // 回放速度选项
  static const List<double> _playbackSpeeds = [0.5, 1.0, 2.0, 4.0, 8.0];

  @override
  void initState() {
    super.initState();
    // 延迟一点时间让地图初始化完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBounds();
    });
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// 调整地图视野以显示完整轨迹
  void _fitBounds() {
    if (widget.trackPoints.isEmpty) return;

    final latitudes = widget.trackPoints.map((p) => p.latitude).toList();
    final longitudes = widget.trackPoints.map((p) => p.longitude).toList();

    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLon = longitudes.reduce(math.min);
    final maxLon = longitudes.reduce(math.max);

    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  /// 开始/暂停回放
  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  /// 开始回放
  void _startPlayback() {
    if (_currentPointIndex >= widget.trackPoints.length) {
      _currentPointIndex = 0; // 从头开始
    }

    setState(() => _isPlaying = true);

    // 根据实际时间间隔进行回放
    if (widget.trackPoints.length > 1) {
      _scheduleNextFrame();
    }
  }

  /// 暂停回放
  void _pausePlayback() {
    _replayTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  /// 停止回放并重置
  void _stopPlayback() {
    _pausePlayback();
    setState(() => _currentPointIndex = 0);
  }

  /// 安排下一帧动画
  void _scheduleNextFrame() {
    if (_currentPointIndex >= widget.trackPoints.length - 1) {
      _pausePlayback();
      return;
    }

    final currentPoint = widget.trackPoints[_currentPointIndex];
    final nextPoint = widget.trackPoints[_currentPointIndex + 1];

    // 计算实际时间间隔
    final timeDiff = nextPoint.timestamp.difference(currentPoint.timestamp).inMilliseconds;
    final adjustedDelay = (timeDiff / _playbackSpeed).clamp(16, 1000).toInt();

    _replayTimer = Timer(Duration(milliseconds: adjustedDelay), () {
      if (mounted && _isPlaying) {
        setState(() {
          _currentPointIndex++;
        });
        _scheduleNextFrame();
      }
    });
  }

  /// 跳转到指定进度
  void _seekTo(double progress) {
    final targetIndex = (progress * (widget.trackPoints.length - 1)).round().clamp(0, widget.trackPoints.length - 1);
    setState(() => _currentPointIndex = targetIndex);

    // 移动地图到当前位置
    if (widget.trackPoints.isNotEmpty) {
      final point = widget.trackPoints[_currentPointIndex];
      _mapController.move(LatLng(point.latitude, point.longitude), 16.0);
    }
  }

  /// 切换回放速度
  void _changePlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.workoutType}轨迹回放'),
        actions: [
          // 速度选择
          _buildSpeedSelector(),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Column(
        children: [
          // 地图区域
          Expanded(
            child: _buildMap(),
          ),

          // 统计信息面板
          _buildStatsPanel(),

          // 回放控制面板
          _buildControlPanel(),
        ],
      ),
    );
  }

  /// 地图组件
  Widget _buildMap() {
    if (widget.trackPoints.isEmpty) {
      return const Center(
        child: Text('没有轨迹数据'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
              : [const Color(0xFFe8f5e9), const Color(0xFFc8e6c9)],
        ),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(
            widget.trackPoints.first.latitude,
            widget.trackPoints.first.longitude,
          ),
          initialZoom: 16.0,
          minZoom: 10.0,
          maxZoom: 19.0,
          backgroundColor: Colors.transparent,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // 完整轨迹（灰色半透明）
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.trackPoints
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList(),
              strokeWidth: 4.0,
              color: AppColors.textHint.withValues(alpha: 0.3),
            ),
          ],
        ),

        // 已回放的轨迹（彩色）
        if (_currentPointIndex > 0)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.trackPoints
                    .take(_currentPointIndex + 1)
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                strokeWidth: 5.0,
                color: AppColors.primary,
              ),
            ],
          ),

        // 起点标记
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                widget.trackPoints.first.latitude,
                widget.trackPoints.first.longitude,
              ),
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
          ],
        ),

        // 当前位置标记
        if (_currentPointIndex < widget.trackPoints.length)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  widget.trackPoints[_currentPointIndex].latitude,
                  widget.trackPoints[_currentPointIndex].longitude,
                ),
                width: 40,
                height: 40,
                child: _buildCurrentLocationMarker(),
              ),
            ],
          ),

        // 终点标记
        if (widget.trackPoints.length > 1)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  widget.trackPoints.last.latitude,
                  widget.trackPoints.last.longitude,
                ),
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
            ],
          ),
      ],
    );
  }

  /// 当前位置标记（带动画效果）
  Widget _buildCurrentLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 脉冲效果
        if (_isPlaying)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        // 中心点
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 统计信息面板
  Widget _buildStatsPanel() {
    final currentDistance = _currentPointIndex > 0
        ? _calculateTraversedDistance()
        : 0.0;
    final progress = widget.trackPoints.length > 1
        ? _currentPointIndex / (widget.trackPoints.length - 1)
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: AppColors.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.route_outlined,
            _formatDistance(currentDistance),
            '已行驶距离',
          ),
          _buildStatItem(
            Icons.timer_outlined,
            _formatDuration(_calculateElapsedTime()),
            '已用时间',
          ),
          _buildStatItem(
            Icons.percent,
            '${(progress * 100).toStringAsFixed(0)}%',
            '进度',
          ),
        ],
      ),
    );
  }

  /// 计算已行驶距离
  double _calculateTraversedDistance() {
    if (_currentPointIndex < 1) return 0.0;

    double distance = 0;
    for (int i = 1; i <= _currentPointIndex && i < widget.trackPoints.length; i++) {
      distance += widget.trackPoints[i - 1].distanceTo(widget.trackPoints[i]);
    }
    return distance;
  }

  /// 计算已用时间
  Duration _calculateElapsedTime() {
    if (_currentPointIndex < 1) return Duration.zero;
    if (_currentPointIndex >= widget.trackPoints.length) return widget.duration;

    final startTime = widget.trackPoints.first.timestamp;
    final currentTime = widget.trackPoints[_currentPointIndex].timestamp;
    return currentTime.difference(startTime);
  }

  /// 格式化距离
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}米';
    }
    return '${(meters / 1000).toStringAsFixed(2)}公里';
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 回放控制面板
  Widget _buildControlPanel() {
    final progress = widget.trackPoints.length > 1
        ? _currentPointIndex / (widget.trackPoints.length - 1)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.dividerColor,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  _seekTo(value);
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 停止按钮
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopPlayback,
                  tooltip: '停止',
                ),

                const SizedBox(width: AppSpacing.xl),

                // 播放/暂停按钮
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: _isPlaying
                          ? AppColors.warningGradient
                          : AppColors.successGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isPlaying
                                  ? AppColors.warning
                                  : AppColors.success)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xl),

                // 调整视野按钮
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  onPressed: _fitBounds,
                  tooltip: '调整视野',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 速度选择器
  Widget _buildSpeedSelector() {
    return PopupMenuButton<double>(
      initialValue: _playbackSpeed,
      onSelected: _changePlaybackSpeed,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_playbackSpeed}x',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        ],
      ),
      itemBuilder: (context) => _playbackSpeeds
          .map(
            (speed) => PopupMenuItem<double>(
              value: speed,
              child: Row(
                children: [
                  Text('${speed}x'),
                  const Spacer(),
                  if (speed == _playbackSpeed)
                    const Icon(Icons.check, color: AppColors.primary),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  /// 统计项组件
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
