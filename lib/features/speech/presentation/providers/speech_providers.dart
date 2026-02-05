/// 语音模块 Providers
/// 提供语音识别、语音合成、意图解析服务的状态管理

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/speech/intent_parser.dart';
import 'package:thick_notepad/services/speech/speech_recognition_service.dart';
import 'package:thick_notepad/services/speech/speech_synthesis_service.dart';

// ==================== 语音识别服务 Providers ====================

/// 语音识别初始化 Provider
/// 在页面中使用此 Provider 确保服务已初始化
final speechRecognitionInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(speechRecognitionServiceProvider);
  await service.initialize();
});

/// 语音识别状态 Provider
/// 提供语音识别的实时状态流
final speechRecognitionStateProvider = StreamProvider<SpeechRecognitionState>((ref) {
  final service = ref.watch(speechRecognitionServiceProvider);
  return service.stateStream;
});

/// 语音识别结果 Provider
/// 提供语音识别的实时结果流
final speechRecognitionResultProvider = StreamProvider<VoiceRecognitionResult>((ref) {
  final service = ref.watch(speechRecognitionServiceProvider);
  return service.resultStream;
});

// ==================== 语音合成服务 Providers ====================

/// 语音合成初始化 Provider
/// 在页面中使用此 Provider 确保服务已初始化
final speechSynthesisInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(speechSynthesisServiceProvider);
  await service.initialize();
});

/// 语音合成状态 Provider
/// 提供语音合成的实时状态流
final speechSynthesisStateProvider = StreamProvider<SpeechSynthesisState>((ref) {
  final service = ref.watch(speechSynthesisServiceProvider);
  return service.stateStream;
});

// ==================== 语音模块统一初始化 Provider ====================

/// 语音模块统一初始化 Provider
/// 同时初始化语音识别和语音合成服务
final speechModuleInitProvider = FutureProvider<void>((ref) async {
  // 并行初始化两个服务以提高性能
  await Future.wait([
    ref.watch(speechRecognitionInitProvider.future),
    ref.watch(speechSynthesisInitProvider.future),
  ]);
});

// ==================== 语音助手状态 Providers ====================

/// 语音助手状态
class VoiceAssistantState {
  final bool isListening;
  final bool isSpeaking;
  final String lastRecognizedText;
  final VoiceIntent? lastIntent;
  final String? errorMessage;

  const VoiceAssistantState({
    this.isListening = false,
    this.isSpeaking = false,
    this.lastRecognizedText = '',
    this.lastIntent,
    this.errorMessage,
  });

  VoiceAssistantState copyWith({
    bool? isListening,
    bool? isSpeaking,
    String? lastRecognizedText,
    VoiceIntent? lastIntent,
    String? errorMessage,
  }) {
    return VoiceAssistantState(
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      lastRecognizedText: lastRecognizedText ?? this.lastRecognizedText,
      lastIntent: lastIntent ?? this.lastIntent,
      errorMessage: errorMessage,
    );
  }
}

