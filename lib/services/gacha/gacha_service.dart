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
  static Map<GachaRarity, double> getRarityProbabilities(int pityCount) {
    // 保底机制：每10抽必出稀有以上
    if (pityCount >= rarePityThreshold) {
      final guaranteedRare = pityCount >= legendaryPityThreshold
          ? GachaRarity.legendary
          : pityCount >= epicPityThreshold
              ? GachaRarity.epic
              : GachaRarity.rare;

      return {
        GachaRarity.common: 0.0,
        GachaRarity.rare: guaranteedRare == GachaRarity.rare ? 1.0 : 0.0,
        GachaRarity.epic: guaranteedRare == GachaRarity.epic ? 1.0 : 0.2,
        GachaRarity.legendary: guaranteedRare == GachaRarity.legendary ? 1.0 : 0.05,
      };
    }

    // 正常概率
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
class GachaItemPool {
  /// 普通物品池
  static const List<GachaItem> commonItems = [
    // 称号
    GachaItem(
      name: '早起鸟',
      description: '连续3天在早上8点前完成活动',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '夜猫子',
      description: '在晚上10点后还有活动记录',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '记录者',
      description: '创建第10条笔记',
      type: GachaItemType.title,
      rarity: GachaRarity.common,
    ),

    // 徽章
    GachaItem(
      name: '青铜徽章',
      description: '新手冒险家的证明',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '运动初学者',
      description: '完成第一次运动记录',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
    GachaItem(
      name: '笔记达人',
      description: '连续7天记录笔记',
      type: GachaItemType.badge,
      rarity: GachaRarity.common,
    ),
  ];

  /// 稀有物品池
  static const List<GachaItem> rareItems = [
    GachaItem(
      name: '健身爱好者',
      description: '连续7天完成运动',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '计划大师',
      description: '完成第50个计划任务',
      type: GachaItemType.title,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '白银徽章',
      description: '熟练冒险家的证明',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '周末战士',
      description: '周末累计运动3小时',
      type: GachaItemType.badge,
      rarity: GachaRarity.rare,
    ),
    GachaItem(
      name: '深蓝主题',
      description: '优雅的深蓝色主题',
      type: GachaItemType.theme,
      rarity: GachaRarity.rare,
    ),
  ];

  /// 史诗物品池
  static const List<GachaItem> epicItems = [
    GachaItem(
      name: '运动健将',
      description: '连续30天完成运动',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '百日坚持',
      description: '连续打卡100天',
      type: GachaItemType.title,
      rarity: GachaRarity.epic,
    ),
    GachaItem(
      name: '黄金徽章',
      description: '精英冒险家的证明',
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
      name: '极光主题',
      description: '绚丽的极光渐变主题',
      type: GachaItemType.theme,
      rarity: GachaRarity.epic,
    ),
  ];

  /// 传说物品池
  static const List<GachaItem> legendaryItems = [
    GachaItem(
      name: '传奇大师',
      description: '达到50级',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '不朽意志',
      description: '连续打卡365天',
      type: GachaItemType.title,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '钻石徽章',
      description: '传说冒险家的证明',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '永恒徽章',
      description: '一年的坚持与陪伴',
      type: GachaItemType.badge,
      rarity: GachaRarity.legendary,
    ),
    GachaItem(
      name: '星空主题',
      description: '神秘的星空主题',
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
  static GachaService? _instance;
  static final _lock = Object();

  AppDatabase? _database;
  UserGachaStatus? _status;

  /// 获取单例实例
  static GachaService get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= GachaService._internal();
      });
    }
    return _instance!;
  }

  /// 同步锁操作
  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

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

    // 抽卡逻辑
    final result = _performGacha(status.pityCount);

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
    final collectedItems = jsonDecode(status.collectedItems) as List;
    final isNew = !collectedItems.any((item) => item['name'] == result.item.name);
    if (isNew) {
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
    int currentPity = (await _getUserStatus()).pityCount;

    for (int i = 0; i < 10; i++) {
      final result = _performGacha(currentPity);
      results.add(result);

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

    // 更新状态
    final status = await _getUserStatus();
    final collectedItems = jsonDecode(status.collectedItems) as List;

    for (final result in results) {
      final isNew = !collectedItems.any((item) => item['name'] == result.item.name);
      if (isNew) {
        collectedItems.add(result.item.toJson());
      }
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
  GachaResult _performGacha(int pityCount) {
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
    final item = GachaItemPool.getRandomItem(rarity);

    // 检查是否新获得（简化版，实际应该查询已收集物品）
    final isNew = Random().nextBool();

    return GachaResult(
      item: item,
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
