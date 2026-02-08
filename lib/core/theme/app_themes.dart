/// 应用主题配置 - 多主题支持
/// 包含多套配色方案，支持用户自定义切换

import 'package:flutter/material.dart';
import 'dart:ui';

// ==================== 主题枚举 ====================

/// 应用主题类型
enum AppTheme {
  /// 现代渐变 - 靛蓝紫/粉红（默认）
  modernGradient,

  /// 简约黑白 - 黑白灰色系
  minimalBlack,

  /// 暗色模式 - 深色背景
  darkMode,

  /// 自然清新 - 绿色系
  natureFresh,

  /// 海洋深邃 - 蓝色系
  oceanDeep,

  /// 日落温暖 - 橙红色系
  sunsetWarm,

  /// 樱粉甜美 - 粉紫渐变
  cherrySweet,

  /// 极光幻彩 - 彩虹渐变
  auroraColorful,

  /// 赛博朋克 - 霓虹紫/青色系
  cyberpunk,

  /// 森林秘境 - 深绿/棕色系
  forest,

  /// 极简白 - 纯白/灰色系
  minimalWhite;
}

/// 主题显示名称
const Map<AppTheme, String> themeNames = {
  AppTheme.modernGradient: '现代渐变',
  AppTheme.minimalBlack: '简约黑白',
  AppTheme.darkMode: '暗夜模式',
  AppTheme.natureFresh: '自然清新',
  AppTheme.oceanDeep: '海洋深邃',
  AppTheme.sunsetWarm: '日落温暖',
  AppTheme.cherrySweet: '樱花甜美',
  AppTheme.auroraColorful: '极光幻彩',
  AppTheme.cyberpunk: '赛博朋克',
  AppTheme.forest: '森林秘境',
  AppTheme.minimalWhite: '极简白',
};

// ==================== 配色方案 ====================

/// 现代渐变配色（默认）
class _ModernGradientColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFFF472B6);
  static const Color secondaryLight = Color(0xFFF9A8D4);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF472B6), Color(0xFFFB7185), Color(0xFFFDA4AF)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFF87171), Color(0xFFFCA5A5)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF93C5FD)],
  );

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
}

/// 简约黑白配色
class _MinimalBlackColors {
  static const Color primary = Color(0xFF000000);
  static const Color primaryDark = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF333333);
  static const Color secondary = Color(0xFF666666);
  static const Color secondaryLight = Color(0xFF999999);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1a1a1a), Color(0xFF333333)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF666666), Color(0xFF808080), Color(0xFF999999)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1a1a1a), Color(0xFF333333), Color(0xFF4a4a4a)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF333333), Color(0xFF4a4a4a), Color(0xFF666666)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1a1a1a), Color(0xFF333333)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF333333), Color(0xFF4a4a4a), Color(0xFF666666)],
  );

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
}

/// 暗色模式配色
class _DarkModeColors {
  static const Color primary = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFA5B4FC);
  static const Color secondary = Color(0xFFF9A8D4);
  static const Color secondaryLight = Color(0xFFFBCFE8);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFFA78BFA), Color(0xFFC4B5FD)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9A8D4), Color(0xFFFBCFE8), Color(0xFFFDDAFE)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF6EE7B7), Color(0xFF6EE7B7)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFFDE68A), Color(0xFFFDE68A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF87171), Color(0xFFFCA5A5), Color(0xFFFCA5A5)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF93C5FD), Color(0xFF93C5FD)],
  );

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
}

/// 自然清新配色（绿色系）
class _NatureFreshColors {
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFF34D399);
  static const Color secondary = Color(0xFF84CC16);
  static const Color secondaryLight = Color(0xFFA3E635);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF84CC16), Color(0xFFA3E635), Color(0xFFBEF264)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF4ADE80), Color(0xFF86EFAC)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF84CC16), Color(0xFFA3E635), Color(0xFFBEF264)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  static const Color background = Color(0xFFF0FDF4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF14532D);
  static const Color textSecondary = Color(0xFF166534);
}

/// 海洋深邃配色（蓝色系）
class _OceanDeepColors {
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryDark = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFF0EA5E9);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color secondaryLight = Color(0xFF22D3EE);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF22D3EE), Color(0xFF67E8F9)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0EA5E9)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  static const Color background = Color(0xFFE0F2FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0C4A6E);
  static const Color textSecondary = Color(0xFF075985);
}

