/// 运动类型选择器

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/database/database.dart';

/// 运动类型选择器
class WorkoutTypeSelector extends StatelessWidget {
  final WorkoutType? selectedType;
  final ValueChanged<WorkoutType?> onSelected;

  const WorkoutTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = {
      'cardio': '有氧运动',
      'strength': '力量训练',
      'sports': '球类运动',
      'other': '其他运动',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择运动类型',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...categories.entries.map((entry) {
            return _buildCategory(context, entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String category, String label) {
    final types = WorkoutType.values.where((t) => t.category == category).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = selectedType == type;
            return FilterChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (_) => onSelected(isSelected ? null : type),
              backgroundColor: AppColors.surfaceVariant,
              selectedColor: _getCategoryColor(category).withOpacity(0.3),
              checkmarkColor: _getCategoryColor(category),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'cardio':
        return AppColors.cardioColor;
      case 'strength':
        return AppColors.strengthColor;
      case 'sports':
        return AppColors.sportsColor;
      default:
        return AppColors.otherColor;
    }
  }
}
