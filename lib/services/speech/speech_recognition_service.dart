/// 语音识别服务 - 使用 speech_to_text 插件
/// 支持普通话和粤语实时语音转文字

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

// ==================== 语音识别状态 ====================

/// 语音识别状态枚举
enum SpeechRecognitionState {
  idle,           // 空闲
  initializing,   // 初始化中
  listening,      // 正在监听
  notListening,   // 停止监听
  unavailable,    // 不可用
  error,          // 错误
}

// ==================== 语言配置 ====================

/// 支持的语言
class SpeechLanguage {
  final String code;
  final String name;
  final String localeId;

  const SpeechLanguage({
    required this.code,
    required this.name,
    required this.localeId,
  });

  /// 普通话
  static const mandarin = SpeechLanguage(
    code: 'zh-CN',
    name: '普通话',
    localeId: 'zh_CN',
  );

  /// 粤语
  static const cantonese = SpeechLanguage(
    code: 'zh-HK',
    name: '粤语',
    localeId: 'zh_HK',
  );

  /// 英语
  static const english = SpeechLanguage(
    code: 'en-US',
    name: '英语',
    localeId: 'en_US',
  );

  /// 所有支持的语言
  static const List<SpeechLanguage> all = [
    mandarin,
    cantonese,
    english,
  ];

  /// 根据代码获取语言
  static SpeechLanguage? fromCode(String code) {
    for (final lang in all) {
      if (lang.code == code) return lang;
    }
    return null;
  }
}

// ==================== 语音识别结果 ====================

/// 语音识别结果
class VoiceRecognitionResult {
  final String recognizedWords;     // 识别的文字
  final String? confidence;          // 置信度（如果可用）
  final DateTime timestamp;         // 时间戳
  final bool isFinal;                // 是否是最终结果

  VoiceRecognitionResult({
    required this.recognizedWords,
    this.confidence,
    required this.timestamp,
    this.isFinal = false,
  });

  @override
  String toString() {
    return 'VoiceRecognitionResult{words: $recognizedWords, confidence: $confidence, isFinal: $isFinal}';
  }

  Map<String, dynamic> toJson() {
    return {
      'recognizedWords': recognizedWords,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
    };
  }
}

// ==================== 语音识别异常 ====================

/// 语音识别异常
class SpeechRecognitionException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  SpeechRecognitionException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'SpeechRecognitionException: $message';
  }
}

// ==================== 语音识别服务 ====================

/// 语音识别服务 - 单例模式
class SpeechRecognitionService {
  // 单例模式
  static SpeechRecognitionService? _instance;
  static final _lock = Object();

