/// 语音识别服务 - 简化版
/// 使用 speech_to_text 插件的最基本配置
/// 移除了复杂的网络检测、多locale尝试和诊断逻辑

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

/// 支持的语言 - 扩展版，包含多种 localeId 尝试格式
class SpeechLanguage {
  final String code;
  final String name;
  final String primaryLocale;
  final List<String> fallbackLocales;

  const SpeechLanguage({
    required this.code,
    required this.name,
    required this.primaryLocale,
    this.fallbackLocales = const [],
  });

  /// 普通话（简体中文）- 多种格式尝试
  static const mandarin = SpeechLanguage(
    code: 'zh-CN',
    name: '普通话',
    primaryLocale: 'zh-CN',
    fallbackLocales: [
      'zh_CN',           // 下划线格式
      'zh-Hans-CN',      // 完整 BCP 47
      'zh',              // 仅语言
      'cmn-Hans-CN',     // 拼音化
      'cmn-CN',          // 拼音简化
    ],
  );

  /// 粤语
  static const cantonese = SpeechLanguage(
    code: 'zh-HK',
    name: '粤语',
    primaryLocale: 'zh-HK',
    fallbackLocales: [
      'zh_HK',
      'yue-Hant-HK',
    ],
  );

  /// 英语
  static const english = SpeechLanguage(
    code: 'en-US',
    name: 'English',
    primaryLocale: 'en-US',
    fallbackLocales: ['en_US'],
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

  /// 获取所有要尝试的 locale（包括主格式和后备格式）
  List<String> get allLocales => [primaryLocale, ...fallbackLocales];
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
    return 'VoiceRecognitionResult{words: $recognizedWords, isFinal: $isFinal}';
  }
}

// ==================== 语音识别异常 ====================

/// 语音识别异常
class SpeechRecognitionException implements Exception {
  final String message;
  final String? suggestion;

  SpeechRecognitionException(
    this.message, [
    this.suggestion,
  ]);

  @override
  String toString() {
    final sb = StringBuffer('SpeechRecognitionException: $message');
    if (suggestion != null) {
      sb.write('\n$suggestion');
    }
    return sb.toString();
  }
}

// ==================== 语音识别服务 ====================

