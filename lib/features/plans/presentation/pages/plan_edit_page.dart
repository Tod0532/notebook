/// 计划编辑页面 - 新建计划时使用
/// 创建后跳转到 PlanDetailPage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';
import 'package:thick_notepad/features/plans/presentation/pages/plan_template_select_page.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// 计划编辑页面
class PlanEditPage extends ConsumerStatefulWidget {
  const PlanEditPage({super.key});

  @override
  ConsumerState<PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends ConsumerState<PlanEditPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String _selectedCategory = 'other';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _savePlan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 模板选择入口
                      _buildTemplateSelector(context),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        style: Theme.of(context).textTheme.titleLarge,
                        decoration: const InputDecoration(
                          hintText: '计划标题',
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: '描述（可选）',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                      ),
                      const SizedBox(height: 16),
                      // 分类选择
                      _buildCategorySelector(context),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 模板选择入口
  Widget _buildTemplateSelector(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlanTemplateSelectPage(),
          ),
        );
        // 如果用户选择了模板，可以在这里处理返回结果
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已使用模板创建计划')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.accent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dashboard_customize,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用模板快速创建',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '从预设模板中选择，一键创建计划',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CategoryChip(
              label: '运动',
              value: 'workout',
              selected: _selectedCategory == 'workout',
              onTap: () => setState(() => _selectedCategory = 'workout'),
            ),
            _CategoryChip(
              label: '习惯',
              value: 'habit',
              selected: _selectedCategory == 'habit',
              onTap: () => setState(() => _selectedCategory = 'habit'),
            ),
            _CategoryChip(
              label: '学习',
              value: 'study',
              selected: _selectedCategory == 'study',
              onTap: () => setState(() => _selectedCategory = 'study'),
            ),
            _CategoryChip(
              label: '工作',
              value: 'work',
              selected: _selectedCategory == 'work',
              onTap: () => setState(() => _selectedCategory = 'work'),
            ),
            _CategoryChip(
              label: '其他',
              value: 'other',
              selected: _selectedCategory == 'other',
              onTap: () => setState(() => _selectedCategory = 'other'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _savePlan() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入计划标题')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(planRepositoryProvider);
      final planId = await repo.createPlan(
        PlansCompanion.insert(
          title: title,
          category: _selectedCategory,
          description: drift.Value(_descriptionController.text.trim()),
          startDate: DateTime.now(),
          targetDate: DateTime.now().add(const Duration(days: 30)),
        ),
      );

      if (mounted) {
        // 跳转到计划详情页
        context.push('${AppRoutes.plans}/$planId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}
