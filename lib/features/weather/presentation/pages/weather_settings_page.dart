/// 天气设置页面
/// 允许用户配置天气功能选项

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/features/weather/presentation/providers/weather_providers.dart';

/// 天气设置页面
class WeatherSettingsPage extends ConsumerWidget {
  const WeatherSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(weatherSettingsProvider);
    final weatherState = ref.watch(weatherStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('天气设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 功能开关
          _buildSection(
            context,
            title: '功能设置',
            children: [
              SettingsCard(
                icon: Icons.cloud,
                title: '启用天气功能',
                subtitle: '根据天气推荐合适的运动',
                trailing: Switch(
                  value: settings.enabled,
                  onChanged: (value) {
                    ref.read(weatherSettingsProvider.notifier).toggleEnabled();
                  },
                ),
              ),
              SettingsCard(
                icon: Icons.refresh,
                title: '自动刷新',
                subtitle: '定期更新天气数据',
                trailing: Switch(
                  value: settings.autoRefresh,
                  onChanged: (value) {
                    ref.read(weatherSettingsProvider.notifier).toggleAutoRefresh();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 刷新间隔设置
          if (settings.autoRefresh)
            _buildSection(
              context,
              title: '刷新间隔',
              children: [
                _buildIntervalCard(
                  context,
                  label: '15分钟',
                  value: 15,
                  selected: settings.refreshInterval == 15,
                  onTap: () => ref.read(weatherSettingsProvider.notifier).setRefreshInterval(15),
                ),
                _buildIntervalCard(
                  context,
                  label: '30分钟',
                  value: 30,
                  selected: settings.refreshInterval == 30,
                  onTap: () => ref.read(weatherSettingsProvider.notifier).setRefreshInterval(30),
                ),
                _buildIntervalCard(
                  context,
                  label: '60分钟',
                  value: 60,
                  selected: settings.refreshInterval == 60,
                  onTap: () => ref.read(weatherSettingsProvider.notifier).setRefreshInterval(60),
                ),
              ],
            ),

          const SizedBox(height: AppSpacing.lg),

          // 数据管理
          _buildSection(
            context,
            title: '数据管理',
            children: [
              SettingsCard(
                icon: Icons.refresh,
                title: '刷新天气',
                subtitle: weatherState.isLoading
                    ? '正在刷新...'
                    : weatherState.lastUpdateTime != null
                        ? '上次更新: ${_formatTime(weatherState.lastUpdateTime!)}'
                        : '点击刷新天气数据',
                onTap: weatherState.isLoading
                    ? null
                    : () => ref.read(weatherStateProvider.notifier).refresh(forceRefresh: true),
              ),
              SettingsCard(
                icon: Icons.delete_outline,
                title: '清除缓存',
                subtitle: '删除本地缓存的天气数据',
                onTap: () => _showClearCacheDialog(context, ref),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 当前天气信息
          if (weatherState.hasData)
            _buildSection(
              context,
              title: '当前天气',
              children: [
                _buildWeatherInfoCard(context, weatherState.weather!),
              ],
            ),
        ],
      ),
    );
  }

  /// 构建设置分组
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }

  /// 构建刷新间隔卡片
  Widget _buildIntervalCard(
    BuildContext context, {
    required String label,
    required int value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.textHint,
                width: 2,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建天气信息卡片
  Widget _buildWeatherInfoCard(BuildContext context, dynamic weather) {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getWeatherIcon(weather.condition),
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather.temperature.toStringAsFixed(0)}°C',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      weather.condition.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.dividerColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          _buildDetailRow(
            context,
            icon: Icons.water_drop,
            label: '湿度',
            value: '${weather.humidity.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            icon: Icons.air,
            label: '风速',
            value: '${weather.windSpeed.toStringAsFixed(0)} km/h',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            icon: Icons.air,
            label: '空气质量',
            value: 'AQI ${weather.airQualityIndex}',
          ),
        ],
      ),
    );
  }

  /// 构建详细信息行
  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 获取天气图标
  IconData _getWeatherIcon(dynamic condition) {
    // 根据 WeatherCondition 枚举返回对应的图标
    switch (condition.toString().split('.').last) {
      case 'sunny':
        return Icons.wb_sunny;
      case 'cloudy':
        return Icons.cloud;
      case 'overcast':
        return Icons.cloud_queue;
      case 'lightRain':
      case 'moderateRain':
        return Icons.water_drop;
      case 'heavyRain':
      case 'thunderstorm':
        return Icons.thunderstorm;
      case 'lightSnow':
      case 'heavySnow':
        return Icons.ac_unit;
      case 'fog':
      case 'dust':
        return Icons.foggy;
      default:
        return Icons.help_outline;
    }
  }

  /// 显示清除缓存对话框
  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除天气缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(weatherStateProvider.notifier).clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              }
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }
}
