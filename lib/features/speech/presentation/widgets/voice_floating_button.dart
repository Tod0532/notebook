/// 浮动语音按钮 - 全局悬浮按钮，快速启动语音输入
/// 支持波浪动画效果，支持语音识别结果回调

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/core/config/providers.dart';

/// 浮动语音按钮位置
enum FloatingButtonPosition {
  rightBottom,   // 右下角
  rightCenter,   // 右侧中间
  leftBottom,    // 左下角
}

/// 语音输入结果回调
/// 当语音识别完成时返回识别的文本
typedef VoiceResultCallback = void Function(String recognizedText);

/// 浮动语音按钮
class VoiceFloatingButton extends ConsumerStatefulWidget {
  final FloatingButtonPosition position;
  final double? offsetX;
  final double? offsetY;
  final VoidCallback? onTap;
  final VoiceResultCallback? onResult;
  final bool showWaveAnimation;
  final String? hint;

  const VoiceFloatingButton({
    super.key,
    this.position = FloatingButtonPosition.rightBottom,
    this.offsetX,
    this.offsetY,
    this.onTap,
    this.onResult,
    this.showWaveAnimation = true,
    this.hint,
  });

  @override
  ConsumerState<VoiceFloatingButton> createState() => _VoiceFloatingButtonState();
}

