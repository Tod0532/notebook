/// 抽卡音效管理器
/// 管理抽卡过程中的各种音效播放

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';

/// 音效管理器抽象接口
abstract class GachaSoundManager {
  /// 单例实例
  static GachaSoundManager? _instance;

  /// 获取单例实例
  static GachaSoundManager get instance {
    _instance ??= _createSoundManager();
    return _instance!;
  }

  /// 创建音效管理器（根据平台选择实现）
  static GachaSoundManager _createSoundManager() {
    // 提供默认的无操作实现
    return _NoOpSoundManager();
  }

  /// 播放抽卡音效（卡片翻转前）
  Future<void> playDrawSound();

  /// 播放揭示音效（根据稀有度）
  Future<void> playRevealSound(GachaRarity rarity);

  /// 播放传说特殊音效
  Future<void> playLegendarySound();

  /// 播放十连抽完成音效
  Future<void> playTenDrawCompleteSound();

  /// 播放新物品获得音效
  Future<void> playNewItemSound();

  /// 设置音量（0.0 - 1.0）
  Future<void> setVolume(double volume);

  /// 静音/取消静音
  Future<void> setMuted(bool muted);

  /// 释放资源
  Future<void> dispose();

  /// 检查是否已初始化
  bool get isInitialized;

  /// 检查是否静音
  bool get isMuted;
}

/// 无操作音效管理器（默认实现）
/// 当没有安装音效包时使用此实现
class _NoOpSoundManager extends GachaSoundManager {
  _NoOpSoundManager();

  @override
  Future<void> playDrawSound() async {
    // 无操作
    if (kDebugMode) {
      debugPrint('[GachaSound] playDrawSound called (no-op)');
    }
  }

  @override
  Future<void> playRevealSound(GachaRarity rarity) async {
    if (kDebugMode) {
      debugPrint('[GachaSound] playRevealSound: ${rarity.displayName} (no-op)');
    }
  }

  @override
  Future<void> playLegendarySound() async {
    if (kDebugMode) {
      debugPrint('[GachaSound] playLegendarySound called (no-op)');
    }
  }

  @override
  Future<void> playTenDrawCompleteSound() async {
    if (kDebugMode) {
      debugPrint('[GachaSound] playTenDrawCompleteSound called (no-op)');
    }
  }

  @override
  Future<void> playNewItemSound() async {
    if (kDebugMode) {
      debugPrint('[GachaSound] playNewItemSound called (no-op)');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (kDebugMode) {
      debugPrint('[GachaSound] setVolume: $volume (no-op)');
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (kDebugMode) {
      debugPrint('[GachaSound] setMuted: $muted (no-op)');
    }
  }

  @override
  Future<void> dispose() async {
    if (kDebugMode) {
      debugPrint('[GachaSound] dispose called (no-op)');
    }
  }

  @override
  bool get isInitialized => true;

  @override
  bool get isMuted => false;
}
