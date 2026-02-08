/// 计划模板选择页面
/// 用户可以从预设模板中快速创建计划

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/plans/data/models/plan_template.dart';
import 'package:thick_notepad/features/plans/data/services/plan_template_service.dart';
import 'package:thick_notepad/core/config/providers.dart';

/// 模板选择页面
class PlanTemplateSelectPage extends ConsumerStatefulWidget {
  const PlanTemplateSelectPage({super.key});

  @override
  ConsumerState<PlanTemplateSelectPage> createState() => _PlanTemplateSelectPageState();
}

class _PlanTemplateSelectPageState extends ConsumerState<PlanTemplateSelectPage> {
  PlanTemplateCategory? _selectedCategory;
  TemplateDifficulty? _selectedDifficulty;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择计划模板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 分类筛选
          _buildCategoryFilter(),
          // 难度筛选
          _buildDifficultyFilter(),
          // 模板列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTemplateList(),
          ),
        ],
      ),
    );
  }

  /// 搜索栏
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索模板...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: AppColors.surface,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  /// 分类筛选
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: '全部',
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ...PlanTemplateCategory.values.map(
            (cat) => _buildFilterChip(
              label: cat.label,
              selected: _selectedCategory == cat,
              onTap: () => setState(() => _selectedCategory = cat),
            ),
          ),
        ],
      ),
    );
  }

  /// 难度筛选
  Widget _buildDifficultyFilter() {
    if (_selectedCategory == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip(
            label: '全部难度',
            selected: _selectedDifficulty == null,
            onTap: () => setState(() => _selectedDifficulty = null),
          ),
          ...TemplateDifficulty.values.map(
            (diff) => _buildFilterChip(
              label: diff.label,
              selected: _selectedDifficulty == diff,
              onTap: () => setState(() => _selectedDifficulty = diff),
            ),
          ),
        ],
      ),
    );
  }

  /// 筛选按钮
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }

  /// 模板列表
  Widget _buildTemplateList() {
    // 获取筛选后的模板
    List<PlanTemplate> templates;

    if (_searchQuery.isNotEmpty) {
      templates = PlanTemplateService.searchTemplates(_searchQuery);
    } else if (_selectedCategory != null) {
      templates = PlanTemplateService.getTemplatesByCategory(_selectedCategory!);
      if (_selectedDifficulty != null) {
        templates = templates.where((t) => t.difficulty == _selectedDifficulty).toList();
      }
    } else {
      templates = PlanTemplateService.getAllTemplates();
    }

    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的模板',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        return _TemplateCard(
          template: templates[index],
          onTap: () => _selectTemplate(templates[index]),
        );
      },
    );
  }

  /// 选择模板
  Future<void> _selectTemplate(PlanTemplate template) async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(planRepositoryProvider);

      // 从模板创建计划
      final planData = PlanTemplateService.createPlanFromTemplate(template);
      final planId = await repo.createPlan(planData);

      // 创建模板任务
      final tasksData = PlanTemplateService.createTasksFromTemplate(template, planId);
      for (final task in tasksData) {
        await repo.createTask(task);
      }

      // 更新计划进度
      await repo.updatePlanProgress(planId);

      if (mounted) {
        // 先清除可能存在的旧SnackBar
        ScaffoldMessenger.of(context).clearSnackBars();
        // 返回上一页
        context.pop();
        // 跳转到计划详情页
        context.push('/plans/$planId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// 模板卡片
class _TemplateCard extends StatelessWidget {
  final PlanTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和标签
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildDifficultyChip(),
                ],
              ),
              const SizedBox(height: 8),
              // 分类标签
              Wrap(
                spacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.category,
                    label: template.category.label,
                    color: _getCategoryColor(template.category),
                  ),
                  _buildInfoChip(
                    icon: Icons.schedule,
                    label: '${template.estimatedDays}天',
                    color: AppColors.primary,
                  ),
                  _buildInfoChip(
                    icon: Icons.task_alt,
                    label: '${template.tasks.length}个任务',
                    color: AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 描述
              Text(
                template.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              // 推荐理由
              if (template.recommendation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          template.recommendation!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 任务预览
              if (template.tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  '任务预览',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...template.tasks.take(3).map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            task.isMilestone ? Icons.flag : Icons.check_circle_outline,
                            size: 16,
                            color: task.isMilestone
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.title,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (template.tasks.length > 3) ...[
                  const SizedBox(height: 4),
                  Text(
                    '还有 ${template.tasks.length - 3} 个任务...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 难度标签
  Widget _buildDifficultyChip() {
    Color color;
    switch (template.difficulty) {
      case TemplateDifficulty.easy:
        color = Colors.green;
        break;
      case TemplateDifficulty.medium:
        color = Colors.orange;
        break;
      case TemplateDifficulty.hard:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        template.difficulty.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 信息标签
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取分类颜色
  Color _getCategoryColor(PlanTemplateCategory category) {
    switch (category) {
      case PlanTemplateCategory.study:
        return Colors.blue;
      case PlanTemplateCategory.fitness:
        return Colors.green;
      case PlanTemplateCategory.work:
        return Colors.orange;
      case PlanTemplateCategory.life:
        return Colors.purple;
    }
  }
}
