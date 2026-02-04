/// 语音合成服务 - 使用 flutter_tts 插件
/// 支持文字转语音反馈

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ==================== 语音合成状态 ====================

/// 语音合成状态枚举
enum SpeechSynthesisState {
  idle,       // 空闲
  speaking,   // 正在播放
  stopped,    // 已停止
  paused,     // 已暂停
  error,      // 错误
}

// ==================== 语音合成异常 ====================

/// 语音合成异常
class SpeechSynthesisException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  SpeechSynthesisException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'SpeechSynthesisException: $message';
  }
}

// ==================== 语音合成服务 ====================

/// 语音合成服务 - 单例模式
class SpeechSynthesisService {
  // 单例模式
  static SpeechSynthesisService? _instance;
  static final _lock = Object();

  factory SpeechSynthesisService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= SpeechSynthesisService._internal();
      });
    }
    return _instance!;
  }

  SpeechSynthesisService._internal();

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 成员变量 ====================

  final _flutterTts = FlutterTts();
  final _stateController = StreamController<SpeechSynthesisState>.broadcast();

  // 当前状态
  SpeechSynthesisState _currentState = SpeechSynthesisState.idle;
  bool _isInitialized = false;

  // TTS 设置
  double _speechRate = 0.5;        // 语速 (0.0 - 1.0)
  double _volume = 1.0;            // 音量 (0.0 - 1.0)
  double _pitch = 1.0;             // 音调 (0.5 - 2.0)
  String _language = 'zh-CN';      // 默认普通话

  // 播放队列
  final List<String> _speakQueue = [];
  bool _isPlayingQueue = false;

  // ==================== 初始化 ====================

  /// 初始化语音合成
  Future<bool> initialize() async {
    try {
      // 设置初始化回调
      _flutterTts.setInitHandler(() {
        debugPrint('TTS 初始化成功');
        _isInitialized = true;
        _updateState(SpeechSynthesisState.idle);
      });

      _flutterTts.setStartHandler(() {
        debugPrint('TTS 开始播放');
        _updateState(SpeechSynthesisState.speaking);
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS 播放完成');
        _updateState(SpeechSynthesisState.stopped);
        _playNextInQueue();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS 错误: $msg');
        _updateState(SpeechSynthesisState.error);
        _playNextInQueue();
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('TTS 已取消');
        _updateState(SpeechSynthesisState.stopped);
      });

      _flutterTts.setPauseHandler(() {
        debugPrint('TTS 已暂停');
        _updateState(SpeechSynthesisState.paused);
      });

      _flutterTts.setContinueHandler(() {
        debugPrint('TTS 继续播放');
        _updateState(SpeechSynthesisState.speaking);
      });

      // 设置默认参数
      await _setDefaults();

      // iOS 平台需要等待初始化完成
      // Android 通常立即可用
      if (!_isInitialized) {
        // 尝试等待一小段时间
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return true;
    } catch (e, st) {
      debugPrint('TTS 初始化失败: $e');
      throw SpeechSynthesisException('初始化语音合成失败', e, st);
    }
  }

  /// 设置默认参数
  Future<void> _setDefaults() async {
    try {
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setLanguage(_language);

      // iOS 特定设置
      await _flutterTts.setSharedInstance(true);
    } catch (e) {
      debugPrint('设置 TTS 默认参数失败: $e');
    }
  }

  // ==================== 语音播放 ====================

  /// 朗读文字
  Future<void> speak(String text) async {
    try {
      if (text.isEmpty) {
        return;
      }

      await _flutterTts.speak(text);
      debugPrint('TTS 朗读: $text');
    } catch (e, st) {
      debugPrint('TTS 朗读失败: $e');
      throw SpeechSynthesisException('朗读失败', e, st);
    }
  }

  /// 添加到播放队列
  Future<void> enqueue(String text) async {
    _speakQueue.add(text);
    if (!_isPlayingQueue) {
      _isPlayingQueue = true;
      await _playNextInQueue();
    }
  }

  /// 播放队列中的下一条
  Future<void> _playNextInQueue() async {
    if (_speakQueue.isEmpty) {
      _isPlayingQueue = false;
      return;
    }

    final text = _speakQueue.removeAt(0);
    await speak(text);
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _speakQueue.clear();
      _isPlayingQueue = false;
      _updateState(SpeechSynthesisState.stopped);
    } catch (e) {
      debugPrint('TTS 停止失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _updateState(SpeechSynthesisState.paused);
    } catch (e) {
      debugPrint('TTS 暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> continueSpeaking() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.speak('');
      _updateState(SpeechSynthesisState.speaking);
    } catch (e) {
      debugPrint('TTS 继续播放失败: $e');
    }
  }

  // ==================== 参数设置 ====================

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    try {
      _speechRate = rate.clamp(0.0, 1.0);
      await _flutterTts.setSpeechRate(_speechRate);
      debugPrint('TTS 语速: $_speechRate');
    } catch (e) {
      debugPrint('设置语速失败: $e');
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _flutterTts.setVolume(_volume);
      debugPrint('TTS 音量: $_volume');
    } catch (e) {
      debugPrint('设置音量失败: $e');
    }
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    try {
      _pitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(_pitch);
      debugPrint('TTS 音调: $_pitch');
    } catch (e) {
      debugPrint('设置音调失败: $e');
    }
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    try {
      final languages = await getLanguages();
      if (languages.contains(language)) {
        _language = language;
        await _flutterTts.setLanguage(language);
        debugPrint('TTS 语言: $_language');
      } else {
        debugPrint('不支持的语言: $language');
      }
    } catch (e) {
      debugPrint('设置语言失败: $e');
    }
  }

  /// 获取支持的语言列表
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages.cast<String>();
    } catch (e) {
      debugPrint('获取语言列表失败: $e');
      return ['zh-CN', 'zh-HK', 'en-US'];
    }
  }

  /// 播放预设的语音反馈
  Future<void> speakPreset(SpeechPreset preset) async {
    final text = _getPresetText(preset);
    await speak(text);
  }

  /// 获取预设文本
  String _getPresetText(SpeechPreset preset) {
    switch (preset) {
      case SpeechPreset.listeningStart:
        return '正在听，请说话';
      case SpeechPreset.listeningStop:
        return '已停止';
      case SpeechPreset.confirmation:
        return '好的';
      case SpeechPreset.error:
        return '抱歉，出错了';
      case SpeechPreset.noMatch:
        return '抱歉，我没听清';
      case SpeechPreset.success:
        return '完成了';
      case SpeechPreset.workoutLogged:
        return '运动记录已保存';
      case SpeechPreset.noteCreated:
        return '笔记已创建';
      case SpeechPreset.reminderSet:
        return '提醒已设置';
    }
  }

  // ==================== Streams ====================

  /// 状态流
  Stream<SpeechSynthesisState> get stateStream => _stateController.stream;

  /// 当前状态
  SpeechSynthesisState get currentState => _currentState;

  /// 当前语速
  double get speechRate => _speechRate;

  /// 当前音量
  double get volume => _volume;

  /// 当前音调
  double get pitch => _pitch;

  /// 当前语言
  String get language => _language;

  // ==================== 清理资源 ====================

  /// 释放资源
  void dispose() {
    stop();
    _stateController.close();
    _instance = null;
  }

  // ==================== 私有方法 ====================

  void _updateState(SpeechSynthesisState state) {
    _currentState = state;
    _stateController.add(state);
    debugPrint('语音合成状态: ${state.name}');
  }
}

// ==================== 预设语音反馈 ====================

/// 预设语音反馈类型
enum SpeechPreset {
  listeningStart,    // 开始监听
  listeningStop,     // 停止监听
  confirmation,      // 确认
  error,             // 错误
  noMatch,           // 无匹配
  success,           // 成功
  workoutLogged,     // 运动已记录
  noteCreated,       // 笔记已创建
  reminderSet,       // 提醒已设置
}
