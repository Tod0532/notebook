/// AI教练服务 - 协调AI生成和数据库存储

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/workout_plan_repository.dart';
import 'package:thick_notepad/features/coach/data/repositories/diet_plan_repository.dart';
import 'package:drift/drift.dart' as drift;

class CoachService {
  final DeepSeekService _aiService = DeepSeekService.instance;
  late UserProfileRepository _userProfileRepo;
  late WorkoutPlanRepository _workoutPlanRepo;
  late DietPlanRepository _dietPlanRepo;

  /// 初始化仓库
  void initRepositories({
    required UserProfileRepository userProfileRepo,
    required WorkoutPlanRepository workoutPlanRepo,
    required DietPlanRepository dietPlanRepo,
  }) {
    _userProfileRepo = userProfileRepo;
    _workoutPlanRepo = workoutPlanRepo;
    _dietPlanRepo = dietPlanRepo;
  }

  /// 为用户生成完整的AI教练计划（训练+饮食）
  ///
  /// 返回生成的计划ID
  Future<Map<String, int?>> generateCompleteCoachPlan({
    required int userProfileId,
    required Function(String) onProgress,
  }) async {
    onProgress('正在获取用户信息...');

    // 获取用户画像
    final profile = await _userProfileRepo.getProfileById(userProfileId);
    if (profile == null) {
      throw Exception('用户画像不存在');
    }

    // 解析JSON列表
    final dietaryRestrictions = profile.dietaryRestrictions != null
        ? UserProfileRepository.parseJsonList(profile.dietaryRestrictions)
        : <String>[];
    final allergies = profile.allergies != null
        ? UserProfileRepository.parseJsonList(profile.allergies)
        : <String>[];
    final injuries = profile.injuries != null
        ? UserProfileRepository.parseJsonList(profile.injuries)
        : <String>[];
    final preferredWorkouts = profile.preferredWorkouts != null
        ? UserProfileRepository.parseJsonList(profile.preferredWorkouts)
        : <String>[];
    final dislikedWorkouts = profile.dislikedWorkouts != null
        ? UserProfileRepository.parseJsonList(profile.dislikedWorkouts)
        : <String>[];

    int? workoutPlanId;
    int? dietPlanId;

    // 生成训练计划
    try {
      onProgress('正在生成训练计划...');
      workoutPlanId = await _generateAndSaveWorkoutPlan(
        profile: profile,
        dietaryRestrictions: dietaryRestrictions,
        injuries: injuries,
        preferredWorkouts: preferredWorkouts,
        dislikedWorkouts: dislikedWorkouts,
      );
      onProgress('训练计划生成完成！');
    } catch (e) {
      onProgress('训练计划生成失败: $e');
    }

    // 生成饮食计划
    try {
      onProgress('正在生成饮食计划...');
      dietPlanId = await _generateAndSaveDietPlan(
        profile: profile,
        dietaryRestrictions: dietaryRestrictions,
        allergies: allergies,
      );
      onProgress('饮食计划生成完成！');
    } catch (e) {
      onProgress('饮食计划生成失败: $e');
    }

    return {
      'workoutPlanId': workoutPlanId,
      'dietPlanId': dietPlanId,
    };
  }

