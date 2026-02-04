/// 游戏化数据模型
/// 定义成就、等级、积分相关的数据结构

import 'dart:math' as math;
import 'package:thick_notepad/services/database/database.dart' as db;

// ==================== 成就枚举定义 ====================

/// 成就分类枚举
enum AchievementCategory {
  workout('运动', 'workout'),
  streak('连续打卡', 'streak'),
  note('笔记', 'note'),
  plan('计划', 'plan'),
  milestone('里程碑', 'milestone'),
  social('社交', 'social'),
  other('其他', 'other');

  final String displayName;
  final String value;

  const AchievementCategory(this.displayName, this.value);

  static AchievementCategory fromString(String value) {
    return AchievementCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AchievementCategory.other,
    );
  }
}

/// 成就稀有度枚举
enum AchievementTier {
  bronze('青铜', 'bronze', '#CD7F32'),
  silver('白银', 'silver', '#C0C0C0'),
  gold('黄金', 'gold', '#FFD700'),
  diamond('钻石', 'diamond', '#B9F2FF'),
  legendary('传说', 'legendary', '#FF6B6B');

  final String displayName;
  final String value;
  final String colorHex;

  const AchievementTier(this.displayName, this.value, this.colorHex);

  static AchievementTier fromString(String value) {
    return AchievementTier.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AchievementTier.bronze,
    );
  }
}

// ==================== 成就定义 ====================

/// 成就定义类 - 用于配置所有可解锁的成就
class AchievementDef {
  final String id; // 成就唯一标识
  final String name; // 成就名称
  final String description; // 成就描述
  final String icon; // 图标名称
  final AchievementCategory category; // 成就分类
  final AchievementTier tier; // 成就稀有度
  final int requirement; // 达成条件数值
  final int expReward; // 经验值奖励
  final int pointsReward; // 积分奖励
  final String conditionType; // 条件类型

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.tier,
    required this.requirement,
    required this.expReward,
    required this.pointsReward,
    required this.conditionType,
  });
}

/// 成就进度信息
class AchievementProgress {
  final AchievementDef achievement; // 成就定义
  final int currentProgress; // 当前进度
  final bool isUnlocked; // 是否已解锁
  final DateTime? unlockedAt; // 解锁时间

  AchievementProgress({
    required this.achievement,
    required this.currentProgress,
    required this.isUnlocked,
    this.unlockedAt,
  });

  /// 获取进度百分比 (0.0 - 1.0)
  double get progressPercent {
    if (isUnlocked) return 1.0;
    if (achievement.requirement <= 0) return 0.0;
    return (currentProgress / achievement.requirement).clamp(0.0, 1.0);
  }
}

// ==================== 用户游戏数据 ====================

/// 用户游戏化数据视图模型
class UserGameDataModel {
  final int id;
  final int level; // 当前等级
  final int exp; // 当前经验值
  final int totalExp; // 总经验值
  final int points; // 当前积分
  final int totalPoints; // 总获得积分
  final int currentStreak; // 当前连续打卡天数
  final int longestStreak; // 最长连续打卡天数
  final DateTime? lastCheckInDate; // 上次打卡日期
  final int unlockedAchievements; // 已解锁成就数
  final int totalAchievements; // 总成就数
  final int totalWorkouts; // 总运动次数
  final int totalWorkoutMinutes; // 总运动时长（分钟）
  final int totalNotes; // 总笔记数
  final int totalPlans; // 总计划数
  final int completedPlans; // 完成计划数

  UserGameDataModel({
    required this.id,
    required this.level,
    required this.exp,
    required this.totalExp,
    required this.points,
    required this.totalPoints,
    required this.currentStreak,
    required this.longestStreak,
    this.lastCheckInDate,
    required this.unlockedAchievements,
    required this.totalAchievements,
    required this.totalWorkouts,
    required this.totalWorkoutMinutes,
    required this.totalNotes,
    required this.totalPlans,
    required this.completedPlans,
  });

