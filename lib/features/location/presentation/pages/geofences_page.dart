/// 地理围栏列表页面
/// 显示所有围栏，支持添加、编辑、删除操作

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/location/presentation/providers/location_providers.dart';
import 'package:thick_notepad/features/location/presentation/widgets/geofence_card.dart';
import 'package:thick_notepad/features/location/presentation/widgets/geofence_map_editor.dart';
import 'package:thick_notepad/services/location/geofence_service.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:geolocator/geolocator.dart';

/// 地理围栏列表页面
class GeofencesPage extends ConsumerStatefulWidget {
  const GeofencesPage({super.key});

  @override
  ConsumerState<GeofencesPage> createState() => _GeofencesPageState();
}

class _GeofencesPageState extends ConsumerState<GeofencesPage> {
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // 初始化地理围栏服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(geofenceServiceInitProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(geofenceListProvider);
    final monitoringState = ref.watch(geofenceMonitoringProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 自定义顶部导航栏
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '位置提醒',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: _buildHeaderBackground(state, monitoringState),
            ),
            actions: [
              // 选择模式按钮
              if (state.geofences.isNotEmpty && !_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '选择',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                ),
              // 取消选择
              if (_isSelectionMode)
                TextButton(
                  onPressed: _cancelSelection,
                  child: const Text('取消'),
                ),
              // 批量删除
              if (_isSelectionMode && _selectedIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '删除',
                  onPressed: _deleteSelected,
                ),
            ],
          ),
          // 统计卡片
          SliverToBoxAdapter(
            child: _buildStatisticsCard(state, monitoringState),
          ),
          // 围栏列表
          state.isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : state.geofences.isEmpty
                  ? _buildEmptyState()
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final geofence = state.geofences[index];
                            final isSelected = _selectedIds.contains(geofence.id);

                            return _buildGeofenceTile(geofence, isSelected, state);
                          },
                          childCount: state.geofences.length,
                        ),
                      ),
                    ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(state),
    );
  }

  /// 构建头部背景
  Widget _buildHeaderBackground(
    GeofenceListState state,
    GeofenceMonitoringState monitoringState,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: monitoringState.isMonitoring
              ? [
                  AppColors.success.withValues(alpha: 0.8),
                  AppColors.success.withValues(alpha: 0.6),
                ]
              : AppColors.primaryGradient.colors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    monitoringState.isMonitoring
                        ? Icons.location_on
                        : Icons.location_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monitoringState.isMonitoring ? '监控中' : '已停止',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          state.geofences
                                  .where((g) => g.isEnabled)
                                  .length
                                  .toString() +
                              ' 个围栏启用',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 监控开关
                  Switch(
                    value: monitoringState.isMonitoring,
                    onChanged: _toggleMonitoring,
                    activeColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatisticsCard(
    GeofenceListState state,
    GeofenceMonitoringState monitoringState,
  ) {
    if (state.statistics == null) return const SizedBox.shrink();

    final stats = state.statistics!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.light,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.radio_button_unchecked,
              label: '总围栏',
              value: '${stats.totalGeofences}',
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.toggle_on,
              label: '已启用',
              value: '${stats.enabledGeofences}',
              color: AppColors.success,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.event,
              label: '今日事件',
              value: '${stats.todayEvents}',
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  /// 构建围栏列表项
  Widget _buildGeofenceTile(
    Geofence geofence,
    bool isSelected,
    GeofenceListState state,
  ) {
    return GeofenceCard(
      geofence: geofence,
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(geofence.id);
                } else {
                  _selectedIds.add(geofence.id);
                }
              });
            }
          : () => _showGeofenceDetail(geofence),
      onEdit: () => _editGeofence(geofence),
      onDelete: () => _deleteGeofence(geofence.id),
      onToggleEnabled: (enabled) {
        ref
            .read(geofenceListProvider.notifier)
            .toggleGeofenceEnabled(geofence.id, enabled);
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有设置任何围栏',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一个围栏',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建浮动操作按钮
  Widget _buildFloatingActionButton(GeofenceListState state) {
    if (_isSelectionMode) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _addGeofence,
      icon: const Icon(Icons.add),
      label: const Text('添加围栏'),
      backgroundColor: AppColors.primary,
    );
  }

  /// 切换监控状态
  Future<void> _toggleMonitoring(bool value) async {
    final notifier = ref.read(geofenceMonitoringProvider.notifier);
    if (value) {
      final hasPermission = await notifier.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
      await notifier.startMonitoring();
    } else {
      notifier.stopMonitoring();
    }
  }

  /// 显示权限对话框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
        title: const Text('需要位置权限'),
        content: const Text(
          '为了使用位置提醒功能，请授予应用位置权限。'
          '您可以在"位置设置"中配置权限和后台选项。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/location/settings');
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 添加围栏
  Future<void> _addGeofence() async {
    // 先获取当前位置
    final notifier = ref.read(geofenceMonitoringProvider.notifier);
    final position = await notifier.getCurrentPosition();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GeofenceMapEditor(
            initialLocation: position != null
                ? LatLng(position.latitude, position.longitude)
                : null,
            onSave: (data) async {
              final success = await ref
                  .read(geofenceListProvider.notifier)
                  .addGeofence(
                    name: data.name,
                    address: data.address,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    radius: data.radius,
                    triggerType: data.triggerType.value,
                    iconCode: data.iconCode,
                    colorHex: data.colorHex,
                  );
              if (mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('添加围栏失败')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  /// 编辑围栏
  void _editGeofence(Geofence geofence) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceMapEditor(
          initialGeofence: geofence,
          onSave: (data) async {
            final updatedGeofence = Geofence(
              id: geofence.id,
              name: data.name,
              address: data.address,
              latitude: data.latitude,
              longitude: data.longitude,
              radius: data.radius,
              triggerType: data.triggerType.value,
              linkedReminderId: data.linkedReminderId,
              isEnabled: geofence.isEnabled,
              iconCode: data.iconCode ?? geofence.iconCode,
              colorHex: data.colorHex,
              createdAt: geofence.createdAt,
            );
            final success = await ref
                .read(geofenceListProvider.notifier)
                .updateGeofence(updatedGeofence);
            if (mounted && !success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更新围栏失败')),
              );
            }
          },
        ),
      ),
    );
  }

  /// 删除围栏
  Future<void> _deleteGeofence(int id) async {
    final success = await ref.read(geofenceListProvider.notifier).deleteGeofence(id);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除围栏失败')),
      );
    }
  }

  /// 显示围栏详情
  void _showGeofenceDetail(Geofence geofence) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GeofenceDetailSheet(geofence: geofence),
    );
  }

  /// 取消选择
  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 删除选中的围栏
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
        title: const Text('删除围栏'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个围栏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(geofenceListProvider.notifier)
          .deleteMultipleGeofences(_selectedIds.toList());
      _cancelSelection();
    }
  }
}

