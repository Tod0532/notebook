/// 列表交错动画组件
/// 让列表项依次进入，创造流畅的视觉效果

import 'package:flutter/material.dart';

// ==================== 交错动画配置 ====================

/// 交错动画配置
class StaggeredConfig {
  /// 每个项目的动画延迟
  final Duration itemDelay;

  /// 单个项目动画时长
  final Duration itemDuration;

  /// 动画曲线
  final Curve curve;

  /// 滑动距离
  final double slideDistance;

  /// 滑动方向
  final SlideDirection direction;

  const StaggeredConfig({
    this.itemDelay = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.slideDistance = 30.0,
    this.direction = SlideDirection.up,
  });

  /// 默认配置（快速）
  static const fast = StaggeredConfig(
    itemDelay: Duration(milliseconds: 30),
    itemDuration: Duration(milliseconds: 250),
  );

  /// 默认配置（慢速）
  static const slow = StaggeredConfig(
    itemDelay: Duration(milliseconds: 75),
    itemDuration: Duration(milliseconds: 400),
  );

  /// 默认配置（从左侧滑入）
  static const fromLeft = StaggeredConfig(
    direction: SlideDirection.left,
  );

  /// 默认配置（从右侧滑入）
  static const fromRight = StaggeredConfig(
    direction: SlideDirection.right,
  );
}

/// 滑动方向
enum SlideDirection {
  up,
  down,
  left,
  right,
}

// ==================== 交错列表项 ====================

/// 交错动画列表项
/// 为单个列表项添加延迟动画
class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final StaggeredConfig config;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.config = StaggeredConfig.fast,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 计算延迟：索引 * 每项延迟
    final delay = Duration(
      milliseconds: widget.config.itemDelay.inMilliseconds * widget.index,
    );

    _controller = AnimationController(
      duration: widget.config.itemDuration,
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
    );

    // 延迟后启动动画
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
    return _StaggeredTransition(
      animation: _animation,
      slideDistance: widget.config.slideDistance,
      direction: widget.config.direction,
      child: widget.child,
    );
  }
}

/// 交错动画过渡组件
class _StaggeredTransition extends StatelessWidget {
  final Animation<double> animation;
  final double slideDistance;
  final SlideDirection direction;
  final Widget child;

  const _StaggeredTransition({
    required this.animation,
    required this.slideDistance,
    required this.direction,
    required this.child,
  });

  Offset getBeginOffset() {
    switch (direction) {
      case SlideDirection.up:
        return Offset(0, slideDistance / 100);
      case SlideDirection.down:
        return Offset(0, -slideDistance / 100);
      case SlideDirection.left:
        return Offset(slideDistance / 100, 0);
      case SlideDirection.right:
        return Offset(-slideDistance / 100, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: getBeginOffset() * (1 - animation.value),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ==================== 交错列表视图 ====================

/// 交错动画列表视图
/// 自动为所有子项添加交错动画
class StaggeredListView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final StaggeredConfig? config;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final ScrollController? controller;

  const StaggeredListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.config,
    this.physics,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      physics: physics,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return StaggeredListItem(
          index: index,
          config: config ?? StaggeredConfig.fast,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

// ==================== 交错网格视图 ====================

/// 交错动画网格视图
class StaggeredGridView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final SliverGridDelegate gridDelegate;
  final StaggeredConfig? config;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const StaggeredGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.config,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: physics,
      padding: padding,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return StaggeredListItem(
          index: index,
          config: config ?? StaggeredConfig.fast,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

// ==================== 交错列表包装器 ====================

/// 交错列表包装器
/// 将现有列表转换为交错动画列表
class StaggeredListWrapper extends StatelessWidget {
  final List<Widget> children;
  final StaggeredConfig? config;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const StaggeredListWrapper({
    super.key,
    required this.children,
    this.config,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return StaggeredListItem(
          index: index,
          config: config ?? StaggeredConfig.fast,
          child: children[index],
        );
      },
    );
  }
}

// ==================== 便捷扩展 ====================

/// 为 List<Widget> 添加交错动画的扩展
extension StaggeredListExtension on List<Widget> {
  /// 将列表包装为交错动画列表
  Widget asStaggeredList({
    StaggeredConfig? config,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return StaggeredListWrapper(
      children: this,
      config: config,
      physics: physics,
      padding: padding,
    );
  }
}

// ==================== 预设动画配置 ====================

/// 预设的交错动画配置
class StaggeredPresets {
  /// 快速从下滑入（适合大量列表）
  static const quickSlideUp = StaggeredConfig(
    itemDelay: Duration(milliseconds: 30),
    itemDuration: Duration(milliseconds: 250),
    slideDistance: 20.0,
    direction: SlideDirection.up,
  );

  /// 标准从下滑入
  static const standardSlideUp = StaggeredConfig(
    itemDelay: Duration(milliseconds: 50),
    itemDuration: Duration(milliseconds: 300),
    slideDistance: 30.0,
    direction: SlideDirection.up,
  );

  /// 慢速从下滑入（适合少量重要项）
  static const slowSlideUp = StaggeredConfig(
    itemDelay: Duration(milliseconds: 75),
    itemDuration: Duration(milliseconds: 400),
    slideDistance: 40.0,
    direction: SlideDirection.up,
  );

  /// 从左滑入
  static const slideFromLeft = StaggeredConfig(
    itemDelay: Duration(milliseconds: 50),
    itemDuration: Duration(milliseconds: 300),
    slideDistance: 30.0,
    direction: SlideDirection.left,
  );

  /// 从右滑入
  static const slideFromRight = StaggeredConfig(
    itemDelay: Duration(milliseconds: 50),
    itemDuration: Duration(milliseconds: 300),
    slideDistance: 30.0,
    direction: SlideDirection.right,
  );

  /// 弹簧效果（从下滑入带弹性）
  static const springSlideUp = StaggeredConfig(
    itemDelay: Duration(milliseconds: 50),
    itemDuration: Duration(milliseconds: 500),
    slideDistance: 30.0,
    direction: SlideDirection.up,
    curve: Curves.easeOutBack,
  );
}
