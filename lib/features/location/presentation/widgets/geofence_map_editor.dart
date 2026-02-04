/// 地理围栏地图编辑器组件
/// 用于在地图上选择位置和设置围栏半径

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 地理围栏编辑数据
class GeofenceEditData {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final GeofenceTriggerType triggerType;
  final int? linkedReminderId;
  final int? iconCode;
  final int? colorHex;

  const GeofenceEditData({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = GeofenceConfig.defaultRadius,
    this.triggerType = GeofenceTriggerType.enter,
    this.linkedReminderId,
    this.iconCode,
    this.colorHex,
  });

  GeofenceEditData copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    GeofenceTriggerType? triggerType,
    int? linkedReminderId,
    int? iconCode,
    int? colorHex,
  }) {
    return GeofenceEditData(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      triggerType: triggerType ?? this.triggerType,
      linkedReminderId: linkedReminderId ?? this.linkedReminderId,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}

/// 地理围栏地图编辑器
class GeofenceMapEditor extends ConsumerStatefulWidget {
  final Geofence? initialGeofence;
  final LatLng? initialLocation;
  final void Function(GeofenceEditData) onSave;
  final VoidCallback? onCancel;

  const GeofenceMapEditor({
    super.key,
    this.initialGeofence,
    this.initialLocation,
    required this.onSave,
    this.onCancel,
  });

  @override
  ConsumerState<GeofenceMapEditor> createState() => _GeofenceMapEditorState();
}

class _GeofenceMapEditorState extends ConsumerState<GeofenceMapEditor> {
  late GeofenceEditData _editData;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.initialGeofence != null) {
      _editData = GeofenceEditData(
        name: widget.initialGeofence!.name,
        address: widget.initialGeofence!.address,
        latitude: widget.initialGeofence!.latitude,
        longitude: widget.initialGeofence!.longitude,
        radius: widget.initialGeofence!.radius,
        triggerType: GeofenceTriggerType.fromString(
          widget.initialGeofence!.triggerType,
        ),
        linkedReminderId: widget.initialGeofence!.linkedReminderId,
        iconCode: widget.initialGeofence!.iconCode,
        colorHex: widget.initialGeofence!.colorHex,
      );
      _nameController.text = _editData.name;
      _addressController.text = _editData.address;
    } else if (widget.initialLocation != null) {
      _editData = GeofenceEditData(
        name: '',
        address: '选择的位置',
        latitude: widget.initialLocation!.latitude,
        longitude: widget.initialLocation!.longitude,
      );
    } else {
      // 默认位置（北京）
      _editData = GeofenceEditData(
        name: '',
        address: '北京市',
        latitude: 39.9042,
        longitude: 116.4074,
      );
    }
    _isLoading = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.initialGeofence != null ? '编辑围栏' : '添加围栏'),
        actions: [
          TextButton.icon(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 地图
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                // 半径调整指示器
                _buildRadiusIndicator(),
              ],
            ),
          ),
          // 编辑面板
          _buildEditPanel(),
        ],
      ),
    );
  }

  /// 构建地图
  Widget _buildMap() {
    final center = LatLng(_editData.latitude, _editData.longitude);
    final radiusKm = _editData.radius / 1000;

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: _getZoomForRadius(_editData.radius),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: _onMapTap,
      ),
      children: [
        // 地图图层
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.thick_notepad',
        ),
        // 围栏圆圈
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: _editData.radius,
              color: (_editData.colorHex != null
                      ? Color(_editData.colorHex!)
                      : AppColors.primary)
                  .withValues(alpha: 0.2),
              borderColor: _editData.colorHex != null
                  ? Color(_editData.colorHex!)
                  : AppColors.primary,
              borderStrokeWidth: 2,
            ),
            // 中心点标记
            CircleMarker(
              point: center,
              radius: 8,
              color: (_editData.colorHex != null
                      ? Color(_editData.colorHex!)
                      : AppColors.primary)
                  .withValues(alpha: 0.8),
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        // 当前位置标记（如果是编辑模式）
        if (widget.initialGeofence == null)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_on,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 构建半径指示器
  Widget _buildRadiusIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgRadius,
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked,
                  size: 16,
                  color: _editData.colorHex != null
                      ? Color(_editData.colorHex!)
                      : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '围栏半径: ${_editData.radius.toInt()}米',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '长按地图可移动围栏位置',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建编辑面板
  Widget _buildEditPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: AppShadows.deep,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称输入
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '围栏名称',
                hintText: '例如：家、公司、健身房',
                prefixIcon: const Icon(Icons.label),
              ),
              onChanged: (value) {
                setState(() {
                  _editData = _editData.copyWith(name: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // 地址输入
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: '地址描述',
                hintText: '详细地址',
                prefixIcon: const Icon(Icons.location_on),
              ),
              onChanged: (value) {
                setState(() {
                  _editData = _editData.copyWith(address: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // 半径滑块
            _buildRadiusSlider(),
            const SizedBox(height: 16),

            // 触发类型选择
            _buildTriggerTypeSelector(),
            const SizedBox(height: 16),

            // 常用地点选择
            _buildCommonLocationSelector(),
            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveAndClose,
                icon: const Icon(Icons.save),
                label: const Text('保存围栏'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建半径滑块
  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '围栏半径',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${_editData.radius.toInt()}米',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _editData.colorHex != null
                        ? Color(_editData.colorHex!)
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        Slider(
          value: _editData.radius,
          min: GeofenceConfig.minRadius,
          max: GeofenceConfig.maxRadius,
          divisions: 19,
          activeColor: _editData.colorHex != null
              ? Color(_editData.colorHex!)
              : AppColors.primary,
          label: '${_editData.radius.toInt()}米',
          onChanged: (value) {
            setState(() {
              _editData = _editData.copyWith(radius: value);
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPresetRadiusButton(50, '50m'),
            _buildPresetRadiusButton(100, '100m'),
            _buildPresetRadiusButton(200, '200m'),
            _buildPresetRadiusButton(500, '500m'),
          ],
        ),
      ],
    );
  }

  /// 构建预设半径按钮
  Widget _buildPresetRadiusButton(double radius, String label) {
    final isSelected = _editData.radius == radius;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _editData = _editData.copyWith(radius: radius);
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? (_editData.colorHex != null
                    ? Color(_editData.colorHex!)
                    : AppColors.primary)
                .withValues(alpha: 0.15)
            : null,
        side: BorderSide(
          color: isSelected
              ? (_editData.colorHex != null
                      ? Color(_editData.colorHex!)
                      : AppColors.primary)
                  .withValues(alpha: 0.5)
              : AppColors.dividerColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(60, 36),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? (_editData.colorHex != null
                      ? Color(_editData.colorHex!)
                      : AppColors.primary)
                  .withValues(alpha: 1)
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// 构建触发类型选择器
  Widget _buildTriggerTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '触发类型',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<GeofenceTriggerType>(
          segments: const [
            ButtonSegment(
              value: GeofenceTriggerType.enter,
              label: Text('进入时'),
              icon: Icon(Icons.login, size: 18),
            ),
            ButtonSegment(
              value: GeofenceTriggerType.exit,
              label: Text('离开时'),
              icon: Icon(Icons.logout, size: 18),
            ),
            ButtonSegment(
              value: GeofenceTriggerType.both,
              label: Text('两者'),
              icon: Icon(Icons.sync_alt, size: 18),
            ),
          ],
          selected: {_editData.triggerType},
          onSelectionChanged: (Set<GeofenceTriggerType> selected) {
            setState(() {
              _editData = _editData.copyWith(triggerType: selected.first);
            });
          },
        ),
      ],
    );
  }

  /// 构建常用地点选择器
  Widget _buildCommonLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '或选择常用地点',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CommonLocation.locations.map((location) {
            return FilterChip(
              label: Text(location.name),
              avatar: Icon(
                _getIconFromCode(location.iconCode),
                size: 18,
              ),
              backgroundColor: Color(location.colorHex).withValues(alpha: 0.1),
              selected: _editData.iconCode == location.iconCode,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _editData = _editData.copyWith(
                      iconCode: location.iconCode,
                      colorHex: location.colorHex,
                    );
                    if (_nameController.text.isEmpty) {
                      _nameController.text = location.name;
                      _editData = _editData.copyWith(name: location.name);
                    }
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 地图点击事件
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _editData = _editData.copyWith(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
    // MapController 不再直接使用，地图位置会通过 setState 重建时自动更新
  }

  /// 根据半径获取缩放级别
  double _getZoomForRadius(double radius) {
    // 半径越大，缩放级别越小
    if (radius < 100) return 16.0;
    if (radius < 200) return 15.0;
    if (radius < 500) return 14.0;
    if (radius < 800) return 13.0;
    return 12.0;
  }

  /// 保存并关闭
  void _saveAndClose() {
    if (_editData.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入围栏名称')),
      );
      return;
    }

    widget.onSave(_editData);
    Navigator.pop(context);
  }

  /// 根据图标代码获取图标
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
