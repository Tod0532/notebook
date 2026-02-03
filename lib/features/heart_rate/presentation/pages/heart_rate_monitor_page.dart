/// 心率监测页面 - 支持蓝牙设备连接和实时心率监测

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/heart_rate/presentation/providers/heart_rate_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/shared/widgets/empty_state_widget.dart';
import 'package:thick_notepad/shared/widgets/loading_widget.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/heart_rate/heart_rate_service.dart';

/// 心率监测页面
class HeartRateMonitorPage extends ConsumerStatefulWidget {
  const HeartRateMonitorPage({super.key});

  @override
  ConsumerState<HeartRateMonitorPage> createState() => _HeartRateMonitorPageState();
}

class _HeartRateMonitorPageState extends ConsumerState<HeartRateMonitorPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 初始化服务
    ref.listen(heartRateServiceInitProvider, (_, __) {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('心率监测'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '实时监测', icon: Icon(Icons.favorite)),
            Tab(text: '历史记录', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MonitorTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ==================== 实时监测标签页 ====================

class _MonitorTab extends ConsumerStatefulWidget {
  const _MonitorTab();

  @override
  ConsumerState<_MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends ConsumerState<_MonitorTab> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // 每秒更新一次会话时长显示
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(heartRateMonitorProvider);
    final deviceListState = ref.watch(deviceListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备连接区域
          _buildDeviceSection(deviceListState),
          const SizedBox(height: 20),

          // 心率显示区域
          _buildHeartRateSection(monitorState),
          const SizedBox(height: 20),

          // 统计信息区域
          if (monitorState.sessionId != null) ...[
            _buildStatsSection(monitorState),
            const SizedBox(height: 20),
          ],

          // 控制按钮区域
          _buildControlSection(monitorState),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(DeviceListState deviceListState) {
    final monitorState = ref.watch(heartRateMonitorProvider);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '设备连接',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (monitorState.serviceState == HeartRateServiceState.connected ||
                  monitorState.serviceState == HeartRateServiceState.monitoring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已连接',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withOpacity(0.1),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.textHint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '未连接',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 设备名称
          if (monitorState.serviceState == HeartRateServiceState.connected ||
              monitorState.serviceState == HeartRateServiceState.monitoring)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth, color: AppColors.primary),
              title: Text(
                monitorState.serviceState == HeartRateServiceState.monitoring
                    ? '正在监测心率...'
                    : '设备已就绪',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(ref
                      .read(heartRateServiceProvider)
                      .connectedDevice
                      ?.platformName ??
                  '未知设备'),
            ),

          // 扫描结果列表
          if (deviceListState.isScanning || deviceListState.devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '附近设备',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (deviceListState.isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: () => ref.read(deviceListProvider.notifier).startScan(),
                    child: const Text('重新扫描'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (deviceListState.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('未发现设备'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deviceListState.devices.length,
                itemBuilder: (context, index) {
                  final device = deviceListState.devices[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth_audio),
                    title: Text(
                      device.device.localName.isNotEmpty
                          ? device.device.localName
                          : device.device.advName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(device.device.remoteId.str),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(heartRateMonitorProvider.notifier)
                            .connect(device.device);
                      },
                      child: const Text('连接'),
                    ),
                  );
                },
              ),
          ] else if (monitorState.serviceState != HeartRateServiceState.connected &&
              monitorState.serviceState != HeartRateServiceState.monitoring)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '未连接设备',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textHint,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(deviceListProvider.notifier).startScan();
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('扫描设备'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeartRateSection(HeartRateMonitorState monitorState) {
    final isMonitoring = monitorState.serviceState == HeartRateServiceState.monitoring;
    final heartRate = monitorState.currentHeartRate ?? 0;

    return GradientCard.primary(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMonitoring ? '实时心率' : '心率',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isMonitoring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPulseIndicator(),
                      const SizedBox(width: 4),
                      Text(
                        '监测中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedScale(
            scale: isMonitoring ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 300),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  heartRate > 0 ? '$heartRate' : '--',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'BPM',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (monitorState.sessionId != null)
            Text(
              '时长: ${_formatDuration(monitorState.sessionDuration)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return SizedBox(
      width: 8,
      height: 8,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildStatsSection(HeartRateMonitorState monitorState) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本次监测统计',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: '平均心率',
                  value: '${monitorState.averageHeartRate}',
                  unit: 'BPM',
                  icon: Icons.show_chart,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: '最高心率',
                  value: '${monitorState.maxHeartRate}',
                  unit: 'BPM',
                  icon: Icons.arrow_upward,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: '最低心率',
                  value: '${monitorState.minHeartRate}',
                  unit: 'BPM',
                  icon: Icons.arrow_downward,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(HeartRateMonitorState monitorState) {
    final isMonitoring = monitorState.serviceState == HeartRateServiceState.monitoring;
    final isConnected = monitorState.serviceState == HeartRateServiceState.connected;

    return ModernCard(
      child: Column(
        children: [
          // 错误提示
          if (monitorState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      monitorState.errorMessage!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 开始监测按钮
          if (isConnected && !isMonitoring)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(heartRateMonitorProvider.notifier)
                        .startMonitoring();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('开始监测失败: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始监测'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.success,
                ),
              ),
            ),

          // 停止监测按钮
          if (isMonitoring)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(heartRateMonitorProvider.notifier).stopMonitoring();
                },
                icon: const Icon(Icons.stop),
                label: const Text('停止监测'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.error,
                ),
              ),
            ),

          // 断开连接按钮
          if (isConnected || isMonitoring)
            const SizedBox(height: 12),

          if (isConnected || isMonitoring)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(heartRateMonitorProvider.notifier).disconnect();
                },
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('断开连接'),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, ' ')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ==================== 历史记录标签页 ====================

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(heartRateSessionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(heartRateSessionsProvider);
      },
      child: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history,
              title: '暂无历史记录',
              message: '开始监测后，记录将显示在这里',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _buildSessionCard(context, ref, session);
            },
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, _) => Center(
          child: EmptyStateWidget(
            icon: Icons.error_outline,
            title: '加载失败',
            message: error.toString(),
            actionLabel: '重试',
            onAction: () => ref.invalidate(heartRateSessionsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, WidgetRef ref, HeartRateSession session) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;

    return ModernCard(
      onTap: () => _showSessionDetail(context, ref, session),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(session.startTime),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _buildStatusChip(session.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat(
                context,
                label: '平均',
                value: '${session.averageHeartRate ?? 0}',
                unit: 'bpm',
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                context,
                label: '最高',
                value: '${session.maxHeartRate ?? 0}',
                unit: 'bpm',
                color: AppColors.error,
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                context,
                label: '最低',
                value: '${session.minHeartRate ?? 0}',
                unit: 'bpm',
                color: AppColors.success,
              ),
              const Spacer(),
              _buildMiniStat(
                context,
                label: '时长',
                value: _formatDurationShort(duration),
                unit: '',
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (session.deviceName != null) ...[
            const SizedBox(height: 8),
            Text(
              '设备: ${session.deviceName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = '已完成';
        break;
      case 'active':
        color = AppColors.primary;
        label = '进行中';
        break;
      case 'cancelled':
        color = AppColors.textHint;
        label = '已取消';
        break;
      default:
        color = AppColors.textHint;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.smRadius,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value + unit,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDurationShort(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _showSessionDetail(BuildContext context, WidgetRef ref, HeartRateSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionDetailSheet(session: session),
    );
  }
}

// ==================== 会话详情底部表单 ====================

class _SessionDetailSheet extends ConsumerStatefulWidget {
  final HeartRateSession session;

  const _SessionDetailSheet({required this.session});

  @override
  ConsumerState<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(heartRateRecordsProvider(widget.session.sessionId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '监测详情',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          Expanded(
            child: detailsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.show_chart,
                    title: '暂无详细数据',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 统计卡片
                    _buildDetailStatsCard(),
                    const SizedBox(height: 16),
                    // 心率区间分布
                    _buildZoneDistributionCard(),
                    const SizedBox(height: 16),
                    // 心率记录列表
                    _buildRecordsList(records),
                  ],
                );
              },
              loading: () => const Center(child: LoadingWidget()),
              error: (error, _) => Center(
                child: EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: '加载失败',
                  message: error.toString(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatsCard() {
    final duration = widget.session.endTime != null
        ? widget.session.endTime!.difference(widget.session.startTime)
        : Duration.zero;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '监测统计',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('平均心率', '${widget.session.averageHeartRate ?? 0}', 'BPM'),
              _buildStatColumn('最高心率', '${widget.session.maxHeartRate ?? 0}', 'BPM'),
              _buildStatColumn('最低心率', '${widget.session.minHeartRate ?? 0}', 'BPM'),
              _buildStatColumn('监测时长', _formatDurationShort(duration), ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value + unit,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildZoneDistributionCard() {
    final zones = [
      ('热身区间', widget.session.zone1Duration, AppColors.info),
      ('燃脂区间', widget.session.zone2Duration, AppColors.success),
      ('有氧区间', widget.session.zone3Duration, AppColors.warning),
      ('无氧区间', widget.session.zone4Duration, const Color(0xFFFB923C)),
      ('极限区间', widget.session.zone5Duration, AppColors.error),
    ];

    final totalDuration = zones.fold<int>(
      0,
      (sum, zone) => sum + (zone.$2 ?? 0),
    );

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '心率区间分布',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...zones.map((zone) {
            final duration = zone.$2 ?? 0;
            final percentage = totalDuration > 0 ? (duration / totalDuration * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        zone.$1,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_formatDurationShort(Duration(seconds: duration))} (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: zone.$3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadius.smRadius,
                    child: LinearProgressIndicator(
                      value: totalDuration > 0 ? duration / totalDuration : 0,
                      backgroundColor: AppColors.dividerColor.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(zone.$3),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecordsList(List<HeartRateRecord> records) {
    // 取最近50条记录
    final displayRecords = records.take(50).toList();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '心率记录 (最近50条)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...displayRecords.map((record) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatRecordTime(record.timestamp),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${record.heartRate}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'BPM',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatRecordTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDurationShort(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
