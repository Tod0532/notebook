/// 主题切换动画组件
/// 提供平滑的主题切换过渡效果

import 'package:flutter/material.dart';

/// 简化版主题切换包装器 - 仅过渡背景色
class SimpleThemeTransition extends StatelessWidget {
  final Widget child;

  const SimpleThemeTransition({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
