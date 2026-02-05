/// 语音识别服务 - 使用 speech_to_text 插件
/// 支持普通话和粤语实时语音转文字
/// 增强版：支持多localeId尝试、降级方案和详细诊断

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

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

  /// 可能的localeId变体列表 - 用于尝试不同的locale格式
  final List<String> localeVariants;

  const SpeechLanguage({
    required this.code,
    required this.name,
    required this.localeId,
    this.localeVariants = const [],
  });

  /// 普通话 - 支持多种locale格式
  static const mandarin = SpeechLanguage(
    code: 'zh-CN',
    name: '普通话',
    localeId: 'zh_CN',
    localeVariants: [
      'zh_CN',        // 常用格式
      'zh-CN',        // BCP 47格式
      'zh',           // 简短格式
      'cmn-Hans-CN',  // 标准拼音格式
      'zh-Hans-CN',   // 汉字拼音格式
      'yue-Hant-CN',  // 粤语繁体中文
    ],
  );

  /// 粤语
  static const cantonese = SpeechLanguage(
    code: 'zh-HK',
    name: '粤语',
    localeId: 'zh_HK',
    localeVariants: [
      'zh_HK',
      'zh-HK',
      'yue-Hant-HK',
      'zh-Hant-HK',
    ],
  );

  /// 英语
  static const english = SpeechLanguage(
    code: 'en-US',
    name: '英语',
    localeId: 'en_US',
    localeVariants: [
      'en_US',
      'en-US',
      'en',
    ],
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

  /// 获取所有可能的localeId列表（包括主要localeId）
  List<String> get allLocaleIds => [localeId, ...localeVariants];
}

// ==================== 诊断信息 ====================

/// 语音识别诊断信息
class SpeechDiagnostics {
  final bool microphoneGranted;
  final bool speechToTextAvailable;
  final bool googleServicesAvailable;
  final List<String> availableLocales;
  final String? activeLocale;
  final String? errorMessage;
  final List<String> warnings;
  final List<String> suggestions;

  const SpeechDiagnostics({
    required this.microphoneGranted,
    required this.speechToTextAvailable,
    required this.googleServicesAvailable,
    required this.availableLocales,
    this.activeLocale,
    this.errorMessage,
    this.warnings = const [],
    this.suggestions = const [],
  });

  /// 是否一切正常
  bool get isOk => microphoneGranted && speechToTextAvailable && errorMessage == null;

  /// 诊断消息
  String get diagnosticMessage {
    if (errorMessage != null) return errorMessage!;
    if (!microphoneGranted) return '麦克风权限未授予';
    if (!speechToTextAvailable) return '语音识别服务不可用';
    return '诊断完成';
  }

  @override
  String toString() {
    return 'SpeechDiagnostics{'
        'microphone: $microphoneGranted, '
        'stt: $speechToTextAvailable, '
        'google: $googleServicesAvailable, '
        'locales: ${availableLocales.length}, '
        'active: $activeLocale, '
        'error: $errorMessage'
        '}';
  }

  Map<String, dynamic> toJson() {
    return {
      'microphoneGranted': microphoneGranted,
      'speechToTextAvailable': speechToTextAvailable,
      'googleServicesAvailable': googleServicesAvailable,
      'availableLocales': availableLocales,
      'activeLocale': activeLocale,
      'errorMessage': errorMessage,
      'warnings': warnings,
      'suggestions': suggestions,
    };
  }
}

// ==================== 语音识别结果 ====================

/// 语音识别结果
class VoiceRecognitionResult {
  final String recognizedWords;     // 识别的文字
  final String? confidence;          // 置信度（如果可用）
  final DateTime timestamp;         // 时间戳
  final bool isFinal;                // 是否是最终结果
  final String? usedLocale;          // 实际使用的locale

  VoiceRecognitionResult({
    required this.recognizedWords,
    this.confidence,
    required this.timestamp,
    this.isFinal = false,
    this.usedLocale,
  });

