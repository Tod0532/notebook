/// 应用主题配置 - 现代渐变风格
/// 支持多主题动态切换和自定义主题色

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_themes.dart';
import 'package:thick_notepad/core/theme/app_color_scheme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/providers/theme_provider.dart';

/// 主色调 - 现代渐变风格
class AppColors {
  // ==================== 主色系 ====================
  // 主色 - 蓝紫渐变系（现代科技感）
  static const Color primary = Color(0xFF6366F1);        // 靛蓝
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primarySoft = Color(0xFFA5B4FC);

  // 辅助色 - 粉橙渐变系（活力运动）
  static const Color secondary = Color(0xFFF472B6);      // 粉红
  static const Color secondaryDark = Color(0xFFEC4899);
  static const Color secondaryLight = Color(0xFFF9A8D4);

  // 强调色 - 金黄渐变系
  static const Color accent = Color(0xFFFBBF24);         // 金黄
  static const Color accentLight = Color(0xFFFCD34D);

  // ==================== 渐变色定义 ====================
  // 主色渐变
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  // 辅助色渐变（粉橙）
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF472B6), Color(0xFFFB7185), Color(0xFFFDA4AF)],
  );

  // 成功色渐变（绿色）
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)],
  );

  // 警告色渐变（橙色）
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  // 错误色渐变（红色）
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFF87171), Color(0xFFFCA5A5)],
  );

  // 信息色渐变（蓝色）
  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF93C5FD)],
  );

  // 背景渐变（深色主题用）
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
  );

  // 卡片渐变（微妙的渐变）
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );

  // ==================== 游戏化等级渐变 ====================
  // 黄金渐变
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD700), Color(0xFFFFED4E), Color(0xFFFFF59D)],
  );

  // 钻石渐变
  static const LinearGradient diamondGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB9F2FF), Color(0xFFD4ECFF), Color(0xFFE8F4FF)],
  );

  // 传说渐变
  static const LinearGradient legendaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFFFB4B4)],
  );

  // ==================== 基础色 ====================
  // 背景色
  static const Color background = Color(0xFFF8FAFC);      // 浅灰蓝
  static const Color backgroundDark = Color(0xFF0F172A);   // 深蓝灰

  // 表面色
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color darkSurface = Color(0xFF1E293B);

  // 文字色
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textHintDark = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // ==================== 状态色 ====================
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color dividerColorDark = Color(0xFF334155);

  // ==================== 运动分类色 ====================
  static const Color cardioColor = Color(0xFFFF6B6B);
  static const Color strengthColor = Color(0xFF4ECDC4);
  static const Color sportsColor = Color(0xFF95E1D3);
  static const Color otherColor = Color(0xFFA8E6CF);

  // ==================== 标签颜色 ====================
  static const List<Color> tagColors = [
    Color(0xFFF472B6), // 粉红
    Color(0xFF818CF8), // 靛蓝
    Color(0xFFFBBF24), // 金黄
    Color(0xFF34D399), // 青绿
    Color(0xFFA78BFA), // 淡紫
    Color(0xFFFDA4AF), // 玫瑰
    Color(0xFFFCD34D), // 橙黄
    Color(0xFF6EE7B7), // 薄荷
  ];

  static Color getTagColor(String tag) {
    final index = tag.hashCode % tagColors.length;
    return tagColors[index.abs()];
  }
}

/// 阴影系统 - 现代层次感
class AppShadows {
  // 微妙阴影 - 用于轻度浮起
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: -1,
    ),
  ];

  // 轻度阴影 - 用于卡片
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -1,
    ),
  ];

  // 中度阴影 - 用于悬浮卡片
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -2,
    ),
  ];

  // 深度阴影 - 用于弹窗、抽屉
  static const List<BoxShadow> deep = [
    BoxShadow(
      color: Color(0x33000000),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x19000000),
      offset: Offset(0, 16),
      blurRadius: 48,
      spreadRadius: -4,
    ),
  ];

  // 彩色阴影 - 主色
  static List<BoxShadow> primary(BuildContext context) => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  // 彩色阴影 - 辅助色
  static List<BoxShadow> secondary(BuildContext context) => [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.3),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  // 内阴影 (通过 Border 实现)
  static const List<BoxShadow> inner = [];
}

/// 圆角系统
/// 统一管理应用中的所有圆角值，确保设计一致性
class AppRadius {
  /// 超小圆角 4 - 用于小元素的内圆角（如列表项内部、小图标容器）
  static const double xs = 4;

  /// 小圆角 8 - 用于按钮、小卡片
  static const double sm = 8;

  /// 中圆角 12 - 用于输入框、chip 标签
  static const double md = 12;

  /// 大圆角 16 - 用于卡片、对话框
  static const double lg = 16;

  /// 超大圆角 20 - 用于大卡片
  static const double xl = 20;

  /// 特大圆角 24 - 用于底部表单、大对话框
  static const double xxl = 24;

  /// 完全圆角 9999 - 用于圆形按钮、胶囊形标签
  static const double full = 9999;

  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlRadius = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullRadius = BorderRadius.all(Radius.circular(full));
}