/// 围栏详情底部表单
class _GeofenceDetailSheet extends ConsumerWidget {
  final Geofence geofence;

  const _GeofenceDetailSheet({required this.geofence});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(geofenceDetailProvider(geofence.id));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: geofence.colorHex != null
                        ? Color(geofence.colorHex!)
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          geofence.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          geofence.address,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              // 统计信息
              if (detailAsync.hasValue && detailAsync.value != null) ...[
                _buildDetailRow(
                  context,
                  icon: Icons.event,
                  label: '总事件',
                  value: '${detailAsync.value!.totalEvents}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  icon: Icons.today,
                  label: '今日事件',
                  value: '${detailAsync.value!.todayEvents}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  icon: Icons.login,
                  label: '进入次数',
                  value: '${detailAsync.value!.enteredCount}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  icon: Icons.logout,
                  label: '离开次数',
                  value: '${detailAsync.value!.exitedCount}',
                ),
                const SizedBox(height: 12),
                if (detailAsync.value!.lastEvent != null)
                  _buildDetailRow(
                    context,
                    icon: Icons.access_time,
                    label: '最后触发',
                    value: detailAsync.value!.statusDescription,
                  ),
                const SizedBox(height: 24),
              ],
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // 调用编辑
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // 查看事件历史
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('历史'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
