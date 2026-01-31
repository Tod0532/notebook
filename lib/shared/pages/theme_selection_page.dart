/// 主题选择页面 - 展示所有可用主题供用户选择
/// 每个主题都有预览卡片，点击即可切换

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/theme/app_themes.dart';
import 'package:thick_notepad/core/providers/theme_provider.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';

/// 主题选择页面
class ThemeSelectionPage extends ConsumerWidget {
  const ThemeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题选择'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 当前主题提示
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: ThemeFactory.getPrimaryGradient(currentTheme),
              borderRadius: AppRadius.lgRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, color: Colors.white),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前主题',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        themeNames[currentTheme] ?? '未知主题',
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
          ),

          // 主题列表
          ...AppTheme.values.map((theme) {
            final isSelected = theme == currentTheme;
            return AnimatedListItem(
              index: theme.index,
              child: _ThemePreviewCard(
                theme: theme,
                isSelected: isSelected,
                onTap: () => _selectTheme(ref, theme),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _selectTheme(WidgetRef ref, AppTheme theme) {
    ref.read(themeNotifierProvider.notifier).setTheme(theme);
  }
}

/// 主题预览卡片
class _ThemePreviewCard extends StatelessWidget {
  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ThemeFactory.getSurface(theme),
              borderRadius: AppRadius.lgRadius,
              border: Border.all(
                color: isSelected
                    ? ThemeFactory.getPrimary(theme)
                    : AppColors.dividerColor.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ThemeFactory.getPrimary(theme).withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：标题和选中标识
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        themeNames[theme] ?? '未知主题',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ThemeFactory.getTextPrimary(theme),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: ThemeFactory.getPrimaryGradient(theme),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '当前',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // 颜色预览条
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ColorPreview(
                      color: ThemeFactory.getPrimary(theme),
                      label: '主色',
                    ),
                    _GradientPreview(
                      gradient: ThemeFactory.getPrimaryGradient(theme),
                      label: '主渐变',
                    ),
                    _GradientPreview(
                      gradient: ThemeFactory.getSecondaryGradient(theme),
                      label: '次渐变',
                    ),
                    _GradientPreview(
                      gradient: ThemeFactory.getSuccessGradient(theme),
                      label: '成功',
                    ),
                    _GradientPreview(
                      gradient: ThemeFactory.getWarningGradient(theme),
                      label: '警告',
                    ),
                    _GradientPreview(
                      gradient: ThemeFactory.getErrorGradient(theme),
                      label: '错误',
                    ),
                  ],
                ),

                // 组件预览
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: ThemeFactory.getBackground(theme),
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: ThemeFactory.getPrimaryGradient(theme),
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: const Icon(
                          Icons.home,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '示例卡片',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ThemeFactory.getTextPrimary(theme),
                              ),
                            ),
                            Text(
                              '这是主题预览文本',
                              style: TextStyle(
                                fontSize: 12,
                                color: ThemeFactory.getTextSecondary(theme),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ThemeFactory.getTextSecondary(theme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 纯色预览
class _ColorPreview extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorPreview({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.dividerColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
      ],
    );
  }
}

/// 渐变预览
class _GradientPreview extends StatelessWidget {
  final LinearGradient gradient;
  final String label;

  const _GradientPreview({
    required this.gradient,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.dividerColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
      ],
    );
  }
}
