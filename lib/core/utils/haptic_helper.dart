/// 触觉反馈工具类
/// 提供统一的触觉反馈接口，提升用户交互体验
///
/// 使用示例：
/// ```dart
/// // 按钮点击
/// await HapticHelper.lightTap();
///
/// // 开关切换
/// await HapticHelper.mediumTap();
///
/// // 任务完成
/// await HapticHelper.success();
///
/// // 滚动选择
/// await HapticHelper.selection();
/// ```

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HapticHelper {
  /// 方法通道
  static const _methodChannel = MethodChannel('flutter_haptic');

  /// 是否支持触觉反馈
  static bool _isSupported = true;

  /// 轻触反馈 - 用于按钮点击、小卡片点击
  /// ImpactStyle.light
  static Future<void> lightTap() async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod('HapticFeedback.lightImpact');
    } catch (e) {
      _isSupported = false;
    }
  }

  /// 中等反馈 - 用于开关切换、Tab切换
  /// ImpactStyle.medium
  static Future<void> mediumTap() async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod('HapticFeedback.mediumImpact');
    } catch (e) {
      _isSupported = false;
    }
  }

  /// 重度反馈 - 用于重要操作确认、任务完成
  /// ImpactStyle.heavy
  static Future<void> success() async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod('HapticFeedback.heavyImpact');
    } catch (e) {
      _isSupported = false;
    }
  }

  /// 选择反馈 - 用于滚动选择、列表滚动
  /// SelectionClick
  static Future<void> selection() async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod('HapticFeedback.selectionClick');
    } catch (e) {
      _isSupported = false;
    }
  }

  /// 通知反馈 - 用于提醒触发
  /// HapticFeedbackType.notification
  static Future<void> notification({HapticNotificationType type = HapticNotificationType.success}) async {
    if (!_isSupported) return;
    try {
      await _methodChannel.invokeMethod(
        'HapticFeedback.vibrate',
        type == HapticNotificationType.success ? 'HapticFeedbackType.notificationSuccess' :
        type == HapticNotificationType.warning ? 'HapticFeedbackType.notificationWarning' :
        'HapticFeedbackType.notificationError',
      );
    } catch (e) {
      _isSupported = false;
    }
  }
}

/// 通知反馈类型
enum HapticNotificationType {
  /// 成功通知
  success,
  /// 警告通知
  warning,
  /// 错误通知
  error,
}

/// 触觉反馈扩展 - 为 Widget 添加触觉反馈
extension HapticWidgetExtension on Widget {
  /// 添加轻触反馈的点击包装
  Widget withHapticFeedback({
    VoidCallback? onTap,
    HapticType hapticType = HapticType.light,
  }) {
    return _HapticInkWell(
      child: this,
      onTap: onTap,
      hapticType: hapticType,
    );
  }
}

/// 触觉反馈类型
enum HapticType {
  light,
  medium,
  heavy,
  selection,
}

/// 内部使用的触觉反馈 InkWell
class _HapticInkWell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HapticType hapticType;

  const _HapticInkWell({
    required this.child,
    this.onTap,
    this.hapticType = HapticType.light,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        switch (hapticType) {
          case HapticType.light:
            await HapticHelper.lightTap();
            break;
          case HapticType.medium:
            await HapticHelper.mediumTap();
            break;
          case HapticType.heavy:
            await HapticHelper.success();
            break;
          case HapticType.selection:
            await HapticHelper.selection();
            break;
        }
        onTap?.call();
      },
      child: child,
    );
  }
}
