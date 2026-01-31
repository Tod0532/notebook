/// 主题状态管理 - 使用 Riverpod 管理用户选择的主题
/// 支持主题持久化存储

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/core/theme/app_themes.dart';

/// 主题存储 Key
const String _kThemeKey = 'app_theme';

/// SharedPreferences 提供者
final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// 主题状态管理器 - 使用 StateNotifier
class ThemeNotifier extends StateNotifier<AppTheme> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(AppTheme.modernGradient) {
    // 不在构造函数中异步加载，避免初始化问题
    _loadThemeFromPrefs();
  }

  /// 从 SharedPreferences 加载主题
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await _ref.read(_sharedPreferencesProvider.future);
      final themeIndex = prefs.getInt(_kThemeKey);
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
      await prefs.setInt(_kThemeKey, theme.index);
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

/// 主题 Notifier Provider
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier(ref);
});

/// 当前主题提供者 - 直接从 StateNotifier 获取
final currentThemeProvider = Provider<AppTheme>((ref) {
  return ref.watch(themeNotifierProvider);
});

/// 当前主题名称提供者
final currentThemeNameProvider = Provider<String>((ref) {
  final theme = ref.watch(currentThemeProvider);
  return themeNames[theme] ?? '未知主题';
});