/// 日落温暖配色（橙红色系）
class _SunsetWarmColors {
  static const Color primary = Color(0xFFEA580C);
  static const Color primaryDark = Color(0xFFC2410C);
  static const Color primaryLight = Color(0xFFF97316);
  static const Color secondary = Color(0xFFDC2626);
  static const Color secondaryLight = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFDBA74)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFDBA74)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFFDBA74), Color(0xFFFED7AA)],
  );

  static const Color background = Color(0xFFFFF7ED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF7C2D12);
  static const Color textSecondary = Color(0xFF9A3412);
}

/// 樱粉甜美配色（粉紫渐变）
class _CherrySweetColors {
  static const Color primary = Color(0xFFEC4899);
  static const Color primaryDark = Color(0xFFDB2777);
  static const Color primaryLight = Color(0xFFF472B6);
  static const Color secondary = Color(0xFFA855F7);
  static const Color secondaryLight = Color(0xFFC084FC);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF472B6), Color(0xFFF9A8D4)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFFC084FC), Color(0xFFE879F9)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFFDE68A), Color(0xFFFDE68A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFFC4B5FD)],
  );

  static const Color background = Color(0xFFFDF2F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF831843);
  static const Color textSecondary = Color(0xFF9D174D);
}

/// 极光幻彩配色（彩虹渐变）
class _AuroraColorfulColors {
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryDark = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color secondary = Color(0xFFEC4899);
  static const Color secondaryLight = Color(0xFFF472B6);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF472B6)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF22C55E), Color(0xFF4ADE80)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF93C5FD)],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),  // 紫
      Color(0xFFEC4899),  // 粉
      Color(0xFFF59E0B),  // 橙
      Color(0xFF10B981),  // 绿
      Color(0xFF3B82F6),  // 蓝
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  static const Color background = Color(0xFFFAF5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF581C87);
  static const Color textSecondary = Color(0xFF6B21A8);
}

/// 赛博朋克配色（霓虹紫/青色系）
class _CyberpunkColors {
  static const Color primary = Color(0xFFD946EF);
  static const Color primaryDark = Color(0xFFC026D3);
  static const Color primaryLight = Color(0xFFE879F9);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color secondaryLight = Color(0xFF22D3EE);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD946EF), Color(0xFFA855F7), Color(0xFF8B5CF6)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFF87171), Color(0xFFFCA5A5)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF93C5FD)],
  );

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
}

/// 森林秘境配色（深绿/棕色系）
class _ForestColors {
  static const Color primary = Color(0xFF059669);
  static const Color primaryDark = Color(0xFF047857);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color secondary = Color(0xFF92400E);
  static const Color secondaryLight = Color(0xFFB45309);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF4ADE80), Color(0xFF86EFAC)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const Color background = Color(0xFFF0FDF4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF14532D);
  static const Color textSecondary = Color(0xFF166534);
}

/// 极简白配色（纯白/灰色系）
class _MinimalWhiteColors {
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFFF3F4F6);
  static const Color primaryLight = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF9CA3AF);
  static const Color secondaryLight = Color(0xFFD1D5DB);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9CA3AF), Color(0xFFD1D5DB), Color(0xFFE5E7EB)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD1D5DB), Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9CA3AF), Color(0xFFD1D5DB), Color(0xFFE5E7EB)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B7280), Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9CA3AF), Color(0xFFD1D5DB), Color(0xFFE5E7EB)],
  );

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
}

// ==================== 主题工厂 ====================

