/// 语音输入按钮 - 用于页面内的语音输入组件
/// 提供更紧凑的语音输入界面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';
import 'package:thick_notepad/services/speech/intent_parser.dart';
import 'package:thick_notepad/services/speech/speech_recognition_service.dart';

/// 语音输入按钮样式
enum VoiceButtonStyle {
  primary,      // 主按钮样式（圆形）
  secondary,    // 次要按钮样式（圆角矩形）
  minimal,      // 最小样式（仅图标）
  outlined,     // 描边样式
}

/// 语音输入按钮
class VoiceInputButton extends ConsumerStatefulWidget {
  final VoiceButtonStyle style;
  final String? hint;
  final Function(String)? onResult;
  final Function(VoiceIntent)? onIntent;
  final bool autoStart;
  final SpeechLanguage? language;

  const VoiceInputButton({
    super.key,
    this.style = VoiceButtonStyle.primary,
    this.hint,
    this.onResult,
    this.onIntent,
    this.autoStart = false,
    this.language,
  });

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();

    if (widget.autoStart) {
      _autoStartListening();
    }
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        final isListening = ref.read(voiceAssistantProvider).isListening;
        if (isListening) {
          _pulseController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _autoStartListening() async {
    // 等待初始化完成
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final notifier = ref.read(voiceAssistantProvider.notifier);
      await notifier.startListening(language: widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;

    // 控制动画
    if (isListening && !_pulseController.isAnimating) {
      _pulseController.forward();
    } else if (!isListening && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    switch (widget.style) {
      case VoiceButtonStyle.primary:
        return _buildPrimaryButton(isListening);
      case VoiceButtonStyle.secondary:
        return _buildSecondaryButton(isListening);
      case VoiceButtonStyle.minimal:
        return _buildMinimalButton(isListening);
      case VoiceButtonStyle.outlined:
        return _buildOutlinedButton(isListening);
    }
  }

  /// 构建主按钮样式
  Widget _buildPrimaryButton(bool isListening) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isListening ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () => _toggleListening(isListening),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isListening
                    ? AppColors.secondaryGradient
                    : AppColors.primaryGradient,
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : AppShadows.light,
              ),
              child: Icon(
                isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建次要按钮样式
  Widget _buildSecondaryButton(bool isListening) {
    return GestureDetector(
      onTap: () => _toggleListening(isListening),
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
          borderRadius: AppRadius.lgRadius,
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 动画指示器
            if (isListening)
              _buildListeningIndicator(),
            // 图标
            Icon(
              isListening ? Icons.stop : Icons.mic,
              color: isListening ? Colors.white : AppColors.primary,
              size: 18,
            ),
            // 提示文字
            if (widget.hint != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                isListening ? '正在听...' : widget.hint!,
                style: TextStyle(
                  color: isListening ? Colors.white : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建最小样式
  Widget _buildMinimalButton(bool isListening) {
    return GestureDetector(
      onTap: () => _toggleListening(isListening),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isListening
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isListening ? Icons.graphic_eq : Icons.mic_none,
          color: isListening ? AppColors.secondary : AppColors.textHint,
          size: 20,
        ),
      ),
    );
  }

  /// 构建描边样式
  Widget _buildOutlinedButton(bool isListening) {
    return GestureDetector(
      onTap: () => _toggleListening(isListening),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isListening ? AppColors.secondary : AppColors.dividerColor,
            width: isListening ? 2 : 1,
          ),
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isListening) _buildListeningIndicator(),
            Icon(
              isListening ? Icons.stop : Icons.mic,
              color: isListening ? AppColors.secondary : AppColors.textSecondary,
              size: 16,
            ),
            if (widget.hint != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.hint!,
                style: TextStyle(
                  color: isListening
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建监听指示器
  Widget _buildListeningIndicator() {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        children: List.generate(3, (index) {
          return Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 400 + (index * 100)),
              width: 3,
              height: isListening ? 12 : 4,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 切换监听状态
  Future<void> _toggleListening(bool isListening) async {
    final notifier = ref.read(voiceAssistantProvider.notifier);

    if (isListening) {
      await notifier.stopListening();
    } else {
      await notifier.startListening(language: widget.language);
    }
  }

  /// 获取是否有监听状态
  bool get isListening => ref.read(voiceAssistantProvider).isListening;
}

/// 语音输入栏 - 完整的语音输入界面组件
class VoiceInputBar extends ConsumerStatefulWidget {
  final String? hintText;
  final Function(String)? onTextResult;
  final Function(VoiceIntent)? onIntentResult;
  final bool showTextDisplay;
  final SpeechLanguage? language;

  const VoiceInputBar({
    super.key,
    this.hintText = '点击麦克风开始说话...',
    this.onTextResult,
    this.onIntentResult,
    this.showTextDisplay = true,
    this.language,
  });

  @override
  ConsumerState<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends ConsumerState<VoiceInputBar> {
  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final lastText = assistantState.lastRecognizedText;
    final lastIntent = assistantState.lastIntent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部栏
          Row(
            children: [
              // 语音按钮
              VoiceInputButton(
                style: VoiceButtonStyle.secondary,
                hint: '',
                language: widget.language,
              ),
              const SizedBox(width: AppSpacing.md),
              // 提示文字
              Expanded(
                child: Text(
                  assistantState.isListening
                      ? '正在听...'
                      : (widget.hintText ?? '点击麦克风开始说话...'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          // 显示识别结果
          if (widget.showTextDisplay && lastText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.mdRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 识别文字
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastText,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 意图结果
                  if (lastIntent != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          _getIntentIcon(lastIntent.type),
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getIntentName(lastIntent.type),
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        // 确认按钮
                        if (widget.onIntentResult != null)
                          InkWell(
                            onTap: () => widget.onIntentResult!(lastIntent!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 12,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '确认',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIntentIcon(IntentType type) {
    switch (type) {
      case IntentType.createNote:
      case IntentType.quickMemo:
        return Icons.edit_note;
      case IntentType.logWorkout:
        return Icons.fitness_center;
      case IntentType.queryProgress:
        return Icons.query_stats;
      case IntentType.createReminder:
        return Icons.alarm;
      default:
        return Icons.help_outline;
    }
  }

  String _getIntentName(IntentType type) {
    switch (type) {
      case IntentType.createNote:
        return '创建笔记';
      case IntentType.logWorkout:
        return '运动打卡';
      case IntentType.queryProgress:
        return '查询进度';
      case IntentType.createReminder:
        return '创建提醒';
      case IntentType.quickMemo:
        return '快速记事';
      default:
        return '未知';
    }
  }
}
