/// 快捷语音指令按钮 - 全局悬浮按钮
/// 支持快速语音命令，如创建笔记、记录运动、设置提醒等

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';

/// 快捷语音指令按钮
/// 显示在右下角的浮动按钮，点击可快速执行语音命令
class QuickVoiceCommandsButton extends ConsumerStatefulWidget {
  final double? offsetX;
  final double? offsetY;
  final bool showWaveAnimation;

  const QuickVoiceCommandsButton({
    super.key,
    this.offsetX,
    this.offsetY,
    this.showWaveAnimation = true,
  });

  @override
  ConsumerState<QuickVoiceCommandsButton> createState() => _QuickVoiceCommandsButtonState();
}

class _QuickVoiceCommandsButtonState extends ConsumerState<QuickVoiceCommandsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  StreamSubscription<dynamic>? _resultSubscription;
  bool _isListening = false;
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

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

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  /// 设置语音识别结果监听
  void _setupResultListener() {
    final service = ref.read(speechRecognitionServiceProvider);
    _resultSubscription = service.resultStream.listen((result) {
      if (result.isFinal && mounted && _isListening) {
        _handleVoiceResult(result.recognizedWords);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _resultSubscription?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final isListening = assistantState.isListening;
    _isListening = isListening;

    if (isListening && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!isListening && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }

    return Positioned(
      right: widget.offsetX ?? 16,
      bottom: widget.offsetY ?? 80,
      child: GestureDetector(
        onLongPress: _showQuickCommands,
        onTap: () => _toggleListening(assistantState),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // 波纹效果
                if (widget.showWaveAnimation && isListening)
                  _buildRippleEffect(),

                // 主按钮
                _buildMainButton(isListening),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建波纹效果
  Widget _buildRippleEffect() {
    return AnimatedBuilder(
      animation: _rippleAnimation,
      builder: (context, child) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withOpacity(0.4 * _rippleAnimation.value),
                AppColors.primary.withOpacity(0.2 * _rippleAnimation.value),
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isListening
            ? AppColors.secondaryGradient
            : AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: (isListening ? AppColors.secondary : AppColors.primary)
                .withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        isListening ? Icons.stop : Icons.mic,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  /// 切换监听状态
  Future<void> _toggleListening(VoiceAssistantState state) async {
    final notifier = ref.read(voiceAssistantProvider.notifier);

    if (state.isListening) {
      await notifier.stopListening();
      _animationController.stop();
      _animationController.reset();
    } else {
      await notifier.startListening();
    }
  }

  /// 处理语音识别结果
  void _handleVoiceResult(String text) {
    if (text.trim().isEmpty) return;

    // 使用意图解析器解析语音指令
    final intent = ref.read(intentParserProvider).parse(text);

    // 根据意图执行相应操作
    _executeIntent(intent, text);
  }

  /// 执行语音意图
  void _executeIntent(dynamic intent, String rawText) {
    if (!mounted) return;

    // 移除覆盖层
    _removeOverlay();

    // 显示解析结果
    _showIntentResult(intent, rawText);
  }

  /// 显示意图结果
  void _showIntentResult(dynamic intent, String rawText) {
    if (!mounted) return;

    String message;
    IconData icon;
    Color color;

    switch (intent.type.toString()) {
      case 'IntentType.createNote':
      case 'IntentType.quickMemo':
        message = '识别为：创建笔记';
        icon = Icons.edit_note;
        color = AppColors.primary;
        break;
      case 'IntentType.logWorkout':
        message = '识别为：记录运动';
        icon = Icons.fitness_center;
        color = AppColors.secondary;
        break;
      case 'IntentType.createReminder':
        message = '识别为：设置提醒';
        icon = Icons.alarm;
        color = AppColors.warning;
        break;
      case 'IntentType.queryProgress':
        message = '识别为：查询进度';
        icon = Icons.query_stats;
        color = AppColors.info;
        break;
      default:
        message = '识别内容：$rawText';
        icon = Icons.chat_bubble;
        color = AppColors.textSecondary;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        action: intent.content != null && intent.content!.isNotEmpty
            ? SnackBarAction(
                label: '查看',
                textColor: Colors.white,
                onPressed: () => _navigateToIntent(intent),
              )
            : null,
      ),
    );
  }

  /// 导航到意图对应的页面
  void _navigateToIntent(dynamic intent) {
    if (!mounted) return;

    switch (intent.type.toString()) {
      case 'IntentType.createNote':
      case 'IntentType.quickMemo':
        context.push(AppRoutes.noteEdit, extra: {'initialContent': intent.content});
        break;
      case 'IntentType.logWorkout':
        context.push(AppRoutes.workoutEdit, extra: {'initialNotes': intent.content});
        break;
      case 'IntentType.createReminder':
        // 可以传递初始文本到提醒页面
        context.push(AppRoutes.reminders);
        break;
      default:
        break;
    }
  }

  /// 显示快捷命令菜单
  void _showQuickCommands() {
    if (_isOverlayVisible) {
      _removeOverlay();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _QuickCommandsMenu(
        onSelected: (command) {
          _removeOverlay();
          _executeQuickCommand(command);
        },
        onDismiss: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true;
  }

  /// 移除覆盖层
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOverlayVisible = false;
  }

  /// 执行快捷命令
  void _executeQuickCommand(QuickVoiceCommand command) {
    switch (command) {
      case QuickVoiceCommand.createNote:
        context.push(AppRoutes.noteEdit);
        break;
      case QuickVoiceCommand.logWorkout:
        context.push(AppRoutes.workoutEdit);
        break;
      case QuickVoiceCommand.createReminder:
        context.push(AppRoutes.reminders);
        break;
      case QuickVoiceCommand.voiceAssistant:
        context.push(AppRoutes.voiceAssistant);
        break;
    }
  }
}

/// 快捷语音命令枚举
enum QuickVoiceCommand {
  createNote,
  logWorkout,
  createReminder,
  voiceAssistant,
}

/// 快捷命令菜单
class _QuickCommandsMenu extends StatelessWidget {
  final Function(QuickVoiceCommand) onSelected;
  final VoidCallback onDismiss;

  const _QuickCommandsMenu({
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.only(right: 16, bottom: 150, left: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCommandItem(
                  context,
                  icon: Icons.edit_note,
                  label: '创建笔记',
                  color: AppColors.primary,
                  command: QuickVoiceCommand.createNote,
                ),
                const SizedBox(height: 8),
                _buildCommandItem(
                  context,
                  icon: Icons.fitness_center,
                  label: '记录运动',
                  color: AppColors.secondary,
                  command: QuickVoiceCommand.logWorkout,
                ),
                const SizedBox(height: 8),
                _buildCommandItem(
                  context,
                  icon: Icons.alarm,
                  label: '设置提醒',
                  color: AppColors.warning,
                  command: QuickVoiceCommand.createReminder,
                ),
                const SizedBox(height: 8),
                _buildCommandItem(
                  context,
                  icon: Icons.support_agent,
                  label: '语音助手',
                  color: AppColors.info,
                  command: QuickVoiceCommand.voiceAssistant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required QuickVoiceCommand command,
  }) {
    return GestureDetector(
      onTap: () => onSelected(command),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdRadius,
          boxShadow: AppShadows.light,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).slideIn(),
    );
  }
}

/// 快捷语音命令按钮包装器
/// 用于在页面中嵌入全局语音命令按钮
class QuickVoiceCommandsButtonWrapper extends StatelessWidget {
  final Widget child;
  final double? offsetX;
  final double? offsetY;
  final bool showWaveAnimation;

  const QuickVoiceCommandsButtonWrapper({
    super.key,
    required this.child,
    this.offsetX,
    this.offsetY,
    this.showWaveAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        QuickVoiceCommandsButton(
          offsetX: offsetX,
          offsetY: offsetY,
          showWaveAnimation: showWaveAnimation,
        ),
      ],
    );
  }
}