  /// 生成并保存训练计划
  Future<int> _generateAndSaveWorkoutPlan({
    required UserProfile profile,
    required List<String> dietaryRestrictions,
    required List<String> injuries,
    required List<String> preferredWorkouts,
    required List<String> dislikedWorkouts,
  }) async {
    // 调用AI生成
    final planData = await _aiService.generateCoachWorkoutPlan(
      goalType: profile.goalType,
      durationDays: profile.goalDurationDays ?? 30,
      gender: profile.gender,
      age: profile.age,
      height: profile.height,
      weight: profile.weight,
      fitnessLevel: profile.fitnessLevel,
      equipmentType: profile.equipmentType,
      dietType: profile.dietType,
      dietaryRestrictions: dietaryRestrictions,
      injuries: injuries,
      dailyWorkoutMinutes: profile.dailyWorkoutMinutes,
      preferredWorkouts: preferredWorkouts,
      dislikedWorkouts: dislikedWorkouts,
    );

    // 保存计划
    final planCompanion = WorkoutPlansCompanion.insert(
      userProfileId: profile.id,
      name: planData['planName'] as String? ?? 'AI训练计划',
      description: drift.Value(planData['description'] as String?),
      goalType: profile.goalType,
      totalDays: profile.goalDurationDays ?? 30,
      status: const drift.Value('active'),
      startDate: drift.Value(DateTime.now()),
      targetEndDate: drift.Value(
        DateTime.now().add(Duration(days: profile.goalDurationDays ?? 30)),
      ),
      totalWorkouts: drift.Value(planData['totalWorkouts'] as int? ?? (profile.goalDurationDays ?? 30)),
    );

    final planId = await _workoutPlanRepo.createPlan(planCompanion);

    // 保存每日训练
    final days = planData['days'] as List?;
    if (days != null) {
      for (final dayData in days) {
        await _saveWorkoutPlanDay(planId, dayData as Map<String, dynamic>);
      }
    }

    return planId;
  }

  /// 保存单日训练
  Future<void> _saveWorkoutPlanDay(int planId, Map<String, dynamic> dayData) async {
    final dayCompanion = WorkoutPlanDaysCompanion.insert(
      workoutPlanId: planId,
      dayNumber: dayData['day'] as int,
      dayName: drift.Value(dayData['dayName'] as String?),
      trainingFocus: drift.Value(dayData['trainingFocus'] as String?),
      estimatedMinutes: drift.Value(dayData['estimatedMinutes'] as int?),
    );

    final dayId = await _workoutPlanRepo.createDay(dayCompanion);

    // 保存动作
    final exercises = dayData['exercises'] as List?;
    if (exercises != null) {
      for (final exerciseData in exercises) {
        await _saveWorkoutPlanExercise(dayId, exerciseData as Map<String, dynamic>);
      }
    }
  }

  /// 保存训练动作
  Future<void> _saveWorkoutPlanExercise(int dayId, Map<String, dynamic> exerciseData) async {
    final exerciseCompanion = WorkoutPlanExercisesCompanion.insert(
      workoutPlanDayId: dayId,
      exerciseOrder: exerciseData['order'] as int,
      exerciseName: exerciseData['name'] as String,
      description: drift.Value(exerciseData['description'] as String?),
      sets: drift.Value(exerciseData['sets'] as int?),
      repsDescription: drift.Value(exerciseData['reps'] as String?),
      restSeconds: drift.Value(exerciseData['restSeconds'] as int?),
      equipment: drift.Value(exerciseData['equipment'] as String?),
      difficulty: drift.Value(exerciseData['difficulty'] as String?),
      exerciseType: exerciseData['exerciseType'] as String,
    );

    await _workoutPlanRepo.createExercise(exerciseCompanion);
  }

  /// 生成并保存饮食计划
  Future<int> _generateAndSaveDietPlan({
    required UserProfile profile,
    required List<String> dietaryRestrictions,
    required List<String> allergies,
  }) async {
    // 调用AI生成
    final planData = await _aiService.generateCoachDietPlan(
      goalType: profile.goalType,
      durationDays: profile.goalDurationDays ?? 30,
      gender: profile.gender,
      age: profile.age,
      height: profile.height,
      weight: profile.weight,
      fitnessLevel: profile.fitnessLevel,
      dietType: profile.dietType,
      dietaryRestrictions: dietaryRestrictions,
      allergies: allergies,
      tastePreference: profile.tastePreference,
    );

    // 保存计划
    final planCompanion = DietPlansCompanion.insert(
      userProfileId: profile.id,
      name: planData['planName'] as String? ?? 'AI饮食计划',
      description: drift.Value(planData['description'] as String?),
      goalType: profile.goalType,
      totalDays: profile.goalDurationDays ?? 30,
      dailyCalories: drift.Value((planData['dailyCalories'] as num?)?.toDouble()),
      dailyProtein: drift.Value((planData['dailyProtein'] as num?)?.toDouble()),
      dailyCarbs: drift.Value((planData['dailyCarbs'] as num?)?.toDouble()),
      dailyFat: drift.Value((planData['dailyFat'] as num?)?.toDouble()),
      status: const drift.Value('active'),
      startDate: drift.Value(DateTime.now()),
      targetEndDate: drift.Value(
        DateTime.now().add(Duration(days: profile.goalDurationDays ?? 30)),
      ),
    );

    final planId = await _dietPlanRepo.createPlan(planCompanion);

    // 保存每日饮食
    final days = planData['days'] as List?;
    if (days != null) {
      for (final dayData in days) {
        await _saveDietPlanDay(planId, dayData as Map<String, dynamic>);
      }
    }

    return planId;
  }

