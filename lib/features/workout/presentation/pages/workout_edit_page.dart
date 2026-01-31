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
    );

    try {
      // 保存运动记录
      final workoutId = await workoutRepo.createWorkout(workout);

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
  void _askToCreateNote(int workoutId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成运动笔记'),
        content: const Text('是否为这次运动生成一篇小结笔记？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 直接退出，不生成笔记
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_selectedPlanId != null
                      ? '运动记录已保存，计划任务已自动完成'
                      : '运动记录已保存'),
                  backgroundColor: AppColors.success,
                ),
              );
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

  /// 创建运动笔记
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
    } catch (e) {
      // 静默失败，不影响主流程
      debugPrint('完成计划任务失败: $e');
    }
  }
}
