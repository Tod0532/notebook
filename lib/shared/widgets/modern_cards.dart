/// 现代 UI 卡片组件库
/// 包含渐变卡片、毛玻璃效果卡片等现代设计元素

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';

// ==================== 渐变卡片 ====================

/// 渐变卡片 - 带有美丽渐变背景和点击动画的卡片
class GradientCard extends StatefulWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final Border? border;

  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
    this.shadows,
    this.border,
  });

  @override
  State<GradientCard> createState() => _GradientCardState();

  /// 主色渐变卡片
  factory GradientCard.primary({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
  }) {
    return GradientCard(
      key: key,
      gradient: AppColors.primaryGradient,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      onTap: onTap,
      borderRadius: borderRadius,
      shadows: AppShadows.light,
    );
  }

  /// 辅助色渐变卡片（粉橙）
  factory GradientCard.secondary({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
  }) {
    return GradientCard(
      key: key,
      gradient: AppColors.secondaryGradient,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      onTap: onTap,
      borderRadius: borderRadius,
      shadows: AppShadows.light,
    );
  }

  /// 成功色渐变卡片
  factory GradientCard.success({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      key: key,
      gradient: AppColors.successGradient,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      onTap: onTap,
      shadows: AppShadows.light,
    );
  }

  /// 警告色渐变卡片
  factory GradientCard.warning({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      key: key,
      gradient: AppColors.warningGradient,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      onTap: onTap,
      shadows: AppShadows.light,
    );
  }
}

class _GradientCardState extends State<GradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;
    final effectiveShadows = widget.shadows ?? AppShadows.light;

    Widget cardWidget = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        borderRadius: effectiveBorderRadius,
        boxShadow: effectiveShadows,
        border: widget.border,
      ),
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardWidget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) async {
          _controller.reverse();
          await HapticHelper.lightTap();
          widget.onTap!();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

// ==================== 毛玻璃卡片 ====================

/// 毛玻璃卡片 - 半透明模糊背景效果 + 点击动画
/// 优化：根据明暗模式自动调整不透明度和边框
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final double? blur;
  final double? opacity;
  final BorderRadius? borderRadius;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blur,
    this.opacity,
    this.borderRadius,
    this.border,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 根据主题调整参数：浅色模式需要更高不透明度
    final effectiveOpacity = widget.opacity ?? (isDark ? 0.7 : 0.95);
    final effectiveBlur = widget.blur ?? (isDark ? 10.0 : 5.0);
    final effectiveBorder = widget.border ??
        Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.5),
          width: 1,
        );

    Widget cardWidget = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(effectiveOpacity)
            : Colors.white.withOpacity(effectiveOpacity),
        borderRadius: effectiveBorderRadius,
        border: effectiveBorder,
        boxShadow: AppShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      cardWidget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) async {
          _controller.reverse();
          await HapticHelper.lightTap();
          widget.onTap!();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

// ==================== 现代卡片 ====================

/// 现代卡片 - 带有微妙阴影和现代设计
/// 优化：确保触控目标最小尺寸为 44x44px（iOS 人机交互指南）
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool elevated;
  final Border? border;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.elevated = false,
    this.border,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;
    final effectiveBackgroundColor = widget.backgroundColor ?? AppColors.surface;
    final effectiveShadows = widget.elevated ? AppShadows.medium : AppShadows.light;

    Widget cardWidget = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: effectiveBorderRadius,
        boxShadow: effectiveShadows,
        border: widget.border ??
            Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5), width: 1),
      ),
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardWidget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) async {
          _scaleController.reverse();
          // 添加触觉反馈
          await HapticHelper.lightTap();
          widget.onTap!();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardWidget,
        ),
      );
    }

    // 确保最小触控目标尺寸（iOS HIG: 44x44pt）
    return Container(
      constraints: const BoxConstraints(
        minHeight: 44,
        minWidth: 44,
      ),
      child: cardWidget,
    );
  }
}

// ==================== 浮动卡片 ====================

/// 浮动卡片 - 带有更大阴影和点击动画的悬浮效果卡片
class FloatingCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Color? backgroundColor;

  const FloatingCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
    this.gradient,
    this.backgroundColor,
  });

  @override
  State<FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<FloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.xlRadius;

    Widget cardWidget = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        color: widget.backgroundColor ?? AppColors.surface,
        borderRadius: effectiveBorderRadius,
        boxShadow: AppShadows.medium,
      ),
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardWidget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) async {
          _controller.reverse();
          await HapticHelper.lightTap();
          widget.onTap!();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

// ==================== 图标卡片 ====================

/// 图标卡片 - 带图标的现代卡片
class IconCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? iconColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double? size;

  const IconCard({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.iconColor,
    this.backgroundColor,
    this.gradient,
    this.onTap,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveBackground = backgroundColor ?? effectiveIconColor.withOpacity(0.1);

    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size ?? 48,
            height: size ?? 48,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? effectiveBackground : null,
              borderRadius: AppRadius.lgRadius,
            ),
            child: Icon(
              icon,
              color: gradient != null ? Colors.white : effectiveIconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (value != null)
            Text(
              value!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: effectiveIconColor,
                  ),
            ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ==================== 统计卡片 ====================

/// 统计数据卡片 - 显示统计信息 + 波纹点击效果
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Gradient? gradient;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.gradient,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: effectiveIconColor,
              borderRadius: AppRadius.lgRadius,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      cardContent = Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          splashColor: effectiveIconColor.withOpacity(0.15),
          highlightColor: effectiveIconColor.withOpacity(0.08),
          child: cardContent,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.light,
        border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5), width: 1),
      ),
      child: cardContent,
    );
  }
}

// ==================== 闪烁卡片 ====================

/// 闪烁卡片 - 带有动画边框的卡片
class ShimmerCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: effectiveBorderRadius,
            boxShadow: AppShadows.light,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: effectiveBorderRadius,
              gradient: LinearGradient(
                begin: Alignment(_shimmerAnimation.value - 1, 0),
                end: Alignment(_shimmerAnimation.value + 1, 0),
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ==================== 设置项卡片 ====================

/// 设置项卡片 - 用于设置页面的选项卡片
class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: AppRadius.mdRadius,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onTap != null && trailing == null)
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
        ],
      ),
    );
  }
}
