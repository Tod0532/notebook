/// 心率区间设置页面 - 用户可自定义心率区间配置
/// 包括静息心率、最大心率设置，以及5个心率区间的自定义阈值
/// 包含心率异常提醒开关设置

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/heart_rate/data/repositories/heart_rate_repository.dart';
import 'package:thick_notepad/features/heart_rate/presentation/providers/heart_rate_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/shared/widgets/loading_widget.dart';
import 'package:thick_notepad/services/heart_rate/heart_rate_alert_service.dart';

/// 心率区间设置页面
class HeartRateSettingsPage extends ConsumerStatefulWidget {
  const HeartRateSettingsPage({super.key});

  @override
  ConsumerState<HeartRateSettingsPage> createState() => _HeartRateSettingsPageState();
}

class _HeartRateSettingsPageState extends ConsumerState<HeartRateSettingsPage> {
  // 表单 key
  final _formKey = GlobalKey<FormState>();

  // 编辑控制器
  late TextEditingController _ageController;
  late TextEditingController _restingHRController;
  late TextEditingController _maxHRController;

  // 区间控制器
  late TextEditingController _zone1MinController;
  late TextEditingController _zone1MaxController;
  late TextEditingController _zone2MinController;
  late TextEditingController _zone2MaxController;
  late TextEditingController _zone3MinController;
  late TextEditingController _zone3MaxController;
  late TextEditingController _zone4MinController;
  late TextEditingController _zone4MaxController;
  late TextEditingController _zone5MinController;
  late TextEditingController _zone5MaxController;

  // 区间名称控制器
  late TextEditingController _zone1NameController;
  late TextEditingController _zone2NameController;
  late TextEditingController _zone3NameController;
  late TextEditingController _zone4NameController;
  late TextEditingController _zone5NameController;

  // 当前配置
  HeartRateZoneConfig? _currentConfig;
  bool _isLoading = true;
  bool _isSaving = false;

