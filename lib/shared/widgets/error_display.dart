/// 统一的错误处理组件
/// 用于各模块的错误状态展示和处理

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

/// 错误展示组件
class ErrorDisplayWidget extends StatelessWidget {
  final String? message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorDisplayWidget({
    super.key,
    this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// 网络错误
  const ErrorDisplayWidget.network({
    super.key,
    String? message,
    VoidCallback? onRetry,
  }) : icon = Icons.wifi_off,
       message = message ?? '网络连接失败',
       onRetry = onRetry,
       details = '请检查网络连接后重试';

  /// 服务器错误
  const ErrorDisplayWidget.server({
    super.key,
    String? message,
    VoidCallback? onRetry,
  }) : icon = Icons.cloud_off,
       message = message ?? '服务器错误',
       onRetry = onRetry,
       details = '请稍后重试';

  /// 权限错误
  const ErrorDisplayWidget.permission({
    super.key,
    String? message,
    VoidCallback? onSettings,
  }) : icon = Icons.lock_outline,
       message = message ?? '权限不足',
       details = '需要相应权限才能使用此功能',
       onRetry = onSettings;

  /// 未找到错误
  const ErrorDisplayWidget.notFound({
    super.key,
    String? message,
    VoidCallback? onBack,
  }) : icon = Icons.search_off,
       message = message ?? '未找到内容',
       onRetry = onBack,
       details = '请检查后重试';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: AppColors.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 20),
          if (message != null)
            Text(
              message!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
              textAlign: TextAlign.center,
            ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(_getRetryIcon()),
              label: Text(_getRetryLabel()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.xlRadius,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getRetryIcon() {
    switch (icon) {
      case Icons.lock_outline:
        return Icons.settings;
      case Icons.search_off:
        return Icons.arrow_back;
      default:
        return Icons.refresh;
    }
  }

  String _getRetryLabel() {
    switch (icon) {
      case Icons.lock_outline:
        return '去设置';
      case Icons.search_off:
        return '返回';
      default:
        return '重试';
    }
  }
}

/// 错误对话框
class ErrorDialog {
  /// 显示错误对话框
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    String? details,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: AppColors.error, size: 32),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) Text(message),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }

  /// 确认对话框
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isDestructive ? Icons.warning : Icons.help_outline,
          color: isDestructive ? AppColors.warning : AppColors.primary,
          size: 32,
        ),
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText ?? '确定',
              style: TextStyle(
                color: isDestructive ? AppColors.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 输入对话框
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: maxLines,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    // 修复内存泄漏：及时释放 controller
    controller.dispose();
    return result;
  }
}

/// SnackBar 工具类
class AppSnackBar {
  /// 显示成功消息
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }

  /// 显示错误消息
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// 显示警告消息
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }

  /// 显示普通消息
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }
}
