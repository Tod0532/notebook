/// 抽卡系统服务
/// 管理抽卡概率、保底机制、物品池等

import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:thick_notepad/services/database/database.dart';

// ==================== 抽卡配置 ====================

/// 稀有度枚举
enum GachaRarity {
  common('普通', 'common', 0.60, '#9E9E9E'),
  rare('稀有', 'rare', 0.30, '#2196F3'),
  epic('史诗', 'epic', 0.08, '#9C27B0'),
  legendary('传说', 'legendary', 0.02, '#FF9800');

  final String displayName;
  final String value;
  final double baseProbability; // 基础概率
  final String colorHex;

  const GachaRarity(
    this.displayName,
    this.value,
    this.baseProbability,
    this.colorHex,
  );

  static GachaRarity fromString(String value) {
    return GachaRarity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GachaRarity.common,
    );
  }
}

/// 物品类型枚举
enum GachaItemType {
  title('称号', 'title'),
  theme('主题', 'theme'),
  icon('图标', 'icon'),
  badge('徽章', 'badge');

  final String displayName;
  final String value;

  const GachaItemType(this.displayName, this.value);

  static GachaItemType fromString(String value) {
    return GachaItemType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GachaItemType.badge,
    );
  }
}

/// 抽卡配置
class GachaConfig {
  /// 保底机制：10抽必出稀有以上
  static const int pityThreshold = 10;

  /// 免费抽卡次数
  static const int freeDailyDraws = 1;

  /// 单抽消耗积分
  static const int singleDrawCost = 50;

  /// 十连抽消耗积分
  static const int tenDrawCost = 450;

  /// 稀有度保底阈值
  static const int rarePityThreshold = 10;
  static const int epicPityThreshold = 50;
  static const int legendaryPityThreshold = 100;

  /// 获取稀有度概率（考虑保底）
  ///
  /// 保底机制说明：
  /// - 10抽必出稀有以上
  /// - 50抽必出史诗以上
  /// - 100抽必出传说
  static Map<GachaRarity, double> getRarityProbabilities(int pityCount) {
    // 100抽保底：必出传说（修复：移除-1偏移）
    if (pityCount >= legendaryPityThreshold) {
      return {
        GachaRarity.common: 0.0,
        GachaRarity.rare: 0.0,
        GachaRarity.epic: 0.0,
        GachaRarity.legendary: 1.0,
      };
    }

    // 50抽保底：必出史诗以上（修复：移除-1偏移）
    if (pityCount >= epicPityThreshold) {
      return {
        GachaRarity.common: 0.0,
        GachaRarity.rare: 0.0,
        GachaRarity.epic: 1.0,
        GachaRarity.legendary: 0.0,
      };
    }

    // 10抽保底：必出稀有以上（修复：使用正确的触发点和概率归一化）
    if (pityCount >= rarePityThreshold) {
      // 软保底阶段：从第10抽到第49抽
      // 进度值：0.0 (第10抽) -> 1.0 (第49抽)
      final softPityProgress = (pityCount - rarePityThreshold) /
          (epicPityThreshold - rarePityThreshold - 1);

      // 修复：调整概率增量，确保总和为100%
      // 初始：稀有70%、史诗25%、传说5% = 100%
      // 最终：稀有80%、史诗15%、传说5% = 100%
      final rareChance = 0.70 + (0.10 * softPityProgress); // 70% -> 80%
      final epicChance = 0.25 - (0.10 * softPityProgress); // 25% -> 15%
      final legendaryChance = 0.05; // 保持5%不变

      // 归一化处理，确保总和精确为100%
      final total = rareChance + epicChance + legendaryChance;

      return {
        GachaRarity.common: 0.0,
        GachaRarity.rare: rareChance / total,
        GachaRarity.epic: epicChance / total,
        GachaRarity.legendary: legendaryChance / total,
      };
    }

    // 正常概率：普通60%、稀有30%、史诗8%、传说2%
    return {
      GachaRarity.common: 0.60,
      GachaRarity.rare: 0.30,
      GachaRarity.epic: 0.08,
      GachaRarity.legendary: 0.02,
    };
  }
}

// ==================== 物品池定义 ====================

/// 抽卡物品
class GachaItem {
  final String name;
  final String description;
  final GachaItemType type;
  final GachaRarity rarity;

  const GachaItem({
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'rarity': rarity.value,
    };
  }