  @override
  String toString() {
    return 'VoiceRecognitionResult{words: $recognizedWords, confidence: $confidence, isFinal: $isFinal, locale: $usedLocale}';
  }

  Map<String, dynamic> toJson() {
    return {
      'recognizedWords': recognizedWords,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
      'usedLocale': usedLocale,
    };
  }
}

// ==================== 语音识别异常 ====================

/// 语音识别异常
class SpeechRecognitionException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final String? suggestion;

  SpeechRecognitionException(
    this.message, [
    this.originalError,
    this.stackTrace,
    this.suggestion,
  ]);

  @override
  String toString() {
    final sb = StringBuffer('SpeechRecognitionException: $message');
    if (suggestion != null) {
      sb.write('\n建议: $suggestion');
    }
    return sb.toString();
  }
}

// ==================== 语音识别服务 ====================

/// 语音识别服务 - 单例模式
/// 增强版：支持多locale尝试和降级方案
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
  String? _activeLocale; // 实际成功使用的locale

  // 监听会话
  String? _currentSessionId;
  List<String> _sessionTranscripts = [];

  // 诊断信息缓存
  SpeechDiagnostics? _lastDiagnostics;

  // 降级模式标志
  bool _useFallbackMode = false;

  // MethodChannel用于原生语音识别降级方案
  static const _platform = MethodChannel('com.thicknotepad.thick_notepad/speech');

  // ==================== 初始化 ====================

  /// 初始化语音识别
  /// 自动尝试多种localeId直到找到可用的
  Future<bool> initialize({SpeechLanguage? language}) async {
    try {
      debugPrint('===== 初始化语音识别服务（增强版）=====');
      _updateState(SpeechRecognitionState.initializing);

      // 1. 检查麦克风权限
      debugPrint('1. 检查麦克风权限...');
      final hasPermission = await _checkMicrophonePermission();
      debugPrint('2. 权限检查结果: $hasPermission');

      if (!hasPermission) {
        _updateState(SpeechRecognitionState.unavailable);
        throw SpeechRecognitionException(
          '缺少麦克风权限',
          null,
          null,
          '请在设置中允许录音权限',
        );
      }

      // 2. 初始化 speech_to_text
      debugPrint('3. 初始化 speech_to_text 插件...');
      final isAvailable = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );

      debugPrint('4. 初始化结果: isAvailable=$isAvailable');

      if (!isAvailable) {
        _updateState(SpeechRecognitionState.unavailable);
        final diag = await runDiagnostics();
        throw SpeechRecognitionException(
          '语音识别不可用',
          null,
          null,
          _getSuggestionFromDiagnostics(diag),
        );
      }

      _isInitialized = true;

      // 3. 设置语言并尝试找到可用的locale
      if (language != null) {
        _currentLanguage = language;
      }

      // 4. 尝试找到可用的localeId
      debugPrint('5. 尝试找到可用的localeId...');
      final availableLocales = await _getAvailableLocaleList();
      debugPrint('6. 设备支持 ${availableLocales.length} 种语言');

      final successLocale = await _findWorkingLocale(_currentLanguage);
      if (successLocale != null) {
        _activeLocale = successLocale;
        debugPrint('7. 成功找到可用locale: $successLocale');
      } else {
        debugPrint('7. 警告: 未找到完全匹配的locale，将使用默认值');
        _activeLocale = _currentLanguage.localeId;
      }

      _updateState(SpeechRecognitionState.idle);
      debugPrint('===== 语音识别初始化成功 =====');
      debugPrint('当前语言: ${_currentLanguage.name}');
      debugPrint('使用locale: $_activeLocale');
      return true;
    } catch (e, st) {
      debugPrint('===== 语音识别初始化失败 =====');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误信息: $e');
      debugPrint('堆栈跟踪: $st');
      _updateState(SpeechRecognitionState.error);
      throw SpeechRecognitionException(
        '初始化语音识别失败: ${e.toString()}',
        e,
        st,
        '请检查设备是否支持语音识别，或重启应用重试',
      );
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
          throw SpeechRecognitionException(
            '麦克风权限被永久拒绝',
            null,
            null,
            '请在系统设置中手动开启麦克风权限',
          );
        }

        debugPrint('  1.8 权限请求失败');
        return false;
      }

      if (status.isPermanentlyDenied) {
        debugPrint('  1.9 权限被永久拒绝');
        throw SpeechRecognitionException(
          '麦克风权限被永久拒绝',
          null,
          null,
          '请在系统设置中手动开启麦克风权限',
        );
      }

      return false;
    } catch (e) {
      debugPrint('  检查麦克风权限失败: $e');
      rethrow;
    }
  }

  /// 获取设备支持的locale列表
  Future<List<stt.LocaleName>> _getAvailableLocaleList() async {
    try {
      final locales = await _speechToText.locales();
      debugPrint('设备支持的locale列表:');
      for (final locale in locales.take(15)) {
        debugPrint('   - ${locale.localeId} (${locale.name})');
      }
      if (locales.length > 15) {
        debugPrint('   ... 还有 ${locales.length - 15} 种语言');
      }
      return locales;
    } catch (e) {
      debugPrint('获取语言列表失败: $e');
      return [];
    }
  }

  /// 尝试找到可用的localeId
  /// 按优先级尝试各种locale格式
  Future<String?> _findWorkingLocale(SpeechLanguage language) async {
    debugPrint('尝试为语言 ${language.name} 找到可用locale...');

    final availableLocales = await _speechToText.locales();
    final allVariants = language.allLocaleIds;

    for (final variant in allVariants) {
      // 检查是否完全匹配
      final match = availableLocales.firstWhere(
        (locale) => locale.localeId.toLowerCase() == variant.toLowerCase(),
        orElse: () => availableLocales.isNotEmpty ? availableLocales.first : stt.LocaleName('', ''),
      );

      if (match.localeId.isNotEmpty) {
        debugPrint('  找到匹配: $variant');
        return match.localeId;
      }

      // 检查是否部分匹配（语言代码相同）
      final langCode = variant.split('-').first.split('_').first;
      final partialMatch = availableLocales.firstWhere(
        (locale) => locale.localeId.toLowerCase().startsWith(langCode.toLowerCase()),
        orElse: () => stt.LocaleName('', ''),
      );

      if (partialMatch.localeId.isNotEmpty) {
        debugPrint('  找到部分匹配: ${partialMatch.localeId} (请求: $variant)');
        return partialMatch.localeId;
      }
    }

    return null;
  }

  /// 错误回调
  void _onError(dynamic error) {
    debugPrint('===== 语音识别错误回调 =====');
    debugPrint('错误详情: $error');
    debugPrint('错误类型: ${error.runtimeType}');

    // 尝试解析错误信息
    String errorMsg = '未知错误';
    String? suggestion;

    try {
      if (error is Map) {
        errorMsg = error['error']?.toString() ?? errorMsg;
        final code = error['code']?.toString();
        if (code == 'no_match') {
          suggestion = '请说话更清晰或靠近麦克风';
        } else if (code == 'network_error') {
          suggestion = '请检查网络连接';
        }
      } else if (error is String) {
        errorMsg = error;
      } else {
        errorMsg = error.toString();
      }
    } catch (_) {}

    debugPrint('解析后的错误: $errorMsg');
    if (suggestion != null) {
      debugPrint('建议: $suggestion');
    }

    _updateState(SpeechRecognitionState.error);
  }

  /// 状态回调
  void _onStatus(String status) {
    debugPrint('语音识别状态变化: $status');
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
      case 'available':
        // 服务可用
        break;
      case 'unavailable':
        _updateState(SpeechRecognitionState.unavailable);
        break;
      default:
        debugPrint('未知状态: $status');
    }
  }

  /// 检查语音识别是否可用
  bool get isAvailable => _speechToText.isAvailable;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  // ==================== 语音识别控制 ====================

  /// 开始监听
  /// 自动尝试多种localeId直到成功
  Future<String> startListening({
    SpeechLanguage? language,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    try {
      debugPrint('===== 开始语音识别流程（增强版）=====');
      debugPrint('1. 检查初始化状态: $_isInitialized');

      if (!_isInitialized) {
        debugPrint('2. 服务未初始化，开始初始化...');
        final initSuccess = await initialize(language: language);
        debugPrint('3. 初始化结果: $initSuccess');
      }

      debugPrint('4. 检查语音识别可用性: ${_speechToText.isAvailable}');

      if (!isAvailable) {
        debugPrint('5. 语音识别不可用，运行诊断...');
        final diag = await runDiagnostics();
        throw SpeechRecognitionException(
          '语音识别不可用',
          null,
          null,
          _getSuggestionFromDiagnostics(diag),
        );
      }

      // 更新语言
      if (language != null) {
        _currentLanguage = language;
        // 重新找到可用的locale
        final successLocale = await _findWorkingLocale(language);
        if (successLocale != null) {
          _activeLocale = successLocale;
        }
      }

      debugPrint('6. 当前语言: ${_currentLanguage.name}');
      debugPrint('7. 使用locale: $_activeLocale');

      _updateState(SpeechRecognitionState.listening);

      // 创建新会话
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionTranscripts.clear();

      // 尝试使用当前locale开始监听
      debugPrint('8. 尝试使用locale: $_activeLocale 开始监听...');
      final success = await _tryListenWithLocale(
        _activeLocale ?? _currentLanguage.localeId,
        listenFor,
        pauseFor,
      );

      if (success) {
        debugPrint('===== 语音识别已启动 =====');
        return _currentSessionId!;
      } else {
        // 尝试所有可用的locale变体
        debugPrint('主locale失败，尝试其他locale变体...');
        for (final variant in _currentLanguage.localeVariants) {
          debugPrint('尝试locale: $variant');
          final result = await _tryListenWithLocale(variant, listenFor, pauseFor);
          if (result) {
            _activeLocale = variant;
            debugPrint('===== 语音识别已启动 (使用备用locale) =====');
            return _currentSessionId!;
          }
        }

        throw SpeechRecognitionException(
          '无法启动语音识别',
          null,
          null,
          '设备可能不支持语音识别或缺少Google语音服务',
        );
      }
    } catch (e, st) {
      debugPrint('===== 开始语音识别失败 =====');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误信息: $e');
      debugPrint('堆栈跟踪: $st');
      _updateState(SpeechRecognitionState.error);
      rethrow;
    }
  }

  /// 尝试使用指定的localeId开始监听
  Future<bool> _tryListenWithLocale(
    String localeId,
    Duration? listenFor,
    Duration? pauseFor,
  ) async {
    try {
      debugPrint('  调用listen方法，localeId=$localeId...');
      debugPrint('  配置: listenFor=${listenFor ?? const Duration(seconds: 30)}, pauseFor=${pauseFor ?? const Duration(seconds: 5)}');

      final listenStarted = await _speechToText.listen(
        onResult: _onResult,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 5),
        partialResults: true,
        localeId: localeId,
        cancelOnError: false,
        listenMode: stt.ListenMode.deviceDefault,
      );

      debugPrint('  listen返回值: $listenStarted');
      debugPrint('  当前isListening: ${_speechToText.isListening}');

      return listenStarted && _speechToText.isListening;
    } catch (e) {
      debugPrint('  locale $localeId 尝试失败: $e');
      return false;
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
          usedLocale: _activeLocale,
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

  // ==================== 语言控制 ====================

  /// 设置当前语言
  Future<void> setLanguage(SpeechLanguage language) async {
    _currentLanguage = language;
    // 重新查找可用的locale
    if (_isInitialized) {
      final successLocale = await _findWorkingLocale(language);
      if (successLocale != null) {
        _activeLocale = successLocale;
      }
    }
    debugPrint('设置语音识别语言: ${language.name}, locale: $_activeLocale');
  }

  /// 获取当前语言
  SpeechLanguage get currentLanguage => _currentLanguage;

  /// 获取当前实际使用的locale
  String? get activeLocale => _activeLocale;

  /// 获取设备支持的所有语言
  Future<List<SpeechLanguage>> getAvailableLanguages() async {
    try {
      final locales = await _speechToText.locales();

      final availableLanguages = <SpeechLanguage>[];
      for (final lang in SpeechLanguage.all) {
        if (locales.any((locale) =>
            locale.localeId.toLowerCase() == lang.localeId.toLowerCase() ||
            lang.localeVariants.any((v) => locale.localeId.toLowerCase() == v.toLowerCase()))) {
          availableLanguages.add(lang);
        }
      }

      return availableLanguages;
    } catch (e) {
      debugPrint('获取可用语言失败: $e');
      return [SpeechLanguage.mandarin];
    }
  }

  // ==================== 诊断功能 ====================

  /// 运行完整诊断
  Future<SpeechDiagnostics> runDiagnostics() async {
    debugPrint('===== 运行语音识别诊断 =====');

    final warnings = <String>[];
    final suggestions = <String>[];

    // 1. 检查麦克风权限
    debugPrint('1. 检查麦克风权限...');
    final micStatus = await Permission.microphone.status;
    final micGranted = micStatus.isGranted;
    debugPrint('   麦克风权限: ${micGranted ? "已授予" : "未授予"}');

    if (!micGranted) {
      warnings.add('麦克风权限未授予');
      suggestions.add('请在设置中允许麦克风权限');
      if (micStatus.isPermanentlyDenied) {
        suggestions.add('权限已被永久拒绝，请在系统设置中手动开启');
      }
    }

    // 2. 检查语音识别服务
    debugPrint('2. 检查语音识别服务...');
    final sttAvailable = _speechToText.isAvailable;
    debugPrint('   speech_to_text: ${sttAvailable ? "可用" : "不可用"}');

    if (!sttAvailable) {
      warnings.add('speech_to_text服务不可用');
      suggestions.add('请检查设备是否支持语音识别');
      suggestions.add('部分设备需要安装Google语音服务');
    }

    // 3. 检查Google服务（通过尝试获取locale列表）
    debugPrint('3. 检查Google语音服务...');
    bool googleAvailable = false;
    List<String> availableLocaleIds = [];
    try {
      final locales = await _speechToText.locales();
      googleAvailable = locales.isNotEmpty;
      availableLocaleIds = locales.map((l) => l.localeId).toList();
      debugPrint('   Google服务: ${googleAvailable ? "可用" : "不可用"}');
      debugPrint('   支持的locale数量: ${locales.length}');

      // 检查是否支持中文
      final hasChinese = locales.any((l) =>
          l.localeId.toLowerCase().startsWith('zh'));
      debugPrint('   支持中文: $hasChinese');

      if (!hasChinese && locales.isNotEmpty) {
        warnings.add('设备可能不支持中文语音识别');
        suggestions.add('尝试安装Google中文语音包');
      }
    } catch (e) {
      debugPrint('   检查失败: $e');
      googleAvailable = false;
    }

    // 4. 构建诊断结果
    final diagnostics = SpeechDiagnostics(
      microphoneGranted: micGranted,
      speechToTextAvailable: sttAvailable,
      googleServicesAvailable: googleAvailable,
      availableLocales: availableLocaleIds,
      activeLocale: _activeLocale,
      warnings: warnings,
      suggestions: suggestions,
    );

    _lastDiagnostics = diagnostics;

    debugPrint('===== 诊断完成 =====');
    debugPrint('诊断结果: $diagnostics');

    return diagnostics;
  }

  /// 获取最后一次诊断结果
  SpeechDiagnostics? get lastDiagnostics => _lastDiagnostics;

  /// 从诊断结果获取建议
  String _getSuggestionFromDiagnostics(SpeechDiagnostics diag) {
    if (diag.suggestions.isNotEmpty) {
      return diag.suggestions.first;
    }
    return '请检查设备设置或重启应用';
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
    debugPrint('语音识别状态更新: ${state.name}');
  }
}
