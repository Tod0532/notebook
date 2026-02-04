/// 用户反馈页面
/// 收集用户对训练计划和饮食计划的反馈，用于AI优化迭代

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 用户反馈页面
class FeedbackPage extends ConsumerStatefulWidget {
  final int? userProfileId;
  final int? workoutPlanId;
  final int? dietPlanId;

  const FeedbackPage({
    super.key,
    this.userProfileId,
    this.workoutPlanId,
    this.dietPlanId,
  });

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _specificItemsController = TextEditingController();

  FeedbackType _selectedType = FeedbackType.exercise;
  String? _selectedReasonExercise;
  String? _selectedReasonFood;
  String? _selectedItem;

  bool _isSubmitting = false;
  List<UserFeedback> _recentFeedbacks = [];

  // 常见问题快速选择
  final _commonExerciseIssues = const [
    {'icon': Icons.trending_up, 'title': '动作太难', 'reason': 'too_hard', 'color': AppColors.error},
    {'icon': Icons.trending_down, 'title': '动作太简单', 'reason': 'too_easy', 'color': AppColors.warning},
    {'icon': Icons.not_interested, 'title': '不喜欢这个动作', 'reason': 'dislike', 'color': AppColors.textHint},
    {'icon': Icons.fitness_center, 'title': '没有器械', 'reason': 'no_equipment', 'color': AppColors.info},
    {'icon': Icons.healing, 'title': '身体不适合', 'reason': 'injury', 'color': AppColors.error},
  ];

  final _commonFoodIssues = const [
    {'icon': Icons.shopping_basket, 'title': '买不到食材', 'reason': 'unavailable', 'color': AppColors.error},
    {'icon': Icons.restaurant, 'title': '太难做', 'reason': 'too_hard', 'color': AppColors.warning},
    {'icon': Icons.no_meals, 'title': '不喜欢吃', 'reason': 'dislike', 'color': AppColors.textHint},
    {'icon': Icons.sick, 'title': '过敏/不耐受', 'reason': 'allergy', 'color': AppColors.error},
    {'icon': Icons.attach_money, 'title': '太贵了', 'reason': 'too_expensive', 'color': AppColors.warning},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentFeedbacks();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _specificItemsController.dispose();
    super.dispose();
  }

  /// 加载最近的反馈记录
  Future<void> _loadRecentFeedbacks() async {
    if (widget.userProfileId == null) return;

    final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
    final feedbacks = await feedbackRepo.getRecentFeedbacks(
      userProfileId: widget.userProfileId,
      limit: 10,
    );

    setState(() {
      _recentFeedbacks = feedbacks;
    });
  }

