/// 积分商店服务
/// 管理商店物品、购买逻辑

import 'package:drift/drift.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';
import 'gamification_service.dart';

/// 积分商店服务
class ShopService {
  AppDatabase? _db;
  late GamificationService _gamificationService;

  /// 设置数据库实例
  void setDatabase(AppDatabase db, GamificationService gamificationService) {
    _db = db;
    _gamificationService = gamificationService;
  }

  /// 确保数据库已初始化
  AppDatabase get db {
    if (_db == null) {
      throw StateError('ShopService: 数据库未初始化，请先调用 setDatabase()');
    }
    return _db!;
  }

  // ==================== 商店物品管理 ====================

  /// 初始化默认商店物品
  Future<void> initializeDefaultItems() async {
    final existing = await db.select(db.shopItems).get();

    // 如果已经有物品，不重复初始化
    if (existing.isNotEmpty) return;

    // 默认商店物品列表
    final defaultItems = [
      // 主题类
      ShopItemModel(
        id: 1,
        name: '深海主题',
        description: '深邃的蓝色渐变主题',
        cost: 100,
        type: ShopItemType.theme,
        value: 'ocean',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 2,
        name: '森林主题',
        description: '清新的绿色渐变主题',
        cost: 100,
        type: ShopItemType.theme,
        value: 'forest',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 3,
        name: '日落主题',
        description: '温暖的橙色渐变主题',
        cost: 150,
        type: ShopItemType.theme,
        value: 'sunset',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 4,
        name: '紫罗兰主题',
        description: '优雅的紫色渐变主题',
        cost: 200,
        type: ShopItemType.theme,
        value: 'violet',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 5,
        name: '暗夜主题',
        description: '酷炫的暗黑渐变主题',
        cost: 250,
        type: ShopItemType.theme,
        value: 'darknight',
        isAvailable: true,
      ),

      // 称号类
      ShopItemModel(
        id: 101,
        name: '运动健将',
        description: '显示在你的个人资料上',
        cost: 500,
        type: ShopItemType.title,
        value: '运动健将',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 102,
        name: '健身达人',
        description: '彰显你的健身成就',
        cost: 500,
        type: ShopItemType.title,
        value: '健身达人',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 103,
        name: '自律之王',
        description: '100天连续打卡者专属',
        cost: 1000,
        type: ShopItemType.title,
        value: '自律之王',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 104,
        name: '运动传奇',
        description: '只有真正的传奇才能拥有',
        cost: 2000,
        type: ShopItemType.title,
        value: '运动传奇',
        isAvailable: true,
      ),

      // 图标类
      ShopItemModel(
        id: 201,
        name: '火焰图标',
        description: '燃烧你的运动激情',
        cost: 300,
        type: ShopItemType.icon,
        value: 'local_fire_department',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 202,
        name: '闪电图标',
        description: '速度与力量的象征',
        cost: 300,
        type: ShopItemType.icon,
        value: 'bolt',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 203,
        name: '钻石图标',
        description: '闪耀你的成就',
        cost: 500,
        type: ShopItemType.icon,
        value: 'diamond',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 204,
        name: '皇冠图标',
        description: '你是真正的王者',
        cost: 1000,
        type: ShopItemType.icon,
        value: 'emoji_events',
        isAvailable: true,
      ),

      // 徽章类
      ShopItemModel(
        id: 301,
        name: '早起徽章',
        description: '晨间运动者的荣誉',
        cost: 200,
        type: ShopItemType.badge,
        value: 'wb_sunny',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 302,
        name: '夜跑徽章',
        description: '夜跑爱好者的标志',
        cost: 200,
        type: ShopItemType.badge,
        value: 'nights_stay',
        isAvailable: true,
      ),
      ShopItemModel(
        id: 303,
        name: '全勤徽章',
        description: '连续打卡30天的证明',
        cost: 500,
        type: ShopItemType.badge,
        value: 'verified',
        isAvailable: true,
      ),
    ];

    // 插入数据库
    for (final item in defaultItems) {
      await db.into(db.shopItems).insert(ShopItemsCompanion.insert(
        name: item.name,
        description: Value(item.description),
        cost: item.cost,
        type: item.type.value,
        value: item.value,
        isAvailable: const Value(true),
      ));
    }
  }

  /// 获取所有商店物品
  Future<List<ShopItemModel>> getAllShopItems() async {
    await initializeDefaultItems();

    final items = await db.select(db.shopItems).get();
    final userGameData = await _gamificationService.getUserGameData();

    // TODO: 查询用户已购买的物品（需要额外的购买记录表）
    // 目前先返回所有可用物品
    return items
        .where((item) => item.isAvailable)
        .map((item) => ShopItemModel.fromDb(item, isPurchased: false))
        .toList();
  }

  /// 按类型获取商店物品
  Future<List<ShopItemModel>> getShopItemsByType(ShopItemType type) async {
    final all = await getAllShopItems();
    return all.where((item) => item.type == type).toList();
  }

  /// 获取物品详情
  Future<ShopItemModel?> getShopItem(int id) async {
    final item = await (db.select(db.shopItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return null;

    // TODO: 查询是否已购买
    return ShopItemModel.fromDb(item, isPurchased: false);
  }

  /// 购买物品
  /// 返回 (是否成功, 错误消息)
  Future<(bool, String?)> purchaseItem(int itemId) async {
    // 获取物品信息
    final item = await (db.select(db.shopItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) {
      return (false, '物品不存在');
    }

    if (!item.isAvailable) {
      return (false, '该物品暂不可用');
    }

    // 检查用户积分
    final userGameData = await _gamificationService.getUserGameData();
    if (userGameData.points < item.cost) {
      return (false, '积分不足，还需要 ${item.cost - userGameData.points} 积分');
    }

    // 扣除积分
    final success = await _gamificationService.spendPoints(item.cost);
    if (!success) {
      return (false, '积分扣除失败');
    }

    // TODO: 记录购买记录（需要额外的购买记录表）
    // 目前购买后只扣除积分

    return (true, null);
  }

  /// 按价格筛选物品
  Future<List<ShopItemModel>> getShopItemsByPriceRange(int minPrice, int maxPrice) async {
    final all = await getAllShopItems();
    return all.where((item) => item.cost >= minPrice && item.cost <= maxPrice).toList();
  }

  /// 获取用户可以买得起的物品
  Future<List<ShopItemModel>> getAffordableItems() async {
    final userGameData = await _gamificationService.getUserGameData();
    final all = await getAllShopItems();
    return all.where((item) => item.cost <= userGameData.points).toList();
  }
}
