/// 主题色选择页面 - 允许用户选择预设主题色或自定义颜色
/// 展示所有预设主题供用户选择，支持自定义颜色

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/theme/app_color_scheme.dart';
import 'package:thick_notepad/core/providers/theme_provider.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';

/// 主题色选择页面
class ColorSelectionPage extends ConsumerStatefulWidget {
  const ColorSelectionPage({super.key});

  @override
  ConsumerState<ColorSelectionPage> createState() => _ColorSelectionPageState();
}

class _ColorSelectionPageState extends ConsumerState<ColorSelectionPage> {
  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(currentCustomColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题色选择'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 当前主题色提示
          _CurrentColorIndicator(currentColor: currentColor),

          const SizedBox(height: AppSpacing.lg),

          // 预设主题色标题
          _SectionTitle(title: '预设主题色', count: AppThemeColor.all.length),

          const SizedBox(height: AppSpacing.md),

          // 预设主题色网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1,
            ),
            itemCount: AppThemeColor.all.length,
            itemBuilder: (context, index) {
              final color = AppThemeColor.all[index];
              final isSelected = color.name == currentColor.name;
              return AnimatedListItem(
                index: index,
                child: _ColorCard(
                  color: color,
                  isSelected: isSelected,
                  onTap: () => _selectColor(color),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 自定义颜色标题
          _SectionTitle(title: '自定义颜色', count: 0),

          const SizedBox(height: AppSpacing.md),

          // 自定义颜色按钮
          _CustomColorButton(
            onTap: _showCustomColorPicker,
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _selectColor(AppThemeColor color) {
    ref.read(customColorNotifierProvider.notifier).setThemeColor(color);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换到 ${color.name}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }

  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) => const _CustomColorDialog(),
    );
  }
}

// ==================== 当前颜色指示器 ====================

class _CurrentColorIndicator extends StatelessWidget {
  final AppThemeColor currentColor;

  const _CurrentColorIndicator({required this.currentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: currentColor.primaryGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: [
          BoxShadow(
            color: currentColor.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: AppRadius.mdRadius,
            ),
            child: Icon(Icons.palette_outlined, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前主题色',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Text(
                  currentColor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 区块标题 ====================

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.smRadius,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ==================== 颜色卡片 ====================

class _ColorCard extends StatelessWidget {
  final AppThemeColor color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCard({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          decoration: BoxDecoration(
            gradient: color.primaryGradient,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AppShadows.subtle,
          ),
          child: Stack(
            children: [
              // 颜色预览
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: AppRadius.lgRadius,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.primary,
                          color.secondary,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 内容
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜色圆圈
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 名称
                    Text(
                      color.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 选中标识
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: color.primary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 自定义颜色按钮 ====================

class _CustomColorButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomColorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: AppColors.dividerColor,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.tagColors.take(5).toList(),
                  ),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义颜色',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '选择任意颜色作为主题色',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 自定义颜色对话框 ====================

class _CustomColorDialog extends ConsumerStatefulWidget {
  const _CustomColorDialog();

  @override
  ConsumerState<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends ConsumerState<_CustomColorDialog> {
  Color _selectedColor = const Color(0xFF6366F1);

  // 常用颜色预设
  static const List<Color> presetColors = [
    Color(0xFF6366F1), // 靛蓝
    Color(0xFF10B981), // 翡翠绿
    Color(0xFFEC4899), // 樱花粉
    Color(0xFF8B5CF6), // 紫罗兰
    Color(0xFFF59E0B), // 琥珀橙
    Color(0xFF0284C7), // 海洋蓝
    Color(0xFFE11D48), // 玫瑰红
    Color(0xFF84CC16), // 青柠绿
    Color(0xFF6366F1), // 靛青
    Color(0xFF14B8A6), // 青色
    Color(0xFFF97316), // 橙色
    Color(0xFF8B5CF6), // 紫色
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择自定义颜色'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 颜色预览
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_selectedColor, _selectedColor.withValues(alpha: 0.7)],
              ),
              borderRadius: AppRadius.lgRadius,
            ),
            child: Center(
              child: Text(
                '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 颜色选择网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1,
            ),
            itemCount: presetColors.length,
            itemBuilder: (context, index) {
              final color = presetColors[index];
              final isSelected = color.value == _selectedColor.value;
              return InkWell(
                onTap: () => setState(() => _selectedColor = color),
                borderRadius: AppRadius.smRadius,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.smRadius,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
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
        FilledButton(
          onPressed: () {
            ref
                .read(customColorNotifierProvider.notifier)
                .setCustomColor('自定义', _selectedColor);
            Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已应用自定义颜色'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smRadius,
                  ),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: _selectedColor,
          ),
          child: const Text('应用'),
        ),
      ],
    );
  }
}