  /// 保存单日饮食
  Future<void> _saveDietPlanDay(int planId, Map<String, dynamic> dayData) async {
    final meals = dayData['meals'] as List?;
    if (meals == null) return;

    for (final mealData in meals) {
      final mealCompanion = DietPlanMealsCompanion.insert(
        dietPlanId: planId,
        dayNumber: dayData['day'] as int,
        mealType: (mealData as Map<String, dynamic>)['mealType'] as String,
        mealName: drift.Value((mealData as Map<String, dynamic>)['mealName'] as String?),
        eatingTime: drift.Value((mealData as Map<String, dynamic>)['eatingTime'] as String?),
        calories: drift.Value(((mealData as Map<String, dynamic>)['calories'] as num?)?.toDouble()),
        protein: drift.Value(((mealData as Map<String, dynamic>)['protein'] as num?)?.toDouble()),
        carbs: drift.Value(((mealData as Map<String, dynamic>)['carbs'] as num?)?.toDouble()),
        fat: drift.Value(((mealData as Map<String, dynamic>)['fat'] as num?)?.toDouble()),
        scheduledDate: drift.Value(DateTime.now().add(Duration(days: (dayData['day'] as int) - 1))),
      );

      final mealId = await _dietPlanRepo.createMeal(mealCompanion);

      // 保存食材
      final items = (mealData as Map<String, dynamic>)['items'] as List?;
      if (items != null) {
        for (final itemData in items) {
          await _saveDietPlanMealItem(mealId, itemData as Map<String, dynamic>);
        }
      }
    }
  }

  /// 保存餐次食材
  Future<void> _saveDietPlanMealItem(int mealId, Map<String, dynamic> itemData) async {
    final itemCompanion = MealItemsCompanion.insert(
      dietPlanMealId: mealId,
      foodName: itemData['foodName'] as String,
      amount: drift.Value(itemData['amount'] as String?),
      weightGrams: drift.Value((itemData['weightGrams'] as num?)?.toDouble()),
      calories: drift.Value((itemData['calories'] as num?)?.toDouble()),
      protein: drift.Value((itemData['protein'] as num?)?.toDouble()),
      carbs: drift.Value((itemData['carbs'] as num?)?.toDouble()),
      fat: drift.Value((itemData['fat'] as num?)?.toDouble()),
      cookingMethod: drift.Value(itemData['cookingMethod'] as String?),
      itemOrder: drift.Value(itemData['order'] as int?),
    );

    await _dietPlanRepo.createItem(itemCompanion);
  }

  /// 生成默认教练计划（不依赖AI）
  ///
  /// 当AI生成失败时使用，提供预设的训练和饮食计划
  Future<Map<String, int?>> generateDefaultCoachPlan({
    required int userProfileId,
    required Function(String) onProgress,
  }) async {
    onProgress('正在获取用户信息...');

    final profile = await _userProfileRepo.getProfileById(userProfileId);
    if (profile == null) {
      throw Exception('用户画像不存在');
    }

    final durationDays = profile.goalDurationDays ?? 30;
    final dailyMinutes = profile.dailyWorkoutMinutes ?? 30;

    int? workoutPlanId;
    int? dietPlanId;

    // 生成默认训练计划 - 必须成功
    onProgress('正在准备训练计划...');
    try {
      workoutPlanId = await _generateDefaultWorkoutPlan(
        profile: profile,
        durationDays: durationDays,
        dailyMinutes: dailyMinutes,
      );
      onProgress('训练计划准备完成！');
    } catch (e) {
      debugPrint('默认训练计划生成失败: $e');
      onProgress('训练计划准备失败，请重试');
      rethrow; // 重新抛出异常
    }

    // 生成默认饮食计划 - 必须成功
    onProgress('正在准备饮食计划...');
    try {
      dietPlanId = await _generateDefaultDietPlan(
        profile: profile,
        durationDays: durationDays,
      );
      onProgress('饮食计划准备完成！');
    } catch (e) {
      debugPrint('默认饮食计划生成失败: $e');
      onProgress('饮食计划准备失败，请重试');
      rethrow; // 重新抛出异常
    }

    // 确保至少有一个计划成功
    if (workoutPlanId == null && dietPlanId == null) {
      throw Exception('默认计划生成失败');
    }

    return {
      'workoutPlanId': workoutPlanId,
      'dietPlanId': dietPlanId,
    };
  }

