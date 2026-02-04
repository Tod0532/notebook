/// 浮动语音按钮 - 全局悬浮按钮，快速启动语音输入
/// 支持波浪动画效果

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';
import 'package:thick_notepad/core/config/router.dart';

/// 浮动语音按钮位置
enum FloatingButtonPosition {
  rightBottom,   // 右下角
  rightCenter,   // 右侧中间
  leftBottom,    // 左下角
}

/// 浮动语音按钮
class VoiceFloatingButton extends ConsumerStatefulWidget {
  final FloatingButtonPosition position;
  final double? offsetX;
  final double? offsetY;
  final VoidCallback? onTap;
  final bool showWaveAnimation;

  const VoiceFloatingButton({
    super.key,
    this.position = FloatingButtonPosition.rightBottom,
    this.offsetX,
    this.offsetY,
    this.onTap,
    this.showWaveAnimation = true,
  });

  @override
  ConsumerState<VoiceFloatingButton> createState() => _VoiceFloatingButtonState();
}

class _VoiceFloatingButtonState extends ConsumerState<VoiceFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
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

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;

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

    // 如果正在监听，停止监听
    if (state.isListening) {
      await ref.read(voiceAssistantProvider.notifier).stopListening();
      return;
    }

    // 导航到语音助手页面
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
  final bool showWaveAnimation;

  const VoiceFloatingButtonWrapper({
    super.key,
    required this.child,
    this.position = FloatingButtonPosition.rightBottom,
    this.offsetX,
    this.offsetY,
    this.onTap,
    this.showWaveAnimation = true,
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
          showWaveAnimation: showWaveAnimation,
        ),
      ],
    );
  }
}

/// 快速语音输入按钮 - 内联版本，用于页面内嵌入
class QuickVoiceInputButton extends ConsumerWidget {
  final String? hint;
  final Function(String)? onResult;
  final bool showIcon;

  const QuickVoiceInputButton({
    super.key,
    this.hint,
    this.onResult,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;

    return InkWell(
      onTap: () => _toggleListening(ref, assistantState),
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
            if (showIcon)
              Icon(
                isListening ? Icons.stop : Icons.mic,
                color: isListening ? Colors.white : AppColors.primary,
                size: 18,
              ),
            if (showIcon && hint != null)
              const SizedBox(width: AppSpacing.sm),
            if (hint != null)
              Text(
                isListening ? '正在听...' : hint!,
                style: TextStyle(
                  color: isListening ? Colors.white : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleListening(WidgetRef ref, VoiceAssistantState state) async {
    final notifier = ref.read(voiceAssistantProvider.notifier);

    if (state.isListening) {
      await notifier.stopListening();
    } else {
      await notifier.startListening();
    }
  }
}
