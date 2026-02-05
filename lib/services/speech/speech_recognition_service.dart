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
      debugPrint('===== 初始化语音识别服务 =====');
      _updateState(SpeechRecognitionState.initializing);

      // 检查麦克风权限
      debugPrint('1. 检查麦克风权限...');
      final hasPermission = await _checkMicrophonePermission();
      debugPrint('2. 权限检查结果: $hasPermission');

      if (!hasPermission) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException('缺少麦克风权限，请在设置中允许录音权限');
      }

      // 初始化 speech_to_text
      debugPrint('3. 初始化 speech_to_text 插件...');
      final isAvailable = await _speechToText.initialize(
        onError: (dynamic error) {
          // error 是动态类型
          debugPrint('===== 语音识别错误回调 =====');
          debugPrint('错误详情: $error');
          debugPrint('错误类型: ${error.runtimeType}');
          _updateState(SpeechRecognitionState.error);
        },
        onStatus: (status) {
          debugPrint('语音识别状态回调: $status');
          _onStatus(status);
        },
      );

      debugPrint('4. 初始化结果: isAvailable=$isAvailable');

      if (!isAvailable) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException('语音识别不可用，设备可能不支持语音识别功能');
      }

      _isInitialized = true;

      // 设置语言
      if (language != null) {
        _currentLanguage = language;
      }

      // 打印支持的 locale 列表用于调试
      try {
        final locales = await _speechToText.locales();
        debugPrint('5. 设备支持的语言列表 (${locales.length} 种):');
        for (final locale in locales.take(10)) {
          debugPrint('   - ${locale.localeId} (${locale.name})');
        }
      } catch (e) {
        debugPrint('5. 获取语言列表失败: $e');
      }

      _updateState(SpeechRecognitionState.idle);
      debugPrint('===== 语音识别初始化成功 =====');
      debugPrint('当前语言: ${_currentLanguage.name} (${_currentLanguage.localeId})');
      return true;
    } catch (e, st) {
      debugPrint('===== 语音识别初始化失败 =====');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误信息: $e');
      debugPrint('堆栈跟踪: $st');
      _updateState(SpeechRecognitionState.error);
      throw SpeechRecognitionException('初始化语音识别失败: ${e.toString()}', e, st);
    }
  }

  /// 检查麦克风权限
  Future<bool> _checkMicrophonePermission() async {
    try {
      debugPrint('  1.1 请求麦克风权限...');
      final status = await Permission.microphone.status;
      debugPrint('  1.2 当前权限状态: $status');

      if (status.isGranted) {
        debugPrint('  1.3 权限已授予');
        return true;
      }

      if (status.isDenied) {
        debugPrint('  1.4 权限被拒绝，请求权限...');
        final result = await Permission.microphone.request();
        debugPrint('  1.5 请求结果: $result');

        if (result.isGranted) {
          debugPrint('  1.6 权限已授予');
          return true;
        }

        if (result.isPermanentlyDenied) {
          debugPrint('  1.7 权限被永久拒绝');
          throw SpeechRecognitionException('麦克风权限被永久拒绝，请在设置中开启');
        }

        debugPrint('  1.8 权限请求失败');
        return false;
      }

      if (status.isPermanentlyDenied) {
        debugPrint('  1.9 权限被永久拒绝');
        throw SpeechRecognitionException('麦克风权限被永久拒绝，请在设置中开启');
      }

      return false;
    } catch (e) {
      debugPrint('  检查麦克风权限失败: $e');
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
      debugPrint('===== 开始语音识别流程 =====');
      debugPrint('1. 检查初始化状态: $_isInitialized');

      if (!_isInitialized) {
        debugPrint('2. 服务未初始化，开始初始化...');
        final initSuccess = await initialize(language: language);
        debugPrint('3. 初始化结果: $initSuccess');
      }

      debugPrint('4. 检查语音识别可用性: ${_speechToText.isAvailable}');

      if (!isAvailable) {
        debugPrint('5. 语音识别不可用');
        throw SpeechRecognitionException('语音识别不可用，请检查设备是否支持语音识别功能');
      }

      // 更新语言
      if (language != null) {
        _currentLanguage = language;
      }

      debugPrint('6. 当前语言: ${_currentLanguage.name} (${_currentLanguage.localeId})');

      _updateState(SpeechRecognitionState.listening);

      // 创建新会话
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionTranscripts.clear();

      debugPrint('7. 开始调用 listen 方法...');
      debugPrint('8. 配置参数: listenFor=${listenFor ?? const Duration(seconds: 30)}, pauseFor=${pauseFor ?? const Duration(seconds: 3)}');

      // 开始监听 - 使用 deviceDefault 模式而不是 confirmation
      // confirmation 模式可能在某些设备上不支持中文
      final listenStarted = await _speechToText.listen(
        onResult: _onResult,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 5), // 增加暂停时间
        partialResults: true,
        localeId: _currentLanguage.localeId,
        cancelOnError: false, // 改为 false，避免出错时直接取消
        listenMode: stt.ListenMode.deviceDefault, // 使用设备默认模式
      );

      debugPrint('9. listen 方法调用完成，返回值: $listenStarted');
      debugPrint('10. 当前 isListening 状态: ${_speechToText.isListening}');
      debugPrint('===== 语音识别已启动 =====');
      return _currentSessionId!;
    } catch (e, st) {
      debugPrint('===== 开始语音识别失败 =====');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误信息: $e');
      debugPrint('堆栈跟踪: $st');
      _updateState(SpeechRecognitionState.error);
      throw SpeechRecognitionException('开始语音识别失败: ${e.toString()}', e, st);
    }
  }

  /// 停止监听
  Future<void> stopListening() async {
    try {
      debugPrint('===== 停止语音识别 =====');
      debugPrint('当前状态: $_currentState');
      debugPrint('isListening: ${_speechToText.isListening}');

      if (_currentState != SpeechRecognitionState.listening && !_speechToText.isListening) {
        debugPrint('当前未在监听，无需停止');
        return;
      }

      await _speechToText.stop();
      _updateState(SpeechRecognitionState.notListening);

      debugPrint('已停止语音识别，会话ID: $_currentSessionId');
      final sessionId = _currentSessionId;
      _currentSessionId = null;
    } catch (e) {
      debugPrint('===== 停止语音识别失败 =====');
      debugPrint('错误: $e');
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
    debugPrint('===== 语音识别结果回调 =====');
    debugPrint('结果类型: ${result.runtimeType}');

    String recognizedWords = '';
    bool isFinal = false;
    String? confidence;

    try {
      if (result is Map) {
        recognizedWords = result['recognizedWords'] ?? '';
        isFinal = result['finalResult'] ?? false;
        confidence = result['confidence']?.toString();
      } else {
        recognizedWords = result.recognizedWords ?? '';
        isFinal = result.finalResult ?? false;
        confidence = result.confidence?.toString();
      }

      debugPrint('识别文字: "$recognizedWords"');
      debugPrint('是否最终结果: $isFinal');
      debugPrint('置信度: $confidence');

      if (recognizedWords.isNotEmpty) {
        final recognitionResult = VoiceRecognitionResult(
          recognizedWords: recognizedWords,
          confidence: confidence,
          timestamp: DateTime.now(),
          isFinal: isFinal,
        );

        if (isFinal) {
          _sessionTranscripts.add(recognizedWords);
          debugPrint('最终结果已保存，会话记录: $_sessionTranscripts');
        }

        _resultController.add(recognitionResult);
      } else {
        debugPrint('识别文字为空，忽略此结果');
      }
    } catch (e) {
      debugPrint('解析识别结果失败: $e');
    }
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
