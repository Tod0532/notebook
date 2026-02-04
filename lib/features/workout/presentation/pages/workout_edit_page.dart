/// 运动记录页

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/date_formatter.dart';
import 'package:thick_notepad/core/utils/provider_invalidator.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/workout/presentation/widgets/workout_type_selector.dart';
import 'package:thick_notepad/features/workout/presentation/widgets/plan_selector.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/ai/plan_integration_service.dart';
import 'package:thick_notepad/services/gps/gps_tracking_service.dart';
import 'package:thick_notepad/services/gps/gps_route_repository.dart';
import 'package:thick_notepad/services/calories/calorie_calculator_service.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';
import 'package:drift/drift.dart' as drift;

/// 运动记录页
class WorkoutEditPage extends ConsumerStatefulWidget {
  const WorkoutEditPage({super.key});

  @override
  ConsumerState<WorkoutEditPage> createState() => _WorkoutEditPageState();
}

class _WorkoutEditPageState extends ConsumerState<WorkoutEditPage> {
  WorkoutType? _selectedType;
  int? _selectedPlanId;
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  FeelingLevel? _feeling;
  DateTime _startTime = DateTime.now();

  // 力量训练字段
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  // GPS追踪数据
  double? _gpsDistance; // 米
  int? _gpsDuration; // 秒
  List<Map<String, dynamic>>? _gpsTrackPoints;
  GpsStatistics? _gpsStatistics; // GPS统计信息

  // 卡路里估算
  double? _estimatedCalories;

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStrength = _selectedType?.category == 'strength';

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录运动'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveWorkout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 运动类型选择
          WorkoutTypeSelector(
            selectedType: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
          ),
          const Divider(),
          // 基础信息
          _buildSection('基础信息'),
          _buildDateTimePicker(),
          _buildDurationInput(),
          // 卡路里估算预览
          if (_selectedType != null) ...[
            const SizedBox(height: 8),
            _buildCaloriesPreview(),
          ],