/// 统一文字样式系统
/// 确保应用内文字大小和字重一致
class AppTextStyles {
  /// 大标题 - 24px, ExtraBold
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// 中标题 - 20px, Bold
  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// 小标题 - 18px, SemiBold
  static const TextStyle titleSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// 大正文 - 16px, Medium
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// 中正文 - 14px, Regular
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 小正文 - 12px, Regular
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 标签文字 - 11px, Medium
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 按钮文字 - 16px, SemiBold
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
  );
}

/// 间距系统
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// 旧版颜色兼容（保持兼容性）
typedef AppColorsCompat = AppColors;

/// 浅色主题 - 现代渐变风格
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    error: AppColors.error,
  ),

  // Scaffold 背景 - 使用浅灰蓝
  scaffoldBackgroundColor: AppColors.background,

  // AppBar 主题
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.surface.withOpacity(0.9),
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  ),

  // 卡片主题 - 增加现代感
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgRadius,
      side: BorderSide(color: AppColors.dividerColor.withOpacity(0.5), width: 1),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
  ),

  // 输入框主题 - 现代风格
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(
      color: AppColors.textHint,
      fontSize: 15,
    ),
  ),

  // 按钮主题 - 渐变风格
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ).copyWith(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return AppColors.primaryDark;
        }
        return AppColors.primary;
      }),
    ),
  ),

  // 文本按钮主题
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smRadius,
      ),
    ),
  ),

  // 浮动按钮主题
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlRadius,
    ),
  ),

  // 底部导航栏主题
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface.withOpacity(0.95),
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textHint,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
    selectedLabelStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  ),

  // 分割线主题
  dividerTheme: DividerThemeData(
    color: AppColors.dividerColor.withOpacity(0.6),
    thickness: 1,
    space: 1,
  ),

  // 对话框主题 - 现代风格
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlRadius,
    ),
    elevation: 8,
    titleTextStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    contentTextStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 15,
    ),
  ),

  // 底部表单主题
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 12,
    shadowColor: Colors.black.withOpacity(0.15),
  ),

  // Chip 主题
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    selectedColor: AppColors.primary.withOpacity(0.15),
    labelStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.smRadius,
    ),
    side: BorderSide.none,
  ),

  // 文本主题 - 优化字重和间距
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: AppColors.textHint,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      color: AppColors.textHint,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  ),
);

/// 深色主题 - 现代渐变风格
final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    secondary: AppColors.secondaryLight,
    surface: AppColors.surfaceDark,
    error: AppColors.error,
  ),

  scaffoldBackgroundColor: AppColors.backgroundDark,

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.surfaceDark.withOpacity(0.9),
    foregroundColor: AppColors.textPrimaryDark,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      color: AppColors.textPrimaryDark,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  ),

  cardTheme: CardThemeData(
    color: AppColors.surfaceDark,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgRadius,
      side: BorderSide(color: AppColors.dividerColorDark.withOpacity(0.3), width: 1),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariantDark,
    border: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(
      color: AppColors.textHintDark,
      fontSize: 15,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryLight,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlRadius,
    ),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceDark.withOpacity(0.95),
    selectedItemColor: AppColors.primaryLight,
    unselectedItemColor: AppColors.textHintDark,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),

  dividerTheme: DividerThemeData(
    color: AppColors.dividerColorDark.withOpacity(0.3),
    thickness: 1,
    space: 1,
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surfaceDark,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlRadius,
    ),
    elevation: 8,
  ),

  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: AppColors.textPrimaryDark,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    bodyLarge: TextStyle(
      color: AppColors.textPrimaryDark,
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondaryDark,
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: AppColors.textHintDark,
      fontSize: 12,
    ),
  ),
);

// ==================== 动态主题系统 ====================

/// 根据选定的主题类型生成 ThemeData
/// 用于支持多主题切换
ThemeData getThemeData(AppTheme theme) {
  final primary = ThemeFactory.getPrimary(theme);
  final secondary = ThemeFactory.getSecondaryGradient(theme).colors.first;
  final background = ThemeFactory.getBackground(theme);
  final surface = ThemeFactory.getSurface(theme);
  final textPrimary = ThemeFactory.getTextPrimary(theme);
  final textSecondary = ThemeFactory.getTextSecondary(theme);
  final isDark = ThemeFactory.isDarkTheme(theme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: AppColors.error,
    ),

    // Scaffold 背景
    scaffoldBackgroundColor: background,

    // AppBar 主题
    appBarTheme: AppBarTheme(
      backgroundColor: surface.withValues(alpha: isDark ? 0.95 : 0.9),
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    // 卡片主题
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgRadius,
        side: BorderSide(
          color: isDark
              ? AppColors.dividerColorDark.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
    ),

    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 15,
      ),
    ),

    // 按钮主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // 文本按钮主题
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
      ),
    ),

    // 浮动按钮主题
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlRadius,
      ),
    ),

    // 底部导航栏主题
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface.withOpacity(0.95),
      selectedItemColor: primary,
      unselectedItemColor: isDark ? AppColors.textHintDark : AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    // 分割线主题
    dividerTheme: DividerThemeData(
      color: isDark
          ? AppColors.dividerColorDark.withOpacity(0.3)
          : AppColors.dividerColor.withOpacity(0.6),
      thickness: 1,
      space: 1,
    ),

    // 对话框主题
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlRadius,
      ),
      elevation: 8,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: textSecondary,
        fontSize: 15,
      ),
    ),

    // 底部表单主题
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.15),
    ),

    // Chip 主题
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      selectedColor: primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: textSecondary,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smRadius,
      ),
      side: BorderSide.none,
    ),

    // 文本主题
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// ==================== 自定义主题色系统 ====================

