/// 天气推荐卡片组件
/// 显示当前天气和运动推荐

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/weather/data/models/weather_data.dart';
import 'package:thick_notepad/features/weather/presentation/providers/weather_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';

// ==================== 天气推荐卡片 ====================

/// 天气推荐卡片 - 显示天气信息和运动建议
class WeatherRecommendationCard extends ConsumerStatefulWidget {
  /// 点击回调
  final VoidCallback? onTap;

  /// 是否显示详细模式
  final bool showDetails;

  const WeatherRecommendationCard({
    super.key,
    this.onTap,
    this.showDetails = false,
  });

  @override
  ConsumerState<WeatherRecommendationCard> createState() =>
      _WeatherRecommendationCardState();
}

class _WeatherRecommendationCardState
    extends ConsumerState<WeatherRecommendationCard> {
  @override
  void initState() {
    super.initState();
    // 自动刷新天气
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWeather();
    });
  }

  Future<void> _refreshWeather() async {
    final settings = ref.read(weatherSettingsProvider);
    if (settings.enabled) {
      await ref.read(weatherStateProvider.notifier).refresh(forceRefresh: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherStateProvider);
    final settings = ref.watch(weatherSettingsProvider);

    // 如果功能被禁用，不显示
    if (!settings.enabled) {
      return const SizedBox.shrink();
    }

    return weatherAsync.isLoading
        ? _buildLoadingCard()
        : weatherAsync.hasError
            ? _buildErrorCard(weatherAsync.error ?? '加载失败')
            : weatherAsync.hasData
                ? _buildWeatherCard(weatherAsync.weather!)
                : _buildEmptyCard();
  }

  /// 构建加载状态卡片
  Widget _buildLoadingCard() {
    return ModernCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
      child: const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  /// 构建错误状态卡片
  Widget _buildErrorCard(String error) {
    return ModernCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.errorGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.cloud_off,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '天气数据获取失败',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '点击重试',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.refresh,
            color: AppColors.textHint,
            size: 20,
          ),
        ],
      ),
    );
  }

  /// 构建空状态卡片
  Widget _buildEmptyCard() {
    return ModernCard(
      onTap: () async {
        await ref.read(weatherStateProvider.notifier).refresh();
      },
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.cloud_queue,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '获取天气信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '点击查看运动建议',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.textHint,
            size: 20,
          ),
        ],
      ),
    );
  }

  /// 构建天气卡片
  Widget _buildWeatherCard(WeatherData weather) {
    final isOutdoor = weather.isSuitableForOutdoor();
    final gradient = isOutdoor ? AppColors.infoGradient : AppColors.warningGradient;
    final iconData = _getWeatherIcon(weather.condition);
    final scenario = isOutdoor ? '户外' : '室内';
    final recommendations = weather.getRecommendedWorkouts().take(3).toList();

    return ModernCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: gradient.colors.first.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              // 天气图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 天气信息
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${weather.temperature.toStringAsFixed(0)}°',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: isOutdoor ? AppColors.info : AppColors.warning,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          weather.condition.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.air,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AQI ${weather.airQualityIndex}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '推荐$scenario运动',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isOutdoor ? AppColors.info : AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 刷新按钮
              InkWell(
                onTap: () async {
                  await ref.read(weatherStateProvider.notifier).refresh();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.refresh,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          // 分隔线
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: AppColors.dividerColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),

          // 运动推荐
          Text(
            '推荐运动',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recommendations.map((workout) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradient.colors.first.withValues(alpha: 0.15),
                      gradient.colors.last.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  workout,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOutdoor ? AppColors.info : AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              );
            }).toList(),
          ),

          // 详细信息（可选显示）
          if (widget.showDetails) ...[
            const SizedBox(height: 12),
            _buildWeatherDetails(weather, isOutdoor),
          ],
        ],
      ),
    );
  }

  /// 构建天气详细信息
  Widget _buildWeatherDetails(WeatherData weather, bool isOutdoor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.water_drop,
                  label: '湿度',
                  value: '${weather.humidity.toStringAsFixed(0)}%',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.air,
                  label: '风速',
                  value: '${weather.windSpeed.toStringAsFixed(0)} km/h',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.thermostat,
                  label: '体感',
                  value: '${weather.feelsLike.toStringAsFixed(0)}°',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建详细信息项
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
                fontSize: 10,
              ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 根据天气状况获取图标
  IconData _getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.overcast:
        return Icons.cloud_queue;
      case WeatherCondition.lightRain:
      case WeatherCondition.moderateRain:
        return Icons.water_drop;
      case WeatherCondition.heavyRain:
      case WeatherCondition.thunderstorm:
        return Icons.thunderstorm;
      case WeatherCondition.lightSnow:
      case WeatherCondition.heavySnow:
        return Icons.ac_unit;
      case WeatherCondition.fog:
      case WeatherCondition.dust:
        return Icons.foggy;
      case WeatherCondition.unknown:
        return Icons.help_outline;
    }
  }
}

// ==================== 简化版天气图标卡片 ====================

/// 简化版天气卡片 - 仅显示图标和温度
class WeatherIconCard extends ConsumerWidget {
  final VoidCallback? onTap;
  final double? size;

  const WeatherIconCard({
    super.key,
    this.onTap,
    this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherStateProvider);
    final settings = ref.watch(weatherSettingsProvider);

    if (!settings.enabled) {
      return const SizedBox.shrink();
    }

    final weather = weatherAsync.weather;
    if (weather == null) {
      return const SizedBox.shrink();
    }

    final iconData = _getWeatherIcon(weather.condition);
    final cardSize = size ?? 52.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          gradient: AppColors.infoGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 天气图标
            Center(
              child: Icon(
                iconData,
                color: Colors.white.withValues(alpha: 0.9),
                size: cardSize * 0.45,
              ),
            ),
            // 温度标签
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${weather.temperature.toStringAsFixed(0)}°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: cardSize * 0.22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.overcast:
        return Icons.cloud_queue;
      case WeatherCondition.lightRain:
      case WeatherCondition.moderateRain:
        return Icons.water_drop;
      case WeatherCondition.heavyRain:
      case WeatherCondition.thunderstorm:
        return Icons.thunderstorm;
      case WeatherCondition.lightSnow:
      case WeatherCondition.heavySnow:
        return Icons.ac_unit;
      case WeatherCondition.fog:
      case WeatherCondition.dust:
        return Icons.foggy;
      case WeatherCondition.unknown:
        return Icons.help_outline;
    }
  }
}