  /// 提交反馈
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReasonExercise == null && _selectedReasonFood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择反馈原因'), backgroundColor: AppColors.error),
      );
      return;
    }

    final itemName = _specificItemsController.text.trim();
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入具体的动作或食材名称'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
      final reason = _selectedType == FeedbackType.exercise
          ? _selectedReasonExercise!
          : _selectedReasonFood!;

      await feedbackRepo.createFeedback(
        feedbackType: _selectedType,
        itemId: DateTime.now().millisecondsSinceEpoch,
        itemType: _selectedType.value,
        reason: reason,
        originalName: itemName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        userProfileId: widget.userProfileId,
      );

      await HapticHelper.success();

      if (mounted) {
        // 重新加载反馈记录
        await _loadRecentFeedbacks();

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedType == FeedbackType.exercise ? '训练反馈已提交！' : '饮食反馈已提交！'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: '查看反馈',
              textColor: Colors.white,
              onPressed: () {
                // 滚动到反馈记录列表
              },
            ),
          ),
        );

        // 重置表单
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// 重置表单
  void _resetForm() {
    _formKey.currentState?.reset();
    _notesController.clear();
    _specificItemsController.clear();
    setState(() {
      _selectedReasonExercise = null;
      _selectedReasonFood = null;
      _selectedItem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('反馈与优化'),
      elevation: 0,
      actions: [
        if (_recentFeedbacks.isNotEmpty)
          TextButton.icon(
            onPressed: () => _showFeedbackHistory(),
            icon: const Icon(Icons.history),
            label: const Text('历史'),
          ),
      ],
    );
  }

  /// 主体内容
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 反馈类型选择
            _buildFeedbackTypeSelector(),
            const SizedBox(height: 24),

            // 具体项目输入
            _buildSpecificItemInput(),
            const SizedBox(height: 24),

            // 反馈原因选择
            _buildReasonSelector(),
            const SizedBox(height: 24),

            // 详细说明
            _buildNotesInput(),
            const SizedBox(height: 24),

            // 提交按钮
            _buildSubmitButton(),

            // 最近的反馈记录
            if (_recentFeedbacks.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildRecentFeedbacksSection(),
            ],
          ],
        ),
      ),
    );
  }

  /// 反馈类型选择器
  Widget _buildFeedbackTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '反馈类型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<FeedbackType>(
          segments: const [
            ButtonSegment(
              value: FeedbackType.exercise,
              label: Text('训练动作'),
              icon: Icon(Icons.fitness_center),
            ),
            ButtonSegment(
              value: FeedbackType.food,
              label: Text('饮食食材'),
              icon: Icon(Icons.restaurant),
            ),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<FeedbackType> selected) {
            setState(() {
              _selectedType = selected.first;
              _selectedReasonExercise = null;
              _selectedReasonFood = null;
            });
            HapticHelper.lightTap();
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return AppColors.primary.withOpacity(0.1);
              }
              return null;
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return AppColors.primary;
              }
              return null;
            }),
          ),
        ),
      ],
    );
  }

  /// 具体项目输入
  Widget _buildSpecificItemInput() {
    final hintText = _selectedType == FeedbackType.exercise
        ? '如：俯卧撑、深蹲、哑铃卧推...'
        : '如：鸡胸肉、西兰花、燕麦片...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedType == FeedbackType.exercise ? '训练动作名称' : '食材名称',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _specificItemsController,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(_selectedType == FeedbackType.exercise
                ? Icons.fitness_center
                : Icons.restaurant),
            suffixIcon: _specificItemsController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _specificItemsController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入具体名称';
            }
            return null;
          },
        ),
        // 常见项目快速选择
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getCommonItems().map((item) {
            return _buildCommonItemChip(item);
          }).toList(),
        ),
      ],
    );
  }

  /// 获取常见项目
  List<String> _getCommonItems() {
    if (_selectedType == FeedbackType.exercise) {
      return ['俯卧撑', '深蹲', '卷腹', '平板支撑', '哑铃弯举', '箭步蹲', '臀桥', '开合跳'];
    } else {
      return ['鸡胸肉', '西兰花', '燕麦片', '鸡蛋', '牛奶', '红薯', '糙米', '三文鱼'];
    }
  }

  /// 常见项目标签
  Widget _buildCommonItemChip(String item) {
    return ActionChip(
      label: Text(item),
      onPressed: () {
        _specificItemsController.text = item;
        setState(() {});
        HapticHelper.lightTap();
      },
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
    );
  }

  /// 反馈原因选择器
  Widget _buildReasonSelector() {
    final issues = _selectedType == FeedbackType.exercise
        ? _commonExerciseIssues
        : _commonFoodIssues;

    final selectedReason = _selectedType == FeedbackType.exercise
        ? _selectedReasonExercise
        : _selectedReasonFood;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '反馈原因',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...issues.map((issue) {
          final reason = issue['reason'] as String;
          final isSelected = selectedReason == reason;
          final color = issue['color'] as Color;
          final icon = issue['icon'] as IconData;
          final title = issue['title'] as String;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_selectedType == FeedbackType.exercise) {
                    _selectedReasonExercise = reason;
                  } else {
                    _selectedReasonFood = reason;
                  }
                });
                HapticHelper.lightTap();
              },
              borderRadius: AppRadius.mdRadius,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : AppColors.surfaceVariant,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(
                    color: isSelected ? color : AppColors.dividerColor.withOpacity(0.5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withOpacity(0.1),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 详细说明输入
  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '详细说明（可选）',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_notesController.text.length}/200',
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: '补充说明您的具体需求或建议...',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  /// 提交按钮
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '提交反馈',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// 最近反馈记录区域
  Widget _buildRecentFeedbacksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '最近反馈',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showFeedbackHistory(),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _recentFeedbacks.take(3).length,
          (index) => _buildFeedbackItem(_recentFeedbacks[index]),
        ),
      ],
    );
  }

  /// 反馈记录项
  Widget _buildFeedbackItem(UserFeedback feedback) {
    final isExercise = feedback.feedbackType == 'exercise';
    final icon = isExercise ? Icons.fitness_center : Icons.restaurant;
    final color = isExercise ? AppColors.primary : AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.originalName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getReasonText(feedback.reason),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(feedback.createdAt),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示反馈历史
  void _showFeedbackHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖动条
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 头部
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '反馈历史',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_recentFeedbacks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _clearAllFeedbacks(),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清空'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 列表
              Expanded(
                child: _recentFeedbacks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feedback_outlined, size: 64, color: AppColors.textHint),
                            SizedBox(height: 16),
                            Text(
                              '还没有反馈记录',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentFeedbacks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildFeedbackItem(_recentFeedbacks[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 清空所有反馈
  Future<void> _clearAllFeedbacks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空反馈记录'),
        content: const Text('确定要清空所有反馈记录吗？此操作不可恢复。'),
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
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (widget.userProfileId == null) return;

    try {
      final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
      await feedbackRepo.clearFeedbacksByProfile(widget.userProfileId!);
      await _loadRecentFeedbacks();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('反馈记录已清空'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 获取原因文本
  String _getReasonText(String reason) {
    final exerciseReasons = {
      'too_hard': '太难了',
      'too_easy': '太简单了',
      'dislike': '不喜欢',
      'no_equipment': '没有器械',
      'injury': '身体不适合',
    };
    final foodReasons = {
      'unavailable': '买不到',
      'too_hard': '太难做',
      'dislike': '不喜欢吃',
      'allergy': '过敏/不耐受',
      'too_expensive': '太贵了',
    };

    return exerciseReasons[reason] ?? foodReasons[reason] ?? reason;
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