class _VoiceFloatingButtonState extends ConsumerState<VoiceFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  StreamSubscription<dynamic>? _resultSubscription;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _setupResultListener();
  }

  void _setupAnimation() {
    if (widget.showWaveAnimation) {
      _waveController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _waveController,
          curve: Curves.easeOut,
        ),
      );

      _waveController.repeat();
    }
  }

  /// 设置语音识别结果监听
  void _setupResultListener() {
    if (widget.onResult != null) {
      // 监听语音识别结果
      final service = ref.read(speechRecognitionServiceProvider);
      _resultSubscription = service.resultStream.listen((result) {
        if (result.isFinal && mounted) {
          // 调用回调返回结果
          widget.onResult!(result.recognizedWords);
        }
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _resultSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;
    _isListening = isListening;

    return Positioned(
      right: _getRightPosition(),
      bottom: _getBottomPosition(),
      left: _getLeftPosition(),
      top: _getTopPosition(),
      child: GestureDetector(
        onTap: () => _handleTap(assistantState),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 波浪动画
              if (widget.showWaveAnimation && isListening)
                _buildWaveAnimation(),

              // 主按钮
              _buildMainButton(isListening),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建波浪动画
  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withOpacity(0.3 * _waveAnimation.value),
                AppColors.primary.withOpacity(0.1 * _waveAnimation.value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建主按钮
  Widget _buildMainButton(bool isListening) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isListening
            ? AppColors.secondaryGradient
            : AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: (isListening ? AppColors.secondary : AppColors.primary)
                .withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        isListening ? Icons.mic : Icons.mic_none,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  /// 处理点击事件
  void _handleTap(VoiceAssistantState state) async {
    // 如果有自定义回调，优先执行
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    final notifier = ref.read(voiceAssistantProvider.notifier);

    // 如果正在监听，停止监听
    if (state.isListening) {
      await notifier.stopListening();
      return;
    }

    // 如果有结果回调，开始监听并返回结果
    if (widget.onResult != null) {
      await notifier.startListening();
      return;
    }

    // 默认导航到语音助手页面
    context.push(AppRoutes.voiceAssistant);
  }

  /// 获取右侧位置
  double? _getRightPosition() {
    switch (widget.position) {
      case FloatingButtonPosition.rightBottom:
      case FloatingButtonPosition.rightCenter:
        return widget.offsetX ?? 16;
      case FloatingButtonPosition.leftBottom:
        return null;
    }
  }

  /// 获取底部位置
  double? _getBottomPosition() {
    switch (widget.position) {
      case FloatingButtonPosition.rightBottom:
      case FloatingButtonPosition.leftBottom:
        return widget.offsetY ?? 80;
      case FloatingButtonPosition.rightCenter:
        return null;
    }
  }

  /// 获取左侧位置
  double? _getLeftPosition() {
    switch (widget.position) {
      case FloatingButtonPosition.leftBottom:
        return widget.offsetX ?? 16;
      case FloatingButtonPosition.rightBottom:
      case FloatingButtonPosition.rightCenter:
        return null;
    }
  }

  /// 获取顶部位置
  double? _getTopPosition() {
    switch (widget.position) {
      case FloatingButtonPosition.rightCenter:
        final screenHeight = MediaQuery.of(context).size.height;
        return widget.offsetY ?? (screenHeight / 2 - 30);
      case FloatingButtonPosition.rightBottom:
      case FloatingButtonPosition.leftBottom:
        return null;
    }
  }
}

/// 语音浮动按钮包装器 - 用于在页面中嵌入浮动按钮
class VoiceFloatingButtonWrapper extends StatelessWidget {
  final Widget child;
  final FloatingButtonPosition position;
  final double? offsetX;
  final double? offsetY;
  final VoidCallback? onTap;
  final VoiceResultCallback? onResult;
  final bool showWaveAnimation;
  final String? hint;

  const VoiceFloatingButtonWrapper({
    super.key,
    required this.child,
    this.position = FloatingButtonPosition.rightBottom,
    this.offsetX,
    this.offsetY,
    this.onTap,
    this.onResult,
    this.showWaveAnimation = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        VoiceFloatingButton(
          position: position,
          offsetX: offsetX,
          offsetY: offsetY,
          onTap: onTap,
          onResult: onResult,
          showWaveAnimation: showWaveAnimation,
          hint: hint,
        ),
      ],
    );
  }
}

/// 快速语音输入按钮 - 内联版本，用于页面内嵌入
/// 支持语音识别结果回调
class QuickVoiceInputButton extends ConsumerStatefulWidget {
  final String? hint;
  final VoiceResultCallback? onResult;
  final bool showIcon;
  final bool autoStart;
  final bool showStatus;

  const QuickVoiceInputButton({
    super.key,
    this.hint,
    this.onResult,
    this.showIcon = true,
    this.autoStart = true,
    this.showStatus = true,
  });

  @override
  ConsumerState<QuickVoiceInputButton> createState() => _QuickVoiceInputButtonState();
}

class _QuickVoiceInputButtonState extends ConsumerState<QuickVoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<dynamic>? _resultSubscription;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _setupResultListener();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// 设置语音识别结果监听
  void _setupResultListener() {
    if (widget.onResult != null) {
      final service = ref.read(speechRecognitionServiceProvider);
      _resultSubscription = service.resultStream.listen((result) {
        if (result.isFinal && mounted) {
          // 停止监听
          _stopListening();
          // 调用回调返回结果
          widget.onResult!(result.recognizedWords);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _resultSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;
    _isListening = isListening;

    if (isListening && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (!isListening && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isListening ? _pulseAnimation.value : 1.0,
          child: InkWell(
            onTap: () => _toggleListening(assistantState),
            borderRadius: AppRadius.mdRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: isListening
                    ? AppColors.secondaryGradient
                    : null,
                color: isListening
                    ? null
                    : AppColors.surfaceVariant,
                borderRadius: AppRadius.mdRadius,
                border: Border.all(
                  color: isListening
                      ? Colors.transparent
                      : AppColors.dividerColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showIcon)
                    Icon(
                      isListening ? Icons.stop : Icons.mic,
                      color: isListening ? Colors.white : AppColors.primary,
                      size: 18,
                    ),
                  if (widget.showIcon && widget.hint != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (widget.hint != null)
                    Text(
                      isListening && widget.showStatus ? '正在听...' : widget.hint!,
                      style: TextStyle(
                        color: isListening ? Colors.white : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleListening(VoiceAssistantState state) async {
    final notifier = ref.read(voiceAssistantProvider.notifier);

    if (state.isListening) {
      await _stopListening();
    } else {
      await notifier.startListening();
    }
  }

  Future<void> _stopListening() async {
    final notifier = ref.read(voiceAssistantProvider.notifier);
    await notifier.stopListening();
    _animationController.stop();
    _animationController.reset();
  }
}