          // GPS追踪入口（仅对有氧运动显示）
          if (_selectedType?.category == 'cardio' || _selectedType?.category == 'sports') ...[
            const SizedBox(height: 16),
            _buildGpsTrackingCard(),
          ],

          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // 关联计划
          PlanSelector(
            selectedPlanId: _selectedPlanId,
            onSelected: (id) => setState(() => _selectedPlanId = id),
          ),
          const SizedBox(height: 16),
          // 力量训练详情
          if (isStrength) ...[
            _buildSection('训练详情'),
            _buildStrengthInputs(),
            const SizedBox(height: 16),
          ],
          // 感受
          _buildSection('运动感受'),
          _buildFeelingSelector(),
          const SizedBox(height: 16),
          // 备注
          _buildSection('备注'),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              hintText: '记录今天的运动感受...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedType == null ? null : _saveWorkout,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('保存记录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
            ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: Text(DateFormatter.formatMonthDayWeek(_startTime)),
        subtitle: Text(DateFormatter.formatTime(_startTime)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _selectDateTime,
      ),
    );
  }

  Widget _buildDurationInput() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: const Text('运动时长'),
        trailing: SizedBox(
          width: 100,
          child: TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              suffixText: '分钟',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStrengthField('组数', _setsController, '组'),
            const SizedBox(height: 12),
            _buildStrengthField('次数', _repsController, '次'),
            const SizedBox(height: 12),
            _buildStrengthField('重量', _weightController, 'kg'),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthField(String label, TextEditingController controller, String unit) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: unit,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeelingSelector() {
    return Card(
      child: Column(
        children: FeelingLevel.values.map((level) {
          return RadioListTile<FeelingLevel>(
            title: Text(level.displayName),
            value: level,
            groupValue: _feeling,
            onChanged: (value) {
              setState(() => _feeling = value);
            },
            activeColor: AppColors.primary,
          );
        }).toList(),
      ),
    );
  }

  /// GPS追踪卡片
  Widget _buildGpsTrackingCard() {
    final hasGpsData = _gpsDistance != null && _gpsDistance! > 0;

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.smRadius,
          ),
          child: const Icon(
            Icons.gps_fixed,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(hasGpsData ? 'GPS轨迹已记录' : '记录运动轨迹'),
        subtitle: hasGpsData
            ? Text('距离: ${_formatDistance(_gpsDistance!)}')
            : const Text('使用GPS记录运动路线和距离'),
        trailing: hasGpsData
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDistance(_gpsDistance!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _startGpsTracking,
                    tooltip: '重新记录',
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: _startGpsTracking,
      ),
    );
  }

  /// 格式化距离显示
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}米';
    }
    return '${(meters / 1000).toStringAsFixed(2)}公里';
  }

  /// 启动GPS追踪
  Future<void> _startGpsTracking() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择运动类型')),
      );
      return;
    }

    // 构建带查询参数的路由
    final uri = Uri(
      path: AppRoutes.workoutGpsTracking,
      queryParameters: {'type': _selectedType!.displayName},
    );

    final result = await context.push<Map<String, dynamic>>(uri.toString());

    if (result != null && mounted) {
      setState(() {
        _gpsDistance = result['distance'] as double?;
        _gpsDuration = result['duration'] as int?;
        _gpsTrackPoints = (result['trackPoints'] as List?)
            ?.cast<Map<String, dynamic>>();

        // 构建GPS统计对象
        if (_gpsDistance != null && _gpsDuration != null) {
          final duration = Duration(seconds: _gpsDuration!);
          final avgSpeed = _gpsDuration! > 0
              ? (_gpsDistance! / _gpsDuration!)
              : 0.0;
          _gpsStatistics = GpsStatistics(
            distance: _gpsDistance!,
            duration: duration,
            averageSpeed: avgSpeed,
            maxSpeed: result['maxSpeed'] as double? ?? avgSpeed,
            calories: result['calories'] as double? ?? 0,
            elevationGain: result['elevationGain'] as double?,
            elevationLoss: result['elevationLoss'] as double?,
          );
        }

        // 根据GPS数据自动填充时长
        if (_gpsDuration != null && _gpsDuration! > 0) {
          _durationController.text = (_gpsDuration! ~/ 60).toString();
        }

        // 更新卡路里估算
        _updateCaloriesEstimate();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS记录完成 - ${_formatDistance(_gpsDistance ?? 0)}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// 卡路里估算预览卡片
  Widget _buildCaloriesPreview() {
    _updateCaloriesEstimate();

    return Card(
      color: _selectedType?.category == 'cardio' || _selectedType?.category == 'sports'
          ? AppColors.primary.withOpacity(0.1)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.orange[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '预计消耗',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (_estimatedCalories != null)
                      Text(
                        CalorieCalculatorService.formatCalories(_estimatedCalories!),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      )
                    else
                      const Text(
                        '-- 千卡',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // 强度等级
            if (_selectedType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getIntensityColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getIntensityColor(), width: 1),
                ),
                child: Text(
                  _getIntensityLabel(),
                  style: TextStyle(
                    color: _getIntensityColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 更新卡路里估算
  void _updateCaloriesEstimate() {
    if (_selectedType == null) return;

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      setState(() => _estimatedCalories = null);
      return;
    }

    final service = CalorieCalculatorService();
    double calories;

    // 优先使用GPS统计的卡路里
    if (_gpsStatistics != null && _gpsStatistics!.calories > 0) {
      calories = _gpsStatistics!.calories;
    } else if (_gpsDistance != null && _gpsDistance! > 0) {
      // 使用GPS距离计算
      calories = service.calculateCaloriesWithDistance(
        workoutType: _selectedType!.name,
        durationMinutes: duration,
        distanceMeters: _gpsDistance!,
      );
    } else {
      // 基础计算
      final sets = int.tryParse(_setsController.text.trim());
      calories = service.calculateCalories(
        workoutType: _selectedType!.name,
        durationMinutes: duration,
      );

      // 力量训练加成
      if (sets != null && sets > 0) {
        calories += sets * 5;
      }
    }

    setState(() => _estimatedCalories = calories);
  }

  /// 获取运动强度颜色
  Color _getIntensityColor() {
    if (_estimatedCalories == null) return Colors.grey;

    if (_estimatedCalories! < 100) {
      return Colors.green;
    } else if (_estimatedCalories! < 200) {
      return Colors.blue;
    } else if (_estimatedCalories! < 400) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// 获取运动强度标签
  String _getIntensityLabel() {
    if (_estimatedCalories == null) return '--';

    if (_estimatedCalories! < 100) {
      return '轻度';
    } else if (_estimatedCalories! < 200) {
      return '中度';
    } else if (_estimatedCalories! < 400) {
      return '高度';
    } else {
      return '极高';
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _saveWorkout() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择运动类型')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的运动时长')),
      );
      return;
    }

    final workoutRepo = ref.read(workoutRepositoryProvider);
    final planRepo = ref.read(planRepositoryProvider);

    // 计算卡路里
    double? caloriesToSave;
    if (_gpsStatistics != null && _gpsStatistics!.calories > 0) {
      // 优先使用GPS统计的卡路里
      caloriesToSave = _gpsStatistics!.calories;
    } else {
      // 使用估算值
      _updateCaloriesEstimate();
      caloriesToSave = _estimatedCalories;
    }

    // 构建运动记录数据
    final workout = WorkoutsCompanion.insert(
      type: _selectedType!.name,
      startTime: _startTime,
      durationMinutes: duration,
      notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      sets: drift.Value(_setsController.text.trim().isEmpty ? null : int.tryParse(_setsController.text.trim())),
      reps: drift.Value(_repsController.text.trim().isEmpty ? null : int.tryParse(_repsController.text.trim())),
      weight: drift.Value(_weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text.trim())),
      feeling: drift.Value(_feeling?.name),
      linkedPlanId: drift.Value(_selectedPlanId),
      distance: drift.Value(_gpsDistance), // GPS距离
      calories: drift.Value(caloriesToSave), // 自动计算的卡路里
    );

    try {
      // 保存运动记录
      final workoutId = await workoutRepo.createWorkout(workout);

      // 如果有GPS追踪数据，保存到数据库
      if (workoutId > 0 && _gpsTrackPoints != null && _gpsTrackPoints!.isNotEmpty) {
        await _saveGpsRoute(workoutId);
      }

      // 如果选择了关联计划，自动完成今日相关任务
      if (_selectedPlanId != null && workoutId > 0) {
        await _completeTodayPlanTasks(_selectedPlanId!, workoutId);
      }

      // 使用统一的刷新工具类刷新相关的 Provider
      ProviderInvalidator.invalidateAfterWorkout(ref);

      if (workoutId > 0 && mounted) {
        // 询问是否生成笔记
        _askToCreateNote(workoutId);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  /// 询问是否生成运动笔记
  void _askToCreateNote(int workoutId) async {
    // 检查 AI 是否已配置
    final aiService = DeepSeekService.instance;
    await aiService.init();
    final useAI = aiService.isConfigured;

    if (!mounted) return;

    if (useAI) {
      // AI 已配置，提供两个选项
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成运动笔记'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择生成方式：'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
                title: const Text('AI 生成小结'),
                subtitle: const Text('使用 AI 自动生成专业的运动小结'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createAIWorkoutNote(workoutId);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_note, color: AppColors.secondary),
                title: const Text('手动生成'),
                subtitle: const Text('按固定模板生成运动小结'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createWorkoutNote(workoutId);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 只 pop 一次，关闭对话框即可
                Navigator.of(context).pop();
                // 延迟显示 SnackBar，避免与导航冲突
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_selectedPlanId != null
                            ? '运动记录已保存，计划任务已自动完成'
                            : '运动记录已保存'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                });
              },
              child: const Text('不用了'),
            ),
          ],
        ),
      );
    } else {
      // AI 未配置，直接使用手动生成
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成运动笔记'),
          content: const Text('是否为这次运动生成一篇小结笔记？'),
          actions: [
            TextButton(
              onPressed: () {
                // 只 pop 一次，关闭对话框即可
                Navigator.of(context).pop();
                // 延迟显示 SnackBar，避免与导航冲突
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_selectedPlanId != null
                            ? '运动记录已保存，计划任务已自动完成'
                            : '运动记录已保存'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                });
              },
              child: const Text('不用了'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createWorkoutNote(workoutId);
              },
              child: const Text('生成笔记', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }
  }

  /// 使用 AI 创建运动笔记
  Future<void> _createAIWorkoutNote(int workoutId) async {
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      final workoutRepo = ref.read(workoutRepositoryProvider);

      // 获取运动记录
      final workouts = await workoutRepo.getAllWorkouts();
      final workout = workouts.where((w) => w.id == workoutId).firstOrNull;

      if (workout == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('运动记录不存在')),
          );
        }
        return;
      }

      // 显示加载状态
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('AI 正在生成小结...'),
              ],
            ),
          ),
        );
      }

      // 使用 AI 生成笔记内容
      final aiService = DeepSeekService.instance;
      String content;

      try {
        content = await aiService.generateWorkoutSummary(
          workoutType: workout.type,
          durationMinutes: workout.durationMinutes,
          notes: workout.notes,
          feeling: workout.feeling,
          sets: workout.sets,
          reps: workout.reps,
          weight: workout.weight,
        );
      } catch (e) {
        // AI 生成失败，回退到手动生成
        if (mounted) {
          Navigator.of(context).pop(); // 关闭加载对话框
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI 生成失败: $e，已切换到手动生成'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        content = _buildNoteContent(workout);
      }

      // 生成笔记标题
      final now = DateTime.now();
      final title = '${workout.type} - ${DateFormatter.formatMonthDay(now)}';

      // 保存笔记并获取笔记ID
      final noteId = await noteRepo.createNote(
        NotesCompanion.insert(
          title: drift.Value(title),
          content: content,
        ),
      );

      // 更新运动记录的关联笔记ID
      if (noteId > 0) {
        await workoutRepo.updateLinkedNoteId(workoutId, noteId);
      }

      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        Navigator.of(context).pop(); // 关闭页面
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedPlanId != null
                ? '运动记录已保存，任务已完成，AI 笔记已生成'
                : '运动记录已保存，AI 笔记已生成'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成笔记失败: $e')),
        );
      }
    }
  }

  /// 创建运动笔记（手动模板）
  Future<void> _createWorkoutNote(int workoutId) async {
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      final workoutRepo = ref.read(workoutRepositoryProvider);

      // 获取运动记录
      final workouts = await workoutRepo.getAllWorkouts();
      final workout = workouts.where((w) => w.id == workoutId).firstOrNull;

      if (workout == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('运动记录不存在')),
          );
        }
        return;
      }

      // 生成笔记标题和内容
      final now = DateTime.now();
      final title = '${workout.type} - ${DateFormatter.formatMonthDay(now)}';

      // 构建笔记内容
      final content = _buildNoteContent(workout);

      // 保存笔记并获取笔记ID
      final noteId = await noteRepo.createNote(
        NotesCompanion.insert(
          title: drift.Value(title),
          content: content,
        ),
      );

      // 更新运动记录的关联笔记ID
      if (noteId > 0) {
        await workoutRepo.updateLinkedNoteId(workoutId, noteId);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedPlanId != null
                ? '运动记录已保存，任务已完成，笔记已生成'
                : '运动记录已保存，笔记已生成'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成笔记失败: $e')),
        );
      }
    }
  }

  /// 构建笔记内容
  String _buildNoteContent(dynamic workout) {
    final buffer = StringBuffer();

    buffer.writeln('# 运动小结');
    buffer.writeln();

    // 基本信息
    buffer.writeln('**运动类型**：${workout.type}');
    buffer.writeln('**运动时长**：${workout.durationMinutes} 分钟');

    if (workout.startTime != null) {
      buffer.writeln('**运动日期**：${DateFormatter.formatMonthDayWeek(workout.startTime)}');
    }

    // 卡路里消耗
    if (workout.calories != null && workout.calories! > 0) {
      buffer.writeln('**消耗卡路里**：${workout.calories!.toStringAsFixed(0)} 千卡');
    }

    // 力量训练详情
    if (workout.sets != null && workout.sets! > 0) {
      buffer.writeln();
      buffer.writeln('## 训练详情');
      buffer.writeln('- 组数：${workout.sets}');
      if (workout.reps != null) buffer.writeln('- 次数：${workout.reps}');
      if (workout.weight != null) buffer.writeln('- 重量：${workout.weight} kg');
    }

    // 运动感受
    if (workout.feeling != null) {
      final feelingMap = {
        'great': '很棒',
        'good': '不错',
        'normal': '适中',
        'tired': '疲惫',
        'exhausted': '力竭',
      };
      buffer.writeln();
      buffer.writeln('**运动感受**：${feelingMap[workout.feeling] ?? workout.feeling}');
    }

    // 备注
    if (workout.notes != null && workout.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## 备注');
      buffer.writeln(workout.notes);
    }

    return buffer.toString();
  }

  /// 完成今日计划中相关的运动任务
  Future<void> _completeTodayPlanTasks(int planId, int workoutId) async {
    try {
      final planRepo = ref.read(planRepositoryProvider);
      final todayTasks = await planRepo.getPlanTasks(planId);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // 查找今日的运动类型任务
      final todayWorkoutTasks = todayTasks.where((task) =>
          !task.isCompleted &&
          task.taskType == 'workout' &&
          task.scheduledDate.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          task.scheduledDate.isBefore(todayEnd)
      ).toList();

      // 自动完成这些任务
      for (final task in todayWorkoutTasks) {
        await planRepo.markTaskComplete(task.id);
      }

      // 刷新计划进度
      await planRepo.updatePlanProgress(planId);

      // 如果是 AI 训练计划，也进行打卡
      final integrationService = PlanIntegrationService.instance;
      await integrationService.completeWorkoutForPlan(workoutId, planId);
    } catch (e) {
      // 静默失败，不影响主流程
      debugPrint('完成计划任务失败: $e');
    }
  }

  /// 保存GPS路线数据
  Future<void> _saveGpsRoute(int workoutId) async {
    try {
      if (_gpsStatistics == null || _gpsTrackPoints == null) {
        debugPrint('没有GPS数据可保存');
        return;
      }

      // 将JSON数据转换为GpsPoint对象
      final gpsPoints = _gpsTrackPoints!.map((json) {
        return GpsPoint.fromJson(json);
      }).toList();

      final routeRepo = GpsRouteRepository.instance;
      final routeId = await routeRepo.saveRoute(
        workoutId: workoutId,
        workoutType: _getWorkoutTypeKey(_selectedType!.displayName),
        startTime: _startTime,
        endTime: _startTime.add(Duration(seconds: _gpsDuration ?? 0)),
        duration: _gpsDuration ?? 0,
        distance: _gpsDistance ?? 0,
        averageSpeed: _gpsStatistics!.averageSpeed,
        maxSpeed: _gpsStatistics!.maxSpeed,
        averagePace: _gpsStatistics!.averagePace,
        elevationGain: _gpsStatistics!.elevationGain,
        elevationLoss: _gpsStatistics!.elevationLoss,
        calories: _gpsStatistics!.calories,
        points: gpsPoints,
      );

      if (routeId > 0) {
        debugPrint('GPS路线已保存，ID: $routeId');
      } else {
        debugPrint('GPS路线保存失败');
      }
    } catch (e) {
      debugPrint('保存GPS路线失败: $e');
    }
  }

  /// 获取运动类型对应的键值
  String _getWorkoutTypeKey(String displayName) {
    const typeMap = {
      '跑步': 'running',
      '骑行': 'cycling',
      '游泳': 'swimming',
      '步行': 'walking',
      '徒步': 'hiking',
      '登山': 'climbing',
      '跳绳': 'jumpRope',
      'HIIT': 'hiit',
      '篮球': 'basketball',
      '足球': 'football',
      '羽毛球': 'badminton',
    };
    return typeMap[displayName] ?? 'other';
  }
}