/// 语音识别服务 - 单例模式
/// 简化版：使用最基本的配置，移除复杂逻辑
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

  // 尝试状态
  int _currentLocaleIndex = 0;
  int _currentModeIndex = 0;
  static const List<stt.ListenMode> _listenModes = [
    stt.ListenMode.deviceDefault,  // 优先使用设备默认
    stt.ListenMode.search,         // 搜索模式
    stt.ListenMode.confirmation,   // 确认模式
    stt.ListenMode.dictation,      // 听写模式
  ];

  // ==================== 初始化 ====================

  /// 初始化语音识别 - 简化版
  /// 只做最基本的初始化，移除复杂的诊断逻辑
  Future<bool> initialize({SpeechLanguage? language}) async {
    try {
      debugPrint('===== 初始化语音识别服务（简化版）=====');
      _updateState(SpeechRecognitionState.initializing);

      // 1. 检查麦克风权限
      debugPrint('1. 检查麦克风权限...');
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException(
          '需要麦克风权限才能使用语音识别',
          '请在设置中允许麦克风权限',
        );
      }

      // 2. 初始化 speech_to_text - 使用默认配置
      debugPrint('2. 初始化 speech_to_text...');
      final initResult = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('初始化超时');
          return false;
        },
      );

      if (!initResult) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException(
          '语音识别服务不可用',
          '请检查设备是否支持语音识别，或重启应用重试',
        );
      }

      _isInitialized = true;

      // 3. 设置语言
      if (language != null) {
        _currentLanguage = language;
      }

      _updateState(SpeechRecognitionState.idle);
      debugPrint('===== 语音识别初始化成功 =====');
      debugPrint('当前语言: ${_currentLanguage.name}');
      debugPrint('使用locale: ${_currentLanguage.primaryLocale}');

      return true;
    } catch (e) {
      debugPrint('===== 语音识别初始化失败 =====');
      debugPrint('错误: $e');
      _updateState(SpeechRecognitionState.error);
      rethrow;
    }
  }

  /// 检查麦克风权限 - 简化版
  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      debugPrint('  权限状态: $status');

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      return false;
    } catch (e) {
      debugPrint('  检查麦克风权限失败: $e');
      return false;
    }
  }

  /// 错误回调 - 简化版，提供清晰的错误信息
  void _onError(dynamic error) {
    debugPrint('语音识别错误: $error');

    String errorMsg = '未知错误';
    String? suggestion;

    if (error is Map) {
      errorMsg = error['error']?.toString() ?? errorMsg;
      final code = error['code']?.toString();

      // 根据错误代码提供具体建议
      switch (code) {
        case 'no_match':
          suggestion = '请说话更清晰或靠近麦克风';
          break;
        case 'network_error':
        case 'error_network':
          suggestion = '网络连接错误，请检查网络设置。语音识别可能需要网络支持。';
          break;
        case 'error_audio':
          suggestion = '音频输入错误，请检查麦克风';
          break;
        case 'error_speech_timeout':
          suggestion = '未检测到语音输入，请重新开始';
          break;
        case 'error_no_match':
          suggestion = '无法识别语音，请重新说话';
          break;
        default:
          if (errorMsg.contains('12') || errorMsg.contains('download')) {
            suggestion = '语音包下载失败。请确保网络连接正常，语音识别需要下载语音包。';
          } else if (errorMsg.contains('network')) {
            suggestion = '网络错误，请检查网络连接。语音识别需要网络支持。';
          }
      }
    } else if (error is String) {
      errorMsg = error;
      if (errorMsg.contains('12') || errorMsg.contains('download')) {
        suggestion = '语音包下载失败。请确保网络连接正常，语音识别需要下载语音包。';
      } else if (errorMsg.contains('network')) {
        suggestion = '网络错误，请检查网络连接。语音识别需要网络支持。';
      }
    }

    if (suggestion != null) {
      debugPrint('建议: $suggestion');
    }

    _updateState(SpeechRecognitionState.error);
  }

  /// 状态回调 - 简化版
  void _onStatus(String status) {
    debugPrint('语音识别状态: $status');
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
      case 'unavailable':
        _updateState(SpeechRecognitionState.unavailable);
        break;
    }
  }

  // ==================== 语音识别控制 ====================

  /// 开始监听 - 增强版，自动尝试多种配置
  Future<void> startListening({SpeechLanguage? language}) async {
    try {
      debugPrint('===== 开始语音识别（增强版）=====');

      // 检查初始化状态
      if (!_isInitialized) {
        debugPrint('服务未初始化，开始初始化...');
        await initialize(language: language);
      }

      // 更新语言
      if (language != null) {
        _currentLanguage = language;
      }

      // 检查可用性
      if (!isAvailable) {
        throw SpeechRecognitionException(
          '语音识别服务不可用',
          '请重启应用或检查设备设置',
        );
      }

      _updateState(SpeechRecognitionState.listening);

      // 尝试所有配置组合
      await _tryAllConfigurations();

      debugPrint('===== 语音识别已启动 =====');
    } catch (e) {
      debugPrint('===== 开始语音识别失败 =====');
      debugPrint('错误: $e');
      _updateState(SpeechRecognitionState.error);
      rethrow;
    }
  }

  /// 尝试所有配置组合（locale + listenMode）
  Future<void> _tryAllConfigurations() async {
    final locales = _currentLanguage.allLocales;
    final modes = _listenModes;

    debugPrint('=== 自动尝试配置组合 ===');
    debugPrint('语言: ${_currentLanguage.name}');
    debugPrint('Locale 候选: ${locales.length} 个');
    debugPrint('ListenMode 候选: ${modes.length} 个');

    for (final mode in modes) {
      for (final locale in locales) {
        debugPrint('--- 尝试: locale="$locale", mode=$mode ---');

        try {
          // 先停止之前的监听
          if (_speechToText.isListening) {
            await _speechToText.stop();
            await Future.delayed(const Duration(milliseconds: 500));
          }

          // 尝试启动监听
          final listenResult = await _speechToText.listen(
            onResult: _onResult,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 5),
            partialResults: true,
            localeId: locale,
            cancelOnError: false,
            listenMode: mode,
          );

          if (!listenResult) {
            debugPrint('配置失败: locale="$locale", mode=$mode');
            continue; // 尝试下一个配置
          }

          debugPrint('✓ 配置成功: locale="$locale", mode=$mode');
          debugPrint('当前使用locale: $locale');
          debugPrint('当前模式: $mode');
          return; // 成功启动，退出循环

        } catch (e) {
          debugPrint('✗ 配置异常: $e');
          // 继续尝试下一个配置
        }
      }
    }

    // 所有配置都失败
    throw SpeechRecognitionException(
      '无法启动语音识别。已尝试 ${locales.length} 个 locale × ${modes.length} 种模式',
      '建议：\n'
      '1. 检查网络连接\n'
      '2. 确保设备语音输入已启用\n'
      '3. 尝试重启设备\n'
      '4. 更新 Google 语音服务',
    );
  }

  /// 停止监听 - 简化版
  Future<void> stopListening() async {
    try {
      debugPrint('停止语音识别');
      if (_speechToText.isListening) {
        await _speechToText.stop();
        _updateState(SpeechRecognitionState.notListening);
      }
    } catch (e) {
      debugPrint('停止语音识别失败: $e');
    }
  }

  /// 取消监听 - 简化版
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _updateState(SpeechRecognitionState.idle);
    } catch (e) {
      debugPrint('取消语音识别失败: $e');
    }
  }

  // ==================== 回调处理 ====================

  /// 识别结果回调 - 简化版
  void _onResult(dynamic result) {
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

      if (recognizedWords.isNotEmpty) {
        final recognitionResult = VoiceRecognitionResult(
          recognizedWords: recognizedWords,
          confidence: confidence,
          timestamp: DateTime.now(),
          isFinal: isFinal,
        );

        _resultController.add(recognitionResult);
        debugPrint('识别结果: "$recognizedWords" (isFinal: $isFinal)');
      }
    } catch (e) {
      debugPrint('解析识别结果失败: $e');
    }
  }

  // ==================== 语言控制 ====================

  /// 设置当前语言
  void setLanguage(SpeechLanguage language) {
    _currentLanguage = language;
    debugPrint('设置语言: ${language.name}');
  }

  /// 获取当前语言
  SpeechLanguage get currentLanguage => _currentLanguage;

  // ==================== Getters ====================

  /// 检查语音识别是否可用
  bool get isAvailable => _speechToText.isAvailable;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前是否正在监听
  bool get isListening => _speechToText.isListening;

  /// 当前状态
  SpeechRecognitionState get currentState => _currentState;

  /// 状态流
  Stream<SpeechRecognitionState> get stateStream => _stateController.stream;

  /// 结果流
  Stream<VoiceRecognitionResult> get resultStream => _resultController.stream;

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
  }
}
