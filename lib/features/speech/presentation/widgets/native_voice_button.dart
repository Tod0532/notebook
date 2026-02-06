/// 原生语音输入按钮
/// 直接使用 Android RecognizerIntent，打开系统语音识别界面
/// 不依赖 speech_to_text 插件和 Google 语音服务

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

/// 语音输入结果回调
typedef OnVoiceResult = void Function(String text);

/// 原生语音输入按钮
class NativeVoiceButton extends StatelessWidget {
  final OnVoiceResult onResult;
  final String? hint;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;

  const NativeVoiceButton({
    super.key,
    required this.onResult,
    this.hint,
    this.icon = Icons.mic,
    this.iconColor,
    this.backgroundColor,
  });

  /// 启动原生语音识别
  Future<void> _startNativeSpeechRecognition(BuildContext context) async {
    try {
      // 检查麦克风权限
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (context.mounted) {
            _showErrorSnackBar(context, '需要麦克风权限');
          }
          return;
        }
      }

      // 显示加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在启动语音识别...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 调用原生方法
      const channel = MethodChannel('com.thicknotepad.thick_notepad/speech');

      final result = await channel.invokeMethod('startSpeechRecognition', {
        'language': 'zh-CN',
      });

      if (result is Map && result['text'] != null) {
        final text = result['text'] as String;
        if (text.isNotEmpty) {
          onResult(text);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('识别: "$text"'),
                duration: const Duration(seconds: 2),
                action: SnackBarAction(
                  label: '确定',
                  onPressed: () {},
                ),
              ),
            );
          }
        }
      } else if (result is Map && result['error'] != null) {
        if (context.mounted) {
          _showErrorSnackBar(context, result['error']);
        }
      }
    } catch (e) {
      debugPrint('原生语音识别失败: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, '语音识别失败: $e');
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '重试',
          textColor: Colors.white,
          onPressed: () => _startNativeSpeechRecognition(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buttonChild = Icon(icon, color: iconColor ?? AppColors.primary);

    // 如果有提示文字，添加文字
    if (hint != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buttonChild,
          const SizedBox(width: AppSpacing.sm),
          Text(
            hint!,
            style: TextStyle(
              color: iconColor ?? AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _startNativeSpeechRecognition(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceVariant,
          borderRadius: AppRadius.lgRadius,
        ),
        child: buttonChild,
      ),
    );
  }
}

/// 圆形原生语音按钮
class NativeVoiceIconButton extends StatelessWidget {
  final OnVoiceResult onResult;
  final double size;
  final Color? backgroundColor;

  const NativeVoiceIconButton({
    super.key,
    required this.onResult,
    this.size = 56,
    this.backgroundColor,
  });

  Future<void> _startNativeSpeechRecognition(BuildContext context) async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要麦克风权限'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在启动语音识别...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      const channel = MethodChannel('com.thicknotepad.thick_notepad/speech');

      final result = await channel.invokeMethod('startSpeechRecognition', {
        'language': 'zh-CN',
      });

      if (result is Map && result['text'] != null) {
        final text = result['text'] as String;
        if (text.isNotEmpty) {
          onResult(text);
        }
      }
    } catch (e) {
      debugPrint('原生语音识别失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _startNativeSpeechRecognition(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: AppShadows.light,
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