  /// 生成默认训练计划
  Future<int> _generateDefaultWorkoutPlan({
    required UserProfile profile,
    required int durationDays,
    required int dailyMinutes,
  }) async {
    final goalType = profile.goalType;
    final equipmentType = profile.equipmentType;
    final fitnessLevel = profile.fitnessLevel;

    // 根据目标确定计划名称
    final planName = _getDefaultPlanName(goalType);
    final description = _getDefaultPlanDescription(goalType);

    // 保存计划
    final planCompanion = WorkoutPlansCompanion.insert(
      userProfileId: profile.id,
      name: planName,
      description: drift.Value(description),
      goalType: goalType,
      totalDays: durationDays,
      status: const drift.Value('active'),
      startDate: drift.Value(DateTime.now()),
      targetEndDate: drift.Value(DateTime.now().add(Duration(days: durationDays))),
      totalWorkouts: drift.Value(durationDays),
    );

    final planId = await _workoutPlanRepo.createPlan(planCompanion);

    // 为每一天生成训练
    for (int day = 1; day <= durationDays; day++) {
      final dayData = _getDefaultDayData(
        day: day,
        goalType: goalType,
        equipmentType: equipmentType,
        fitnessLevel: fitnessLevel,
        dailyMinutes: dailyMinutes,
      );
      await _saveWorkoutPlanDay(planId, dayData);
    }

    return planId;
  }

  /// 获取默认计划名称
  String _getDefaultPlanName(String goalType) {
    switch (goalType) {
      case 'fat_loss':
        return '燃脂塑形计划（默认）';
      case 'muscle_gain':
        return '增肌强体计划（默认）';
      case 'shape':
        return '体态优化计划（默认）';
      case 'maintain':
        return '健康保持计划（默认）';
      case 'fitness':
        return '体能提升计划（默认）';
      default:
        return '综合训练计划（默认）';
    }
  }

  /// 获取默认计划描述
  String _getDefaultPlanDescription(String goalType) {
    switch (goalType) {
      case 'fat_loss':
        return '结合有氧和力量训练，帮助您高效燃烧脂肪，塑造紧致线条';
      case 'muscle_gain':
        return '科学的力量训练方案，帮助您增加肌肉量，提升力量水平';
      case 'shape':
        return '改善身体姿态，优化肌肉线条，让您的体态更加挺拔优美';
      case 'maintain':
        return '保持当前身材和健康状态，适度的运动让您充满活力';
      case 'fitness':
        return '全面提升心肺功能和运动能力，增强体质和耐力';
      default:
        return '科学合理的训练计划，帮助您达成健身目标';
    }
  }

  /// 获取默认单日训练数据
  Map<String, dynamic> _getDefaultDayData({
    required int day,
    required String goalType,
    required String equipmentType,
    required String fitnessLevel,
    required int dailyMinutes,
  }) {
    // 训练重点轮换
    final focuses = ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '全身燃脂', '主动恢复'];
    final focusIndex = (day - 1) % focuses.length;

    // 根据器械类型和运动基础确定动作
    final exercises = _getDefaultExercises(
      day: day,
      goalType: goalType,
      equipmentType: equipmentType,
      fitnessLevel: fitnessLevel,
      dailyMinutes: dailyMinutes,
      trainingFocus: focuses[focusIndex],
    );

