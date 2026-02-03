/// AI饮食计划展示页面
/// 显示饮食计划详情、餐次列表和食材详情

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/features/coach/data/repositories/diet_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_feedback_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'dart:convert';

/// 饮食计划展示页面
class DietPlanDisplayPage extends ConsumerStatefulWidget {
  final int planId;

  const DietPlanDisplayPage({
    super.key,
    required this.planId,
  });

  @override
  ConsumerState<DietPlanDisplayPage> createState() => _DietPlanDisplayPageState();
}

class _DietPlanDisplayPageState extends ConsumerState<DietPlanDisplayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DietPlanWithDetails? _planDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载计划数据
  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(dietPlanRepositoryProvider);
      final details = await repo.getPlanWithDetails(widget.planId);
      if (details == null) {
        setState(() {
          _error = '计划不存在';
          _isLoading = false;
        });
      } else {
        setState(() {
          _planDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 完成餐次
  Future<void> _completeMeal(int mealId) async {
    try {
      final repo = ref.read(dietPlanRepositoryProvider);
      await repo.completeMeal(mealId);
      await _loadPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('餐次已记录！'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 替换食材
  Future<void> _replaceFoodItem(
    MealItem item,
    String mealType,
  ) async {
    // 显示替换原因选择对话框
    final reason = await _showFoodReplaceReasonDialog();
    if (reason == null) return;

    // 保存原始名称
    final originalName = item.foodName;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final aiService = DeepSeekService.instance;
      await aiService.init();

      // 转换原因为英文值
      final reasonValue = _convertFoodReasonToValue(reason);

      // 调用AI生成替代食材
      final replacement = await aiService.replaceFoodItem(
        currentFoodName: item.foodName,
        mealType: mealType,
        reason: reasonValue,
        targetCalories: item.calories,
        targetProtein: item.protein,
      );

      final replacementName = replacement['foodName'] as String;

      // 更新数据库
      final repo = ref.read(dietPlanRepositoryProvider);
      await repo.updateItem(
        MealItem(
          id: item.id,
          dietPlanMealId: item.dietPlanMealId,
          foodName: replacementName,
          amount: replacement['amount'] as String?,
          weightGrams: replacement['weightGrams'] as double?,
          calories: replacement['calories'] as double?,
          protein: replacement['protein'] as double?,
          carbs: replacement['carbs'] as double?,
          fat: replacement['fat'] as double?,
          cookingMethod: replacement['cookingMethod'] as String?,
          itemOrder: item.itemOrder,
        ),
      );

      // 记录用户反馈数据
      try {
        final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
        await feedbackRepo.createFeedback(
          feedbackType: FeedbackType.food,
          itemId: item.id,
          itemType: mealType,
          reason: reasonValue,
          originalName: originalName,
          replacementName: replacementName,
          userProfileId: _planDetails!.plan.userProfileId,
        );
      } catch (e) {
        // 反馈记录失败不影响替换功能
        debugPrint('记录反馈失败: $e');
      }

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已替换为：$replacementName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('替换失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 将中文原因转换为英文值（食材）
  String _convertFoodReasonToValue(String chineseReason) {
    switch (chineseReason) {
      case '买不到':
        return 'unavailable';
      case '太难做':
        return 'too_hard';
      case '不喜欢':
        return 'dislike';
      case '过敏':
        return 'allergy';
      default:
        return 'unavailable';
    }
  }

  /// 显示食材替换原因选择对话框
  Future<String?> _showFoodReplaceReasonDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择替换原因'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FoodReplaceReasonTile(
              icon: Icons.shopping_basket,
              title: '买不到这个食材',
              subtitle: '推荐易获得的替代品',
              value: '买不到',
              onTap: () => Navigator.pop(context, '买不到'),
            ),
            const Divider(),
            _FoodReplaceReasonTile(
              icon: Icons.restaurant,
              title: '太难做了',
              subtitle: '推荐简单的替代品',
              value: '太难做',
              onTap: () => Navigator.pop(context, '太难做'),
            ),
            const Divider(),
            _FoodReplaceReasonTile(
              icon: Icons.block,
              title: '不喜欢吃',
              subtitle: '推荐口味相似的替代品',
              value: '不喜欢',
              onTap: () => Navigator.pop(context, '不喜欢'),
            ),
            const Divider(),
            _FoodReplaceReasonTile(
              icon: Icons.family_restroom,
              title: '过敏/不耐受',
              subtitle: '推荐安全的替代品',
              value: '过敏',
              onTap: () => Navigator.pop(context, '过敏'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// AI重新生成饮食计划
  Future<void> _regeneratePlan() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI重新生成饮食计划'),
        content: const Text('将根据您的反馈数据重新生成整个饮食计划，当前计划将被替换。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI正在根据您的反馈重新生成计划...'),
          ],
        ),
      ),
    );

    try {
      // 获取用户画像和反馈数据
      final userProfileId = _planDetails!.plan.userProfileId;
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final feedbackRepo = ref.read(userFeedbackRepositoryProvider);
      final dietRepo = ref.read(dietPlanRepositoryProvider);

      final userProfile = userProfileId != null
          ? await profileRepo.getProfileById(userProfileId)
          : await profileRepo.getLatestProfile();

      if (userProfile == null) {
        throw Exception('未找到用户画像，请先创建用户画像');
      }

      // 获取用户反馈偏好
      final preferenceSummary = userProfileId != null
          ? await feedbackRepo.getUserPreferenceSummary(userProfileId)
          : <String, dynamic>{};

      // 解析用户画像数据
      final unavailableFoods = preferenceSummary['unavailable_foods'] as List<String>? ?? [];
      final dislikedFoods = preferenceSummary['disliked_foods'] as List<String>? ?? [];

      // 调用AI重新生成计划
      final aiService = DeepSeekService.instance;
      await aiService.init();

      final newPlanData = await aiService.generateCoachDietPlan(
        goalType: userProfile.goalType,
        durationDays: _planDetails!.plan.totalDays,
        gender: userProfile.gender,
        age: userProfile.age,
        height: userProfile.height,
        weight: userProfile.weight,
        fitnessLevel: userProfile.fitnessLevel,
        dietType: userProfile.dietType != 'none' ? userProfile.dietType : null,
        dietaryRestrictions: [
          ...UserProfileRepository.parseJsonList(userProfile.dietaryRestrictions),
          ...unavailableFoods,
        ],
        allergies: UserProfileRepository.parseJsonList(userProfile.allergies),
        tastePreference: userProfile.tastePreference,
      );

      // 删除旧计划数据（餐次和食材）
      final oldMeals = await dietRepo.getPlanMeals(widget.planId);
      for (final meal in oldMeals) {
        await dietRepo.deleteMeal(meal.id);
      }

      // 根据AI返回的数据创建新的餐次
      final days = newPlanData['days'] as List<dynamic>? ?? [];
      final baseDate = _planDetails!.plan.startDate ?? DateTime.now();

      for (final dayData in days) {
        final dayNumber = dayData['day'] as int? ?? 1;
        final mealsList = dayData['meals'] as List<dynamic>? ?? [];

        for (final mealData in mealsList) {
          final mealType = mealData['mealType'] as String? ?? 'breakfast';
          final mealName = mealData['mealName'] as String? ?? '';
          final eatingTime = mealData['eatingTime'] as String? ?? '07:30';
          final calories = mealData['calories'] as num? ?? 0;
          final protein = mealData['protein'] as num? ?? 0;
          final carbs = mealData['carbs'] as num? ?? 0;
          final fat = mealData['fat'] as num? ?? 0;
          final itemsList = mealData['items'] as List<dynamic>? ?? [];

          // 计算计划日期
          final mealScheduledDate = baseDate.add(Duration(days: dayNumber - 1));

          // 创建餐次
          final mealId = await dietRepo.createMeal(
            DietPlanMealsCompanion(
              dietPlanId: drift.Value(widget.planId),
              dayNumber: drift.Value(dayNumber),
              mealType: drift.Value(mealType),
              mealName: drift.Value(mealName),
              eatingTime: drift.Value(eatingTime),
              calories: drift.Value(calories.toDouble()),
              protein: drift.Value(protein.toDouble()),
              carbs: drift.Value(carbs.toDouble()),
              fat: drift.Value(fat.toDouble()),
              scheduledDate: drift.Value(mealScheduledDate),
            ),
          );

          // 创建食材
          for (final itemData in itemsList) {
            final order = itemData['order'] as int? ?? 1;
            final foodName = itemData['foodName'] as String? ?? '';
            final amount = itemData['amount'] as String? ?? '';
            final weightGrams = itemData['weightGrams'] as num? ?? 0;
            final itemCalories = itemData['calories'] as num? ?? 0;
            final itemProtein = itemData['protein'] as num? ?? 0;
            final itemCarbs = itemData['carbs'] as num? ?? 0;
            final itemFat = itemData['fat'] as num? ?? 0;
            final cookingMethod = itemData['cookingMethod'] as String?;

            await dietRepo.createItem(
              MealItemsCompanion(
                dietPlanMealId: drift.Value(mealId),
                itemOrder: drift.Value(order),
                foodName: drift.Value(foodName),
                amount: drift.Value(amount),
                weightGrams: drift.Value(weightGrams.toDouble()),
                calories: drift.Value(itemCalories.toDouble()),
                protein: drift.Value(itemProtein.toDouble()),
                carbs: drift.Value(itemCarbs.toDouble()),
                fat: drift.Value(itemFat.toDouble()),
                cookingMethod: drift.Value(cookingMethod),
              ),
            );
          }
        }
      }

      // 重新加载数据
      await _loadPlan();

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('饮食计划已重新生成！'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重新生成失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_planDetails == null) {
      return const Center(child: Text('计划不存在'));
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(),
          _buildTabs(),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMealsTab(),
          _buildShoppingTab(),
        ],
      ),
    );
  }

  /// AppBar
  Widget _buildAppBar() {
    final plan = _planDetails!.plan;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.secondary,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if (value == 'regenerate') {
              await _regeneratePlan();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'regenerate',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Text('AI重新生成'),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          plan.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(plan.status).withOpacity(0.2),
                      borderRadius: AppRadius.smRadius,
                      border: Border.all(color: _getStatusColor(plan.status), width: 1),
                    ),
                    child: Text(
                      _getStatusText(plan.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.description ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tab栏
  Widget _buildTabs() {
    return SliverPersistentHeader(
      delegate: _TabHeaderDelegate(
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: '餐次', icon: Icon(Icons.restaurant_outlined)),
            Tab(text: '采购', icon: Icon(Icons.shopping_cart_outlined)),
          ],
          indicatorColor: AppColors.secondary,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      pinned: true,
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab() {
    final plan = _planDetails!.plan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度卡片
          _buildProgressCard(),
          const SizedBox(height: 16),

          // 营养目标卡片
          _buildNutritionGoalsCard(plan),
          const SizedBox(height: 16),

          // 今日饮食
          _buildTodayMealsCard(),
        ],
      ),
    );
  }

  /// 进度卡片
  Widget _buildProgressCard() {
    final plan = _planDetails!.plan;
    final progress = _planDetails!.progress;
    final currentDay = plan.currentDay;
    final totalDays = plan.totalDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '计划进度',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$currentDay/$totalDays 天',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.smRadius,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% 完成',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 营养目标卡片
  Widget _buildNutritionGoalsCard(DietPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日营养目标',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNutrientItem(
                  label: '热量',
                  value: plan.dailyCalories?.toStringAsFixed(0) ?? '-',
                  unit: 'kcal',
                  color: AppColors.primary,
                  icon: Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNutrientItem(
                  label: '蛋白质',
                  value: plan.dailyProtein?.toStringAsFixed(0) ?? '-',
                  unit: 'g',
                  color: AppColors.secondary,
                  icon: Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutrientItem(
                  label: '碳水',
                  value: plan.dailyCarbs?.toStringAsFixed(0) ?? '-',
                  unit: 'g',
                  color: AppColors.warning,
                  icon: Icons.grain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNutrientItem(
                  label: '脂肪',
                  value: plan.dailyFat?.toStringAsFixed(0) ?? '-',
                  unit: 'g',
                  color: AppColors.success,
                  icon: Icons.water_drop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// 今日饮食卡片
  Widget _buildTodayMealsCard() {
    final todayMeals = _planDetails!.getTodayMeals();

    if (todayMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.info),
            SizedBox(width: 12),
            Text('今天没有安排饮食计划'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日饮食',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...todayMeals.map((mealWithItems) {
            return _buildTodayMealItem(mealWithItems);
          }),
        ],
      ),
    );
  }

  Widget _buildTodayMealItem(DietPlanMealWithItems mealWithItems) {
    final meal = mealWithItems.meal;
    final isCompleted = meal.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.successLight.withOpacity(0.5)
            : AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getMealTypeColor(meal.mealType),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(
              _getMealTypeIcon(meal.mealType),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMealTypeText(meal.mealType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meal.mealName != null)
                  Text(
                    meal.mealName!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '${mealWithItems.totalCalories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted)
            IconButton(
              onPressed: () => _completeMeal(meal.id),
              icon: const Icon(Icons.check_circle_outline),
              color: AppColors.success,
            )
          else
            Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  /// 餐次标签页
  Widget _buildMealsTab() {
    final mealsByDay = _planDetails!.mealsByDay;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mealsByDay.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final entry = mealsByDay.entries.elementAt(index);
        final dayNumber = entry.key;
        final meals = entry.value;
        return _buildDayCard(dayNumber, meals);
      },
    );
  }

  /// 日期餐次卡片
  Widget _buildDayCard(int dayNumber, List<DietPlanMealWithItems> meals) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // 日期头部
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '第 $dayNumber 天',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildDayNutritionSummary(meals),
              ],
            ),
          ),
          // 餐次列表
          ...meals.map((mealWithItems) {
            return _buildMealItem(mealWithItems);
          }),
        ],
      ),
    );
  }

  Widget _buildDayNutritionSummary(List<DietPlanMealWithItems> meals) {
    final totalCalories = meals.fold<double>(
        0, (sum, m) => sum + m.totalCalories);
    final totalProtein = meals.fold<double>(
        0, (sum, m) => sum + m.totalProtein);

    return Row(
      children: [
        _buildNutrientChip(
            Icons.local_fire_department, totalCalories.toStringAsFixed(0), 'kcal'),
        const SizedBox(width: 8),
        _buildNutrientChip(
            Icons.fitness_center, totalProtein.toStringAsFixed(0), 'g'),
      ],
    );
  }

  Widget _buildNutrientChip(IconData icon, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            '$value$unit',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 餐次项
  Widget _buildMealItem(DietPlanMealWithItems mealWithItems) {
    final meal = mealWithItems.meal;

    return InkWell(
      onTap: () => _showMealDetail(mealWithItems),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.dividerColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getMealTypeColor(meal.mealType),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(
                _getMealTypeIcon(meal.mealType),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMealTypeText(meal.mealType),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meal.mealName != null)
                    Text(
                      meal.mealName!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildNutritionChipSmall(
                        'kcal', mealWithItems.totalCalories.toStringAsFixed(0)),
                      const SizedBox(width: 8),
                      _buildNutritionChipSmall(
                        '蛋白质', mealWithItems.totalProtein.toStringAsFixed(0)),
                      if (meal.eatingTime != null) ...[
                        const Spacer(),
                        Icon(Icons.access_time, size: 14,
                            color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          meal.eatingTime!,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChipSmall(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 显示餐次详情
  void _showMealDetail(DietPlanMealWithItems mealWithItems) {
    final meal = mealWithItems.meal;
    final items = mealWithItems.items;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getMealTypeColor(meal.mealType),
                        borderRadius: AppRadius.mdRadius,
                      ),
                      child: Icon(
                        _getMealTypeIcon(meal.mealType),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getMealTypeText(meal.mealType),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (meal.mealName != null)
                            Text(
                              meal.mealName!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 营养汇总
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildNutrientChipBig(
                        Icons.local_fire_department, mealWithItems.totalCalories.toStringAsFixed(0), 'kcal', AppColors.primary),
                    const SizedBox(width: 8),
                    _buildNutrientChipBig(
                        Icons.fitness_center, mealWithItems.totalProtein.toStringAsFixed(0), 'g', AppColors.secondary),
                    const SizedBox(width: 8),
                    _buildNutrientChipBig(
                        Icons.grain, mealWithItems.totalCarbs.toStringAsFixed(0), 'g', AppColors.warning),
                    const SizedBox(width: 8),
                    _buildNutrientChipBig(
                        Icons.water_drop, mealWithItems.totalFat.toStringAsFixed(0), 'g', AppColors.success),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildFoodItemCard(item, index + 1, meal.mealType);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientChipBig(IconData icon, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: AppRadius.smRadius,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 食材卡片
  Widget _buildFoodItemCard(MealItem item, int order, String mealType) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: AppRadius.smRadius,
            ),
            child: Center(
              child: Text(
                '$order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.cookingMethod != null)
                  Text(
                    item.cookingMethod!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // 替换按钮
          InkWell(
            onTap: () async {
              await HapticHelper.lightTap();
              _replaceFoodItem(item, mealType);
            },
            borderRadius: AppRadius.smRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync_alt,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '替换',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (item.amount != null)
            Text(
              item.amount!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          if (item.weightGrams != null)
            Text(
              ' ${item.weightGrams!.toStringAsFixed(0)}g',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          if (item.calories != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Text(
                '${item.calories!.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 采购清单标签页
  Widget _buildShoppingTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              tabs: const [
                Tab(text: '第1周'),
                Tab(text: '第2周'),
                Tab(text: '第3周'),
                Tab(text: '第4周'),
              ],
              indicatorColor: AppColors.secondary,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.textSecondary,
              isScrollable: true,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [1, 2, 3, 4].map((week) => _buildShoppingList(week)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 采购清单
  Widget _buildShoppingList(int weekNumber) {
    return FutureBuilder<List<ShoppingItem>>(
      future: ref.read(dietPlanRepositoryProvider).generateShoppingList(
        widget.planId,
        weekNumber,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('加载失败: ${snapshot.error}'),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(
            child: Text('该周没有采购清单'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildShoppingItem(item, index + 1);
          },
        );
      },
    );
  }

  Widget _buildShoppingItem(ShoppingItem item, int order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: AppRadius.smRadius,
            ),
            child: Center(
              child: Text(
                '$order',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.foodName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (item.amount != null)
            Text(
              item.amount!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          if (item.weightGrams != null)
            Text(
              ' ${item.weightGrams!.toStringAsFixed(0)}g',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error ?? '未知错误'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPlan,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 辅助方法 ====================

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'paused':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'paused':
        return '已暂停';
      default:
        return status;
    }
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return AppColors.warning;
      case 'lunch':
        return AppColors.primary;
      case 'dinner':
        return AppColors.secondary;
      case 'snack':
        return AppColors.success;
      default:
        return AppColors.textHint;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.restaurant;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.fastfood;
    }
  }

  String _getMealTypeText(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐';
      default:
        return mealType;
    }
  }
}

/// 食材替换原因选择项
class _FoodReplaceReasonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _FoodReplaceReasonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Icon(icon, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab栏头部代理
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabHeaderDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}
