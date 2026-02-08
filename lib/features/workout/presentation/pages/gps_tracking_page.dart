/// GPS追踪页面 - 显示地图和运动轨迹
/// 支持：实时追踪、轨迹绘制、统计数据显示、暂停/继续/结束

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/gps/gps_tracking_service.dart';

/// GPS追踪状态数据
class TrackingData {
  final GpsTrackingStatus status;
  final GpsStatistics statistics;
  final List<GpsPoint> trackPoints;

  TrackingData({
    required this.status,
    required this.statistics,
    required this.trackPoints,
  });
}

/// GPS追踪页面
class GpsTrackingPage extends ConsumerStatefulWidget {
  final String workoutType; // 运动类型（跑步、骑行等）
  final int? workoutId; // 如果是编辑已有运动，传入ID

  const GpsTrackingPage({
    super.key,
    required this.workoutType,
    this.workoutId,
  });

  @override
  ConsumerState<GpsTrackingPage> createState() => _GpsTrackingPageState();
}

class _GpsTrackingPageState extends ConsumerState<GpsTrackingPage> {
  // GPS服务
  final _gpsService = GpsTrackingService.instance;

  // 状态订阅
  StreamSubscription? _statusSubscription;
  StreamSubscription? _trackSubscription;
  StreamSubscription? _statisticsSubscription;

