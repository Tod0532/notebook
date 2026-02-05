/// 原生语音识别服务
/// 使用 MethodChannel 调用 Android 原生 RecognizerIntent
/// 绕过 speech_to_text 插件，直接使用系统语音识别

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// ==================== 语音识别状态 ====================

/// 语音识别状态枚举
enum NativeSpeechState {
  idle,           // 空闲
  listening,      // 正在监听
  processing,     // 处理中
  done,           // 完成
  unavailable,    // 不可用
  error,          // 错误
}

// ==================== 语音识别结果 ====================

/// 原生语音识别结果
class NativeSpeechResult {
  final String text;           // 识别的文字
  final List<String> alternatives; // 备选结果
  final DateTime timestamp;    // 时间戳

  NativeSpeechResult({
    required this.text,
    required this.alternatives,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NativeSpeechResult{text: $text, alternatives: ${alternatives.length}';
  }
}

// ==================== 语音识别异常 ====================

/// 原生语音识别异常
class NativeSpeechException implements Exception {
  final String code;
  final String message;

  NativeSpeechException(this.code, this.message);

  @override
  String toString() => 'NativeSpeechException[$code]: $message';
}

// ==================== 原生语音识别服务 ====================

/// 原生语音识别服务
/// 通过 MethodChannel 调用 Android 原生语音识别
class NativeSpeechRecognitionService {
  static const String _channelName = 'com.thicknotepad.thick_notepad/speech';
  static const MethodChannel _channel = MethodChannel(_channelName);

  static NativeSpeechRecognitionService? _instance;
  static final _lock = Object();

  factory NativeSpeechRecognitionService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= NativeSpeechRecognitionService._internal();
      });
    }
    return _instance!;
  }

  NativeSpeechRecognitionService._internal() {
    debugPrint('NativeSpeechRecognitionService: 初始化');
  }

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  final _stateController = StreamController<NativeSpeechState>.broadcast();
  NativeSpeechState _currentState = NativeSpeechState.idle;
  bool _isInitialized = false;

  // ==================== 初始化 ====================

  /// 初始化服务
  Future<bool> initialize() async {
    try {
      debugPrint('===== 初始化原生语音识别服务 =====');

      // 检查麦克风权限
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        throw NativeSpeechException('NO_PERMISSION', '需要麦克风权限');
      }

      // 检查语音识别服务可用性
      final available = await checkAvailability();
      if (!available) {
        throw NativeSpeechException(
          'UNAVAILABLE',
          '设备没有可用的语音识别服务。请确保输入设置中已启用语音输入。',
        );
      }

      _isInitialized = true;
      _updateState(NativeSpeechState.idle);
      debugPrint('===== 原生语音识别初始化成功 =====');
      return true;
    } catch (e) {
      debugPrint('初始化失败: $e');
      _updateState(NativeSpeechState.error);
      rethrow;
    }
  }

  /// 检查麦克风权限
  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;

      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('检查麦克风权限失败: $e');
      return false;
    }
  }

  /// 检查语音识别服务是否可用
  Future<bool> checkAvailability() async {
    try {
      final result = await _channel.invokeMethod('checkSpeechRecognitionAvailable');
      if (result != null && result is Map) {
        return result['available'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('检查语音识别可用性失败: $e');
      return false;
    }
  }

  // ==================== 语音识别控制 ====================

  /// 开始语音识别
  Future<NativeSpeechResult> startListening({String language = 'zh-CN'}) async {
    try {
      debugPrint('===== 启动原生语音识别 =====');
      debugPrint('语言: $language');

      if (!_isInitialized) {
        await initialize();
      }

      _updateState(NativeSpeechState.listening);

      // 调用原生方法
      final result = await _channel.invokeMethod('startSpeechRecognition', {
        'language': language,
      });

      debugPrint('原生方法调用完成，等待用户输入...');

      // 等待用户完成语音输入（通过原生界面）
      // 结果会在 _handleMethodCall 中处理

      // 这里需要等待结果，使用 Completer
      final completer = Completer<NativeSpeechResult>();

      // 设置一个超时定时器（60秒）
      Timer(const Duration(seconds: 60), () {
        if (!completer.isCompleted) {
          completer.completeError(
            NativeSpeechException('TIMEOUT', '语音识别超时，请重试'),
          );
          _updateState(NativeSpeechState.idle);
        }
      });

      // 将 completer 保存，供回调使用
      _pendingCompleter = completer;

      return completer.future;
    } catch (e) {
      debugPrint('启动语音识别失败: $e');

      // 解析错误消息
      if (e is PlatformException) {
        final code = e.code;
        if (code == 'NO_SPEECH_SERVICE') {
          throw NativeSpeechException(
            'NO_SPEECH_SERVICE',
            '设备没有语音识别服务。请检查输入设置中是否启用了语音输入。',
          );
        }
      }

      _updateState(NativeSpeechState.error);
      rethrow;
    }
  }

  // 用于存储当前等待的 completer
  Completer<NativeSpeechResult>? _pendingCompleter;

  /// 处理来自原生的结果（由 MethodChannel 调用）
  void handleNativeResult(Map<dynamic, dynamic>? result) {
    debugPrint('收到原生语音识别结果: $result');

    if (result == null) {
      _pendingCompleter?.completeError(
        NativeSpeechException('NO_RESULT', '没有收到识别结果'),
      );
      _updateState(NativeSpeechState.idle);
      return;
    }

    final text = result['text'] as String? ?? '';
    final alternatives = result['alternatives'] as List<dynamic>? ?? [];

    if (text.isEmpty) {
      _pendingCompleter?.completeError(
        NativeSpeechException('NO_TEXT', '没有识别到文字'),
      );
    } else {
      final speechResult = NativeSpeechResult(
        text: text,
        alternatives: alternatives.cast<String>(),
        timestamp: DateTime.now(),
      );
      _pendingCompleter?.complete(speechResult);
    }

    _updateState(NativeSpeechState.done);
    _updateState(NativeSpeechState.idle);
  }

  /// 处理原生错误
  void handleNativeError(String code, String message) {
    debugPrint('收到原生错误: $code - $message');

    _pendingCompleter?.completeError(
      NativeSpeechException(code, message),
    );

    _updateState(NativeSpeechState.error);
    _updateState(NativeSpeechState.idle);
  }

  // ==================== Getters ====================

  /// 当前状态
  NativeSpeechState get currentState => _currentState;

  /// 状态流
  Stream<NativeSpeechState> get stateStream => _stateController.stream;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  // ==================== 清理资源 ====================

  void dispose() {
    _stateController.close();
    _instance = null;
  }

  // ==================== 私有方法 ====================

  void _updateState(NativeSpeechState state) {
    _currentState = state;
    _stateController.add(state);
    debugPrint('NativeSpeechState: ${state.name}');
  }
}
