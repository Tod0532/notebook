/// 动画卡片组件
/// 为卡片提供点击缩放、长按、悬停等交互动画效果

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';

// ==================== 动画卡片配置 ====================

/// 动画卡片样式
enum AnimatedCardStyle {
  /// 默认缩放效果
  scale,

  /// 弹簧效果（回弹）
  spring,

  /// 仅波纹效果
  ripple,

  /// 缩放+波纹组合
  scaleWithRipple,

  /// 3D倾斜效果
  tilt3D,
}

/// 动画卡片配置
class AnimatedCardConfig {
  /// 点击缩放比例
  final double pressScale;

  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 波纹颜色
  final Color? splashColor;

  /// 高亮颜色
  final Color? highlightColor;

  /// 卡片样式
  final AnimatedCardStyle style;

  const AnimatedCardConfig({
    this.pressScale = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeInOut,
    this.enableHapticFeedback = true,
    this.splashColor,
    this.highlightColor,
    this.style = AnimatedCardStyle.scaleWithRipple,
  });

  /// 默认配置
  static const defaultConfig = AnimatedCardConfig();

  /// 弹簧效果配置
  static const springConfig = AnimatedCardConfig(
    pressScale = 0.92,
    duration = Duration(milliseconds: 200),
    curve = Curves.easeOutBack,
    style = AnimatedCardStyle.spring,
  );

  /// 快速响应配置
  static const quickConfig = AnimatedCardConfig(
    pressScale = 0.97,
    duration = Duration(milliseconds: 100),
  );

  /// 3D倾斜配置
  static const tiltConfig = AnimatedCardConfig(
    style = AnimatedCardStyle.tilt3D,
  );
}

// ==================== 动画卡片主组件 ====================

/// 动画卡片 - 带点击动画的卡片组件
/// 提供流畅的点击反馈动画效果
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final AnimatedCardConfig? config;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Decoration? decoration;
  final bool enabled;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.config,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.decoration,
    this.enabled = true,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // 3D倾斜相关
  Offset _panOffset = Offset.zero;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    final config = widget.config ?? AnimatedCardConfig.defaultConfig;
    final curve = config.style == AnimatedCardStyle.spring
        ? Curves.easeOutBack
        : config.curve;

    _controller = AnimationController(
      duration: config.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: config.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: curve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) async {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();

    final config = widget.config ?? AnimatedCardConfig.defaultConfig;
    if (config.enableHapticFeedback) {
      await HapticHelper.lightTap();
    }

    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.config?.style == AnimatedCardStyle.tilt3D) {
      setState(() {
        _panOffset = details.localPosition;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.config?.style == AnimatedCardStyle.tilt3D) {
      setState(() {
        _panOffset = Offset.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config ?? AnimatedCardConfig.defaultConfig;
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: widget.decoration ??
          BoxDecoration(
            color: widget.backgroundColor ?? AppColors.surface,
            borderRadius: effectiveBorderRadius,
            border: widget.border,
            boxShadow: widget.boxShadow ?? AppShadows.light,
          ),
      child: widget.child,
    );

    // 根据样式应用不同的交互效果
    if (config.style == AnimatedCardStyle.ripple ||
        config.style == AnimatedCardStyle.scaleWithRipple) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          borderRadius: effectiveBorderRadius,
          splashColor: config.splashColor ?? AppColors.primary.withOpacity(0.15),
          highlightColor: config.highlightColor ?? AppColors.primary.withOpacity(0.08),
          child: content,
        ),
      );
    }

    if (config.style == AnimatedCardStyle.scaleWithRipple) {
      content = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: content,
          ),
        ),
      );
    } else if (config.style == AnimatedCardStyle.scale ||
        config.style == AnimatedCardStyle.spring) {
      content = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: content,
        ),
      );
    } else if (config.style == AnimatedCardStyle.tilt3D) {
      content = GestureDetector(
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: _TiltWidget(
          offset: _panOffset,
          isPressed: _isPressed,
          borderRadius: effectiveBorderRadius,
          child: content,
        ),
      );
    } else {
      // Ripple only
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          borderRadius: effectiveBorderRadius,
          splashColor: config.splashColor ?? AppColors.primary.withOpacity(0.2),
          highlightColor: config.highlightColor ?? AppColors.primary.withOpacity(0.1),
          child: content,
        ),
      );
    }

    // 确保最小触控目标尺寸
    return Container(
      constraints: const BoxConstraints(
        minHeight: 44,
        minWidth: 44,
      ),
      child: content,
    );
  }
}

