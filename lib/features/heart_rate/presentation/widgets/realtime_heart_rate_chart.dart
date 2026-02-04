/// 实时心率曲线图组件
/// 使用 fl_chart 显示实时心率变化，每秒更新一次数据点
/// 显示最近60秒的数据，并标注当前所在区间

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/heart_rate/data/repositories/heart_rate_repository.dart';
import 'package:thick_notepad/features/heart_rate/presentation/providers/heart_rate_providers.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 实时心率曲线图
class RealtimeHeartRateChart extends ConsumerStatefulWidget {
  final String sessionId;
  final int durationSeconds; // 显示时长（秒），默认60秒
  final bool showZoneLabels; // 是否显示区间标签

  const RealtimeHeartRateChart({
    super.key,
    required this.sessionId,
    this.durationSeconds = 60,
    this.showZoneLabels = true,
  });

  @override
  ConsumerState<RealtimeHeartRateChart> createState() => _RealtimeHeartRateChartState();
}

class _RealtimeHeartRateChartState extends ConsumerState<RealtimeHeartRateChart>
    with SingleTickerProviderStateMixin {
  // 数据点列表
  List<HeartRateDataPoint> _dataPoints = [];

  // 动画控制器
  late AnimationController _animationController;

  // 定时器
  Timer? _updateTimer;

  // 当前心率区间
  String? _currentZone;

  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadInitialData();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 加载初始数据
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final repo = HeartRateRepository(db);
      final zoneConfig = await repo.getZoneConfig();

      final points = await repo.getRecentRecords(
        sessionId: widget.sessionId,
        seconds: widget.durationSeconds,
        zoneConfig: zoneConfig,
      );

      if (mounted) {
        setState(() {
          _dataPoints = points;
          if (points.isNotEmpty) {
            _currentZone = points.last.zone;
          }
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('加载心率数据失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 启动定时更新
  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateData();
    });
  }

  /// 更新数据
  Future<void> _updateData() async {
    try {
      final db = ref.read(databaseProvider);
      final repo = HeartRateRepository(db);
      final zoneConfig = await repo.getZoneConfig();

      final points = await repo.getRecentRecords(
        sessionId: widget.sessionId,
        seconds: widget.durationSeconds,
        zoneConfig: zoneConfig,
      );

      if (mounted && points != _dataPoints) {
        setState(() {
          _dataPoints = points;
          if (points.isNotEmpty) {
            _currentZone = points.last.zone;
          }
        });
      }
    } catch (e) {
      debugPrint('更新心率数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_dataPoints.isEmpty) {
      return _buildEmptyWidget();
    }

    return Column(
      children: [
        // 图表主体
        AspectRatio(
          aspectRatio: 2.5,
          child: _buildChart(),
        ),
        // 当前区间指示器
        if (widget.showZoneLabels && _currentZone != null)
          _buildZoneIndicator(),
      ],
    );
  }

  /// 构建图表
  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateYInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.dividerColor.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateXInterval(),
              getTitlesWidget: (value, meta) {
                final seconds = value.toInt();
                if (seconds % 10 != 0) return const Text('');
                return Text(
                  '-${widget.durationSeconds - seconds}s',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateYInterval(),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.round().toString(),
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: AppColors.dividerColor.withOpacity(0.5),
          ),
        ),
        minX: 0,
        maxX: widget.durationSeconds.toDouble(),
        minY: _calculateMinY(),
        maxY: _calculateMaxY(),
        lineBarsData: [_buildLineBarData()],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                AppColors.surfaceDark.withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final point = _dataPoints[spot.x.toInt()];
                return LineTooltipItem(
                  '${point.heartRate} BPM',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// 构建线条数据
  LineChartBarData _buildLineBarData() {
    if (_dataPoints.isEmpty) {
      return LineChartBarData();
    }

    // 计算时间偏移，使数据点相对于当前时间
    final now = DateTime.now();
    final oldestTime = now.subtract(Duration(seconds: widget.durationSeconds));

    // 生成 FlSpot 列表
    final spots = <FlSpot>[];
    for (int i = 0; i < _dataPoints.length; i++) {
      final point = _dataPoints[i];
      // 计算该点距离最旧时间的秒数
      final secondsFromOldest = point.timestamp.difference(oldestTime).inSeconds;
      if (secondsFromOldest >= 0 && secondsFromOldest <= widget.durationSeconds) {
        spots.add(FlSpot(
          secondsFromOldest.toDouble(),
          point.heartRate.toDouble(),
        ));
      }
    }

    // 根据当前区间确定颜色
    final lineColor = _getZoneColor(_currentZone);

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: lineColor,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: lineColor,
            strokeWidth: 2,
            strokeColor: AppColors.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: lineColor.withOpacity(0.1),
      ),
    );
  }

  /// 构建当前区间指示器
  Widget _buildZoneIndicator() {
    final zoneInfo = _getZoneInfo(_currentZone);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            zoneInfo.color.withOpacity(0.2),
            zoneInfo.color.withOpacity(0.05),
          ],
        ),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: zoneInfo.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            zoneInfo.icon,
            color: zoneInfo.color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${zoneInfo.name}区间',
            style: TextStyle(
              color: zoneInfo.color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: zoneInfo.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载中组件
  Widget _buildLoadingWidget() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '加载心率数据...',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空数据组件
  Widget _buildEmptyWidget() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              '等待心率数据...',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 计算Y轴最小值
  double _calculateMinY() {
    if (_dataPoints.isEmpty) return 40;
    final minHeartRate = _dataPoints.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b);
    return (minHeartRate - 10).clamp(40, 220).toDouble();
  }

  /// 计算Y轴最大值
  double _calculateMaxY() {
    if (_dataPoints.isEmpty) return 180;
    final maxHeartRate = _dataPoints.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b);
    return (maxHeartRate + 10).clamp(60, 220).toDouble();
  }

  /// 计算Y轴间隔
  double _calculateYInterval() {
    final minY = _calculateMinY();
    final maxY = _calculateMaxY();
    final range = maxY - minY;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    return 30;
  }

  /// 计算X轴间隔
  double _calculateXInterval() {
    return widget.durationSeconds <= 60 ? 10 : 20;
  }

  /// 获取区间颜色
  Color _getZoneColor(String? zone) {
    switch (zone) {
      case 'zone1':
        return AppColors.info;
      case 'zone2':
        return AppColors.success;
      case 'zone3':
        return AppColors.warning;
      case 'zone4':
        return const Color(0xFFFB923C);
      case 'zone5':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  /// 获取区间信息
  _ZoneInfo _getZoneInfo(String? zone) {
    switch (zone) {
      case 'zone1':
        return _ZoneInfo(
          name: '热身',
          color: AppColors.info,
          icon: Icons.wb_sunny_outlined,
        );
      case 'zone2':
        return _ZoneInfo(
          name: '燃脂',
          color: AppColors.success,
          icon: Icons.local_fire_department_outlined,
        );
      case 'zone3':
        return _ZoneInfo(
          name: '有氧',
          color: AppColors.warning,
          icon: Icons.directions_run,
        );
      case 'zone4':
        return _ZoneInfo(
          name: '无氧',
          color: const Color(0xFFFB923C),
          icon: Icons.fitness_center,
        );
      case 'zone5':
        return _ZoneInfo(
          name: '极限',
          color: AppColors.error,
          icon: Icons.bolt,
        );
      default:
        return _ZoneInfo(
          name: '未知',
          color: AppColors.textHint,
          icon: Icons.help_outline,
        );
    }
  }
}

/// 区间信息
class _ZoneInfo {
  final String name;
  final Color color;
  final IconData icon;

  const _ZoneInfo({
    required this.name,
    required this.color,
    required this.icon,
  });
}

// ==================== 迷你心率图表 ====================

/// 迷你心率图表 - 用于小卡片显示
class MiniHeartRateChart extends ConsumerWidget {
  final String sessionId;
  final int durationSeconds;
  final Color? accentColor;

  const MiniHeartRateChart({
    super.key,
    required this.sessionId,
    this.durationSeconds = 30,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(heartRateRecordsProvider(sessionId));

    return dataAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return _buildEmptyWidget();
        }

        // 取最近的数据点
        final now = DateTime.now();
        final oldestTime = now.subtract(Duration(seconds: durationSeconds));
        final recentRecords = records.where((r) {
          return r.timestamp.isAfter(oldestTime);
        }).toList();

        if (recentRecords.isEmpty) {
          return _buildEmptyWidget();
        }

        final spots = recentRecords.asMap().entries.map((entry) {
          return FlSpot(
            entry.key.toDouble(),
            entry.value.heartRate.toDouble(),
          );
        }).toList();

        final color = accentColor ?? AppColors.primary;

        return AspectRatio(
          aspectRatio: 3,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                show: false,
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: _calculateMinY(recentRecords),
              maxY: _calculateMaxY(recentRecords),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _buildEmptyWidget(),
    );
  }

  Widget _buildEmptyWidget() {
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: AppColors.textHint,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  double _calculateMinY(List<HeartRateRecord> records) {
    final minHR = records.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b);
    return (minHR - 5).clamp(40, 220).toDouble();
  }

  double _calculateMaxY(List<HeartRateRecord> records) {
    final maxHR = records.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b);
    return (maxHR + 5).clamp(60, 220).toDouble();
  }
}
