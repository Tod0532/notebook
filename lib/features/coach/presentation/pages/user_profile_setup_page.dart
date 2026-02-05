/// 用户画像采集页面
/// 分步骤收集用户的健身目标、基础信息、限制条件和偏好

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 用户画像采集页面
class UserProfileSetupPage extends ConsumerStatefulWidget {
  final int? existingProfileId;

  const UserProfileSetupPage({
    super.key,
    this.existingProfileId,
  });

  @override
  ConsumerState<UserProfileSetupPage> createState() => _UserProfileSetupPageState();
}

class _UserProfileSetupPageState extends ConsumerState<UserProfileSetupPage> {
  // 当前步骤：0=目标, 1=基础信息, 2=限制条件, 3=偏好, 4=完成
  int _currentStep = 0;

  // 页面控制器
  late final PageController _pageController;

  // 表单数据
  final _formKey = GlobalKey<FormState>();

  // 保存状态
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _goalTypeController.dispose();
    _durationController.dispose();
    _targetWeightController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _dailyMinutesController.dispose();
    super.dispose();
  }
  final _goalTypeController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _targetWeightController = TextEditingController();
  final _genderController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _dailyMinutesController = TextEditingController(text: '30');

  // 选中的值
  FitnessGoal? _selectedGoal;
  int? _selectedDuration;
  String? _selectedGender;
  FitnessLevel? _selectedFitnessLevel;
  DietType? _selectedDietType;
  EquipmentType? _selectedEquipment;
  TastePreference? _selectedTaste;
  bool _hasHeartRateMonitor = false;

  // 列表数据
  final List<String> _selectedRestrictions = [];
  final List<String> _selectedAllergies = [];
  final List<String> _selectedInjuries = [];
  final List<String> _preferredWorkouts = [];
  final List<String> _dislikedWorkouts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建您的健身画像'),
        actions: [
          TextButton(
            onPressed: _saveAndExit,
            child: const Text('保存', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 步骤指示器
          _buildStepIndicator(),
          // 内容区域
          Expanded(
            child: PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              children: [
                _buildGoalStep(),
                _buildBasicInfoStep(),
                _buildRestrictionsStep(),
                _buildPreferencesStep(),
                _buildSummaryStep(),
              ],
            ),
          ),
          // 导航按钮
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  /// 步骤指示器
  Widget _buildStepIndicator() {
    const steps = ['目标', '基础', '限制', '偏好', '完成'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isPast = index < _currentStep;
          return Row(
            children: [
              // 步骤圆圈
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary
                      : isPast
                          ? AppColors.success
                          : AppColors.surfaceDark,
                ),
                child: Center(
                  child: isPast
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              // 步骤名称
              if (index < steps.length - 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: index < _currentStep ? AppColors.success : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (index == steps.length - 1) const SizedBox(width: 8),
            ],
          );
        }),
      ),
    );
  }

  /// 导航按钮
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('上一步'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.textHint,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_currentStep < 4 ? '下一步' : '完成'),
            ),
          ),
        ],
      ),
    );
  }

  /// 第一步：目标选择
  Widget _buildGoalStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '您的健身目标是什么？',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '选择您的主要目标，我们将为您制定个性化计划',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        ...FitnessGoal.values.map((goal) => _buildGoalCard(goal)),
        const SizedBox(height: 24),
        // 目标周期
        _buildDurationSelector(),
        const SizedBox(height: 16),
        // 目标体重（可选）
        _buildTargetWeightField(),
      ],
    );
  }

  /// 目标体重输入
  Widget _buildTargetWeightField() {
    return TextFormField(
      controller: _targetWeightController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: '目标体重（可选）',
        hintText: '请输入目标体重',
        suffixText: 'kg',
        prefixIcon: Icon(Icons.flag),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surfaceVariant,
      ),
    );
  }

  Widget _buildGoalCard(FitnessGoal goal) {
    final isSelected = _selectedGoal == goal;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getGoalIcon(goal),
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _getGoalDescription(goal),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  IconData _getGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.fatLoss:
        return Icons.local_fire_department;
      case FitnessGoal.muscleGain:
        return Icons.fitness_center;
      case FitnessGoal.shape:
        return Icons.accessibility_new;
      case FitnessGoal.maintain:
        return Icons.balance;
      case FitnessGoal.fitness:
        return Icons.directions_run;
    }
  }

  String _getGoalDescription(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.fatLoss:
        return '通过运动和饮食控制，减少体脂';
      case FitnessGoal.muscleGain:
        return '增加肌肉量，塑造强壮体魄';
      case FitnessGoal.shape:
        return '优化身体线条，改善体态';
      case FitnessGoal.maintain:
        return '保持当前体重和身体状态';
      case FitnessGoal.fitness:
        return '提升体能，增强运动能力';
    }
  }

  /// 第二步：基础信息
  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '基本信息',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          // 性别
          _buildGenderSelector(),
          const SizedBox(height: 16),
          // 年龄
          _buildIntegerField(
            controller: _ageController,
            label: '年龄',
            hint: '请输入年龄',
            suffix: '岁',
            icon: Icons.cake,
          ),
          const SizedBox(height: 16),
          // 身高
          _buildIntegerField(
            controller: _heightController,
            label: '身高',
            hint: '请输入身高',
            suffix: 'cm',
            icon: Icons.height,
          ),
          const SizedBox(height: 16),
          // 体重
          _buildIntegerField(
            controller: _weightController,
            label: '当前体重',
            hint: '请输入体重',
            suffix: 'kg',
            icon: Icons.monitor_weight,
          ),
          const SizedBox(height: 16),
          // 体脂率（选填）
          _buildIntegerField(
            controller: _bodyFatController,
            label: '体脂率（选填）',
            hint: '如有体脂秤可填写',
            suffix: '%',
            icon: Icons.percent,
            isOptional: true,
          ),
          const SizedBox(height: 16),
          // 运动基础
          _buildFitnessLevelSelector(),
          const SizedBox(height: 16),
          // 每日可运动时长
          _buildDailyMinutesSelector(),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性别',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('male', '男', Icons.male),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('female', '女', Icons.female),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegerField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: isOptional ? '$label（选填）' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: suffix,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surfaceVariant,
      ),
      validator: isOptional
          ? null
          : (value) {
              if (value == null || value.isEmpty) {
                return '请输入$label';
              }
              final num = double.tryParse(value);
              if (num == null || num <= 0) {
                return '请输入有效的数值';
              }
              return null;
            },
    );
  }

  Widget _buildFitnessLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '运动基础',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        ...FitnessLevel.values.map((level) {
          return RadioListTile<FitnessLevel>(
            title: Text(level.displayName),
            value: level,
            groupValue: _selectedFitnessLevel,
            onChanged: (value) => setState(() => _selectedFitnessLevel = value),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目标周期',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDurationOption(7, '7天'),
            const SizedBox(width: 8),
            _buildDurationOption(30, '30天'),
            const SizedBox(width: 8),
            _buildDurationOption(90, '90天'),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationOption(int days, String label) {
    final isSelected = _selectedDuration == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDuration = days;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 第三步：限制条件
  Widget _buildRestrictionsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '限制条件',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '这些信息将帮助我们为您制定更合适的计划',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        // 饮食类型
        _buildDietTypeSelector(),
        const SizedBox(height: 24),
        // 饮食禁忌
        _buildRestrictionSelector(
          title: '饮食禁忌',
          options: const ['辛辣', '生冷', '海鲜', '牛羊肉', '花生', '牛奶', '鸡蛋', '麸质'],
          selected: _selectedRestrictions,
        ),
        const SizedBox(height: 16),
        // 过敏食材
        _buildRestrictionSelector(
          title: '过敏食材',
          options: const ['花生', '坚果', '海鲜', '鸡蛋', '牛奶', '大豆', '小麦', '芝麻'],
          selected: _selectedAllergies,
        ),
        const SizedBox(height: 16),
        // 运动损伤
        _buildRestrictionSelector(
          title: '运动损伤（如无则跳过）',
          options: const ['腰部', '肩部', '膝盖', '脚踝', '手腕', '颈部', '无'],
          selected: _selectedInjuries,
        ),
        const SizedBox(height: 24),
        // 每日可运动时长
        _buildDailyMinutesSelector(),
      ],
    );
  }

  Widget _buildDietTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '饮食类型',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DietType.values.map((type) {
            final isSelected = _selectedDietType == type;
            return FilterChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDietType = type),
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRestrictionSelector({
    required String title,
    required List<String> options,
    required List<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    selected.remove(option);
                  } else {
                    selected.add(option);
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDailyMinutesSelector() {
    final currentMinutes = int.tryParse(_dailyMinutesController.text) ?? 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '每日可运动时长',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...[15, 30, 45, 60, 90].map((minutes) {
              final isSelected = currentMinutes == minutes;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _dailyMinutesController.text = minutes.toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${minutes}分钟',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dailyMinutesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '自定义时长（分钟）',
            suffixText: '分钟',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: AppColors.surfaceVariant,
          ),
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  /// 第四步：偏好设置
  Widget _buildPreferencesStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '偏好设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),
        // 器械情况
        _buildEquipmentSelector(),
        const SizedBox(height: 24),
        // 口味偏好
        _buildTasteSelector(),
        const SizedBox(height: 24),
        // 喜欢的运动
        _buildWorkoutPreferenceSelector(
          title: '喜欢的运动类型',
          options: const ['跑步', '游泳', '瑜伽', '力量训练', '骑行', '有氧操', '跳绳', '拉伸'],
          selected: _preferredWorkouts,
        ),
        const SizedBox(height: 16),
        // 讨厌的运动
        _buildWorkoutPreferenceSelector(
          title: '不喜欢的运动类型（可选）',
          options: const ['跑步', '波比跳', '卷腹', '深蹲', '平板支撑', '爬山', '游泳'],
          selected: _dislikedWorkouts,
        ),
        const SizedBox(height: 24),
        // 心率设备
        _buildHeartRateMonitorSwitch(),
      ],
    );
  }

  Widget _buildEquipmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '器械情况',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        ...EquipmentType.values.map((type) {
          return RadioListTile<EquipmentType>(
            title: Text(type.displayName),
            subtitle: Text(_getEquipmentDescription(type)),
            value: type,
            groupValue: _selectedEquipment,
            onChanged: (value) => setState(() => _selectedEquipment = value),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  String _getEquipmentDescription(EquipmentType type) {
    switch (type) {
      case EquipmentType.none:
        return '只使用自重训练';
      case EquipmentType.homeMinimal:
        return '哑铃、弹力带等小器械';
      case EquipmentType.homeFull:
        return '家用健身器材如跑步机、单车等';
      case EquipmentType.gymFull:
        return '可以前往健身房使用全套器械';
    }
  }

  Widget _buildTasteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '口味偏好',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TastePreference.values.map((taste) {
            final isSelected = _selectedTaste == taste;
            return FilterChip(
              label: Text(taste.displayName),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedTaste = taste),
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkoutPreferenceSelector({
    required String title,
    required List<String> options,
    required List<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    selected.remove(option);
                  } else {
                    selected.add(option);
                  }
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeartRateMonitorSwitch() {
    return SwitchListTile(
      title: const Text('拥有心率带/智能手表'),
      subtitle: const Text('如有心率设备，可提供更精准的训练建议'),
      value: _hasHeartRateMonitor,
      onChanged: (value) => setState(() => _hasHeartRateMonitor = value),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// 第五步：完成确认
  Widget _buildSummaryStep() {
    final ageText = _ageController.text.isNotEmpty ? '${_ageController.text}岁' : '未填写';
    final heightText = _heightController.text.isNotEmpty ? _heightController.text : '--';
    final weightText = _weightController.text.isNotEmpty ? _weightController.text : '--';
    final targetWeightText = _targetWeightController.text.isNotEmpty ? _targetWeightController.text : '--';
    final dailyMinutes = int.tryParse(_dailyMinutesController.text) ?? 30;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '准备就绪！',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '我们将根据您的信息生成个性化计划',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: 32),
        _buildSummaryCard('健身目标', _selectedGoal?.displayName ?? '未选择'),
        _buildSummaryCard('目标周期', '${_selectedDuration ?? 30}天'),
        if (_targetWeightController.text.isNotEmpty)
          _buildSummaryCard('目标体重', '${targetWeightText}kg'),
        _buildSummaryCard('性别', _selectedGender == 'male' ? '男' : _selectedGender == 'female' ? '女' : '未选择'),
        _buildSummaryCard('年龄', ageText),
        _buildSummaryCard('身高体重', '${heightText}cm / ${weightText}kg'),
        _buildSummaryCard('运动基础', _selectedFitnessLevel?.displayName ?? '未选择'),
        _buildSummaryCard('每日运动时长', '${dailyMinutes}分钟'),
        _buildSummaryCard('器械情况', _selectedEquipment?.displayName ?? '未选择'),
        if (_selectedDietType != null && _selectedDietType != DietType.none)
          _buildSummaryCard('饮食类型', _selectedDietType!.displayName),
        if (_selectedTaste != null)
          _buildSummaryCard('口味偏好', _selectedTaste!.displayName),
        if (_selectedRestrictions.isNotEmpty)
          _buildSummaryCard('饮食禁忌', _selectedRestrictions.join('、')),
        if (_hasHeartRateMonitor) _buildSummaryCard('心率设备', '已配置'),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 下一步
  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedGoal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择您的健身目标')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // 检查表单状态是否可用
      if (_formKey.currentState == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('表单加载中，请稍后再试')),
        );
        return;
      }
      if (!_formKey.currentState!.validate()) {
        return;
      }
      if (_selectedGender == null || _selectedFitnessLevel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请完善必填信息')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      // 限制条件可以跳过
    } else if (_currentStep == 3) {
      if (_selectedEquipment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择您的器械情况')),
        );
        return;
      }
    } else if (_currentStep == 4) {
      _saveProfile();
      return;
    }

    // 切换到下一步
    setState(() {
      _currentStep++;
    });
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 上一步
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 保存用户画像
  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(userProfileRepositoryProvider);

      // 验证必填字段
      if (_selectedGoal == null ||
          _selectedGender == null ||
          _selectedFitnessLevel == null ||
          _selectedEquipment == null ||
          _ageController.text.isEmpty ||
          _heightController.text.isEmpty ||
          _weightController.text.isEmpty) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请完善所有必填信息'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final profile = UserProfilesCompanion.insert(
        goalType: _selectedGoal!.value,
        gender: _selectedGender!,
        age: int.parse(_ageController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        fitnessLevel: _selectedFitnessLevel!.value,
        equipmentType: _selectedEquipment!.value,
        dietType: drift.Value(_selectedDietType?.value ?? 'none'),
        hasHeartRateMonitor: drift.Value(_hasHeartRateMonitor),
        // 可选字段
        goalDurationDays: _selectedDuration != null ? drift.Value(_selectedDuration!) : const drift.Value.absent(),
        targetWeight: double.tryParse(_targetWeightController.text) != null ? drift.Value(double.tryParse(_targetWeightController.text)!) : const drift.Value.absent(),
        targetBodyFat: double.tryParse(_bodyFatController.text) != null ? drift.Value(double.tryParse(_bodyFatController.text)!) : const drift.Value.absent(),
        bodyFat: double.tryParse(_bodyFatController.text) != null ? drift.Value(double.tryParse(_bodyFatController.text)!) : const drift.Value.absent(),
        dietaryRestrictions: _selectedRestrictions.isNotEmpty ? drift.Value(UserProfileRepository.formatJsonList(_selectedRestrictions)) : const drift.Value.absent(),
        allergies: _selectedAllergies.isNotEmpty ? drift.Value(UserProfileRepository.formatJsonList(_selectedAllergies)) : const drift.Value.absent(),
        injuries: _selectedInjuries.isNotEmpty ? drift.Value(UserProfileRepository.formatJsonList(_selectedInjuries)) : const drift.Value.absent(),
        dailyWorkoutMinutes: int.tryParse(_dailyMinutesController.text) != null ? drift.Value(int.tryParse(_dailyMinutesController.text)!) : const drift.Value.absent(),
        tastePreference: _selectedTaste != null ? drift.Value(_selectedTaste!.value) : const drift.Value.absent(),
        preferredWorkouts: _preferredWorkouts.isNotEmpty ? drift.Value(UserProfileRepository.formatJsonList(_preferredWorkouts)) : const drift.Value.absent(),
        dislikedWorkouts: _dislikedWorkouts.isNotEmpty ? drift.Value(UserProfileRepository.formatJsonList(_dislikedWorkouts)) : const drift.Value.absent(),
      );

      debugPrint('开始保存用户画像...');
      final profileId = await repo.createProfile(profile);
      debugPrint('用户画像保存成功，ID: $profileId');

      if (mounted) {
        setState(() => _isSaving = false);

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像创建成功！正在生成计划...'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // 等待一小段时间让用户看到提示
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          // 使用push而不是go，确保可以返回
          final route = AppRoutes.coachPlanGeneration.replaceAll(':profileId', profileId.toString());
          debugPrint('跳转到路由: $route');
          context.push(route);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('保存用户画像失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () => _saveProfile(),
            ),
          ),
        );
      }
    }
  }

  /// 保存并退出
  void _saveAndExit() {
    // 如果已有选择，保存当前进度
    if (_selectedGoal != null && !_isSaving) {
      _saveProfile();
    } else {
      Navigator.of(context).pop();
    }
  }
}