/// 根据自定义主题色生成 ThemeData
/// 用于支持用户自定义主色调
ThemeData getThemeDataWithCustomColor(
  AppThemeColor themeColor, {
  bool isDark = false,
}) {
  final primary = themeColor.primary;
  final secondary = themeColor.secondary;
  final background = isDark ? AppColors.backgroundDark : AppColors.background;
  final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
  final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: AppColors.error,
    ),

    // Scaffold 背景
    scaffoldBackgroundColor: background,

    // AppBar 主题
    appBarTheme: AppBarTheme(
      backgroundColor: surface.withValues(alpha: isDark ? 0.95 : 0.9),
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    // 卡片主题
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgRadius,
        side: BorderSide(
          color: isDark
              ? AppColors.dividerColorDark.withOpacity(0.3)
              : AppColors.dividerColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
    ),

    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 15,
      ),
    ),

    // 按钮主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // 文本按钮主题
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
      ),
    ),

    // 浮动按钮主题
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlRadius,
      ),
    ),

    // 底部导航栏主题
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface.withOpacity(0.95),
      selectedItemColor: primary,
      unselectedItemColor: isDark ? AppColors.textHintDark : AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    // 分割线主题
    dividerTheme: DividerThemeData(
      color: isDark
          ? AppColors.dividerColorDark.withOpacity(0.3)
          : AppColors.dividerColor.withOpacity(0.6),
      thickness: 1,
      space: 1,
    ),

    // 对话框主题
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlRadius,
      ),
      elevation: 8,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: textSecondary,
        fontSize: 15,
      ),
    ),

    // 底部表单主题
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.15),
    ),

    // Chip 主题
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      selectedColor: primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: textSecondary,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smRadius,
      ),
      side: BorderSide.none,
    ),

    // 文本主题
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: isDark ? AppColors.textHintDark : AppColors.textHint,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// ==================== 动态主题颜色扩展 ====================

/// BuildContext 扩展 - 方便访问当前主题的颜色
extension ThemeColorsExtension on BuildContext {
  /// 当前自定义主题色
  AppThemeColor get customThemeColor =>
      ProviderScope.containerOf(this).read(currentCustomColorProvider);

  /// 当前主题的主色
  Color get themePrimary => customThemeColor.primary;

  /// 当前主题的主色渐变
  LinearGradient get themePrimaryGradient => customThemeColor.primaryGradient;

  /// 当前主题的辅助色渐变
  LinearGradient get themeSecondaryGradient => customThemeColor.secondaryGradient;

  /// 当前主题的辅助色
  Color get themeSecondary => customThemeColor.secondary;
}

/// WidgetRef 扩展 - 方便在 ConsumerWidget 中访问当前主题的颜色
extension ThemeColorsRefExtension on WidgetRef {
  /// 当前自定义主题色
  AppThemeColor get customThemeColor => read(currentCustomColorProvider);

  /// 当前主题的主色
  Color get themePrimary => customThemeColor.primary;

  /// 当前主题的主色渐变
  LinearGradient get themePrimaryGradient => customThemeColor.primaryGradient;

  /// 当前主题的辅助色渐变
  LinearGradient get themeSecondaryGradient => customThemeColor.secondaryGradient;

  /// 当前主题的辅助色
  Color get themeSecondary => customThemeColor.secondary;
}

// ==================== 主题模式支持（深色模式）====================

/// 根据主题模式和颜色主题生成 ThemeData
/// 支持亮色/深色/跟随系统三种模式
ThemeData getThemeDataWithMode(
  AppTheme colorTheme,
  AppColorMode colorMode,
  Brightness? systemBrightness,
) {
  // 确定是否使用深色模式
  final bool useDarkMode = switch (colorMode) {
    AppColorMode.dark => true,
    AppColorMode.light => false,
    AppColorMode.system => systemBrightness == Brightness.dark,
  };

  // 根据颜色模式选择使用深色还是浅色主题
  final bool isDark = switch (colorMode) {
    AppColorMode.light => false,
    AppColorMode.dark => true,
    AppColorMode.system => systemBrightness == Brightness.dark,
  };

  final selectedTheme = isDark ? AppTheme.darkMode : AppTheme.modernGradient;

  return getThemeData(selectedTheme);
}