  /// 从数据库实体创建
  factory UserGameDataModel.fromDb(db.GamificationUserProfile db) {
    return UserGameDataModel(
      id: db.id,
      level: db.level,
      exp: db.experience,
      totalExp: db.totalExperience,
      points: db.points,
      totalPoints: db.totalPoints,
      currentStreak: db.currentStreak,
      longestStreak: db.longestStreak,
      lastCheckInDate: db.lastCheckInDate,
      unlockedAchievements: db.unlockedAchievements,
      totalAchievements: db.totalAchievements,
      totalWorkouts: db.totalWorkouts,
      totalWorkoutMinutes: db.totalWorkoutMinutes,
      totalNotes: db.totalNotes,
      totalPlans: db.totalPlans,
      completedPlans: db.completedPlans,
    );
  }

  /// 获取下一等级所需经验值
  int get expToNextLevel {
    return LevelConfig.getExperienceForLevel(level + 1) - totalExp;
  }

  /// 获取当前等级进度百分比
  double get levelProgress {
    return LevelConfig.getLevelProgress(totalExp);
  }

  /// 获取当前等级的进度条显示值（当前等级内的经验）
  int get currentLevelExp {
    final currentLevelTotalExp = LevelConfig.getExperienceForLevel(level);
    return totalExp - currentLevelTotalExp;
  }

  /// 获取升级到下一级需要的经验
  int get nextLevelRequiredExp {
    return LevelConfig.getExperienceForLevel(level + 1) -
           LevelConfig.getExperienceForLevel(level);
  }
}

// ==================== 等级配置 ====================

/// 等级配置类 - 处理等级相关的计算
class LevelConfig {
  /// 最高等级
  static const int maxLevel = 100;

  /// 获取指定等级所需的总经验值
  /// 使用指数增长公式：100 * (level - 1) ^ 1.5
  static int getExperienceForLevel(int level) {
    if (level <= 1) return 0;
    if (level > maxLevel) level = maxLevel;
    // 使用 Dart 的 pow 函数
    return (100 * _pow(level - 1, 1.5)).round();
  }

  /// 根据总经验值获取当前等级
  static int getLevelFromExperience(int totalExperience) {
    int level = 1;
    while (level < maxLevel && totalExperience >= getExperienceForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  /// 获取当前等级的进度百分比 (0.0 - 1.0)
  static double getLevelProgress(int totalExperience) {
    final level = getLevelFromExperience(totalExperience);
    final currentLevelExp = getExperienceForLevel(level);
    final nextLevelExp = getExperienceForLevel(level + 1);
    final currentExp = totalExperience - currentLevelExp;
    final neededExp = nextLevelExp - currentLevelExp;
    if (neededExp == 0) return 1.0;
    return (currentExp / neededExp).clamp(0.0, 1.0);
  }

  /// 获取等级对应的称号
  static String getLevelTitle(int level) {
    if (level < 5) return '运动新手';
    if (level < 10) return '健身爱好者';
    if (level < 20) return '运动达人';
    if (level < 30) return '健身教练';
    if (level < 40) return '运动大师';
    if (level < 50) return '健身专家';
    if (level < 60) return '运动传奇';
    if (level < 70) return '健身英雄';
    if (level < 80) return '运动之神';
    if (level < 90) return '健身至尊';
    return '运动王者';
  }

  /// 获取等级对应的颜色
  static String getLevelColor(int level) {
    if (level < 10) return '#94A3B8'; // 灰色
    if (level < 20) return '#22C55E'; // 绿色
    if (level < 30) return '#3B82F6'; // 蓝色
    if (level < 40) return '#8B5CF6'; // 紫色
    if (level < 50) return '#EC4899'; // 粉色
    if (level < 60) return '#F59E0B'; // 橙色
    if (level < 70) return '#EF4444'; // 红色
    if (level < 80) return '#FFD700'; // 金色
    if (level < 90) return '#00D4FF'; // 青色
    return '#FF6B6B'; // 传说红
  }

  /// 幂运算辅助函数
  static double _pow(double base, double exponent) {
    return math.pow(base, exponent).toDouble();
  }
}

// ==================== 积分奖励配置 ====================

/// 积分奖励配置类
class PointReward {
  /// 记录运动获得的积分
  static const int workout = 10;
  /// 每运动1分钟额外获得的积分
  static const int workoutPerMinute = 1;
  /// 连续打卡每天获得的积分
  static const int dailyCheckIn = 5;
  /// 完成计划获得的积分
  static const int planCompleted = 20;
  /// 创建笔记获得的积分
  static const int noteCreated = 5;
  /// 完成计划任务获得的积分
  static const int planTaskCompleted = 3;
  /// 连续打卡额外奖励倍数（每7天额外奖励）
  static const int streakWeeklyBonus = 50;
}

// ==================== 经验奖励配置 ====================

/// 经验奖励配置类
class ExperienceReward {
  /// 记录运动获得的经验值
  static const int workout = 15;
  /// 每运动1分钟额外获得的经验值
  static const int workoutPerMinute = 2;
  /// 连续打卡每天获得的经验值
  static const int dailyCheckIn = 10;
  /// 完成计划获得的经验值
  static const int planCompleted = 30;
  /// 创建笔记获得的经验值
  static const int noteCreated = 8;
  /// 完成计划任务获得的经验值
  static const int planTaskCompleted = 5;
  /// 升级额外奖励经验
  static const int levelUpBonus = 50;
}

// ==================== 商店物品模型 ====================

/// 商店物品模型
class ShopItemModel {
  final int id;
  final String name;
  final String description;
  final int cost;
  final ShopItemType type;
  final String value; // 物品值（可能是颜色代码、图标名称等）
  final bool isAvailable;
  final bool isPurchased; // 是否已购买
  final DateTime? purchasedAt;

  ShopItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.value,
    required this.isAvailable,
    this.isPurchased = false,
    this.purchasedAt,
  });

