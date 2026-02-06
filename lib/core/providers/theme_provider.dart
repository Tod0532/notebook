/// 主题状态管理 - 使用 Riverpod 管理用户选择的主题
/// 支持主题持久化存储、深色模式切换和自定义主题色

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/core/theme/app_themes.dart';
import 'package:thick_notepad/core/theme/app_color_scheme.dart';

// ==================== 主题模式枚举 ====================

/// 主题显示模式（亮色/暗色/跟随系统）
enum AppColorMode {
  /// 亮色模式
  light,

  /// 暗色模式
  dark,

  /// 跟随系统设置
  system,
}

/// 主题模式显示名称
const Map<AppColorMode, String> colorModeNames = {
  AppColorMode.light: '亮色模式',
  AppColorMode.dark: '深色模式',
  AppColorMode.system: '跟随系统',
};

// ==================== 存储键 ====================

/// 颜色主题存储 Key
const String _kColorThemeKey = 'app_color_theme';

/// 主题模式存储 Key
const String _kColorModeKey = 'app_color_mode';

/// 自定义主题色存储 Key
const String _kCustomColorKey = 'app_custom_color';

/// 自定义主题色名称存储 Key
const String _kCustomColorNameKey = 'app_custom_color_name';

/// SharedPreferences 提供者
final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// ==================== 自定义主题色管理 ====================

/// 自定义主题色状态管理器
class CustomColorNotifier extends StateNotifier<AppThemeColor> {
  final Ref _ref;

  CustomColorNotifier(this._ref) : super(AppThemeColor.defaultBlue) {
    _loadCustomColorFromPrefs();
  }

  /// 从 SharedPreferences 加载自定义颜色
  Future<void> _loadCustomColorFromPrefs() async {
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      final colorName = prefs.getString(_kCustomColorNameKey);

      if (colorName != null) {
        // 首先尝试从预设主题中查找
        final presetColor = AppThemeColor.findByName(colorName);
        if (presetColor != null) {
          state = presetColor;
          return;
        }

        // 如果是自定义颜色，从存储的 ARGB 值恢复
        final primaryValue = prefs.getInt(_kCustomColorKey);
        if (primaryValue != null) {
          state = AppThemeColor.fromColor(
            colorName,
            Color(primaryValue),
          );
        }
      }
    } catch (e) {
      // 忽略加载错误，保持默认主题
    }
  }

  /// 设置主题色
  Future<void> setThemeColor(AppThemeColor color) async {
    state = color;
    // 持久化存储
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      await prefs.setString(_kCustomColorNameKey, color.name);
      await prefs.setInt(_kCustomColorKey, color.primary.value);
    } catch (e) {
      // 忽略存储错误
    }
  }

  /// 设置自定义颜色
  Future<void> setCustomColor(String name, Color primaryColor, {Color? secondaryColor}) async {
    final customColor = AppThemeColor.fromColor(name, primaryColor, secondaryColor: secondaryColor);
    await setThemeColor(customColor);
  }

  /// 重置为默认颜色
  Future<void> resetToDefault() async {
    await setThemeColor(AppThemeColor.defaultBlue);
  }
}

/// 自定义主题色 Notifier Provider
final customColorNotifierProvider = StateNotifierProvider<CustomColorNotifier, AppThemeColor>((ref) {
  return CustomColorNotifier(ref);
});

/// 当前自定义主题色提供者
final currentCustomColorProvider = Provider<AppThemeColor>((ref) {
  return ref.watch(customColorNotifierProvider);
});

/// 是否使用自定义主题色
final isUsingCustomColorProvider = Provider<bool>((ref) {
  final customColor = ref.watch(currentCustomColorProvider);
  // 如果当前颜色不在预设列表中，则认为是自定义颜色
  return !AppThemeColor.all.contains(customColor);
});

// ==================== 颜色主题管理 ====================

/// 颜色主题状态管理器 - 使用 StateNotifier
class ColorThemeNotifier extends StateNotifier<AppTheme> {
  final Ref _ref;

  ColorThemeNotifier(this._ref) : super(AppTheme.modernGradient) {
    // 不在构造函数中异步加载，避免初始化问题
    _loadThemeFromPrefs();
  }

  /// 从 SharedPreferences 加载主题
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      final themeIndex = prefs.getInt(_kColorThemeKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < AppTheme.values.length) {
        state = AppTheme.values[themeIndex];
      }
    } catch (e) {
      // 忽略加载错误，保持默认主题
    }
  }

  /// 设置主题
  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    // 持久化存储
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      await prefs.setInt(_kColorThemeKey, theme.index);
    } catch (e) {
      // 忽略存储错误
    }
  }

  /// 切换到下一个主题
  Future<void> nextTheme() async {
    final currentIndex = state.index;
    final nextIndex = (currentIndex + 1) % AppTheme.values.length;
    await setTheme(AppTheme.values[nextIndex]);
  }

  /// 切换到上一个主题
  Future<void> previousTheme() async {
    final currentIndex = state.index;
    final prevIndex = (currentIndex - 1 + AppTheme.values.length) % AppTheme.values.length;
    await setTheme(AppTheme.values[prevIndex]);
  }
}

/// 颜色主题 Notifier Provider
final colorThemeNotifierProvider = StateNotifierProvider<ColorThemeNotifier, AppTheme>((ref) {
  return ColorThemeNotifier(ref);
});

/// 当前颜色主题提供者 - 直接从 StateNotifier 获取
final currentColorThemeProvider = Provider<AppTheme>((ref) {
  return ref.watch(colorThemeNotifierProvider);
});

// ==================== 主题模式管理（深色模式） ====================

/// 主题模式状态管理器
class ColorModeNotifier extends StateNotifier<AppColorMode> {
  final Ref _ref;

  ColorModeNotifier(this._ref) : super(AppColorMode.system) {
    _loadModeFromPrefs();
  }

  /// 从 SharedPreferences 加载模式
  Future<void> _loadModeFromPrefs() async {
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      final modeIndex = prefs.getInt(_kColorModeKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < AppColorMode.values.length) {
        state = AppColorMode.values[modeIndex];
      }
    } catch (e) {
      // 忽略加载错误，保持默认模式（跟随系统）
    }
  }

  /// 设置主题模式
  Future<void> setMode(AppColorMode mode) async {
    state = mode;
    // 持久化存储
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      await prefs.setInt(_kColorModeKey, mode.index);
    } catch (e) {
      // 忽略存储错误
    }
  }

  /// 切换到下一个模式
  Future<void> nextMode() async {
    final currentIndex = state.index;
    final nextIndex = (currentIndex + 1) % AppColorMode.values.length;
    await setMode(AppColorMode.values[nextIndex]);
  }
}

/// 主题模式 Notifier Provider
final colorModeNotifierProvider = StateNotifierProvider<ColorModeNotifier, AppColorMode>((ref) {
  return ColorModeNotifier(ref);
});

/// 当前主题模式提供者
final currentColorModeProvider = Provider<AppColorMode>((ref) {
  return ref.watch(colorModeNotifierProvider);
});

// ==================== 兼容旧版 API ====================

/// @deprecated 使用 currentColorThemeProvider 替代
final themeNotifierProvider = colorThemeNotifierProvider;

/// @deprecated 使用 currentColorThemeProvider 替代
final currentThemeProvider = currentColorThemeProvider;

/// @deprecated 使用 colorModeNames 替代
final currentThemeNameProvider = Provider<String>((ref) {
  final theme = ref.watch(currentColorThemeProvider);
  return themeNames[theme] ?? '未知主题';
});