/// 主题工厂 - 根据主题类型生成对应的配色
class ThemeFactory {
  /// 获取主色
  static Color getPrimary(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.primary;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.primary;
      case AppTheme.darkMode:
        return _DarkModeColors.primary;
      case AppTheme.natureFresh:
        return _NatureFreshColors.primary;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.primary;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.primary;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.primary;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.primary;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.primary;
      case AppTheme.forest:
        return _ForestColors.primary;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.primary;
    }
  }

  /// 获取主色渐变
  static LinearGradient getPrimaryGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.primaryGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.primaryGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.primaryGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.primaryGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.primaryGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.primaryGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.primaryGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.primaryGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.primaryGradient;
      case AppTheme.forest:
        return _ForestColors.primaryGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.primaryGradient;
    }
  }

  /// 获取辅助色渐变
  static LinearGradient getSecondaryGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.secondaryGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.secondaryGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.secondaryGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.secondaryGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.secondaryGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.secondaryGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.secondaryGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.secondaryGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.secondaryGradient;
      case AppTheme.forest:
        return _ForestColors.secondaryGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.secondaryGradient;
    }
  }

  /// 获取成功渐变
  static LinearGradient getSuccessGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.successGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.successGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.successGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.successGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.successGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.successGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.successGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.successGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.successGradient;
      case AppTheme.forest:
        return _ForestColors.successGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.successGradient;
    }
  }

  /// 获取警告渐变
  static LinearGradient getWarningGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.warningGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.warningGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.warningGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.warningGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.warningGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.warningGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.warningGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.warningGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.warningGradient;
      case AppTheme.forest:
        return _ForestColors.warningGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.warningGradient;
    }
  }

  /// 获取错误渐变
  static LinearGradient getErrorGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.errorGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.errorGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.errorGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.errorGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.errorGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.errorGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.errorGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.errorGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.errorGradient;
      case AppTheme.forest:
        return _ForestColors.errorGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.errorGradient;
    }
  }

  /// 获取信息渐变
  static LinearGradient getInfoGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.infoGradient;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.infoGradient;
      case AppTheme.darkMode:
        return _DarkModeColors.infoGradient;
      case AppTheme.natureFresh:
        return _NatureFreshColors.infoGradient;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.infoGradient;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.infoGradient;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.infoGradient;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.infoGradient;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.infoGradient;
      case AppTheme.forest:
        return _ForestColors.infoGradient;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.infoGradient;
    }
  }

  /// 获取背景色
  static Color getBackground(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.background;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.background;
      case AppTheme.darkMode:
        return _DarkModeColors.background;
      case AppTheme.natureFresh:
        return _NatureFreshColors.background;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.background;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.background;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.background;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.background;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.background;
      case AppTheme.forest:
        return _ForestColors.background;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.background;
    }
  }

  /// 获取表面色
  static Color getSurface(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.surface;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.surface;
      case AppTheme.darkMode:
        return _DarkModeColors.surface;
      case AppTheme.natureFresh:
        return _NatureFreshColors.surface;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.surface;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.surface;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.surface;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.surface;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.surface;
      case AppTheme.forest:
        return _ForestColors.surface;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.surface;
    }
  }

  /// 获取文本主色
  static Color getTextPrimary(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.textPrimary;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.textPrimary;
      case AppTheme.darkMode:
        return _DarkModeColors.textPrimary;
      case AppTheme.natureFresh:
        return _NatureFreshColors.textPrimary;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.textPrimary;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.textPrimary;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.textPrimary;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.textPrimary;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.textPrimary;
      case AppTheme.forest:
        return _ForestColors.textPrimary;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.textPrimary;
    }
  }

  /// 获取文本次要色
  static Color getTextSecondary(AppTheme theme) {
    switch (theme) {
      case AppTheme.modernGradient:
        return _ModernGradientColors.textSecondary;
      case AppTheme.minimalBlack:
        return _MinimalBlackColors.textSecondary;
      case AppTheme.darkMode:
        return _DarkModeColors.textSecondary;
      case AppTheme.natureFresh:
        return _NatureFreshColors.textSecondary;
      case AppTheme.oceanDeep:
        return _OceanDeepColors.textSecondary;
      case AppTheme.sunsetWarm:
        return _SunsetWarmColors.textSecondary;
      case AppTheme.cherrySweet:
        return _CherrySweetColors.textSecondary;
      case AppTheme.auroraColorful:
        return _AuroraColorfulColors.textSecondary;
      case AppTheme.cyberpunk:
        return _CyberpunkColors.textSecondary;
      case AppTheme.forest:
        return _ForestColors.textSecondary;
      case AppTheme.minimalWhite:
        return _MinimalWhiteColors.textSecondary;
    }
  }

  /// 是否为深色主题
  static bool isDarkTheme(AppTheme theme) {
    return theme == AppTheme.darkMode || theme == AppTheme.cyberpunk;
  }
}