  /// 从JSON创建
  factory GachaItem.fromJson(Map<String, dynamic> json) {
    return GachaItem(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: GachaItemType.fromString(json['type'] as String? ?? 'badge'),
      rarity: GachaRarity.fromString(json['rarity'] as String? ?? 'common'),
    );
  }
}

/// 物品池配置
///
/// 物品池设计原则：
/// 1. 普通池：日常易获得的称号和徽章，保持新鲜感
/// 2. 稀有池：有一定挑战性的成就，加上基础主题
/// 3. 史诗池：长期坚持的成就证明，优质主题
/// 4. 传说池：终极成就，稀有且独特
class GachaItemPool {
  /// 普通物品池 - 20个物品
  static const List<GachaItem> commonItems = [
    // ========== 称号 (10个) ==========
    GachaItem(
      name: '早起鸟',
      description: '晨光中的先行者，在6点前开始活动',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '夜猫子',
      description: '夜晚的守护者，在22点后仍在坚持',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '记录者',
      description: '生活的观察家，创建第10条笔记',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '初出茅庐',
      description: '旅程的开始，完成第一次运动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '持之以恒',
      description: '连续3天保持活动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '周末达人',
      description: '周末也不松懈，完成运动计划',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '计划入门',
      description: '创建第一个个人计划',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '笔耕不辍',
      description: '连续7天记录笔记',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '健康意识',
      description: '关注心率健康，完成首次心率监测',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '探索者',
      description: '使用GPS追踪功能记录运动路线',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),

    // ========== 徽章 (10个) ==========
    GachaItem(
      name: '青铜徽章',
      description: '新手冒险家的证明，迈出第一步',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '运动初学者',
      description: '完成第一次运动记录的纪念',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '笔记达人',
      description: '连续7天记录笔记的坚持',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '步履不停',
      description: '单日步数超过5000步',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '晨练者',
      description: '在早晨完成运动',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '晚练者',
      description: '在傍晚完成运动',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '计划新手',
      description: '创建并完成第一个计划',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '心有灵犀',
      description: '连续监测心率3天',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '路线初探',
      description: '记录第一条GPS运动路线',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '元气满满',
      description: '连续7天保持活跃状态',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
  ];

  /// 稀有物品池 - 20个物品
  static const List<GachaItem> rareItems = [
    // ========== 称号 (10个) ==========
    GachaItem(
      name: '健身爱好者',
      description: '连续7天完成运动，坚持就是胜利',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '计划大师',
      description: '完成第50个计划任务，执行力超群',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '运动新星',
      description: '累计运动时长达到10小时',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '千步英雄',
      description: '单日步数超过10000步',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '周末战士',
      description: '周末累计运动3小时以上',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '月度坚持',
      description: '连续30天保持活动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '笔记收藏家',
      description: '创建第100条笔记',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '路线达人',
      description: '记录10条不同的运动路线',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '心率守护',
      description: '连续30天监测心率',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '计划达人',
      description: '完成10个不同的计划',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),

    // ========== 徽章 (5个) ==========
    GachaItem(
      name: '白银徽章',
      description: '熟练冒险家的证明，渐入佳境',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '运动先锋',
      description: '连续7天完成运动计划',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '千步达人',
      description: '单日步数突破10000步',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '计划完成者',
      description: '完成5个计划任务',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '路线探索者',
      description: '记录5条不同的运动路线',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),

    // ========== 主题 (5个) ==========
    GachaItem(
      name: '深蓝主题',
      description: '优雅深邃的深蓝色调，沉稳大气',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '森林主题',
      description: '清新的森林绿色调，自然舒适',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '海洋主题',
      description: '宁静的海洋蓝色调，心旷神怡',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '简约白主题',
      description: '纯净简约的白色调，清爽干净',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '暖阳主题',
      description: '温暖的橙黄色调，充满活力',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
  ];

  /// 史诗物品池 - 20个物品
  static const List<GachaItem> epicItems = [
    // ========== 称号 (10个) ==========
    GachaItem(
      name: '运动健将',
      description: '连续30天完成运动，毅力非凡',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '百日坚持',
      description: '连续打卡100天，百折不挠',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '运动专家',
      description: '累计运动时长达到100小时',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '万步传奇',
      description: '单日步数超过20000步',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '马拉松者',
      description: '单次运动时长超过2小时',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '季度冠军',
      description: '连续90天保持活动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '笔记大师',
      description: '创建第500条笔记',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '路线大师',
      description: '记录50条不同的运动路线',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '心率达人',
      description: '连续90天监测心率',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '完美执行',
      description: '连续完成30个计划任务',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),

    // ========== 徽章 (5个) ==========
    GachaItem(
      name: '黄金徽章',
      description: '精英冒险家的证明，实力超群',
      type: GachaItemType.badge,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '月度冠军',
      description: '一个月内累计运动20次',
      type: GachaItemType.badge,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '百日战士',
      description: '连续打卡100天的坚持者',
      type: GachaItemType.badge,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '万步王者',
      description: '单日步数突破20000步',
      type: GachaItemType.badge,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '路线专家',
      description: '记录20条不同的运动路线',
      type: GachaItemType.badge,
      rarity: GachaRarity.epic,
    ),

    // ========== 主题 (5个) ==========
    GachaItem(
      name: '极光主题',
      description: '绚丽多彩的极光渐变，梦幻绚丽',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '日落主题',
      description: '温暖的日落橙红渐变，浪漫迷人',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '紫霞主题',
      description: '神秘的紫霞渐变，优雅高贵',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '暗夜主题',
      description: '深邃的暗夜主题，护眼舒适',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '樱花主题',
      description: '温柔的粉樱色调，浪漫唯美',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
  ];

  /// 传说物品池 - 15个物品
  static const List<GachaItem> legendaryItems = [
    // ========== 称号 (8个) ==========
    GachaItem(
      name: '传奇大师',
      description: '达到50级，真正的传奇人物',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '不朽意志',
      description: '连续打卡365天，一年的坚持与陪伴',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '运动之神',
      description: '累计运动时长达到500小时',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '极限挑战',
      description: '单次运动时长超过4小时',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '万步之神',
      description: '单日步数超过30000步',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '年度王者',
      description: '连续365天保持活动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '千日传说',
      description: '连续打卡1000天，千日不朽的传奇',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '全能大师',
      description: '同时达到运动、笔记、计划三项成就顶级',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),

    // ========== 徽章 (4个) ==========
    GachaItem(
      name: '钻石徽章',
      description: '传说冒险家的证明，璀璨夺目',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '永恒徽章',
      description: '一年的坚持与陪伴，永恒的纪念',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '传奇徽章',
      description: '达到50级的传奇证明',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '神话徽章',
      description: '连续打卡1000天的神话级成就',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),

    // ========== 主题 (3个) ==========
    GachaItem(
      name: '星空主题',
      description: '神秘璀璨的星空主题，浩瀚无垠',
      type: GachaItemType.theme,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '银河主题',
      description: '绚烂的银河渐变，梦幻星辰',
      type: GachaItemType.theme,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '黄金殿堂',
      description: '奢华璀璨的金色调，王者风范',
      type: GachaItemType.theme,
      rarity: GachaRarity.legendary,
    ),
  ];

  /// 根据稀有度获取物品池
  static List<GachaItem> getItemsByRarity(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return commonItems;
      case GachaRarity.rare:
        return rareItems;
      case GachaRarity.epic:
        return epicItems;
      case GachaRarity.legendary:
        return legendaryItems;
    }
  }

  /// 随机获取一个物品
  static GachaItem getRandomItem(GachaRarity rarity) {
    final items = getItemsByRarity(rarity);
    final random = Random().nextInt(items.length);
    return items[random];
  }

  /// 获取所有物品
  static List<GachaItem> getAllItems() {
    return [
      ...commonItems,
      ...rareItems,
      ...epicItems,
      ...legendaryItems,
    ];
  }

  /// 获取物品总数
  static int get totalItemCount => getAllItems().length;

  /// 按类型获取物品
  static List<GachaItem> getItemsByType(GachaItemType type) {
    return getAllItems().where((item) => item.type == type).toList();
  }

  /// 获取物品统计信息
  static Map<String, int> getItemStats() {
    return {
      'total': totalItemCount,
      'common': commonItems.length,
      'rare': rareItems.length,
      'epic': epicItems.length,
      'legendary': legendaryItems.length,
      'title': getItemsByType(GachaItemType.title).length,
      'badge': getItemsByType(GachaItemType.badge).length,
      'theme': getItemsByType(GachaItemType.theme).length,
    };
  }
}

// ==================== 抽卡结果 ====================

/// 抽卡结果
class GachaResult {
  final GachaItem item;
  final bool isNew;
  final GachaRarity rarity;

  const GachaResult({
    required this.item,
    required this.isNew,
    required this.rarity,
  });

  /// 转换为数据库记录
  GachaRecordsCompanion toDatabaseCompanion({
    String drawType = 'free',
    int? pointsSpent,
  }) {
    return GachaRecordsCompanion.insert(
      itemType: item.type.value,
      itemName: item.name,
      itemDescription: Value(item.description),
      rarity: rarity.value,
      drawType: Value(drawType),
      pointsSpent: Value(pointsSpent),
      isNew: Value(isNew),
    );
  }
}

// ==================== 抽卡服务 ====================

/// 抽卡服务 - 单例模式
class GachaService {
  // 使用Dart标准单例模式，确保线程安全
  static final GachaService instance = GachaService._internal();

  AppDatabase? _database;
  UserGachaStatus? _status;

  GachaService._internal();

  /// 设置数据库实例
  void setDatabase(AppDatabase database) {
    _database = database;
  }

  /// 确保数据库已初始化
  AppDatabase get database {
    if (_database == null) {
      throw StateError('GachaService: 数据库未初始化，请先调用 setDatabase()');
    }
    return _database!;
  }

  // ==================== 用户状态管理 ====================

  /// 获取或创建用户抽卡状态
  Future<UserGachaStatus> _getUserStatus() async {
    if (_status != null) return _status!;

    final statuses = await database.getAllUserGachaStatuses();
    if (statuses.isNotEmpty) {
      _status = statuses.first;
    } else {
      // 创建新状态
      final id = await database.into(database.userGachaStatuses).insert(
            UserGachaStatusesCompanion.insert(
              totalDraws: Value(0),
              freeDrawsToday: Value(0),
              pityCount: Value(0),
              collectedItems: Value('[]'),
            ),
          );
      final status = await database.getUserGachaStatusById(id);
      _status = status!;
    }

    // 检查并重置每日免费次数
    await _checkAndResetDailyFreeDraws();

    return _status!;
  }

  /// 检查并重置每日免费次数
  Future<void> _checkAndResetDailyFreeDraws() async {
    if (_status == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_status!.lastFreeDrawDate != null) {
      final lastDate = DateTime(
        _status!.lastFreeDrawDate!.year,
        _status!.lastFreeDrawDate!.month,
        _status!.lastFreeDrawDate!.day,
      );

      if (lastDate.isBefore(today)) {
        // 新的一天，重置免费次数
        await database.updateUserGachaStatus(
          UserGachaStatusesCompanion(
            id: Value(_status!.id),
            freeDrawsToday: Value(0),
            lastFreeDrawDate: Value(null),
          ),
        );
        // 重新获取更新后的状态
        _status = await database.getUserGachaStatusById(_status!.id);
      }
    }
  }

  /// 更新状态到内存和数据库
  Future<void> _updateStatus(UserGachaStatusesCompanion update) async {
    await database.updateUserGachaStatus(update);
    // 重新获取更新后的状态
    final id = update.id.value;
    _status = await database.getUserGachaStatusById(id);
  }

  // ==================== 抽卡操作 ====================

  /// 单次抽卡
  Future<GachaResult> drawSingle({bool useFreeDraw = false}) async {
    final status = await _getUserStatus();

    // 检查免费次数
    if (!useFreeDraw) {
      // 付费抽卡（暂未实现积分系统）
      // TODO: 检查用户积分是否足够
    } else {
      if (status.freeDrawsToday >= GachaConfig.freeDailyDraws) {
        throw StateError('今日免费抽卡次数已用完');
      }
    }

    // 获取当前已收集物品，用于判断isNew
    final collectedItems = jsonDecode(status.collectedItems) as List;

    // 抽卡逻辑（修复：传入已收集物品列表以正确判断isNew）
    final result = _performGacha(status.pityCount, collectedItems);

    // 保存抽卡记录
    await database.into(database.gachaRecords).insert(
          result.toDatabaseCompanion(
            drawType: useFreeDraw ? 'free' : 'paid',
            pointsSpent: useFreeDraw ? null : GachaConfig.singleDrawCost,
          ),
        );

    // 更新保底计数
    int newPityCount = status.pityCount + 1;
    if (result.rarity != GachaRarity.common) {
      newPityCount = 0; // 重置保底
    }

    // 更新免费次数
    int newFreeDraws = status.freeDrawsToday;
    DateTime? newLastFreeDate = status.lastFreeDrawDate;
    if (useFreeDraw) {
      newFreeDraws++;
      newLastFreeDate = DateTime.now();
    }

    // 更新已收集物品
    if (result.isNew) {
      collectedItems.add(result.item.toJson());
    }

    await _updateStatus(
      UserGachaStatusesCompanion(
        id: Value(status.id),
        totalDraws: Value(status.totalDraws + 1),
        freeDrawsToday: Value(newFreeDraws),
        lastFreeDrawDate: newLastFreeDate != null ? Value(newLastFreeDate) : Value.absent(),
        pityCount: Value(newPityCount),
        collectedItems: Value(jsonEncode(collectedItems)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return result;
  }

  /// 十连抽
  Future<List<GachaResult>> drawTen() async {
    final results = <GachaResult>[];
    final status = await _getUserStatus();
    int currentPity = status.pityCount;
    final collectedItems = jsonDecode(status.collectedItems) as List;

    for (int i = 0; i < 10; i++) {
      // 修复：传入已收集物品列表以正确判断isNew
      final result = _performGacha(currentPity, collectedItems);
      results.add(result);

      // 更新已收集物品
      if (result.isNew) {
        collectedItems.add(result.item.toJson());
      }

      if (result.rarity != GachaRarity.common) {
        currentPity = 0;
      } else {
        currentPity++;
      }
    }

    // 保存抽卡记录
    for (final result in results) {
      await database.into(database.gachaRecords).insert(
            result.toDatabaseCompanion(
              drawType: 'paid',
              pointsSpent: GachaConfig.tenDrawCost ~/ 10,
            ),
          );
    }

    await _updateStatus(
      UserGachaStatusesCompanion(
        id: Value(status.id),
        totalDraws: Value(status.totalDraws + 10),
        pityCount: Value(currentPity),
        collectedItems: Value(jsonEncode(collectedItems)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return results;
  }

  /// 执行抽卡逻辑
  ///
  /// [pityCount] 当前保底计数
  /// [collectedItems] 已收集物品列表，用于判断是否为新物品
  GachaResult _performGacha(int pityCount, List collectedItems) {
    // 获取考虑保底后的概率
    final probabilities = GachaConfig.getRarityProbabilities(pityCount);

    // 随机决定稀有度
    final random = Random().nextDouble();
    GachaRarity? rarity;
    double cumulative = 0.0;

    for (final entry in probabilities.entries) {
      cumulative += entry.value;
      if (random <= cumulative) {
        rarity = entry.key;
        break;
      }
    }
    rarity ??= GachaRarity.common;

    // 从对应稀有度池中随机选择物品
    final gachaItem = GachaItemPool.getRandomItem(rarity);

    // 修复：正确判断是否为新物品，通过查询已收集物品列表
    final isNew = !collectedItems.any((item) => item['name'] == gachaItem.name);

    return GachaResult(
      item: gachaItem,
      isNew: isNew,
      rarity: rarity,
    );
  }

  // ==================== 查询操作 ====================

  /// 获取抽卡历史
  Future<List<GachaRecord>> getDrawHistory({int limit = 50}) async {
    return database.getRecentGachaRecords(limit);
  }

  /// 获取剩余免费抽卡次数
  Future<int> getRemainingFreeDraws() async {
    final status = await _getUserStatus();
    return GachaConfig.freeDailyDraws - status.freeDrawsToday;
  }

  /// 获取已收集物品
  Future<List<GachaItem>> getCollectedItems() async {
    final status = await _getUserStatus();
    final itemsJson = jsonDecode(status.collectedItems) as List;
    return itemsJson.map((json) => GachaItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 获取当前保底计数
  Future<int> getPityCount() async {
    final status = await _getUserStatus();
    return status.pityCount;
  }

  /// 距离保底的抽数
  Future<int> getPityCountdown() async {
    final pity = await getPityCount();
    return GachaConfig.rarePityThreshold - pity;
  }

  // ==================== 统计信息 ====================

  /// 获取抽卡统计
  Future<Map<String, dynamic>> getStatistics() async {
    final status = await _getUserStatus();
    final history = await getDrawHistory(limit: 1000);

    final rarityCount = <GachaRarity, int>{};
    for (final record in history) {
      final rarity = GachaRarity.fromString(record.rarity);
      rarityCount[rarity] = (rarityCount[rarity] ?? 0) + 1;
    }

    return {
      'totalDraws': status.totalDraws,
      'pityCount': status.pityCount,
      'collectedCount': jsonDecode(status.collectedItems).length,
      'rarityDistribution': rarityCount.map(
        (key, value) => MapEntry(key.displayName, value),
      ),
    };
  }
}