  // 异常提醒配置
  HeartRateAlertConfig? _alertConfig;
  bool _isLoadingAlertConfig = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadConfig();
  }

  void _initControllers() {
    _ageController = TextEditingController();
    _restingHRController = TextEditingController();
    _maxHRController = TextEditingController();

    _zone1MinController = TextEditingController();
    _zone1MaxController = TextEditingController();
    _zone2MinController = TextEditingController();
    _zone2MaxController = TextEditingController();
    _zone3MinController = TextEditingController();
    _zone3MaxController = TextEditingController();
    _zone4MinController = TextEditingController();
    _zone4MaxController = TextEditingController();
    _zone5MinController = TextEditingController();
    _zone5MaxController = TextEditingController();

    _zone1NameController = TextEditingController(text: '热身');
    _zone2NameController = TextEditingController(text: '燃脂');
    _zone3NameController = TextEditingController(text: '有氧');
    _zone4NameController = TextEditingController(text: '无氧');
    _zone5NameController = TextEditingController(text: '极限');
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final repo = HeartRateRepository(db);
      final config = await repo.getZoneConfig();

      if (config != null) {
        _currentConfig = config;
        _fillControllersFromConfig(config);
      } else {
        // 设置默认值
        _ageController.text = '30';
        _restingHRController.text = '70';
        _maxHRController.text = '';
      }

      // 加载异常提醒配置
      final alertService = ref.read(heartRateServiceProvider).alertService;
      if (alertService != null) {
        _alertConfig = alertService.config;
      } else {
        _alertConfig = await HeartRateAlertConfig.load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载配置失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
      _isLoadingAlertConfig = false;
    }
  }

  void _fillControllersFromConfig(HeartRateZoneConfig config) {
    _restingHRController.text = config.restingHeartRate.toString();
    if (config.maxHeartRate != null) {
      _maxHRController.text = config.maxHeartRate.toString();
    }

    _zone1MinController.text = config.zone1.min?.toString() ?? '';
    _zone1MaxController.text = config.zone1.max?.toString() ?? '';
    _zone1NameController.text = config.zone1.name;

    _zone2MinController.text = config.zone2.min?.toString() ?? '';
    _zone2MaxController.text = config.zone2.max?.toString() ?? '';
    _zone2NameController.text = config.zone2.name;

    _zone3MinController.text = config.zone3.min?.toString() ?? '';
    _zone3MaxController.text = config.zone3.max?.toString() ?? '';
    _zone3NameController.text = config.zone3.name;

    _zone4MinController.text = config.zone4.min?.toString() ?? '';
    _zone4MaxController.text = config.zone4.max?.toString() ?? '';
    _zone4NameController.text = config.zone4.name;

    _zone5MinController.text = config.zone5.min?.toString() ?? '';
    _zone5MaxController.text = config.zone5.max?.toString() ?? '';
    _zone5NameController.text = config.zone5.name;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _ageController.dispose();
    _restingHRController.dispose();
    _maxHRController.dispose();

    _zone1MinController.dispose();
    _zone1MaxController.dispose();
    _zone2MinController.dispose();
    _zone2MaxController.dispose();
    _zone3MinController.dispose();
    _zone3MaxController.dispose();
    _zone4MinController.dispose();
    _zone4MaxController.dispose();
    _zone5MinController.dispose();
    _zone5MaxController.dispose();

    _zone1NameController.dispose();
    _zone2NameController.dispose();
    _zone3NameController.dispose();
    _zone4NameController.dispose();
    _zone5NameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心率设置'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _resetToDefault,
              child: const Text('重置默认'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBasicInfoCard(),
                  const SizedBox(height: 16),
                  _buildAlertSettingsCard(),
                  const SizedBox(height: 16),
                  _buildZoneCard(
                    zoneIndex: 1,
                    nameController: _zone1NameController,
                    minController: _zone1MinController,
                    maxController: _zone1MaxController,
                    color: AppColors.info,
                    icon: Icons.wb_sunny_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildZoneCard(
                    zoneIndex: 2,
                    nameController: _zone2NameController,
                    minController: _zone2MinController,
                    maxController: _zone2MaxController,
                    color: AppColors.success,
                    icon: Icons.local_fire_department_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildZoneCard(
                    zoneIndex: 3,
                    nameController: _zone3NameController,
                    minController: _zone3MinController,
                    maxController: _zone3MaxController,
                    color: AppColors.warning,
                    icon: Icons.directions_run,
                  ),
                  const SizedBox(height: 12),
                  _buildZoneCard(
                    zoneIndex: 4,
                    nameController: _zone4NameController,
                    minController: _zone4MinController,
                    maxController: _zone4MaxController,
                    color: const Color(0xFFFB923C),
                    icon: Icons.fitness_center,
                  ),
                  const SizedBox(height: 12),
                  _buildZoneCard(
                    zoneIndex: 5,
                    nameController: _zone5NameController,
                    minController: _zone5MinController,
                    maxController: _zone5MaxController,
                    color: AppColors.error,
                    icon: Icons.bolt,
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  /// 基础信息卡片
  Widget _buildBasicInfoCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基础信息',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          // 年龄输入
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '年龄',
              hintText: '用于计算默认最大心率',
              prefixIcon: Icon(Icons.cake),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入年龄';
              }
              final age = int.tryParse(value);
              if (age == null || age < 10 || age > 100) {
                return '请输入有效的年龄（10-100）';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // 静息心率输入
          TextFormField(
            controller: _restingHRController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '静息心率',
              hintText: '平静状态下的心率',
              prefixIcon: Icon(Icons.favorite_border),
              suffixText: 'BPM',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入静息心率';
              }
              final hr = int.tryParse(value);
              if (hr == null || hr < 40 || hr > 100) {
                return '请输入有效的静息心率（40-100）';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // 最大心率输入
          TextFormField(
            controller: _maxHRController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '最大心率（可选）',
              hintText: '留空则根据年龄自动计算',
              prefixIcon: const Icon(Icons.show_chart),
              suffixText: 'BPM',
              helperText: '建议通过专业测试获取准确值',
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final hr = int.tryParse(value);
                if (hr == null || hr < 120 || hr > 220) {
                  return '请输入有效的最大心率（120-220）';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // 计算说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: AppRadius.mdRadius,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '心率区间基于心率储备法（卡瓦诺公式）计算：'
                    '目标心率 = 静息心率 + (最大心率 - 静息心率) × 强度百分比',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 心率区间卡片
  Widget _buildZoneCard({
    required int zoneIndex,
    required TextEditingController nameController,
    required TextEditingController minController,
    required TextEditingController maxController,
    required Color color,
    required IconData icon,
  }) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '区间 $zoneIndex 名称',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '最小值',
                    suffixText: 'BPM',
                    fillColor: color.withOpacity(0.05),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '必填';
                    }
                    final hr = int.tryParse(value);
                    if (hr == null || hr < 40 || hr > 220) {
                      return '无效值';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '最大值',
                    suffixText: 'BPM',
                    fillColor: color.withOpacity(0.05),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '必填';
                    }
                    final hr = int.tryParse(value);
                    if (hr == null || hr < 40 || hr > 220) {
                      return '无效值';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          // 区间预览条
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.smRadius,
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveConfig,
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('保存设置', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  /// 重置为默认值
  void _resetToDefault() {
    final age = int.tryParse(_ageController.text) ?? 30;
    final restingHR = int.tryParse(_restingHRController.text) ?? 70;

    final defaultConfig = HeartRateZoneConfig.calculateDefault(
      age: age,
      restingHeartRate: restingHR,
    );

    _fillControllersFromConfig(defaultConfig);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重置为默认值，请点击保存生效')),
    );
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 获取输入值
      final age = int.parse(_ageController.text);
      final restingHR = int.parse(_restingHRController.text);
      final maxHR = _maxHRController.text.isNotEmpty
          ? int.parse(_maxHRController.text)
          : null;

      // 构建配置对象
      final config = HeartRateZoneConfig(
        id: _currentConfig?.id,
        userProfileId: _currentConfig?.userProfileId,
        restingHeartRate: restingHR,
        maxHeartRate: maxHR,
        zone1: HeartZoneRange(
          name: _zone1NameController.text,
          min: int.tryParse(_zone1MinController.text),
          max: int.tryParse(_zone1MaxController.text),
        ),
        zone2: HeartZoneRange(
          name: _zone2NameController.text,
          min: int.tryParse(_zone2MinController.text),
          max: int.tryParse(_zone2MaxController.text),
        ),
        zone3: HeartZoneRange(
          name: _zone3NameController.text,
          min: int.tryParse(_zone3MinController.text),
          max: int.tryParse(_zone3MaxController.text),
        ),
        zone4: HeartZoneRange(
          name: _zone4NameController.text,
          min: int.tryParse(_zone4MinController.text),
          max: int.tryParse(_zone4MaxController.text),
        ),
        zone5: HeartZoneRange(
          name: _zone5NameController.text,
          min: int.tryParse(_zone5MinController.text),
          max: int.tryParse(_zone5MaxController.text),
        ),
        calculationMethod: maxHR != null ? 'measured' : 'age_based',
        createdAt: _currentConfig?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 保存到数据库
      final db = ref.read(databaseProvider);
      final repo = HeartRateRepository(db);
      final success = await repo.saveZoneConfig(config);

      if (success) {
        // 保存异常提醒配置
        if (_alertConfig != null) {
          await _alertConfig!.save();

          // 更新服务配置
          final alertService = ref.read(heartRateServiceProvider).alertService;
          if (alertService != null) {
            await alertService.updateConfig(_alertConfig!);
          }
        }

        // 清除缓存
        ref.invalidate(heartRateSettingsConfigProvider);
        repo.clearAllCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存成功'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('保存失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 异常提醒设置卡片
  Widget _buildAlertSettingsCard() {
    if (_alertConfig == null) return const SizedBox.shrink();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '异常提醒设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 启用异常提醒总开关
          SwitchListTile(
            title: const Text('启用异常提醒'),
            subtitle: const Text('心率超出目标区间时提醒'),
            value: _alertConfig!.enableVibration ||
                _alertConfig!.enableNotification ||
                _alertConfig!.enableDialog,
            onChanged: (value) {
              setState(() {
                if (value) {
                  // 启用所有提醒方式
                  _alertConfig = _alertConfig!.copyWith(
                    enableVibration: true,
                    enableNotification: true,
                    enableDialog: true,
                  );
                } else {
                  // 禁用所有提醒方式
                  _alertConfig = _alertConfig!.copyWith(
                    enableVibration: false,
                    enableNotification: false,
                    enableDialog: false,
                  );
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(),
          const SizedBox(height: 8),

          // 震动提醒开关
          SwitchListTile(
            title: const Text('震动提醒'),
            subtitle: const Text('心率异常时震动反馈'),
            value: _alertConfig!.enableVibration,
            onChanged: (value) {
              setState(() {
                _alertConfig = _alertConfig!.copyWith(
                  enableVibration: value,
                );
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          // 弹窗提醒开关
          SwitchListTile(
            title: const Text('弹窗提醒'),
            subtitle: const Text('显示异常提示弹窗'),
            value: _alertConfig!.enableDialog,
            onChanged: (value) {
              setState(() {
                _alertConfig = _alertConfig!.copyWith(
                  enableDialog: value,
                );
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          // 通知提醒开关
          SwitchListTile(
            title: const Text('通知提醒'),
            subtitle: const Text('发送系统通知'),
            value: _alertConfig!.enableNotification,
            onChanged: (value) {
              setState(() {
                _alertConfig = _alertConfig!.copyWith(
                  enableNotification: value,
                );
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(),
          const SizedBox(height: 8),

          // 检测延迟设置
          ListTile(
            title: const Text('检测延迟'),
            subtitle: Text('心率持续异常 ${_alertConfig!.alertDelaySeconds} 秒后触发提醒'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDelaySettingDialog(),
            contentPadding: EdgeInsets.zero,
          ),

          // 阈值设置
          ListTile(
            title: const Text('触发阈值'),
            subtitle: Text(
              '高于上限 ${(_alertConfig!.highThresholdMultiplier * 100).toInt()}% '
              '或低于下限 ${(_alertConfig!.lowThresholdMultiplier * 100).toInt()}%',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThresholdSettingDialog(),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// 显示检测延迟设置对话框
  void _showDelaySettingDialog() {
    int currentDelay = _alertConfig!.alertDelaySeconds;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置检测延迟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('心率持续异常多少秒后触发提醒'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Slider(
                      value: currentDelay.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '$currentDelay 秒',
                      onChanged: (value) {
                        setDialogState(() {
                          currentDelay = value.round();
                        });
                      },
                    ),
                    Text(
                      '$currentDelay 秒',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _alertConfig = _alertConfig!.copyWith(
                  alertDelaySeconds: currentDelay,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示阈值设置对话框
  void _showThresholdSettingDialog() {
    int highPercent = (_alertConfig!.highThresholdMultiplier * 100).toInt();
    int lowPercent = (_alertConfig!.lowThresholdMultiplier * 100).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置触发阈值'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 心率过高阈值
                Text(
                  '心率过高阈值',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: highPercent.toDouble(),
                  min: 100,
                  max: 150,
                  divisions: 10,
                  label: '$highPercent%',
                  onChanged: (value) {
                    setDialogState(() {
                      highPercent = value.round();
                    });
                  },
                ),
                Text('$highPercent%'),
                const SizedBox(height: 8),
                Text(
                  '超过目标区间上限的 ${highPercent}% 时触发',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const Divider(height: 32),

                // 心率过低阈值
                Text(
                  '心率过低阈值',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: lowPercent.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '$lowPercent%',
                  onChanged: (value) {
                    setDialogState(() {
                      lowPercent = value.round();
                    });
                  },
                ),
                Text('$lowPercent%'),
                const SizedBox(height: 8),
                Text(
                  '低于目标区间下限的 ${lowPercent}% 时触发',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _alertConfig = _alertConfig!.copyWith(
                  highThresholdMultiplier: highPercent / 100,
                  lowThresholdMultiplier: lowPercent / 100,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