  // 当前状态
  GpsTrackingStatus _status = GpsTrackingStatus.idle;
  GpsStatistics _statistics = GpsStatistics(
    distance: 0,
    duration: Duration.zero,
    averageSpeed: 0,
    maxSpeed: 0,
  );
  List<GpsPoint> _trackPoints = [];

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _trackSubscription?.cancel();
    _statisticsSubscription?.cancel();
    super.dispose();
  }

  /// 初始化追踪
  Future<void> _initializeTracking() async {
    // 设置运动类型
    _gpsService.setWorkoutType(_getWorkoutTypeKey(widget.workoutType));

    // 订阅状态变化
    _statusSubscription = _gpsService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });

    // 订阅轨迹更新
    _trackSubscription = _gpsService.trackStream.listen((points) {
      if (mounted) {
        setState(() => _trackPoints = points);
      }
    });

    // 订阅统计更新
    _statisticsSubscription = _gpsService.statisticsStream.listen((stats) {
      if (mounted) {
        setState(() => _statistics = stats);
      }
    });

    // 自动开始追踪
    await Future.delayed(const Duration(milliseconds: 500));
    await _startTracking();
  }

  /// 获取运动类型对应的键值
  String _getWorkoutTypeKey(String displayName) {
    final typeMap = {
      '跑步': 'running',
      '骑行': 'cycling',
      '游泳': 'swimming',
      '步行': 'walking',
      '徒步': 'hiking',
      '登山': 'climbing',
      '跳绳': 'jumpRope',
      'HIIT': 'hiit',
      '篮球': 'basketball',
      '足球': 'football',
      '羽毛球': 'badminton',
    };
    return typeMap[displayName] ?? 'other';
  }

  /// 开始追踪
  Future<void> _startTracking() async {
    final success = await _gpsService.startTracking();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法开始GPS追踪，请检查位置权限'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 暂停/继续追踪
  void _togglePause() {
    if (_status == GpsTrackingStatus.tracking) {
      _gpsService.pauseTracking();
    } else if (_status == GpsTrackingStatus.paused) {
      _gpsService.resumeTracking();
    }
  }

  /// 停止追踪并保存
  void _stopTracking() {
    _gpsService.stopTracking();
    _showSaveDialog();
  }

  /// 显示保存对话框
  void _showSaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('保存运动记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('距离', _statistics.distanceText),
            const SizedBox(height: 8),
            _buildSummaryRow('时长', _statistics.durationText),
            const SizedBox(height: 8),
            if (_statistics.paceText != null)
              _buildSummaryRow('配速', _statistics.paceText!),
            const SizedBox(height: 8),
            _buildSummaryRow('平均速度', _statistics.speedText),
            const SizedBox(height: 8),
            _buildSummaryRow('消耗卡路里', _statistics.caloriesText),
            const SizedBox(height: 8),
            if (_statistics.elevationGain != null && _statistics.elevationGain! > 0)
              _buildSummaryRow('累计爬升', _statistics.elevationText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gpsService.clearTracking();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveAndReturn();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// 保存并返回
  void _saveAndReturn() {
    final result = {
      'distance': _statistics.distance,
      'duration': _statistics.duration.inSeconds,
      'calories': _statistics.calories,
      'elevationGain': _statistics.elevationGain,
      'averageSpeed': _statistics.averageSpeed,
      'maxSpeed': _statistics.maxSpeed,
      'trackPoints': _trackPoints.map((p) => p.toJson()).toList(),
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status == GpsTrackingStatus.idle,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _status == GpsTrackingStatus.tracking) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 地图视图
            _buildMapPlaceholder(),

            // 顶部状态栏
            _buildTopBar(),

            // 底部控制面板
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  /// 顶部状态栏
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // 运动类型标题
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (_status == GpsTrackingStatus.tracking ||
                        _status == GpsTrackingStatus.paused) {
                      _showExitConfirmation();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    widget.workoutType,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // 平衡关闭按钮
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // GPS状态指示
            _buildGpsStatusIndicator(),
          ],
        ),
      ),
    );
  }

  /// GPS状态指示器
  Widget _buildGpsStatusIndicator() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_status) {
      case GpsTrackingStatus.idle:
        statusColor = AppColors.textHint;
        statusText = '未开始';
        statusIcon = Icons.location_off;
        break;
      case GpsTrackingStatus.starting:
        statusColor = AppColors.warning;
        statusText = '获取GPS中...';
        statusIcon = Icons.gps_fixed;
        break;
      case GpsTrackingStatus.tracking:
        statusColor = AppColors.success;
        statusText = 'GPS信号良好';
        statusIcon = Icons.gps_fixed;
        break;
      case GpsTrackingStatus.paused:
        statusColor = AppColors.warning;
        statusText = '已暂停';
        statusIcon = Icons.pause;
        break;
      case GpsTrackingStatus.stopped:
        statusColor = AppColors.textHint;
        statusText = '已结束';
        statusIcon = Icons.stop;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 底部控制面板
  Widget _buildBottomPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 统计数据
        _buildStatisticsPanel(),

        const SizedBox(height: AppSpacing.md),

        // 控制按钮
        _buildControls(),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// 统计数据面板
  Widget _buildStatisticsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.medium,
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
                _statistics.distance < 1000
                    ? _statistics.distance.toStringAsFixed(0)
                    : (_statistics.distance / 1000).toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _statistics.distance < 1000 ? '米' : '公里',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
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
                _statistics.durationText,
                '时长',
              ),
              _buildStatItem(
                Icons.local_fire_department_outlined,
                _statistics.caloriesText,
                '卡路里',
              ),
              _buildStatItem(
                Icons.speed_outlined,
                _statistics.speedText,
                '速度',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  /// 控制按钮区域
  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 锁定按钮（保持屏幕常亮）
        _buildControlButton(
          icon: Icons.screen_lock_portrait,
          label: '常亮',
          onTap: () {
            // TODO: 实现屏幕常亮
            HapticFeedback.lightImpact();
          },
        ),

        const SizedBox(width: AppSpacing.xl),

        // 主控制按钮 - 暂停/结束
        _buildMainControlButton(),

        const SizedBox(width: AppSpacing.xl),

        // 地图按钮（切换地图样式）
        _buildControlButton(
          icon: Icons.map_outlined,
          label: '地图',
          onTap: () {
            // TODO: 切换地图样式
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }

  /// 主控制按钮
  Widget _buildMainControlButton() {
    if (_status == GpsTrackingStatus.idle ||
        _status == GpsTrackingStatus.starting) {
      return _buildLargeButton(
        icon: Icons.play_arrow,
        label: '开始',
        gradient: AppColors.successGradient,
        onTap: _startTracking,
      );
    }

    if (_status == GpsTrackingStatus.paused) {
      return Row(
        children: [
          _buildLargeButton(
            icon: Icons.stop,
            label: '结束',
            gradient: AppColors.errorGradient,
            onTap: _stopTracking,
          ),
          const SizedBox(width: AppSpacing.md),
          _buildLargeButton(
            icon: Icons.play_arrow,
            label: '继续',
            gradient: AppColors.successGradient,
            onTap: _togglePause,
          ),
        ],
      );
    }

    // 追踪中
    return _buildLargeButton(
      icon: Icons.pause,
      label: '暂停',
      gradient: AppColors.warningGradient,
      onTap: _togglePause,
    );
  }

  Widget _buildLargeButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: AppColors.dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 地图视图 - 使用flutter_map
  Widget _buildMapPlaceholder() {
    // 如果没有轨迹点，显示等待界面
    if (_trackPoints.isEmpty) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 80,
                color: AppColors.textHint.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _status == GpsTrackingStatus.starting
                    ? '正在获取GPS信号...'
                    : '等待开始追踪...',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 16,
                ),
              ),
              if (_status == GpsTrackingStatus.starting)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      );
    }

    // 使用flutter_map显示轨迹（无瓦片模式）
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
        options: MapOptions(
          initialCenter: _calculateCenter(),
          initialZoom: _calculateInitialZoom(),
          minZoom: 10.0,
          maxZoom: 19.0,
          backgroundColor: Colors.transparent,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // 轨迹线图层
          PolylineLayer(
            polylines: [
              Polyline(
                points: _convertToLatLngPoints(),
                strokeWidth: 4.0,
                color: AppColors.primary,
                pattern: const StrokePattern.solid(),
              ),
            ],
          ),

          // 起点和终点标记
          MarkerLayer(
            markers: _buildMarkers(),
          ),

          // 当前位置标记（如果正在追踪）
          if (_status == GpsTrackingStatus.tracking && _trackPoints.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                    _trackPoints.last.latitude,
                    _trackPoints.last.longitude,
                  ),
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
              ],
            ),
        ],
      ),
    );
  }

  /// 计算地图中心点
  LatLng _calculateCenter() {
    if (_trackPoints.isEmpty) {
      return const LatLng(39.9042, 116.4074); // 默认北京
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
    // 单点时显示周围区域，不要缩放太近
    if (_trackPoints.length < 2) return 15.0;

    final latitudes = _trackPoints.map((p) => p.latitude).toList();
    final longitudes = _trackPoints.map((p) => p.longitude).toList();

    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLon = longitudes.reduce(math.min);
    final maxLon = longitudes.reduce(math.max);

    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = math.max(latDiff, lonDiff);

    // 根据轨迹范围计算缩放级别
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

  /// 构建起点和终点标记
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 起点标记
    if (_trackPoints.isNotEmpty) {
      markers.add(
        Marker(
          point: LatLng(
            _trackPoints.first.latitude,
            _trackPoints.first.longitude,
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
      );
    }

    // 终点标记（如果有多个点）
    if (_trackPoints.length > 1) {
      markers.add(
        Marker(
          point: LatLng(
            _trackPoints.last.latitude,
            _trackPoints.last.longitude,
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
      );
    }

    return markers;
  }

  /// 显示退出确认对话框
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出将丢失当前追踪数据，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('继续运动'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gpsService.clearTracking();
              Navigator.of(context).pop();
            },
            child: const Text(
              '确认退出',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