// ==================== 3D倾斜效果组件 ====================

/// 3D倾斜效果 Widget
class _TiltWidget extends StatelessWidget {
  final Offset offset;
  final bool isPressed;
  final BorderRadius borderRadius;
  final Widget child;

  const _TiltWidget({
    required this.offset,
    required this.isPressed,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 计算倾斜角度（限制最大角度）
    final maxTilt = 0.05; // 最大倾斜弧度
    final tiltX = ((offset.dy - 50) / 100).clamp(-maxTilt, maxTilt);
    final tiltY = ((offset.dx - 50) / 100).clamp(-maxTilt, maxTilt);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isPressed ? 0.95 : 1.0),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 透视效果
            ..rotateX(isPressed ? 0 : tiltX)
            ..rotateY(isPressed ? 0 : -tiltY)
            ..scale(scale),
          child: child,
        );
      },
      child: child,
    );
  }
}

// ==================== 渐变动画卡片 ====================

/// 渐变动画卡片 - 带渐变背景的动画卡片
class AnimatedGradientCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Gradient gradient;
  final AnimatedCardConfig? config;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;

  const AnimatedGradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.onTap,
    this.config,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.shadows,
  });

  @override
  State<AnimatedGradientCard> createState() => _AnimatedGradientCardState();
}

class _AnimatedGradientCardState extends State<AnimatedGradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.lgRadius;
    final effectiveShadows = widget.shadows ?? AppShadows.light;

    return GestureDetector(
      onTapDown: (_) => _shimmerController.forward(),
      onTapUp: (_) {
        _shimmerController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _shimmerController.reverse(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: effectiveBorderRadius,
          boxShadow: effectiveShadows,
        ),
        padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: widget.child,
      ),
    );
  }
}

// ==================== 玻璃态动画卡片 ====================

/// 玻璃态动画卡片 - 毛玻璃效果 + 交互动画
class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AnimatedGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.blur = 10.0,
    this.opacity = 0.7,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        _controller.reverse();
        await HapticHelper.lightTap();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(widget.opacity)
                : Colors.white.withOpacity(widget.opacity),
            borderRadius: effectiveBorderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : AppColors.dividerColor.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 便捷工厂方法 ====================

/// 动画卡片便捷工厂方法
class AnimatedCardFactory {
  /// 创建带主色渐变的动画卡片
  static Widget primaryGradient({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return AnimatedGradientCard(
      key: key,
      gradient: AppColors.primaryGradient,
      onTap: onTap,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      borderRadius: borderRadius,
      shadows: AppShadows.light,
    );
  }

  /// 创建带辅助色渐变的动画卡片
  static Widget secondaryGradient({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return AnimatedGradientCard(
      key: key,
      gradient: AppColors.secondaryGradient,
      onTap: onTap,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      borderRadius: borderRadius,
      shadows: AppShadows.light,
    );
  }

  /// 创建玻璃态动画卡片
  static Widget glass({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    double blur = 10.0,
  }) {
    return AnimatedGlassCard(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      borderRadius: borderRadius,
      blur: blur,
    );
  }

  /// 创建弹簧效果动画卡片
  static Widget spring({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? backgroundColor,
  }) {
    return AnimatedCard(
      key: key,
      config: AnimatedCardConfig.springConfig,
      onTap: onTap,
      child: child,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
    );
  }
}