  factory SpeechRecognitionService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= SpeechRecognitionService._internal();
      });
    }
    return _instance!;
  }

  SpeechRecognitionService._internal();

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 成员变量 ====================

  final _speechToText = stt.SpeechToText();
  final _stateController = StreamController<SpeechRecognitionState>.broadcast();
  final _resultController = StreamController<VoiceRecognitionResult>.broadcast();

  // 当前状态
  SpeechRecognitionState _currentState = SpeechRecognitionState.idle;
  SpeechLanguage _currentLanguage = SpeechLanguage.mandarin;
  bool _isInitialized = false;

  // 监听会话
  String? _currentSessionId;
  List<String> _sessionTranscripts = [];

  // ==================== 初始化 ====================

  /// 初始化语音识别
  Future<bool> initialize({SpeechLanguage? language}) async {
    try {
      _updateState(SpeechRecognitionState.initializing);

      // 检查麦克风权限
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException('缺少麦克风权限');
      }

      // 初始化 speech_to_text
      // speech_to_text 包的 onError 回调使用动态类型，不包含 SpeechRecognitionError 类
      final isAvailable = await _speechToText.initialize(
        onError: (error) {
          // error 是一个包含 errorMsg 和 errorCode 的动态对象
          debugPrint('语音识别错误: $error');
          _updateState(SpeechRecognitionState.error);
        },
        onStatus: _onStatus,
      );

      if (!isAvailable) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException('语音识别不可用');
      }

      _isInitialized = true;

      // 设置语言
      if (language != null) {
        _currentLanguage = language;
      }

      _updateState(SpeechRecognitionState.idle);
      debugPrint('语音识别初始化成功，语言: ${_currentLanguage.name}');
      return true;
    } catch (e, st) {
      _updateState(SpeechRecognitionState.error);
      debugPrint('语音识别初始化失败: $e');
      throw SpeechRecognitionException('初始化语音识别失败', e, st);
    }
  }

  /// 检查麦克风权限
  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        throw SpeechRecognitionException('麦克风权限被永久拒绝，请在设置中开启');
      }

      return false;
    } catch (e) {
      debugPrint('检查麦克风权限失败: $e');
      rethrow;
    }
  }

  /// 检查语音识别是否可用
  bool get isAvailable => _speechToText.isAvailable;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  // ==================== 语音识别控制 ====================

  /// 开始监听
  Future<String> startListening({
    SpeechLanguage? language,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!isAvailable) {
        throw SpeechRecognitionException('语音识别不可用');
      }

      // 更新语言
      if (language != null) {
        _currentLanguage = language;
      }

      _updateState(SpeechRecognitionState.listening);

      // 创建新会话
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionTranscripts.clear();

      // 开始监听
      await _speechToText.listen(
        onResult: _onResult,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: true,
        localeId: _currentLanguage.localeId,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      debugPrint('开始语音识别，会话ID: $_currentSessionId, 语言: ${_currentLanguage.name}');
      return _currentSessionId!;
    } catch (e, st) {
      _updateState(SpeechRecognitionState.error);
      debugPrint('开始语音识别失败: $e');
      throw SpeechRecognitionException('开始语音识别失败', e, st);
    }
  }

  /// 停止监听
  Future<void> stopListening() async {
    try {
      if (_currentState != SpeechRecognitionState.listening) {
        return;
      }

      await _speechToText.stop();
      _updateState(SpeechRecognitionState.notListening);

      debugPrint('停止语音识别，会话ID: $_currentSessionId');
      final sessionId = _currentSessionId;
      _currentSessionId = null;
    } catch (e) {
      debugPrint('停止语音识别失败: $e');
    }
  }

  /// 取消监听
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _updateState(SpeechRecognitionState.idle);
      _currentSessionId = null;
    } catch (e) {
      debugPrint('取消语音识别失败: $e');
    }
  }

  // ==================== 回调处理 ====================

  /// 识别结果回调
  void _onResult(dynamic result) {
    final recognitionResult = VoiceRecognitionResult(
      recognizedWords: result.recognizedWords ?? '',
      confidence: result.confidence?.toString(),
      timestamp: DateTime.now(),
      isFinal: result.finalResult ?? false,
    );

    if (result.finalResult) {
      _sessionTranscripts.add(result.recognizedWords);
    }

    _resultController.add(recognitionResult);
    debugPrint('语音识别结果: ${result.recognizedWords}, final: ${result.finalResult}');
  }

  /// 状态回调
  void _onStatus(String status) {
    switch (status.toLowerCase()) {
      case 'listening':
        _updateState(SpeechRecognitionState.listening);
        break;
      case 'notlistening':
        _updateState(SpeechRecognitionState.notListening);
        break;
      case 'done':
        _updateState(SpeechRecognitionState.idle);
        break;
      default:
        debugPrint('语音识别状态: $status');
    }
  }

  // 错误回调已移到 initialize 中内联处理
  // speech_to_text 包不提供 SpeechRecognitionError 类型
  // 错误信息通过动态对象传递

  // ==================== 语言控制 ====================

  /// 设置当前语言
  Future<void> setLanguage(SpeechLanguage language) async {
    _currentLanguage = language;
    debugPrint('设置语音识别语言: ${language.name}');
  }

  /// 获取当前语言
  SpeechLanguage get currentLanguage => _currentLanguage;

  /// 获取设备支持的所有语言
  Future<List<SpeechLanguage>> getAvailableLanguages() async {
    try {
      final locales = await _speechToText.locales();

      // 转换为我们的语言列表
      final availableLanguages = <SpeechLanguage>[];
      for (final lang in SpeechLanguage.all) {
        if (locales.any((locale) =>
            locale.localeId.toLowerCase() == lang.localeId.toLowerCase())) {
          availableLanguages.add(lang);
        }
      }

      return availableLanguages;
    } catch (e) {
      debugPrint('获取可用语言失败: $e');
      return [SpeechLanguage.mandarin]; // 默认返回普通话
    }
  }

  // ==================== 会话管理 ====================

  /// 获取当前会话ID
  String? get currentSessionId => _currentSessionId;

  /// 获取会话完整文本
  String get sessionTranscript => _sessionTranscripts.join(' ');

  /// 获取会话片段列表
  List<String> get sessionTranscripts => List.unmodifiable(_sessionTranscripts);

  // ==================== Streams ====================

  /// 状态流
  Stream<SpeechRecognitionState> get stateStream => _stateController.stream;

  /// 结果流
  Stream<VoiceRecognitionResult> get resultStream => _resultController.stream;

  /// 当前状态
  SpeechRecognitionState get currentState => _currentState;

  /// 当前是否正在监听
  bool get isListening => _speechToText.isListening;

  // ==================== 清理资源 ====================

  /// 释放资源
  void dispose() {
    cancelListening();
    _stateController.close();
    _resultController.close();
    _instance = null;
  }

  // ==================== 私有方法 ====================

  void _updateState(SpeechRecognitionState state) {
    _currentState = state;
    _stateController.add(state);
    debugPrint('语音识别状态: ${state.name}');
  }
}