/// 语音助手状态管理器
class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  final SpeechRecognitionService _recognitionService;
  final SpeechSynthesisService _synthesisService;
  final IntentParser _intentParser;

  VoiceAssistantNotifier(
    this._recognitionService,
    this._synthesisService,
    this._intentParser,
  ) : super(const VoiceAssistantState()) {
    _initListeners();
  }

  void _initListeners() {
    // 监听语音识别状态
    _recognitionService.stateStream.listen((recognitionState) {
      state = state.copyWith(isListening: recognitionState == SpeechRecognitionState.listening);
    });

    // 监听语音识别结果
    _recognitionService.resultStream.listen((result) {
      if (result.isFinal) {
        _handleFinalResult(result);
      }
    });

    // 监听语音合成状态
    _synthesisService.stateStream.listen((_) {
      state = state.copyWith(isSpeaking: _synthesisService.currentState == SpeechSynthesisState.speaking);
    });
  }

  /// 处理最终识别结果
  void _handleFinalResult(VoiceRecognitionResult result) {
    final text = result.recognizedWords;
    final intent = _intentParser.parse(text);

    state = state.copyWith(
      lastRecognizedText: text,
      lastIntent: intent,
    );
  }

  /// 开始语音识别
  Future<void> startListening({SpeechLanguage? language}) async {
    try {
      state = state.copyWith(errorMessage: null);

      // 播放开始语音反馈
      await _synthesisService.speakPreset(SpeechPreset.listeningStart);

      await _recognitionService.startListening(language: language);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      await _synthesisService.speakPreset(SpeechPreset.error);
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    try {
      await _recognitionService.stopListening();
      await _synthesisService.speakPreset(SpeechPreset.listeningStop);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    try {
      await _recognitionService.cancelListening();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 执行意图
  Future<void> executeIntent(VoiceIntent intent) async {
    try {
      switch (intent.type) {
        case IntentType.createNote:
          await _handleCreateNote(intent);
          break;
        case IntentType.logWorkout:
          await _handleLogWorkout(intent);
          break;
        case IntentType.queryProgress:
          await _handleQueryProgress(intent);
          break;
        case IntentType.createReminder:
          await _handleCreateReminder(intent);
          break;
        case IntentType.quickMemo:
          await _handleQuickMemo(intent);
          break;
        default:
          await _synthesisService.speakPreset(SpeechPreset.noMatch);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      await _synthesisService.speakPreset(SpeechPreset.error);
    }
  }

  /// 处理创建笔记意图
  Future<void> _handleCreateNote(VoiceIntent intent) async {
    if (intent.content != null && intent.content!.isNotEmpty) {
      // 这里应该调用笔记仓库创建笔记
      await _synthesisService.speakPreset(SpeechPreset.noteCreated);
    } else {
      await _synthesisService.speak('请说笔记内容');
    }
  }

  /// 处理运动打卡意图
  Future<void> _handleLogWorkout(VoiceIntent intent) async {
    // 这里应该调用运动仓库创建运动记录
    await _synthesisService.speakPreset(SpeechPreset.workoutLogged);
  }

  /// 处理查询进度意图
  Future<void> _handleQueryProgress(VoiceIntent intent) async {
    final queryType = intent.data?['queryType'] as String?;

    String response;
    switch (queryType) {
      case 'workout':
        response = '本周已运动3次，累计120分钟';
        break;
      case 'note':
        response = '今天已完成5项任务';
        break;
      case 'plan':
        response = '当前有2个活跃计划';
        break;
      default:
        response = '您可以询问运动、任务或计划进度';
    }

    await _synthesisService.speak(response);
  }

  /// 处理创建提醒意图
  Future<void> _handleCreateReminder(VoiceIntent intent) async {
    if (intent.content != null && intent.content!.isNotEmpty) {
      // 这里应该调用提醒仓库创建提醒
      await _synthesisService.speakPreset(SpeechPreset.reminderSet);
    } else {
      await _synthesisService.speak('请说提醒内容');
    }
  }

  /// 处理快速记事意图
  Future<void> _handleQuickMemo(VoiceIntent intent) async {
    if (intent.content != null && intent.content!.isNotEmpty) {
      // 这里应该调用笔记仓库创建快速笔记
      await _synthesisService.speakPreset(SpeechPreset.noteCreated);
    } else {
      await _synthesisService.speak('请说记事内容');
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 重置状态
  void reset() {
    state = const VoiceAssistantState();
  }

  @override
  void dispose() {
    super.dispose();
    // 不释放服务，因为它们是单例
  }
}

/// 语音助手状态 Provider
final voiceAssistantProvider = StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>((ref) {
  final recognitionService = ref.watch(speechRecognitionServiceProvider);
  final synthesisService = ref.watch(speechSynthesisServiceProvider);
  final intentParser = ref.watch(intentParserProvider);

  return VoiceAssistantNotifier(
    recognitionService,
    synthesisService,
    intentParser,
  );
});

// ==================== 语音助手派生 Providers ====================
/// 使用 select 优化，避免整个 VoiceAssistantState 变化时所有监听者重建

/// 是否正在监听 Provider - 只监听 isListening 字段
final isListeningProvider = Provider<bool>((ref) {
  return ref.watch(
    voiceAssistantProvider.select((state) => state.isListening),
  );
});

/// 是否正在说话 Provider - 只监听 isSpeaking 字段
final isSpeakingProvider = Provider<bool>((ref) {
  return ref.watch(
    voiceAssistantProvider.select((state) => state.isSpeaking),
  );
});

/// 最后识别文本 Provider - 只监听 lastRecognizedText 字段
final lastRecognizedTextProvider = Provider<String>((ref) {
  return ref.watch(
    voiceAssistantProvider.select((state) => state.lastRecognizedText),
  );
});

/// 最后意图 Provider - 只监听 lastIntent 字段
final lastIntentProvider = Provider<VoiceIntent?>((ref) {
  return ref.watch(
    voiceAssistantProvider.select((state) => state.lastIntent),
  );
});

/// 语音助手错误信息 Provider - 只监听 errorMessage 字段
final voiceAssistantErrorProvider = Provider<String?>((ref) {
  return ref.watch(
    voiceAssistantProvider.select((state) => state.errorMessage),
  );
});
