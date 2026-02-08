/// 自定义主题色配置
/// 提供多种预设主题色，支持用户自定义主色调

import 'package:flutter/material.dart';

/// 预设主题色配置
class AppThemeColor {
  /// 主题名称
  final String name;

  /// 主色
  final Color primary;

  /// 主色浅色变体
  final Color primaryLight;

  /// 主色深色变体
  final Color primaryDark;

  /// 辅助色
  final Color secondary;

  /// 辅助色浅色变体
  final Color secondaryLight;

  /// 辅助色深色变体
  final Color secondaryDark;

  const AppThemeColor({
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryDark,
  });

  /// 获取主色渐变
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDark, primary, primaryLight],
      );

  /// 获取辅助色渐变
  LinearGradient get secondaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [secondaryDark, secondary, secondaryLight],
      );

  /// 复制并修改部分颜色
  AppThemeColor copyWith({
    String? name,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? secondary,
    Color? secondaryLight,
    Color? secondaryDark,
  }) {
    return AppThemeColor(
      name: name ?? this.name,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      secondaryDark: secondaryDark ?? this.secondaryDark,
    );
  }

  /// 从颜色值创建自定义主题
  factory AppThemeColor.fromColor(String name, Color primaryColor, {Color? secondaryColor}) {
    // 自动生成主色的深浅变体
    final hsl = HSLColor.fromColor(primaryColor);
    final primaryLight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final primaryDark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();

    // 如果没有指定辅助色，使用互补色
    final secondary = secondaryColor ?? hsl.withHue((hsl.hue + 180) % 360).toColor();
    final secondaryHsl = HSLColor.fromColor(secondary);
    final secondaryLight = secondaryHsl.withLightness((secondaryHsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final secondaryDark = secondaryHsl.withLightness((secondaryHsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();

    return AppThemeColor(
      name: name,
      primary: primaryColor,
      primaryLight: primaryLight,
      primaryDark: primaryDark,
      secondary: secondary,
      secondaryLight: secondaryLight,
      secondaryDark: secondaryDark,
    );
  }

  // ==================== 预设主题 ====================

  /// 默认蓝
  static const AppThemeColor defaultBlue = AppThemeColor(
    name: '默认蓝',
    primary: Color(0xFF2196F3),
    primaryLight: Color(0xFF64B5F6),
    primaryDark: Color(0xFF1976D2),
    secondary: Color(0xFFFF9800),
    secondaryLight: Color(0xFFFFB74D),
    secondaryDark: Color(0xFFF57C00),
  );

  /// 翡翠绿
  static const AppThemeColor emerald = AppThemeColor(
    name: '翡翠绿',
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF34D399),
    primaryDark: Color(0xFF059669),
    secondary: Color(0xFF8B5CF6),
    secondaryLight: Color(0xFFA78BFA),
    secondaryDark: Color(0xFF7C3AED),
  );

  /// 樱花粉
  static const AppThemeColor cherry = AppThemeColor(
    name: '樱花粉',
    primary: Color(0xFFEC4899),
    primaryLight: Color(0xFFF472B6),
    primaryDark: Color(0xFFDB2777),
    secondary: Color(0xFF6366F1),
    secondaryLight: Color(0xFF818CF8),
    secondaryDark: Color(0xFF4F46E5),
  );

  /// 紫罗兰
  static const AppThemeColor violet = AppThemeColor(
    name: '紫罗兰',
    primary: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFA78BFA),
    primaryDark: Color(0xFF7C3AED),
    secondary: Color(0xFFEC4899),
    secondaryLight: Color(0xFFF472B6),
    secondaryDark: Color(0xFFDB2777),
  );

  /// 琥珀橙
  static const AppThemeColor amber = AppThemeColor(
    name: '琥珀橙',
    primary: Color(0xFFF59E0B),
    primaryLight: Color(0xFFFBBF24),
    primaryDark: Color(0xFFD97706),
    secondary: Color(0xFF10B981),
    secondaryLight: Color(0xFF34D399),
    secondaryDark: Color(0xFF059669),
  );

  /// 石墨灰
  static const AppThemeColor graphite = AppThemeColor(
    name: '石墨灰',
    primary: Color(0xFF6B7280),
    primaryLight: Color(0xFF9CA3AF),
    primaryDark: Color(0xFF4B5563),
    secondary: Color(0xFF2196F3),
    secondaryLight: Color(0xFF64B5F6),
    secondaryDark: Color(0xFF1976D2),
  );

  /// 海洋蓝
  static const AppThemeColor ocean = AppThemeColor(
    name: '海洋蓝',
    primary: Color(0xFF0284C7),
    primaryLight: Color(0xFF0EA5E9),
    primaryDark: Color(0xFF0369A1),
    secondary: Color(0xFF06B6D4),
    secondaryLight: Color(0xFF22D3EE),
    secondaryDark: Color(0xFF0891B2),
  );

  /// 玫瑰红
  static const AppThemeColor rose = AppThemeColor(
    name: '玫瑰红',
    primary: Color(0xFFE11D48),
    primaryLight: Color(0xFFF43F5E),
    primaryDark: Color(0xFFBE123C),
    secondary: Color(0xFFF59E0B),
    secondaryLight: Color(0xFFFBBF24),
    secondaryDark: Color(0xFFD97706),
  );

  /// 青柠绿
  static const AppThemeColor lime = AppThemeColor(
    name: '青柠绿',
    primary: Color(0xFF84CC16),
    primaryLight: Color(0xFFA3E635),
    primaryDark: Color(0xFF65A30D),
    secondary: Color(0xFFEC4899),
    secondaryLight: Color(0xFFF472B6),
    secondaryDark: Color(0xFFDB2777),
  );

  /// 靛青色
  static const AppThemeColor indigo = AppThemeColor(
    name: '靛青色',
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFF818CF8),
    primaryDark: Color(0xFF4F46E5),
    secondary: Color(0xFFF472B6),
    secondaryLight: Color(0xFFF9A8D4),
    secondaryDark: Color(0xFFEC4899),
  );

  /// 薄荷绿
  static const AppThemeColor mintGreen = AppThemeColor(
    name: '薄荷绿',
    primary: Color(0xFF6EE7B7),
    primaryLight: Color(0xFFA7F3D0),
    primaryDark: Color(0xFF34D399),
    secondary: Color(0xFF8B5CF6),
    secondaryLight: Color(0xFFA78BFA),
    secondaryDark: Color(0xFF7C3AED),
  );

  /// 天空蓝
  static const AppThemeColor skyBlue = AppThemeColor(
    name: '天空蓝',
    primary: Color(0xFF7DD3FC),
    primaryLight: Color(0xFFBAE6FD),
    primaryDark: Color(0xFF38BDF8),
    secondary: Color(0xFF6366F1),
    secondaryLight: Color(0xFF818CF8),
    secondaryDark: Color(0xFF4F46E5),
  );

  /// 珊瑚粉
  static const AppThemeColor coralPink = AppThemeColor(
    name: '珊瑚粉',
    primary: Color(0xFFFCA5A5),
    primaryLight: Color(0xFFFECACA),
    primaryDark: Color(0xFFF87171),
    secondary: Color(0xFFF59E0B),
    secondaryLight: Color(0xFFFBBF24),
    secondaryDark: Color(0xFFD97706),
  );

  /// 所有预设主题
  static const List<AppThemeColor> all = [
    defaultBlue,
    emerald,
    cherry,
    violet,
    amber,
    graphite,
    ocean,
    rose,
    lime,
    indigo,
    mintGreen,
    skyBlue,
    coralPink,
  ];

  /// 根据名称查找主题
  static AppThemeColor? findByName(String name) {
    for (final color in all) {
      if (color.name == name) return color;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeColor &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
