/// 页面切换动画库
/// 提供多种现代页面过渡动画效果

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==================== 页面过渡动画类型 ====================

/// 页面过渡动画类型
enum PageTransitionType {
  /// 滑动+淡入（默认，从右侧滑入）
  slideFade,

  /// 缩放+淡入（从小到大）
  scaleFade,

  /// 旋转+淡入（带旋转效果）
  rotateFade,

  /// 淡入淡出（仅透明度变化）
  fade,

  /// 从上滑入
  slideFromTop,

  /// 从下滑入
  slideFromBottom,

  /// 缩放+旋转+淡入（组合效果）
  scaleRotateFade,
}

// ==================== 页面过渡动画类 ====================

/// 通用页面过渡路由
class PageTransitions {
  /// 创建自定义页面过渡动画
  static Route<T> buildRoute<T>({
    required Widget child,
    PageTransitionType type = PageTransitionType.slideFade,
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
    Curve curve = Curves.easeInOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration ?? const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildTransition(type, animation, child, curve);
      },
    );
  }

  /// 滑动+淡入过渡动画（从右侧）
  static Route<T> slideFadeRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) {
    return buildRoute(
      child: child,
      type: PageTransitionType.slideFade,
      duration: duration,
      curve: curve,
    );
  }

  /// 缩放+淡入过渡动画
  static Route<T> scaleFadeRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutBack,
  }) {
    return buildRoute(
      child: child,
      type: PageTransitionType.scaleFade,
      duration: duration,
      curve: curve,
    );
  }

  /// 淡入淡出过渡动画
  static Route<T> fadeRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) {
    return buildRoute(
      child: child,
      type: PageTransitionType.fade,
      duration: duration,
      curve: curve,
    );
  }

  /// 从上滑入过渡动画
  static Route<T> slideFromTopRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return buildRoute(
      child: child,
      type: PageTransitionType.slideFromTop,
      duration: duration,
      curve: curve,
    );
  }

  /// 从下滑入过渡动画
  static Route<T> slideFromBottomRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return buildRoute(
      child: child,
      type: PageTransitionType.slideFromBottom,
      duration: duration,
      curve: curve,
    );
  }

  /// 构建过渡动画
  static Widget _buildTransition(
    PageTransitionType type,
    Animation<double> animation,
    Widget child,
    Curve curve,
  ) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    switch (type) {
      case PageTransitionType.slideFade:
        return _SlideFadeTransition(
          animation: curvedAnimation,
          child: child,
        );

      case PageTransitionType.scaleFade:
        return _ScaleFadeTransition(
          animation: curvedAnimation,
          child: child,
        );

      case PageTransitionType.rotateFade:
        return _RotateFadeTransition(
          animation: curvedAnimation,
          child: child,
        );

      case PageTransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case PageTransitionType.slideFromTop:
        return _SlideFromTopTransition(
          animation: curvedAnimation,
          child: child,
        );

      case PageTransitionType.slideFromBottom:
        return _SlideFromBottomTransition(
          animation: curvedAnimation,
          child: child,
        );

      case PageTransitionType.scaleRotateFade:
        return _ScaleRotateFadeTransition(
          animation: curvedAnimation,
          child: child,
        );
    }
  }
}

// ==================== 过渡动画 Widget ====================

/// 滑动+淡入过渡
class _SlideFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 缩放+淡入过渡
class _ScaleFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _ScaleFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 旋转+淡入过渡
class _RotateFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _RotateFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0.05, end: 0.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}

/// 从上滑入过渡
class _SlideFromTopTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideFromTopTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, -1.0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 从下滑入过渡
class _SlideFromBottomTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideFromBottomTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 缩放+旋转+淡入组合过渡
class _ScaleRotateFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _ScaleRotateFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
      ),
      child: RotationTransition(
        turns: Tween<double>(begin: 0.1, end: 0.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}
