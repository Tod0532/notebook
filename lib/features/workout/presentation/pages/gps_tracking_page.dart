/// GPS追踪页面 - 显示地图和运动轨迹
/// 支持：实时追踪、轨迹绘制、统计数据显示、暂停/继续/结束

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  GpsStatistics _statistics = const GpsStatistics(
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
                Icons.speed_outlined,
                _statistics.speedText,
                '速度',
              ),
              if (_statistics.paceText != null)
                _buildStatItem(
                  Icons.timer_outlined,
                  _statistics.paceText!,
                  '配速',
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

  /// 地图占位符（后续可替换为真实地图）
  Widget _buildMapPlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: _trackPoints.isEmpty
            ? Column(
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
              )
            : _buildTrackVisualization(),
      ),
    );
  }

  /// 简单的轨迹可视化（CustomPaint绘制）
  Widget _buildTrackVisualization() {
    if (_trackPoints.isEmpty) return const SizedBox();

    // 计算边界
    final minLat = _trackPoints.map((p) => p.latitude).reduce(math.min);
    final maxLat = _trackPoints.map((p) => p.latitude).reduce(math.max);
    final minLon = _trackPoints.map((p) => p.longitude).reduce(math.min);
    final maxLon = _trackPoints.map((p) => p.longitude).reduce(math.max);

    return CustomPaint(
      size: Size.infinite,
      painter: TrackPainter(
        points: _trackPoints,
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      ),
    );
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

/// 轨迹绘制器
class TrackPainter extends CustomPainter {
  final List<GpsPoint> points;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  TrackPainter({
    required this.points,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = _normalizeX(point.longitude, size.width);
      final y = _normalizeY(point.latitude, size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制起点标记
    if (points.isNotEmpty) {
      _drawMarker(canvas, points.first, size, AppColors.success);
    }
    // 绘制终点标记
    if (points.length > 1) {
      _drawMarker(canvas, points.last, size, AppColors.error);
    }
  }

  void _drawMarker(Canvas canvas, GpsPoint point, Size size, Color color) {
    final x = _normalizeX(point.longitude, size.width);
    final y = _normalizeY(point.latitude, size.height);

    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 12, markerPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 8, whitePaint);
  }

  double _normalizeX(double longitude, double width) {
    final range = maxLon - minLon;
    if (range == 0) return width / 2;
    final padding = width * 0.1;
    final availableWidth = width - 2 * padding;
    return padding + ((longitude - minLon) / range) * availableWidth;
  }

  double _normalizeY(double latitude, double height) {
    final range = maxLat - minLat;
    if (range == 0) return height / 2;
    final padding = height * 0.1;
    final availableHeight = height - 2 * padding;
    return height - padding - ((latitude - minLat) / range) * availableHeight;
  }

  @override
  bool shouldRepaint(covariant TrackPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
