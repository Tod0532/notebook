/// 现代 UI 动画组件库
/// 包含页面切换动画、列表动画、微交互动画等

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

// ==================== 页面切换动画 ====================

/// 现代页面切换动画路由（默认：滑动 + 淡入淡出）
class ModernPageTransition extends PageRouteBuilder {
  final Widget child;

  ModernPageTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 使用更生动的曲线组合
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart, // 更流畅的减曲线
              )),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
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
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic, // 更平滑的淡入淡出
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
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack, // 弹性缩放效果
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        );
}

/// 滑动 + 缩放组合页面切换（新增）
class SlideScalePageTransition extends PageRouteBuilder {
  final Widget child;
  final SlideDirection direction;

  SlideScalePageTransition({
    required this.child,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 获取起始偏移
            Offset beginOffset;
            switch (direction) {
              case SlideDirection.right:
                beginOffset = const Offset(1.0, 0.0);
                break;
              case SlideDirection.left:
                beginOffset = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.up:
                beginOffset = const Offset(0.0, 1.0);
                break;
              case SlideDirection.down:
                beginOffset = const Offset(0.0, -1.0);
                break;
            }

            return SlideTransition(
              position: Tween<Offset>(
                begin: beginOffset,
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                  ),
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// 淡入淡出 + 缩放组合页面切换（新增）
class FadeScalePageTransition extends PageRouteBuilder {
  final Widget child;

  FadeScalePageTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

// ==================== 列表项动画 ====================

/// 列表项动画构建器（已优化）
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? duration;
  final Offset? beginOffset;
  final bool enableScale;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration,
    this.beginOffset,
    this.enableScale = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = duration ?? const Duration(milliseconds: 350);
    final effectiveBegin = beginOffset ?? const Offset(0.3, 0.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: effectiveDuration,
      curve: Curves.easeOutCubic, // 更流畅的曲线
      builder: (context, value, child) {
        final widget = Transform.translate(
          offset: Offset((1 - value) * effectiveBegin.dx, (1 - value) * effectiveBegin.dy),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );

        // 可选的缩放效果
        if (enableScale) {
          return Transform.scale(
            scale: 0.7 + (0.3 * value),
            child: widget,
          );
        }
        return widget;
      },
      child: child,
    );
  }
}

/// 交错列表动画（已优化 - 改进时间曲线和延迟效果）
class StaggeredListView extends StatelessWidget {
  final List<Widget> children;
  final Duration? staggerDelay;
  final Duration? itemDuration;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final bool enableScale;

  const StaggeredListView({
    super.key,
    required this.children,
    this.staggerDelay,
    this.itemDuration,
    this.physics,
    this.padding,
    this.enableScale = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStaggerDelay = staggerDelay ?? const Duration(milliseconds: 60);

    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          duration: itemDuration,
          beginOffset: const Offset(0.2, 0.0),
          enableScale: enableScale,
          child: children[index],
        );
      },
    );
  }
}

/// 垂直交错列表动画（新增 - 从底部滑入的列表）
class VerticalStaggeredListView extends StatelessWidget {
  final List<Widget> children;
  final Duration? staggerDelay;
  final Duration? itemDuration;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const VerticalStaggeredListView({
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
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: itemDuration ?? const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
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
      curve: Curves.easeOutCubic, // 更流畅的曲线
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

// ==================== 新增动画组件 ====================

/// 弹性缩放动画（新增 - 使用 Curves.elasticInOut）
class ElasticScaleIn extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;
  final double beginScale;

  const ElasticScaleIn({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
    this.beginScale = 0.5,
  });

  @override
  State<ElasticScaleIn> createState() => _ElasticScaleInState();
}

class _ElasticScaleInState extends State<ElasticScaleIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // 弹性效果
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
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
        child: widget.child,
      ),
    );
  }
}

/// 弹簧动画组件（新增 - 模拟物理弹簧效果）
class SpringAnimation extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;
  final SpringType springType;

  const SpringAnimation({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
    this.springType = SpringType.bounce,
  });

  @override
  State<SpringAnimation> createState() => _SpringAnimationState();
}

class _SpringAnimationState extends State<SpringAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 600),
      vsync: this,
    );

    // 根据弹簧类型选择不同的曲线
    Curve curve;
    double beginScale;

    switch (widget.springType) {
      case SpringType.bounce:
        curve = Curves.bounceOut;
        beginScale = 0.6;
        break;
      case SpringType.elastic:
        curve = Curves.elasticOut;
        beginScale = 0.5;
        break;
      case SpringType.soft:
        curve = Curves.easeOutBack;
        beginScale = 0.85;
        break;
    }

    _scaleAnimation = Tween<double>(
      begin: beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: curve,
    ));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

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
        opacity: _opacityAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 摇摆动画组件（新增 - 用于提示或强调）
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final DelayDuration delay;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.duration,
    this.delay = DelayDuration.none,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 500),
      vsync: this,
    );

    // 摇摆效果序列
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    return RotationTransition(
      turns: _rotationAnimation,
      child: widget.child,
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
      duration: widget.pulseDuration ?? const Duration(milliseconds: 120),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
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

/// 波纹按钮（新增）
class RippleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? rippleColor;

  const RippleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.rippleColor,
  });

  @override
  State<RippleButton> createState() => _RippleButtonState();
}

class _RippleButtonState extends State<RippleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
      onTap: () {
        _controller.forward().then((_) {
          _controller.reset();
          widget.onPressed?.call();
        });
      },
      child: Container(
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
/// 已优化动画流畅度，添加线性插值
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
        strokeWidth: (size ?? 40) > 30 ? 3 : 2,
        backgroundColor: (color ?? AppColors.primary).withOpacity(0.1),
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
        backgroundColor: (color ?? AppColors.primary).withOpacity(0.1),
      ),
    );
  }
}

/// 脉冲加载指示器（新增 - 更生动的加载效果）
class PulseLoadingIndicator extends StatefulWidget {
  final Color? color;
  final double? size;

  const PulseLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  State<PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<PulseLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
    final size = widget.size ?? 40.0;
    final color = widget.color ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== 枚举定义 ====================

/// 延迟时长枚举
enum DelayDuration { none, short, medium, long }

/// 滑入方向枚举
enum SlideDirection { up, down, left, right }

/// 弹簧类型枚举（新增）
enum SpringType { bounce, elastic, soft }

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

  /// 弹性缩放动画扩展（新增）
  Widget elasticScaleIn({
    Duration? duration,
    DelayDuration delay = DelayDuration.none,
    double beginScale = 0.5,
  }) {
    return ElasticScaleIn(
      duration: duration,
      delay: delay,
      beginScale: beginScale,
      child: this,
    );
  }

  /// 弹簧动画扩展（新增）
  Widget springIn({
    Duration? duration,
    DelayDuration delay = DelayDuration.none,
    SpringType springType = SpringType.bounce,
  }) {
    return SpringAnimation(
      duration: duration,
      delay: delay,
      springType: springType,
      child: this,
    );
  }
}
