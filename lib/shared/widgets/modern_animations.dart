/// 现代 UI 动画组件库
/// 包含页面切换动画、列表动画、微交互动画等

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

// ==================== 页面切换动画 ====================

/// 现代页面切换动画路由
class ModernPageTransition extends PageRouteBuilder {
  final Widget child;

  ModernPageTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}

/// 淡入淡出页面切换
class FadePageTransition extends PageRouteBuilder {
  final Widget child;

  FadePageTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
}

/// 缩放页面切换
class ScalePageTransition extends PageRouteBuilder {
  final Widget child;

  ScalePageTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}

// ==================== 列表项动画 ====================

/// 列表项动画构建器
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? duration;
  final Offset? beginOffset;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration,
    this.beginOffset,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = duration ?? const Duration(milliseconds: 300);
    final effectiveBegin = beginOffset ?? const Offset(0.3, 0.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: effectiveDuration,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * effectiveBegin.dx, (1 - value) * effectiveBegin.dy),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 交错列表动画
class StaggeredListView extends StatelessWidget {
  final List<Widget> children;
  final Duration? staggerDelay;
  final Duration? itemDuration;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const StaggeredListView({
    super.key,
    required this.children,
    this.staggerDelay,
    this.itemDuration,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStaggerDelay = staggerDelay ?? const Duration(milliseconds: 50);

    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          duration: itemDuration,
          child: children[index],
        );
      },
    );
  }
}

// ==================== 淡入动画组件 ====================

/// 自动淡入组件
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;
  final Curve curve;

  const FadeIn({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
    this.curve = Curves.easeOut,
  });

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    // 根据延迟启动动画
    final delay = widget.delay == DelayDuration.short
        ? const Duration(milliseconds: 100)
        : widget.delay == DelayDuration.medium
            ? const Duration(milliseconds: 200)
            : widget.delay == DelayDuration.long
                ? const Duration(milliseconds: 400)
                : Duration.zero;

    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }
}

/// 滑入动画组件
class SlideIn extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;
  final SlideDirection direction;
  final double distance;

  const SlideIn({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
    this.direction = SlideDirection.up,
    this.distance = 30.0,
  });

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 400),
      vsync: this,
    );

    Offset begin;
    switch (widget.direction) {
      case SlideDirection.up:
        begin = Offset(0, widget.distance / 100);
        break;
      case SlideDirection.down:
        begin = Offset(0, -widget.distance / 100);
        break;
      case SlideDirection.left:
        begin = Offset(widget.distance / 100, 0);
        break;
      case SlideDirection.right:
        begin = Offset(-widget.distance / 100, 0);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    final delay = widget.delay == DelayDuration.short
        ? const Duration(milliseconds: 100)
        : widget.delay == DelayDuration.medium
            ? const Duration(milliseconds: 200)
            : widget.delay == DelayDuration.long
                ? const Duration(milliseconds: 400)
                : Duration.zero;

    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _controller,
        child: widget.child,
      ),
    );
  }
}

/// 缩放动画组件
class ScaleIn extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;
  final double beginScale;

  const ScaleIn({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
    this.beginScale = 0.8,
  });

  @override
  State<ScaleIn> createState() => _ScaleInState();
}

class _ScaleInState extends State<ScaleIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    final delay = widget.delay == DelayDuration.short
        ? const Duration(milliseconds: 100)
        : widget.delay == DelayDuration.medium
            ? const Duration(milliseconds: 200)
            : widget.delay == DelayDuration.long
                ? const Duration(milliseconds: 400)
                : Duration.zero;

    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _controller,
        child: widget.child,
      ),
    );
  }
}

// ==================== 按钮动画 ====================

/// 脉冲动画按钮
class PulseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration? pulseDuration;

  const PulseButton({
    super.key,
    required this.child,
    this.onPressed,
    this.pulseDuration,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.pulseDuration ?? const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ==================== 加载动画 ====================

/// 现代加载指示器（已优化为简化版，性能更好）
/// 保留原有组件作为兼容，内部使用简化实现
class ModernLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;

  const ModernLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleLoadingIndicator(
      color: color,
      size: size,
    );
  }
}

/// 简化版加载指示器 - 使用 Flutter 内置组件
/// 性能更好，动画更流畅
class SimpleLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;

  const SimpleLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? 40,
      height: size ?? 40,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
        strokeWidth: 3,
      ),
    );
  }
}

/// 小型加载指示器 - 用于按钮内
class SmallLoadingIndicator extends StatelessWidget {
  final Color? color;

  const SmallLoadingIndicator({
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
        strokeWidth: 2,
      ),
    );
  }
}

// ==================== 枚举定义 ====================

/// 延迟时长枚举
enum DelayDuration { none, short, medium, long }

/// 滑入方向枚举
enum SlideDirection { up, down, left, right }

// ==================== 便捷扩展 ====================

/// 为 Widget 添加淡入动画的扩展
extension FadeInExtension on Widget {
  Widget fadeIn({
    Duration? duration,
    DelayDuration delay = DelayDuration.none,
    Curve curve = Curves.easeOut,
  }) {
    return FadeIn(
      duration: duration,
      delay: delay,
      curve: curve,
      child: this,
    );
  }
}

/// 为 Widget 添加滑入动画的扩展
extension SlideInExtension on Widget {
  Widget slideIn({
    Duration? duration,
    DelayDuration delay = DelayDuration.none,
    SlideDirection direction = SlideDirection.up,
    double distance = 30.0,
  }) {
    return SlideIn(
      duration: duration,
      delay: delay,
      direction: direction,
      distance: distance,
      child: this,
    );
  }
}

/// 为 Widget 添加缩入动画的扩展
extension ScaleInExtension on Widget {
  Widget scaleIn({
    Duration? duration,
    DelayDuration delay = DelayDuration.none,
    double beginScale = 0.8,
  }) {
    return ScaleIn(
      duration: duration,
      delay: delay,
      beginScale: beginScale,
      child: this,
    );
  }
}
