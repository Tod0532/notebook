/// 语音助手页面 - 提供语音交互界面
/// 包含语音输入按钮、实时显示识别结果、意图确认等功能
/// 简化版：移除复杂诊断功能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';
import 'package:thick_notepad/services/speech/speech_recognition_service.dart'
    show
        SpeechRecognitionService,
        SpeechLanguage;
import 'package:thick_notepad/services/speech/intent_parser.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/core/config/providers.dart';

/// 语音助手页面
class VoiceAssistantPage extends ConsumerStatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  ConsumerState<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends ConsumerState<VoiceAssistantPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkAndRequestPermission();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  /// 检查并请求麦克风权限
  Future<void> _checkAndRequestPermission() async {
    try {
      final status = await Permission.microphone.status;
      debugPrint('麦克风权限状态: $status');

      if (status.isDenied) {
        debugPrint('麦克风权限被拒绝，请求权限...');
        final result = await Permission.microphone.request();
        debugPrint('权限请求结果: $result');

        if (!result.isGranted) {
          if (mounted) {
            _showPermissionDialog();
          }
        }
      } else if (status.isPermanentlyDenied) {
        debugPrint('麦克风权限被永久拒绝');
        if (mounted) {
          _showPermissionDialog();
        }
      }
    } catch (e) {
      debugPrint('检查麦克风权限失败: $e');
    }
  }

  /// 显示权限对话框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('语音助手需要麦克风权限才能正常工作。请在设置中允许录音权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  /// 显示简化的诊断信息
  Future<void> _showDiagnostics() async {
    final service = ref.read(speechRecognitionServiceProvider);
    final synthesisService = ref.read(speechSynthesisServiceProvider);
    final micStatus = await Permission.microphone.status;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _SimpleDiagnosticsDialog(
          service: service,
          synthesisInitialized: synthesisService.isInitialized,
          micStatus: micStatus,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantProvider);
    final recognitionInitState = ref.watch(speechRecognitionInitProvider);
    final synthesisInitState = ref.watch(speechSynthesisInitProvider);

    // 并行检查两个服务的初始化状态
    final initStates = [recognitionInitState, synthesisInitState];
    final hasError = initStates.any((state) => state.hasError);
    final isLoading = initStates.any((state) => state.isLoading);

    if (hasError) {
      // 获取第一个错误信息
      final errorState = initStates.firstWhere((state) => state.hasError);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: _buildErrorView(errorState.error.toString()),
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: _buildLoadingView(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: _buildMainContent(assistantState),
      ),
    );
  }

  /// 构建AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        '语音助手',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        // 诊断按钮
        IconButton(
          icon: const Icon(Icons.bug_report_outlined, color: AppColors.textPrimary),
          onPressed: _showDiagnostics,
          tooltip: '诊断',
        ),
        // 设置按钮
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
          onPressed: () => _showSettingsDialog(context),
        ),
      ],
    );
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: AppSpacing.md),
          Text(
            '正在初始化语音服务...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.mic_off,
              color: AppColors.error,
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '语音服务初始化失败',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () {
              // 同时刷新两个服务的初始化
              ref.invalidate(speechRecognitionInitProvider);
              ref.invalidate(speechSynthesisInitProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: _showDiagnostics,
            icon: const Icon(Icons.info_outline),
            label: const Text('查看状态'),
          ),
        ],
      ),
    );
  }

  /// 构建主要内容
  Widget _buildMainContent(VoiceAssistantState state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                _buildStatusCard(state),
                const SizedBox(height: AppSpacing.xl),
                _buildRecognitionResult(state),
                const SizedBox(height: AppSpacing.xl),
                _buildDebugInfo(state),
                const SizedBox(height: AppSpacing.xl),
                if (state.lastIntent != null) _buildIntentResult(state.lastIntent!),
                const Spacer(),
                _buildVoiceButton(state),
                const SizedBox(height: AppSpacing.xl),
                _buildQuickCommands(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard(VoiceAssistantState state) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (state.isListening) {
      statusText = '正在听...';
      statusIcon = Icons.mic;
      statusColor = AppColors.primary;
    } else if (state.isSpeaking) {
      statusText = '正在播放...';
      statusIcon = Icons.volume_up;
      statusColor = AppColors.secondary;
    } else {
      statusText = '点击下方按钮开始';
      statusIcon = Icons.mic_none;
      statusColor = AppColors.textHint;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: state.isListening ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: state.isListening
                    ? [AppColors.primary, AppColors.primaryLight]
                    : [AppColors.surfaceVariant, AppColors.surfaceVariant],
              ),
              borderRadius: AppRadius.xlRadius,
              boxShadow: state.isListening
                  ? AppShadows.primary(context)
                  : AppShadows.light,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: state.isListening ? Colors.white : statusColor,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  statusText,
                  style: TextStyle(
                    color: state.isListening ? Colors.white : statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建识别结果显示
  Widget _buildRecognitionResult(VoiceAssistantState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '识别结果',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (state.lastRecognizedText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.lastRecognizedText,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '等待语音输入...',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建调试信息面板
  Widget _buildDebugInfo(VoiceAssistantState state) {
    final recognitionService = ref.read(speechRecognitionServiceProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                color: AppColors.info,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '调试信息',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildDebugRow('正在监听', state.isListening ? '是' : '否'),
          _buildDebugRow('正在播放', state.isSpeaking ? '是' : '否'),
          _buildDebugRow('服务已初始化', recognitionService.isInitialized ? '是' : '否'),
          _buildDebugRow('服务可用', recognitionService.isAvailable ? '是' : '否'),
          _buildDebugRow('当前语言', recognitionService.currentLanguage.name),
          _buildDebugRow('识别状态', recognitionService.currentState.name),
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
            _buildDebugRow('错误信息', state.errorMessage!, isError: true),
        ],
      ),
    );
  }

  /// 构建调试信息行
  Widget _buildDebugRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? AppColors.error : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建意图结果显示
  Widget _buildIntentResult(VoiceIntent intent) {
    String intentName;
    String intentDescription;
    IconData intentIcon;
    Color intentColor;

    switch (intent.type) {
      case IntentType.createNote:
      case IntentType.quickMemo:
        intentName = '创建笔记';
        intentDescription = intent.content ?? '无内容';
        intentIcon = Icons.edit_note;
        intentColor = AppColors.primary;
        break;
      case IntentType.logWorkout:
        intentName = '运动打卡';
        intentDescription = intent.workoutType?.name ?? '运动';
        intentIcon = Icons.fitness_center;
        intentColor = AppColors.secondary;
        break;
      case IntentType.queryProgress:
        intentName = '查询进度';
        intentDescription = '获取统计数据';
        intentIcon = Icons.query_stats;
        intentColor = AppColors.info;
        break;
      case IntentType.createReminder:
        intentName = '创建提醒';
        intentDescription = intent.content ?? '提醒内容';
        intentIcon = Icons.alarm;
        intentColor = AppColors.warning;
        break;
      default:
        intentName = '未知';
        intentDescription = '无法识别';
        intentIcon = Icons.help_outline;
        intentColor = AppColors.textHint;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: intentColor.withOpacity(0.1),
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: intentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: intentColor.withOpacity(0.2),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(
                  intentIcon,
                  color: intentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                intentName,
                style: TextStyle(
                  color: intentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            intentDescription,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ElevatedButton.icon(
                onPressed: () => _executeIntent(intent),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('确认'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: intentColor,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.read(voiceAssistantProvider.notifier).reset(),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    ).slideIn();
  }

  /// 构建语音按钮
  Widget _buildVoiceButton(VoiceAssistantState state) {
    return GestureDetector(
      onTap: () => _toggleListening(state),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: state.isListening
              ? AppColors.secondaryGradient
              : AppColors.primaryGradient,
          boxShadow: state.isListening
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ]
              : AppShadows.light,
        ),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: state.isListening ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Icon(
            state.isListening ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 50,
          ),
        ),
      ),
    );
  }

  /// 构建快捷指令
  Widget _buildQuickCommands() {
    final commands = [
      _QuickCommand(
        icon: Icons.edit_note,
        label: '记笔记',
        prompt: '记一下',
        color: AppColors.primary,
      ),
      _QuickCommand(
        icon: Icons.fitness_center,
        label: '记运动',
        prompt: '我刚刚跑了5公里',
        color: AppColors.secondary,
      ),
      _QuickCommand(
        icon: Icons.query_stats,
        label: '查进度',
        prompt: '我本周运动了多久',
        color: AppColors.info,
      ),
      _QuickCommand(
        icon: Icons.alarm,
        label: '设提醒',
        prompt: '明天早上8点提醒我',
        color: AppColors.warning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷指令',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: commands.map((cmd) => _buildQuickCommandChip(cmd)).toList(),
        ),
      ],
    );
  }

  /// 构建快捷指令芯片
  Widget _buildQuickCommandChip(_QuickCommand command) {
    return InkWell(
      onTap: () => _showQuickCommandExample(command),
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: command.color.withOpacity(0.1),
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: command.color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              command.icon,
              color: command.color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              command.label,
              style: TextStyle(
                color: command.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换监听状态
  void _toggleListening(VoiceAssistantState state) async {
    debugPrint('VoiceAssistantPage: ========== 切换监听状态 ==========');
    debugPrint('VoiceAssistantPage: 当前状态 isListening: ${state.isListening}');

    final notifier = ref.read(voiceAssistantProvider.notifier);

    if (state.isListening) {
      debugPrint('VoiceAssistantPage: 停止监听...');
      await notifier.stopListening();
    } else {
      debugPrint('VoiceAssistantPage: 开始监听...');
      await notifier.startListening();
    }

    debugPrint('VoiceAssistantPage: ========== 切换完成 ==========');
  }

  /// 执行意图
  void _executeIntent(VoiceIntent intent) async {
    await ref.read(voiceAssistantProvider.notifier).executeIntent(intent);
  }

  /// 显示快捷指令示例
  void _showQuickCommandExample(_QuickCommand command) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('示例: "${command.prompt}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示设置对话框
  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _VoiceSettingsSheet(),
    );
  }
}

// ==================== 快捷指令模型 ====================

class _QuickCommand {
  final IconData icon;
  final String label;
  final String prompt;
  final Color color;

  _QuickCommand({
    required this.icon,
    required this.label,
    required this.prompt,
    required this.color,
  });
}

// ==================== 简化的诊断对话框 ====================

class _SimpleDiagnosticsDialog extends StatelessWidget {
  final SpeechRecognitionService service;
  final bool synthesisInitialized;
  final PermissionStatus micStatus;

  const _SimpleDiagnosticsDialog({
    required this.service,
    required this.synthesisInitialized,
    required this.micStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isMicGranted = micStatus.isGranted;
    final isSttInitialized = service.isInitialized;
    final isSttAvailable = service.isAvailable;
    final isListening = service.isListening;
    final currentLanguage = service.currentLanguage;

    return AlertDialog(
      title: const Text('语音服务状态'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow('麦克风权限', isMicGranted ? '已授予' : '未授予', isMicGranted),
          _buildRow('语音识别服务', isSttAvailable ? '可用' : '不可用', isSttAvailable),
          _buildRow('服务已初始化', isSttInitialized ? '是' : '否', isSttInitialized),
          _buildRow('当前正在监听', isListening ? '是' : '否', isListening),
          _buildRow('当前语言', currentLanguage.name, true),
          _buildRow('语音合成', synthesisInitialized ? '已初始化' : '未初始化', synthesisInitialized),
          const Divider(height: 24),
          const Text(
            '提示',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '语音识别需要网络连接才能正常工作。如果遇到问题，请确保：\n'
            '1. 已授予麦克风权限\n'
            '2. 网络连接正常\n'
            '3. 设备支持语音识别',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings();
          },
          child: const Text('打开系统设置'),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            size: 18,
            color: isOk ? Colors.green : AppColors.error,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isOk ? Colors.green : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 语音设置表单 ====================

class _VoiceSettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VoiceSettingsSheet> createState() => _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends ConsumerState<_VoiceSettingsSheet> {
  SpeechLanguage _selectedLanguage = SpeechLanguage.mandarin;
  bool _voiceFeedbackEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // 标题
          const Text(
            '语音设置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 语言选择
          _buildLanguageSelector(),
          const SizedBox(height: AppSpacing.lg),
          // 语音反馈开关
          _buildVoiceFeedbackToggle(),
          const SizedBox(height: AppSpacing.xl),
          // 关闭按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '识别语言',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: SpeechLanguage.all.map((lang) {
              final isSelected = _selectedLanguage == lang;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLanguage = lang),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: lang != SpeechLanguage.all.last ? AppSpacing.sm : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: AppRadius.mdRadius,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.dividerColor,
                      ),
                    ),
                    child: Text(
                      lang.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceFeedbackToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Text(
            '语音反馈',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Switch(
            value: _voiceFeedbackEnabled,
            onChanged: (value) => setState(() => _voiceFeedbackEnabled = value),
          ),
        ],
      ),
    );
  }
}
