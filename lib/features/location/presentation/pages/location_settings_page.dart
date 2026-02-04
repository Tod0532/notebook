/// 位置设置页面
/// 配置位置权限、后台定位、电池优化等选项

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/location/presentation/providers/location_providers.dart';
import 'package:thick_notepad/services/location/background_location_service.dart';

/// 位置设置页面
class LocationSettingsPage extends ConsumerStatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  ConsumerState<LocationSettingsPage> createState() => _LocationSettingsPageState();
}

class _LocationSettingsPageState extends ConsumerState<LocationSettingsPage> {
  bool _isLoadingPermissions = true;
  bool _hasLocationPermission = false;
  bool _hasBackgroundPermission = false;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
    });

    // 检查位置权限
    final locationStatus = await Permission.locationWhenInUse.status;
    final backgroundStatus = await Permission.locationAlways.status;

    // 检查电池优化
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _hasLocationPermission = locationStatus.isGranted;
      _hasBackgroundPermission = backgroundStatus.isGranted;
      _batteryOptimizationIgnored = batteryStatus.isGranted;
      _isLoadingPermissions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitoringState = ref.watch(geofenceMonitoringProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('位置设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 权限状态卡片
          _buildPermissionCard(),
          const SizedBox(height: 24),

          // 监控控制
          _buildMonitoringCard(monitoringState),
          const SizedBox(height: 24),

          // 后台位置配置
          _buildBackgroundLocationCard(),
          const SizedBox(height: 24),

          // 使用说明
          _buildUsageGuideCard(),
          const SizedBox(height: 24),

          // 围栏管理入口
          _buildGeofenceManagementCard(),
        ],
      ),
    );
  }

  /// 构建权限状态卡片
  Widget _buildPermissionCard() {
    return _SettingsSection(
      title: '权限状态',
      children: [
        if (_isLoadingPermissions)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          _PermissionTile(
            icon: Icons.location_on,
            title: '位置权限',
            subtitle: '用于获取当前位置',
            isGranted: _hasLocationPermission,
            onTap: _requestLocationPermission,
          ),
          const Divider(height: 1),
          _PermissionTile(
            icon: Icons.all_inclusive,
            title: '后台位置权限',
            subtitle: '用于在后台监控位置变化',
            isGranted: _hasBackgroundPermission,
            onTap: _requestBackgroundPermission,
          ),
          const Divider(height: 1),
          _PermissionTile(
            icon: Icons.battery_alert,
            title: '忽略电池优化',
            subtitle: '保持后台服务运行',
            isGranted: _batteryOptimizationIgnored,
            onTap: _requestIgnoreBatteryOptimization,
          ),
        ],
      ],
    );
  }

  /// 构建监控控制卡片
  Widget _buildMonitoringCard(GeofenceMonitoringState monitoringState) {
    return _SettingsSection(
      title: '监控控制',
      children: [
        SwitchListTile(
          value: monitoringState.isMonitoring,
          onChanged: _toggleMonitoring,
          title: const Text('位置监控'),
          subtitle: Text(
            monitoringState.isMonitoring ? '监控中' : '已停止',
          ),
          secondary: Icon(
            monitoringState.isMonitoring
                ? Icons.location_on
                : Icons.location_off,
            color: monitoringState.isMonitoring
                ? AppColors.success
                : AppColors.textSecondary,
          ),
        ),
        if (monitoringState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdRadius,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      monitoringState.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 构建后台位置配置卡片
  Widget _buildBackgroundLocationCard() {
    return _SettingsSection(
      title: '后台位置配置',
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('更新策略'),
          subtitle: const Text('平衡精度和电池消耗'),
          trailing: DropdownButton<BackgroundLocationConfig>(
            value: BackgroundLocationService.instance.config,
            items: const [
              DropdownMenuItem(
                value: BackgroundLocationPresets.daily,
                child: Text('日常'),
              ),
              DropdownMenuItem(
                value: BackgroundLocationPresets.geofence,
                child: Text('围栏监控'),
              ),
              DropdownMenuItem(
                value: BackgroundLocationPresets.workout,
                child: Text('运动追踪'),
              ),
              DropdownMenuItem(
                value: BackgroundLocationPresets.powerSaving,
                child: Text('省电'),
              ),
            ],
            onChanged: (config) {
              if (config != null) {
                BackgroundLocationService.instance.setConfig(config);
                setState(() {});
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('当前配置'),
          subtitle: Text(
            '更新间隔: ${BackgroundLocationService.instance.config.updateInterval.inMinutes}分钟\n'
            '距离阈值: ${BackgroundLocationService.instance.config.distanceFilter.toInt()}米',
          ),
        ),
      ],
    );
  }

  /// 构建使用说明卡片
  Widget _buildUsageGuideCard() {
    return _SettingsSection(
      title: '使用说明',
      children: [
        _GuideStep(
          step: 1,
          title: '设置权限',
          description: '授予位置权限和后台位置权限，确保应用可以获取位置变化。',
        ),
        const Divider(height: 1),
        _GuideStep(
          step: 2,
          title: '添加围栏',
          description: '在围栏管理中添加常用地点，设置触发条件和半径。',
        ),
        const Divider(height: 1),
        _GuideStep(
          step: 3,
          title: '开启监控',
          description: '返回主页面开启位置监控，应用将在后台监听位置变化。',
        ),
        const Divider(height: 1),
        _GuideStep(
          step: 4,
          title: '接收提醒',
          description: '到达或离开围栏区域时，应用会触发相应的提醒。',
        ),
      ],
    );
  }

  /// 构建围栏管理入口卡片
  Widget _buildGeofenceManagementCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.mdRadius,
          ),
          child: const Icon(
            Icons.radio_button_unchecked,
            color: Colors.white,
          ),
        ),
        title: const Text('围栏管理'),
        subtitle: const Text('管理您的地理围栏'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.locationGeofences),
      ),
    );
  }

  /// 请求位置权限
  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    setState(() {
      _hasLocationPermission = status.isGranted;
    });
  }

  /// 请求后台位置权限
  Future<void> _requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    setState(() {
      _hasBackgroundPermission = status.isGranted;
    });
  }

  /// 请求忽略电池优化
  Future<void> _requestIgnoreBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryOptimizationIgnored = status.isGranted;
    });
  }

  /// 切换监控状态
  Future<void> _toggleMonitoring(bool value) async {
    final notifier = ref.read(geofenceMonitoringProvider.notifier);

    if (value) {
      // 检查权限
      if (!_hasLocationPermission) {
        _showPermissionDialog('位置权限', '需要位置权限才能监控位置变化');
        return;
      }

      final success = await notifier.startMonitoring();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('启动监控失败，请检查权限设置')),
        );
      }
    } else {
      notifier.stopMonitoring();
    }
  }

  /// 显示权限对话框
  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}

/// 权限设置列表项
class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGranted ? AppColors.success : AppColors.warning;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppRadius.smRadius,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          isGranted ? '已授权' : '未授权',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// 使用指南步骤
class _GuideStep extends StatelessWidget {
  final int step;
  final String title;
  final String description;

  const _GuideStep({
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        child: Text(
          '$step',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}

/// 设置分组
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