    return {
      'day': day,
      'dayName': '第${day}天',
      'trainingFocus': focuses[focusIndex],
      'estimatedMinutes': dailyMinutes,
      'exercises': exercises,
    };
  }

  /// 获取默认训练动作
  List<Map<String, dynamic>> _getDefaultExercises({
    required int day,
    required String goalType,
    required String equipmentType,
    required String fitnessLevel,
    required int dailyMinutes,
    required String trainingFocus,
  }) {
    final isBodyweightOnly = equipmentType == 'none';
    final isBeginner = fitnessLevel == 'beginner';

    List<Map<String, dynamic>> exercises = [];
    int order = 1;

    // 热身（5分钟）
    exercises.add({
      'order': order++,
      'name': '关节活动热身',
      'description': '转动肩、髋、膝、踝关节，手臂环绕，高抬腿，做2组',
      'sets': 2,
      'reps': '30秒',
      'restSeconds': 30,
      'equipment': '无',
      'difficulty': '简单',
      'exerciseType': 'warmup',
    });

    // 根据训练重点添加主训练动作
    if (trainingFocus.contains('胸背') || trainingFocus.contains('全身')) {
      exercises.addAll(_getDefaultChestBackExercises(
        order: order,
        isBodyweightOnly: isBodyweightOnly,
        isBeginner: isBeginner,
      ));
      order = exercises.length + 1;
    }

    if (trainingFocus.contains('肩臂') || trainingFocus.contains('全身')) {
      exercises.addAll(_getDefaultShoulderArmExercises(
        order: order,
        isBodyweightOnly: isBodyweightOnly,
        isBeginner: isBeginner,
      ));
      order = exercises.length + 1;
    }

    if (trainingFocus.contains('腿部') || trainingFocus.contains('全身')) {
      exercises.addAll(_getDefaultLegExercises(
        order: order,
        isBodyweightOnly: isBodyweightOnly,
        isBeginner: isBeginner,
      ));
      order = exercises.length + 1;
    }

    if (trainingFocus.contains('核心') || trainingFocus.contains('全身')) {
      exercises.addAll(_getDefaultCoreExercises(
        order: order,
        isBeginner: isBeginner,
      ));
      order = exercises.length + 1;
    }

    if (trainingFocus.contains('燃脂') || goalType == 'fat_loss') {
      exercises.addAll(_getDefaultCardioExercises(
        order: order,
        dailyMinutes: dailyMinutes,
      ));
    }

    // 拉伸放松（5分钟）
    exercises.add({
      'order': exercises.length + 1,
      'name': '全身拉伸放松',
      'description': '拉伸主要肌群，每个动作保持30秒',
      'sets': 1,
      'reps': '5分钟',
      'restSeconds': 0,
      'equipment': '无',
      'difficulty': '简单',
      'exerciseType': 'stretch',
    });

    return exercises;
  }

  /// 胸背训练动作
  List<Map<String, dynamic>> _getDefaultChestBackExercises({
    required int order,
    required bool isBodyweightOnly,
    required bool isBeginner,
  }) {
    if (isBodyweightOnly) {
      return [
        {
          'order': order,
          'name': '俯卧撑',
          'description': '双手略宽于肩，身体保持一条直线，胸部贴近地面后推起',
          'sets': isBeginner ? 3 : 4,
          'reps': isBeginner ? '8-12' : '12-15',
          'restSeconds': 60,
          'equipment': '无',
          'difficulty': isBeginner ? '中等' : '进阶',
          'exerciseType': 'strength',
        },
        {
          'order': order + 1,
          'name': '俯卧划船',
          'description': '趴在地上，双手拉起重物或使用水瓶，感受背部发力',
          'sets': 3,
          'reps': '12-15',
          'restSeconds': 60,
          'equipment': '无/水瓶',
          'difficulty': '简单',
          'exerciseType': 'strength',
        },
      ];
    } else {
      return [
        {
          'order': order,
          'name': '哑铃卧推/杠铃卧推',
          'description': '躺于凳上，推举哑铃或杠铃，感受胸肌收缩',
          'sets': 4,
          'reps': '8-12',
          'restSeconds': 90,
          'equipment': '哑铃/杠铃',
          'difficulty': '进阶',
          'exerciseType': 'strength',
        },
        {
          'order': order + 1,
          'name': '哑铃划船',
          'description': '单手支撑，另一手拉举哑铃，感受背部肌群发力',
          'sets': 4,
          'reps': '10-12',
          'restSeconds': 90,
          'equipment': '哑铃',
          'difficulty': '进阶',
          'exerciseType': 'strength',
        },
      ];
    }
  }

  /// 肩臂训练动作
  List<Map<String, dynamic>> _getDefaultShoulderArmExercises({
    required int order,
    required bool isBodyweightOnly,
    required bool isBeginner,
  }) {
    if (isBodyweightOnly) {
      return [
        {
          'order': order,
          'name': '俯卧撑（窄距）',
          'description': '双手与肩同宽，重点刺激肱三头肌',
          'sets': 3,
          'reps': '8-12',
          'restSeconds': 60,
          'equipment': '无',
          'difficulty': '中等',
          'exerciseType': 'strength',
        },
        {
          'order': order + 1,
          'name': '臂屈伸',
          'description': '双手撑在椅子边缘，身体下沉后推起',
          'sets': 3,
          'reps': '10-15',
          'restSeconds': 60,
          'equipment': '椅子',
          'difficulty': '简单',
          'exerciseType': 'strength',
        },
      ];
    } else {
      return [
        {
          'order': order,
          'name': '哑铃推举',
          'description': '坐姿或站姿，双手持哑铃向上推举',
          'sets': 4,
          'reps': '10-12',
          'restSeconds': 90,
          'equipment': '哑铃',
          'difficulty': '进阶',
          'exerciseType': 'strength',
        },
        {
          'order': order + 1,
          'name': '哑铃弯举',
          'description': '双手持哑铃做弯举动作，刺激二头肌',
          'sets': 4,
          'reps': '12-15',
          'restSeconds': 60,
          'equipment': '哑铃',
          'difficulty': '简单',
          'exerciseType': 'strength',
        },
      ];
    }
  }

  /// 腿部训练动作
  List<Map<String, dynamic>> _getDefaultLegExercises({
    required int order,
    required bool isBodyweightOnly,
    required bool isBeginner,
  }) {
    final sets = isBeginner ? 3 : 4;
    final reps = isBeginner ? '10-15' : '15-20';

    return [
      {
        'order': order,
        'name': '深蹲',
        'description': '双脚与肩同宽，下蹲至大腿与地面平行，注意膝盖方向',
        'sets': sets,
        'reps': reps,
        'restSeconds': 90,
        'equipment': isBodyweightOnly ? '无' : '哑铃（可选）',
        'difficulty': '简单',
        'exerciseType': 'strength',
      },
      {
        'order': order + 1,
        'name': '箭步蹲',
        'description': '交替向前跨步下蹲，保持身体稳定',
        'sets': 3,
        'reps': '每侧10-15次',
        'restSeconds': 60,
        'equipment': '无',
        'difficulty': '中等',
        'exerciseType': 'strength',
      },
      {
        'order': order + 2,
        'name': '臀桥',
        'description': '仰卧，双脚踩地，抬起臀部至身体成一直线',
        'sets': 4,
        'reps': '15-20',
        'restSeconds': 45,
        'equipment': '无',
        'difficulty': '简单',
        'exerciseType': 'strength',
      },
    ];
  }

  /// 核心训练动作
  List<Map<String, dynamic>> _getDefaultCoreExercises({
    required int order,
    required bool isBeginner,
  }) {
    final sets = isBeginner ? 3 : 4;

    return [
      {
        'order': order,
        'name': '平板支撑',
        'description': '用前臂和脚尖支撑身体，保持身体平直',
        'sets': sets,
        'reps': isBeginner ? '30秒' : '45-60秒',
        'restSeconds': 60,
        'equipment': '无',
        'difficulty': '中等',
        'exerciseType': 'strength',
      },
      {
        'order': order + 1,
        'name': '卷腹',
        'description': '仰卧，双手扶耳，用腹部力量卷起上半身',
        'sets': 4,
        'reps': '15-20',
        'restSeconds': 45,
        'equipment': '无',
        'difficulty': '简单',
        'exerciseType': 'strength',
      },
      {
        'order': order + 2,
        'name': '俄罗斯转体',
        'description': '坐姿，抬起双脚，双手握拳左右转动',
        'sets': 3,
        'reps': '20次',
        'restSeconds': 45,
        'equipment': '无',
        'difficulty': '中等',
        'exerciseType': 'strength',
      },
    ];
  }

  /// 有氧训练动作
  List<Map<String, dynamic>> _getDefaultCardioExercises({
    required int order,
    required int dailyMinutes,
  }) {
    final cardioMinutes = (dailyMinutes * 0.4).round(); // 40%时间做有氧

    return [
      {
        'order': order,
        'name': '开合跳',
        'description': '双脚开合跳跃，同时双手在头顶击掌',
        'sets': 1,
        'reps': '$cardioMinutes分钟',
        'restSeconds': 0,
        'equipment': '无',
        'difficulty': '中等',
        'exerciseType': 'cardio',
      },
      {
        'order': order + 1,
        'name': '高抬腿',
        'description': '原地快速抬高膝盖至腰部高度',
        'sets': 1,
        'reps': '${(cardioMinutes / 2).round()}分钟',
        'restSeconds': 0,
        'equipment': '无',
        'difficulty': '进阶',
        'exerciseType': 'cardio',
      },
    ];
  }

  /// 生成默认饮食计划
  Future<int> _generateDefaultDietPlan({
    required UserProfile profile,
    required int durationDays,
  }) async {
    final goalType = profile.goalType;
    final weight = profile.weight;

    // 根据目标估算每日热量
    final dailyCalories = _estimateDailyCalories(goalType, weight, profile.gender);
    final dailyProtein = (weight * 1.5); // 每公斤1.5g蛋白质
    final dailyCarbs = dailyCalories * 0.45 / 4; // 45%热量来自碳水
    final dailyFat = dailyCalories * 0.25 / 9; // 25%热量来自脂肪

    // 保存计划
    final planCompanion = DietPlansCompanion.insert(
      userProfileId: profile.id,
      name: '均衡饮食计划（默认）',
      description: drift.Value('科学均衡的饮食方案，帮助您达成健身目标'),
      goalType: goalType,
      totalDays: durationDays,
      dailyCalories: drift.Value(dailyCalories),
      dailyProtein: drift.Value(dailyProtein),
      dailyCarbs: drift.Value(dailyCarbs),
      dailyFat: drift.Value(dailyFat),
      status: const drift.Value('active'),
      startDate: drift.Value(DateTime.now()),
      targetEndDate: drift.Value(DateTime.now().add(Duration(days: durationDays))),
    );

    final planId = await _dietPlanRepo.createPlan(planCompanion);

    // 为每一天生成饮食
    for (int day = 1; day <= durationDays; day++) {
      await _saveDefaultDietPlanDay(planId, day, dailyCalories);
    }

    return planId;
  }

  /// 估算每日热量需求
  double _estimateDailyCalories(String goalType, double weight, String gender) {
    // 基础代谢粗略估算
    double baseCalories = gender == 'male' ? 1800 : 1500;

    switch (goalType) {
      case 'fat_loss':
        return baseCalories - 300; // 热量缺口
      case 'muscle_gain':
        return baseCalories + 300; // 热量盈余
      case 'shape':
      case 'fitness':
        return baseCalories;
      case 'maintain':
      default:
        return baseCalories;
    }
  }

  /// 保存默认单日饮食
  Future<void> _saveDefaultDietPlanDay(int planId, int day, double totalCalories) async {
    // 分配三餐热量
    final breakfastCalories = totalCalories * 0.3;
    final lunchCalories = totalCalories * 0.4;
    final dinnerCalories = totalCalories * 0.3;

    final meals = [
      _getDefaultMealData(day, 1, 'breakfast', '早餐', breakfastCalories),
      _getDefaultMealData(day, 2, 'lunch', '午餐', lunchCalories),
      _getDefaultMealData(day, 3, 'dinner', '晚餐', dinnerCalories),
    ];

    for (final mealData in meals) {
      final mealCompanion = DietPlanMealsCompanion.insert(
        dietPlanId: planId,
        dayNumber: day,
        mealType: mealData['mealType'] as String,
        mealName: drift.Value(mealData['mealName'] as String?),
        eatingTime: drift.Value(mealData['eatingTime'] as String?),
        calories: drift.Value((mealData['calories'] as num?)?.toDouble()),
        protein: drift.Value((mealData['protein'] as num?)?.toDouble()),
        carbs: drift.Value((mealData['carbs'] as num?)?.toDouble()),
        fat: drift.Value((mealData['fat'] as num?)?.toDouble()),
        scheduledDate: drift.Value(DateTime.now().add(Duration(days: day - 1))),
      );

      final mealId = await _dietPlanRepo.createMeal(mealCompanion);

      // 保存食材
      final items = mealData['items'] as List;
      for (final itemData in items) {
        await _saveDietPlanMealItem(mealId, itemData as Map<String, dynamic>);
      }
    }
  }

  /// 获取默认餐次数据
  Map<String, dynamic> _getDefaultMealData(
    int day,
    int mealOrder,
    String mealType,
    String mealName,
    double calories,
  ) {
    final protein = calories * 0.25 / 4; // 25%蛋白质
    final carbs = calories * 0.5 / 4; // 50%碳水
    final fat = calories * 0.25 / 9; // 25%脂肪

    return {
      'day': day,
      'mealType': mealType,
      'mealName': mealName,
      'eatingTime': mealType == 'breakfast'
          ? '07:00-08:00'
          : mealType == 'lunch' ? '12:00-13:00' : '18:00-19:00',
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'items': _getDefaultMealItems(mealType, calories),
    };
  }

  /// 获取默认餐次食材
  List<Map<String, dynamic>> _getDefaultMealItems(String mealType, double calories) {
    if (mealType == 'breakfast') {
      return [
        {
          'foodName': '燕麦片',
          'amount': '50g',
          'weightGrams': 50,
          'calories': 180,
          'protein': 6,
          'carbs': 30,
          'fat': 3,
          'cookingMethod': '用热水或牛奶冲泡',
          'order': 1,
        },
        {
          'foodName': '鸡蛋',
          'amount': '2个',
          'weightGrams': 100,
          'calories': 140,
          'protein': 12,
          'carbs': 1,
          'fat': 10,
          'cookingMethod': '水煮或煎',
          'order': 2,
        },
        {
          'foodName': '牛奶/豆浆',
          'amount': '250ml',
          'weightGrams': 250,
          'calories': 120,
          'protein': 8,
          'carbs': 10,
          'fat': 5,
          'cookingMethod': '直接饮用',
          'order': 3,
        },
      ];
    } else if (mealType == 'lunch') {
      return [
        {
          'foodName': '米饭',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 180,
          'protein': 4,
          'carbs': 40,
          'fat': 0.5,
          'cookingMethod': '蒸煮',
          'order': 1,
        },
        {
          'foodName': '鸡胸肉',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 165,
          'protein': 31,
          'carbs': 0,
          'fat': 3.6,
          'cookingMethod': '煎炒或水煮',
          'order': 2,
        },
        {
          'foodName': '西兰花',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 50,
          'protein': 4,
          'carbs': 10,
          'fat': 0.5,
          'cookingMethod': '焯水后凉拌',
          'order': 3,
        },
      ];
    } else {
      // dinner
      return [
        {
          'foodName': '红薯/紫薯',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 130,
          'protein': 2,
          'carbs': 30,
          'fat': 0.2,
          'cookingMethod': '蒸煮',
          'order': 1,
        },
        {
          'foodName': '鱼肉',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 150,
          'protein': 25,
          'carbs': 0,
          'fat': 5,
          'cookingMethod': '清蒸或煎',
          'order': 2,
        },
        {
          'foodName': '青菜',
          'amount': '200g',
          'weightGrams': 200,
          'calories': 50,
          'protein': 2,
          'carbs': 8,
          'fat': 0.5,
          'cookingMethod': '清炒',
          'order': 3,
        },
      ];
    }
  }
}
