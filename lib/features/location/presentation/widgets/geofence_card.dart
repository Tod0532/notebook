/// 地理围栏卡片组件
/// 用于显示单个围栏的信息和控制

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:latlong2/latlong.dart';

/// 地理围栏卡片
class GeofenceCard extends ConsumerWidget {
  final Geofence geofence;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleEnabled;

  const GeofenceCard({
    super.key,
    required this.geofence,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggerType = GeofenceTriggerType.fromString(geofence.triggerType);
    final color = geofence.colorHex != null
        ? Color(geofence.colorHex!)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: geofence.isEnabled
            ? color.withValues(alpha: 0.08)
            : AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: geofence.isEnabled
              ? color.withValues(alpha: 0.3)
              : AppColors.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onEdit,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 图标
                _buildIcon(color),
                const SizedBox(width: 12),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称和状态标签
                      Row(
                        children: [
                          Text(
                            geofence.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: geofence.isEnabled
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          _buildTriggerTypeBadge(context, triggerType),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 地址
                      Text(
                        geofence.address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // 信息行
                      Row(
                        children: [
                          _buildInfoChip(
                            context,
                            icon: Icons.straighten,
                            label: '${geofence.radius.toInt()}米',
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            context,
                            icon: Icons.location_on,
                            label: _formatCoordinates(
                              geofence.latitude,
                              geofence.longitude,
                            ),
                            color: AppColors.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 开关和操作
                Column(
                  children: [
                    // 启用开关
                    Switch(
                      value: geofence.isEnabled,
                      onChanged: onToggleEnabled,
                      activeColor: color,
                    ),
                    // 更多操作按钮
                    if (onEdit != null || onDelete != null)
                      _buildMoreButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建图标
  Widget _buildIcon(Color color) {
    IconData iconData;
    if (geofence.iconCode != null && geofence.iconCode! > 0) {
      // 使用预设图标
      iconData = _getIconFromCode(geofence.iconCode!);
    } else {
      iconData = Icons.place;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: geofence.isEnabled ? 0.15 : 0.08),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Icon(
        iconData,
        color: color.withValues(alpha: geofence.isEnabled ? 1.0 : 0.5),
        size: 24,
      ),
    );
  }

  /// 构建触发类型徽章
  Widget _buildTriggerTypeBadge(
    BuildContext context,
    GeofenceTriggerType triggerType,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: triggerType == GeofenceTriggerType.enter
            ? AppColors.success.withValues(alpha: 0.15)
            : triggerType == GeofenceTriggerType.exit
                ? AppColors.warning.withValues(alpha: 0.15)
                : AppColors.info.withValues(alpha: 0.15),
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: triggerType == GeofenceTriggerType.enter
              ? AppColors.success.withValues(alpha: 0.3)
              : triggerType == GeofenceTriggerType.exit
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.info.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        triggerType.displayName,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: triggerType == GeofenceTriggerType.enter
                  ? AppColors.success
                  : triggerType == GeofenceTriggerType.exit
                      ? AppColors.warning
                      : AppColors.info,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建更多按钮
  Widget _buildMoreButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            _showDeleteDialog(context);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
        title: const Text('删除围栏'),
        content: Text('确定要删除围栏"${geofence.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 格式化坐标
  String _formatCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// 根据图标代码获取图标
  IconData _getIconFromCode(int code) {
    // 这里只返回一些常用图标
    switch (code) {
      case 0xE88A: return Icons.home;
      case 0xE0AF: return Icons.business;
      case 0xE539: return Icons.fitness_center;
      case 0xEBB5: return Icons.park;
      case 0xE80C: return Icons.school;
      case 0xE8CC: return Icons.shopping_cart;
      case 0xE561: return Icons.restaurant;
      default: return Icons.place;
    }
  }
}

/// 地理围栏卡片列表项（用于列表展示）
class GeofenceListItem extends ConsumerWidget {
  final Geofence geofence;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleEnabled;

  const GeofenceListItem({
    super.key,
    required this.geofence,
    this.onTap,
    this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggerType = GeofenceTriggerType.fromString(geofence.triggerType);
    final color = geofence.colorHex != null
        ? Color(geofence.colorHex!)
        : AppColors.primary;

    return ListTile(
      enabled: geofence.isEnabled,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          _getIconFromCode(geofence.iconCode ?? 0),
          color: color,
        ),
      ),
      title: Text(
        geofence.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: geofence.isEnabled ? null : AppColors.textSecondary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(geofence.address),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.straighten, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                '${geofence.radius.toInt()}米',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              Icon(Icons.notification_important, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                triggerType.displayName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
      trailing: Switch(
        value: geofence.isEnabled,
        onChanged: onToggleEnabled,
        activeColor: color,
      ),
      onTap: onTap,
    );
  }

  IconData _getIconFromCode(int code) {
    switch (code) {
      case 0xE88A: return Icons.home;
      case 0xE0AF: return Icons.business;
      case 0xE539: return Icons.fitness_center;
      case 0xEBB5: return Icons.park;
      case 0xE80C: return Icons.school;
      case 0xE8CC: return Icons.shopping_cart;
      case 0xE561: return Icons.restaurant;
      default: return Icons.place;
    }
  }
}
