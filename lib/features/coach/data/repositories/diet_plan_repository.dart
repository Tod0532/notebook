/// AI饮食计划仓库 - 封装饮食计划相关的数据库操作

import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class DietPlanRepository {
  final AppDatabase _db;

  DietPlanRepository(this._db);

  /// 获取所有饮食计划
  Future<List<DietPlan>> getAllPlans() async {
    return await (_db.select(_db.dietPlans)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取进行中的饮食计划
  Future<List<DietPlan>> getActivePlans() async {
    return await (_db.select(_db.dietPlans)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 根据用户画像获取饮食计划
  Future<List<DietPlan>> getPlansByProfileId(int profileId) async {
    return await (_db.select(_db.dietPlans)
          ..where((tbl) => tbl.userProfileId.equals(profileId))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 根据ID获取饮食计划
  Future<DietPlan?> getPlanById(int id) async {
    return await (_db.select(_db.dietPlans)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建饮食计划
  Future<int> createPlan(DietPlansCompanion plan) async {
    return await _db.into(_db.dietPlans).insert(plan);
  }

  /// 更新饮食计划
  Future<bool> updatePlan(DietPlan plan) async {
    return await _db.update(_db.dietPlans).replace(plan);
  }

  /// 完成饮食计划
  Future<void> completePlan(int planId) async {
    await (_db.update(_db.dietPlans)..where((tbl) => tbl.id.equals(planId))).write(
      DietPlansCompanion(
        status: const drift.Value('completed'),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 暂停/恢复饮食计划
  Future<void> togglePausePlan(int planId, bool pause) async {
    await (_db.update(_db.dietPlans)..where((tbl) => tbl.id.equals(planId))).write(
      DietPlansCompanion(
        status: drift.Value(pause ? 'paused' : 'active'),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除饮食计划
  Future<int> deletePlan(int id) async {
    // 删除计划及其关联的所有数据
    final meals = await getPlanMeals(id);
    for (final meal in meals) {
      await deleteMeal(meal.id);
    }
    return await (_db.delete(_db.dietPlans)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== 餐次相关 ====================

  /// 获取饮食计划的所有餐次
  Future<List<DietPlanMeal>> getPlanMeals(int planId) async {
    return await (_db.select(_db.dietPlanMeals)
          ..where((tbl) => tbl.dietPlanId.equals(planId))
          ..orderBy([
            (tbl) => drift.OrderingTerm.asc(tbl.dayNumber),
            (tbl) => drift.OrderingTerm.asc(tbl.mealType),
          ]))
        .get();
  }

  /// 获取指定日期的餐次
  Future<List<DietPlanMeal>> getMealsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return await (_db.select(_db.dietPlanMeals)
          ..where((tbl) =>
              tbl.scheduledDate.isBiggerThanValue(start.subtract(const Duration(milliseconds: 1))) &
              tbl.scheduledDate.isSmallerThanValue(end))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.mealType)]))
        .get();
  }

  /// 获取指定天数的餐次
  Future<List<DietPlanMeal>> getMealsByDay(int planId, int dayNumber) async {
    return await (_db.select(_db.dietPlanMeals)
          ..where((tbl) => tbl.dietPlanId.equals(planId) & tbl.dayNumber.equals(dayNumber))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.mealType)]))
        .get();
  }

  /// 根据ID获取餐次
  Future<DietPlanMeal?> getMealById(int id) async {
    return await (_db.select(_db.dietPlanMeals)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建餐次
  Future<int> createMeal(DietPlanMealsCompanion meal) async {
    return await _db.into(_db.dietPlanMeals).insert(meal);
  }

  /// 批量创建餐次
  Future<void> createMeals(List<DietPlanMealsCompanion> meals) async {
    await _db.batch((batch) {
      for (final meal in meals) {
        batch.insert(_db.dietPlanMeals, meal);
      }
    });
  }

  /// 更新餐次
  Future<bool> updateMeal(DietPlanMeal meal) async {
    return await _db.update(_db.dietPlanMeals).replace(meal);
  }

  /// 完成餐次
  Future<void> completeMeal(int mealId) async {
    await (_db.update(_db.dietPlanMeals)..where((tbl) => tbl.id.equals(mealId))).write(
      DietPlanMealsCompanion(
        isCompleted: const drift.Value(true),
        completedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// 删除餐次
  Future<int> deleteMeal(int id) async {
    // 删除餐次及其关联的所有食材
    final items = await getMealItems(id);
    for (final item in items) {
      await deleteItem(item.id);
    }
    return await (_db.delete(_db.dietPlanMeals)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== 食材相关 ====================

  /// 获取餐次的所有食材
  Future<List<MealItem>> getMealItems(int mealId) async {
    return await (_db.select(_db.mealItems)
          ..where((tbl) => tbl.dietPlanMealId.equals(mealId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.itemOrder)]))
        .get();
  }

  /// 根据ID获取食材
  Future<MealItem?> getItemById(int id) async {
    return await (_db.select(_db.mealItems)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建食材
  Future<int> createItem(MealItemsCompanion item) async {
    return await _db.into(_db.mealItems).insert(item);
  }

  /// 批量创建食材
  Future<void> createItems(List<MealItemsCompanion> items) async {
    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(_db.mealItems, item);
      }
    });
  }

  /// 更新食材
  Future<bool> updateItem(MealItem item) async {
    return await _db.update(_db.mealItems).replace(item);
  }

  /// 删除食材
  Future<int> deleteItem(int id) async {
    return await (_db.delete(_db.mealItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 获取完整的饮食计划（含餐次和食材）
  Future<DietPlanWithDetails?> getPlanWithDetails(int planId) async {
    final plan = await getPlanById(planId);
    if (plan == null) return null;

    final meals = await getPlanMeals(planId);
    final mealsWithItems = <DietPlanMealWithItems>[];

    for (final meal in meals) {
      final items = await getMealItems(meal.id);
      mealsWithItems.add(DietPlanMealWithItems(
        meal: meal,
        items: items,
      ));
    }

    return DietPlanWithDetails(
      plan: plan,
      meals: mealsWithItems,
    );
  }

  /// 获取指定天数的饮食（含食材）
  Future<List<DietPlanMealWithItems>> getDayWithItems(int planId, int dayNumber) async {
    final meals = await getMealsByDay(planId, dayNumber);
    final mealsWithItems = <DietPlanMealWithItems>[];

    for (final meal in meals) {
      final items = await getMealItems(meal.id);
      mealsWithItems.add(DietPlanMealWithItems(
        meal: meal,
        items: items,
      ));
    }

    return mealsWithItems;
  }

  /// 生成食材采购清单（按周）
  Future<List<ShoppingItem>> generateShoppingList(int planId, int weekNumber) async {
    final plan = await getPlanById(planId);
    if (plan == null) return [];

    final startDay = (weekNumber - 1) * 7 + 1;
    final endDay = weekNumber * 7;

    final meals = await getPlanMeals(planId);
    final weekMeals = meals.where((m) => m.dayNumber >= startDay && m.dayNumber <= endDay).toList();

    final shoppingList = <String, ShoppingItem>{};

    for (final meal in weekMeals) {
      final items = await getMealItems(meal.id);
      for (final item in items) {
        final key = item.foodName;
        if (shoppingList.containsKey(key)) {
          final existing = shoppingList[key]!;
          shoppingList[key] = ShoppingItem(
            foodName: item.foodName,
            amount: _combineAmounts(existing.amount, item.amount),
            weightGrams: (existing.weightGrams ?? 0) + (item.weightGrams ?? 0),
          );
        } else {
          shoppingList[key] = ShoppingItem(
            foodName: item.foodName,
            amount: item.amount,
            weightGrams: item.weightGrams,
          );
        }
      }
    }

    return shoppingList.values.toList()
      ..sort((a, b) => a.foodName.compareTo(b.foodName));
  }

  /// 合并用量描述
  String _combineAmounts(String? amount1, String? amount2) {
    if (amount1 == null || amount1.isEmpty) return amount2 ?? '';
    if (amount2 == null || amount2.isEmpty) return amount1;
    return '$amount1 + $amount2';
  }
}

// ==================== 数据模型 ====================

/// 完整的饮食计划（含餐次和食材）
class DietPlanWithDetails {
  final DietPlan plan;
  final List<DietPlanMealWithItems> meals;

  DietPlanWithDetails({
    required this.plan,
    required this.meals,
  });

  /// 计算完成进度
  double get progress {
    if (plan.totalDays == 0) return 0;
    return plan.currentDay / plan.totalDays;
  }

  /// 获取今日饮食
  List<DietPlanMealWithItems> getTodayMeals() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    return meals.where((mealWithItems) {
      final scheduled = mealWithItems.meal.scheduledDate;
      return scheduled != null && scheduled.isAfter(start) && scheduled.isBefore(end);
    }).toList();
  }

  /// 按天数分组餐次
  Map<int, List<DietPlanMealWithItems>> get mealsByDay {
    final grouped = <int, List<DietPlanMealWithItems>>{};
    for (final mealWithItems in meals) {
      final day = mealWithItems.meal.dayNumber;
      grouped.putIfAbsent(day, () => []).add(mealWithItems);
    }
    return grouped;
  }
}

/// 餐次及其食材
class DietPlanMealWithItems {
  final DietPlanMeal meal;
  final List<MealItem> items;

  DietPlanMealWithItems({
    required this.meal,
    required this.items,
  });

  /// 计算餐次总热量
  double get totalCalories {
    return items.fold(0.0, (sum, item) => sum + (item.calories ?? 0));
  }

  /// 计算餐次总蛋白质
  double get totalProtein {
    return items.fold(0.0, (sum, item) => sum + (item.protein ?? 0));
  }

  /// 计算餐次总碳水
  double get totalCarbs {
    return items.fold(0.0, (sum, item) => sum + (item.carbs ?? 0));
  }

  /// 计算餐次总脂肪
  double get totalFat {
    return items.fold(0.0, (sum, item) => sum + (item.fat ?? 0));
  }
}

/// 采购清单项
class ShoppingItem {
  final String foodName;
  final String? amount;
  final double? weightGrams;

  ShoppingItem({
    required this.foodName,
    this.amount,
    this.weightGrams,
  });
}