  /// 从数据库实体创建
  factory ShopItemModel.fromDb(db.ShopItem item, {bool isPurchased = false}) {
    return ShopItemModel(
      id: item.id,
      name: item.name,
      description: item.description ?? '',
      cost: item.cost,
      type: ShopItemType.fromString(item.type),
      value: item.value,
      isAvailable: item.isAvailable,
      isPurchased: isPurchased,
    );
  }
}

/// 商店物品类型
enum ShopItemType {
  theme('主题', 'theme'),
  title('称号', 'title'),
  icon('图标', 'icon'),
  badge('徽章', 'badge');

  final String displayName;
  final String value;

  const ShopItemType(this.displayName, this.value);

  static ShopItemType fromString(String value) {
    return ShopItemType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ShopItemType.theme,
    );
  }
}

// ==================== 成就定义列表 ====================

/// 所有成就定义
class AchievementDefinitions {
  /// 获取所有成就定义
  static const List<AchievementDef> allAchievements = [
    // ==================== 运动相关成就 ====================
    AchievementDef(
      id: 'first_workout',
      name: '初出茅庐',
      description: '完成第一次运动记录',
      icon: 'emoji_events',
      category: AchievementCategory.workout,
      tier: AchievementTier.bronze,
      requirement: 1,
      expReward: 10,
      pointsReward: 5,
      conditionType: 'workout_count',
    ),
    AchievementDef(
      id: 'workout_10',
      name: '运动达人',
      description: '累计完成10次运动',
      icon: 'fitness_center',
      category: AchievementCategory.workout,
      tier: AchievementTier.bronze,
      requirement: 10,
      expReward: 30,
      pointsReward: 15,
      conditionType: 'total_workouts',
    ),
    AchievementDef(
      id: 'workout_50',
      name: '运动健将',
      description: '累计完成50次运动',
      icon: 'directions_run',
      category: AchievementCategory.workout,
      tier: AchievementTier.silver,
      requirement: 50,
      expReward: 100,
      pointsReward: 50,
      conditionType: 'total_workouts',
    ),
    AchievementDef(
      id: 'workout_100',
      name: '运动大师',
      description: '累计完成100次运动',
      icon: 'military_tech',
      category: AchievementCategory.workout,
      tier: AchievementTier.gold,
      requirement: 100,
      expReward: 300,
      pointsReward: 150,
      conditionType: 'total_workouts',
    ),
    AchievementDef(
      id: 'workout_minutes_60',
      name: '一小时勇士',
      description: '单次运动超过60分钟',
      icon: 'timer',
      category: AchievementCategory.workout,
      tier: AchievementTier.bronze,
      requirement: 60,
      expReward: 20,
      pointsReward: 10,
      conditionType: 'single_workout_minutes',
    ),
    AchievementDef(
      id: 'workout_minutes_500',
      name: '耐力冠军',
      description: '累计运动时长达到500分钟',
      icon: 'schedule',
      category: AchievementCategory.workout,
      tier: AchievementTier.silver,
      requirement: 500,
      expReward: 80,
      pointsReward: 40,
      conditionType: 'total_minutes',
    ),
    AchievementDef(
      id: 'workout_minutes_1000',
      name: '耐力之王',
      description: '累计运动时长达到1000分钟',
      icon: 'access_time',
      category: AchievementCategory.workout,
      tier: AchievementTier.gold,
      requirement: 1000,
      expReward: 200,
      pointsReward: 100,
      conditionType: 'total_minutes',
    ),

    // ==================== 连续打卡成就 ====================
    AchievementDef(
      id: 'streak_3',
      name: '坚持不懈',
      description: '连续打卡3天',
      icon: 'local_fire_department',
      category: AchievementCategory.streak,
      tier: AchievementTier.bronze,
      requirement: 3,
      expReward: 15,
      pointsReward: 10,
      conditionType: 'streak_days',
    ),
    AchievementDef(
      id: 'streak_7',
      name: '一周坚持',
      description: '连续打卡7天',
      icon: 'whatshot',
      category: AchievementCategory.streak,
      tier: AchievementTier.silver,
      requirement: 7,
      expReward: 50,
      pointsReward: 25,
      conditionType: 'streak_days',
    ),
    AchievementDef(
      id: 'streak_14',
      name: '双周奇迹',
      description: '连续打卡14天',
      icon: 'flare',
      category: AchievementCategory.streak,
      tier: AchievementTier.silver,
      requirement: 14,
      expReward: 100,
      pointsReward: 50,
      conditionType: 'streak_days',
    ),
    AchievementDef(
      id: 'streak_30',
      name: '月度传奇',
      description: '连续打卡30天',
      icon: 'stars',
      category: AchievementCategory.streak,
      tier: AchievementTier.gold,
      requirement: 30,
      expReward: 300,
      pointsReward: 150,
      conditionType: 'streak_days',
    ),
    AchievementDef(
      id: 'streak_100',
      name: '百日挑战',
      description: '连续打卡100天',
      icon: 'grade',
      category: AchievementCategory.streak,
      tier: AchievementTier.diamond,
      requirement: 100,
      expReward: 1000,
      pointsReward: 500,
      conditionType: 'streak_days',
    ),

    // ==================== 笔记相关成就 ====================
    AchievementDef(
      id: 'first_note',
      name: '记录开始',
      description: '创建第一条笔记',
      icon: 'edit_note',
      category: AchievementCategory.note,
      tier: AchievementTier.bronze,
      requirement: 1,
      expReward: 5,
      pointsReward: 2,
      conditionType: 'note_count',
    ),
    AchievementDef(
      id: 'note_10',
      name: '笔记新手',
      description: '累计创建10条笔记',
      icon: 'note',
      category: AchievementCategory.note,
      tier: AchievementTier.bronze,
      requirement: 10,
      expReward: 20,
      pointsReward: 10,
      conditionType: 'note_count',
    ),
    AchievementDef(
      id: 'note_50',
      name: '笔记达人',
      description: '累计创建50条笔记',
      icon: 'description',
      category: AchievementCategory.note,
      tier: AchievementTier.silver,
      requirement: 50,
      expReward: 80,
      pointsReward: 40,
      conditionType: 'note_count',
    ),
    AchievementDef(
      id: 'note_100',
      name: '笔记大师',
      description: '累计创建100条笔记',
      icon: 'menu_book',
      category: AchievementCategory.note,
      tier: AchievementTier.gold,
      requirement: 100,
      expReward: 200,
      pointsReward: 100,
      conditionType: 'note_count',
    ),

    // ==================== 计划相关成就 ====================
    AchievementDef(
      id: 'first_plan',
      name: '计划启程',
      description: '创建第一个计划',
      icon: 'event_note',
      category: AchievementCategory.plan,
      tier: AchievementTier.bronze,
      requirement: 1,
      expReward: 10,
      pointsReward: 5,
      conditionType: 'plan_count',
    ),
    AchievementDef(
      id: 'complete_first_plan',
      name: '说到做到',
      description: '完成第一个计划',
      icon: 'check_circle',
      category: AchievementCategory.plan,
      tier: AchievementTier.bronze,
      requirement: 1,
      expReward: 20,
      pointsReward: 10,
      conditionType: 'completed_plans',
    ),
    AchievementDef(
      id: 'complete_5_plans',
      name: '计划专家',
      description: '完成5个计划',
      icon: 'task_alt',
      category: AchievementCategory.plan,
      tier: AchievementTier.silver,
      requirement: 5,
      expReward: 100,
      pointsReward: 50,
      conditionType: 'completed_plans',
    ),
    AchievementDef(
      id: 'complete_10_plans',
      name: '计划大师',
      description: '完成10个计划',
      icon: 'fact_check',
      category: AchievementCategory.plan,
      tier: AchievementTier.gold,
      requirement: 10,
      expReward: 250,
      pointsReward: 125,
      conditionType: 'completed_plans',
    ),

    // ==================== 等级成就 ====================
    AchievementDef(
      id: 'level_5',
      name: '初露锋芒',
      description: '达到5级',
      icon: 'trending_up',
      category: AchievementCategory.milestone,
      tier: AchievementTier.bronze,
      requirement: 5,
      expReward: 25,
      pointsReward: 15,
      conditionType: 'level',
    ),
    AchievementDef(
      id: 'level_10',
      name: '渐入佳境',
      description: '达到10级',
      icon: 'showchart',
      category: AchievementCategory.milestone,
      tier: AchievementTier.silver,
      requirement: 10,
      expReward: 50,
      pointsReward: 30,
      conditionType: 'level',
    ),
    AchievementDef(
      id: 'level_25',
      name: '脱颖而出',
      description: '达到25级',
      icon: 'rocket_launch',
      category: AchievementCategory.milestone,
      tier: AchievementTier.gold,
      requirement: 25,
      expReward: 150,
      pointsReward: 75,
      conditionType: 'level',
    ),
    AchievementDef(
      id: 'level_50',
      name: '登峰造极',
      description: '达到50级',
      icon: 'workspace_premium',
      category: AchievementCategory.milestone,
      tier: AchievementTier.diamond,
      requirement: 50,
      expReward: 500,
      pointsReward: 250,
      conditionType: 'level',
    ),
    AchievementDef(
      id: 'level_100',
      name: '传奇之巅',
      description: '达到100级',
      icon: 'diamond',
      category: AchievementCategory.milestone,
      tier: AchievementTier.legendary,
      requirement: 100,
      expReward: 2000,
      pointsReward: 1000,
      conditionType: 'level',
    ),

    // ==================== 积分成就 ====================
    AchievementDef(
      id: 'points_100',
      name: '积分新星',
      description: '累计获得100积分',
      icon: 'stars',
      category: AchievementCategory.milestone,
      tier: AchievementTier.bronze,
      requirement: 100,
      expReward: 20,
      pointsReward: 10,
      conditionType: 'total_points',
    ),
    AchievementDef(
      id: 'points_500',
      name: '积分富户',
      description: '累计获得500积分',
      icon: 'paid',
      category: AchievementCategory.milestone,
      tier: AchievementTier.silver,
      requirement: 500,
      expReward: 100,
      pointsReward: 50,
      conditionType: 'total_points',
    ),
    AchievementDef(
      id: 'points_1000',
      name: '积分大亨',
      description: '累计获得1000积分',
      icon: 'account_balance',
      category: AchievementCategory.milestone,
      tier: AchievementTier.gold,
      requirement: 1000,
      expReward: 250,
      pointsReward: 125,
      conditionType: 'total_points',
    ),
    AchievementDef(
      id: 'points_5000',
      name: '积分巨鳄',
      description: '累计获得5000积分',
      icon: 'savings',
      category: AchievementCategory.milestone,
      tier: AchievementTier.diamond,
      requirement: 5000,
      expReward: 1000,
      pointsReward: 500,
      conditionType: 'total_points',
    ),
  ];

  /// 根据ID获取成就定义
  static AchievementDef? getById(String id) {
    try {
      return allAchievements.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据分类获取成就列表
  static List<AchievementDef> getByCategory(AchievementCategory category) {
    return allAchievements.where((a) => a.category == category).toList();
  }

  /// 根据稀有度获取成就列表
  static List<AchievementDef> getByTier(AchievementTier tier) {
    return allAchievements.where((a) => a.tier == tier).toList();
  }
}
