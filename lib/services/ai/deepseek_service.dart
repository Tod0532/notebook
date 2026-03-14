/// DeepSeek AI 服务
/// 提供 AI 功能接口：计划生成、运动小结生成等

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';

/// DeepSeek AI 服务类
class DeepSeekService {
  static DeepSeekService? _instance;
  static const _apiKeyKey = 'deepseek_api_key';
  static const _apiBaseUrl = 'https://api.deepseek.com/v1';

  // 默认 API Key 已移除，要求用户自己配置
  // 请在 AI 设置页面配置您的 DeepSeek API Key
  // 获取 API Key：访问 https://platform.deepseek.com/ 注册账号

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _apiBaseUrl,
    connectTimeout: const Duration(seconds: 60), // 增加连接超时
    receiveTimeout: const Duration(seconds: 180), // 增加接收超时到3分钟
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  String? _apiKey;

  /// 默认 API Key - 用户配置的Key
  /// 获取 API Key：访问 https://platform.deepseek.com/ 注册账号
  static const String _defaultApiKey = 'sk-c854090502824575a257bc6da42f485f';

  DeepSeekService._internal();

  /// 获取单例实例
  static DeepSeekService get instance {
    _instance ??= DeepSeekService._internal();
    return _instance!;
  }

  /// 初始化 API Key
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey);

    // 如果用户未配置，使用默认 Key
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = _defaultApiKey;
      debugPrint('使用默认 API Key');
    }

    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_apiKey';
    }
  }

  /// 设置 API Key
  Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    _apiKey = apiKey;
    _dio.options.headers['Authorization'] = 'Bearer $_apiKey';
  }

  /// 获取 API Key
  String? get apiKey => _apiKey;

  /// 检查 API Key 是否已配置
  bool get isConfigured {
    // 默认使用内置 API Key，始终返回 true
    return _apiKey != null && _apiKey!.isNotEmpty && _apiKey!.length > 10;
  }

  /// 清除 API Key
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    _apiKey = null;
    _dio.options.headers.remove('Authorization');
  }

  /// 测试 API Key 是否有效
  Future<bool> testApiKey() async {
    if (!isConfigured) return false;

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'user',
              'content': 'test',
            },
          ],
          'max_tokens': 5,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Key 测试失败: $e');
      return false;
    }
  }

  /// 生成运动计划
  ///
  /// [goal] 用户目标，如"减肥10斤"、"练出腹肌"
  /// [durationDays] 计划天数
  /// [currentLevel] 当前运动水平，如"新手"、"中级"
  /// [availableDays] 每周可运动天数
  /// [availableTime] 每次可运动时长（分钟）
  Future<String> generateWorkoutPlan({
    required String goal,
    required int durationDays,
    String currentLevel = '新手',
    int availableDays = 3,
    int availableTime = 30,
  }) async {
    if (!isConfigured) {
      throw Exception('API Key 未配置');
    }

    final prompt = _buildWorkoutPlanPrompt(
      goal: goal,
      durationDays: durationDays,
      currentLevel: currentLevel,
      availableDays: availableDays,
      availableTime: availableTime,
    );

    return await _callChatAPIWithRetry(prompt);
  }

  /// 生成运动小结
  ///
  /// [workoutType] 运动类型
  /// [durationMinutes] 运动时长（分钟）
  /// [notes] 用户备注
  /// [feeling] 运动感受
  /// [sets] 组数
  /// [reps] 次数
  /// [weight] 重量
  Future<String> generateWorkoutSummary({
    required String workoutType,
    required int durationMinutes,
    String? notes,
    String? feeling,
    int? sets,
    int? reps,
    double? weight,
  }) async {
    if (!isConfigured) {
      // 返回默认小结
      return _getDefaultWorkoutSummary(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        sets: sets,
        reps: reps,
      );
    }

    final prompt = _buildWorkoutSummaryPrompt(
      workoutType: workoutType,
      durationMinutes: durationMinutes,
      notes: notes,
      feeling: feeling,
      sets: sets,
      reps: reps,
      weight: weight,
    );

    try {
      return await _callChatAPIWithRetry(prompt, maxTokens: 500);
    } catch (e) {
      // 失败时返回默认小结
      return _getDefaultWorkoutSummary(
        workoutType: workoutType,
        durationMinutes: durationMinutes,
        sets: sets,
        reps: reps,
      );
    }
  }

  /// 生成每日早安问候
  ///
  /// [todayTasks] 今天的任务列表
  /// [weather] 天气信息（可选）
  /// [userName] 用户名
  Future<String> generateMorningGreeting({
    required List<String> todayTasks,
    String? weather,
    String userName = '老大',
  }) async {
    // 早安问候直接返回默认值，不调用 AI
    return _getDefaultMorningGreeting(todayTasks, userName, weather);
  }

  /// 分析笔记情绪
  ///
  /// 返回情绪分析结果：positive/neutral/negative
  Future<String> analyzeMood(String noteContent) async {
    if (!isConfigured) {
      return 'neutral';
    }

    final prompt = '''请分析以下笔记内容的情绪，只返回一个词：

如果是积极、开心、兴奋的情绪，返回：positive
如果是中性、平静、普通的情绪，返回：neutral
如果是消极、难过、焦虑的情绪，返回：negative

笔记内容：
$noteContent

只返回一个词（positive/neutral/negative），不要其他内容。''';

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 50);
      return response.toLowerCase().trim();
    } catch (e) {
      return 'neutral';
    }
  }

  /// ==================== AI教练功能 ====================

  /// 生成AI教练训练计划（结构化JSON格式）
  ///
  /// 基于用户画像生成详细的训练计划，返回JSON格式数据
  /// 失败时自动返回默认计划
  Future<Map<String, dynamic>> generateCoachWorkoutPlan({
    required String goalType, // fat_loss/muscle_gain/shape/maintain/fitness
    required int durationDays,
    required String gender,
    required int age,
    required double height,
    required double weight,
    required String fitnessLevel, // beginner/novice/intermediate/advanced
    required String equipmentType, // none/home_minimal/home_full/gym_full
    String? dietType,
    List<String>? dietaryRestrictions,
    List<String>? injuries,
    int? dailyWorkoutMinutes,
    List<String>? preferredWorkouts,
    List<String>? dislikedWorkouts,
  }) async {
    // 输入验证和边界处理
    const validGoalTypes = ['fat_loss', 'muscle_gain', 'shape', 'maintain', 'fitness'];
    const validFitnessLevels = ['beginner', 'novice', 'intermediate', 'advanced'];
    const validEquipmentTypes = ['none', 'home_minimal', 'home_full', 'gym_full'];

    // 验证并修正枚举值
    final validatedGoalType = validGoalTypes.contains(goalType) ? goalType : 'fat_loss';
    final validatedFitnessLevel = validFitnessLevels.contains(fitnessLevel) ? fitnessLevel : 'novice';
    final validatedEquipmentType = validEquipmentTypes.contains(equipmentType) ? equipmentType : 'none';

    // 验证数值范围（添加类型转换）
    final validatedDurationDays = durationDays.clamp(1, 365) as int;
    final validatedAge = age.clamp(10, 100) as int;
    final validatedHeight = height.clamp(100, 250).toDouble(); // cm
    final validatedWeight = weight.clamp(30, 200).toDouble(); // kg

    // 验证并处理可选参数
    int? validatedDailyWorkoutMinutes;
    if (dailyWorkoutMinutes != null) {
      validatedDailyWorkoutMinutes = dailyWorkoutMinutes.clamp(10, 180) as int;
    }

    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认训练计划');
      return _getDefaultWorkoutPlan(
        goalType: validatedGoalType,
        durationDays: validatedDurationDays,
        equipmentType: validatedEquipmentType,
        fitnessLevel: validatedFitnessLevel,
        dailyWorkoutMinutes: validatedDailyWorkoutMinutes,
        age: validatedAge,
        height: validatedHeight,
        weight: validatedWeight,
      );
    }

    final prompt = _buildCoachWorkoutPlanPrompt(
      goalType: validatedGoalType,
      durationDays: validatedDurationDays,
      gender: gender,
      age: validatedAge,
      height: validatedHeight,
      weight: validatedWeight,
      fitnessLevel: validatedFitnessLevel,
      equipmentType: validatedEquipmentType,
      dietType: dietType,
      dietaryRestrictions: dietaryRestrictions,
      injuries: injuries,
      dailyWorkoutMinutes: validatedDailyWorkoutMinutes,
      preferredWorkouts: preferredWorkouts,
      dislikedWorkouts: dislikedWorkouts,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      return _parseWorkoutPlanJSON(
        response,
        goalType: validatedGoalType,
        durationDays: validatedDurationDays,
        equipmentType: validatedEquipmentType,
        fitnessLevel: validatedFitnessLevel,
        dailyWorkoutMinutes: validatedDailyWorkoutMinutes,
      );
    } catch (e) {
      debugPrint('AI生成训练计划失败，使用默认计划: $e');
      return _getDefaultWorkoutPlan(
        goalType: validatedGoalType,
        durationDays: validatedDurationDays,
        equipmentType: validatedEquipmentType,
        fitnessLevel: validatedFitnessLevel,
        dailyWorkoutMinutes: validatedDailyWorkoutMinutes,
        age: validatedAge,
        height: validatedHeight,
        weight: validatedWeight,
      );
    }
  }

  /// 生成AI教练饮食计划（结构化JSON格式）
  ///
  /// 基于用户画像生成详细的饮食计划，返回JSON格式数据
  /// 失败时自动返回默认计划
  Future<Map<String, dynamic>> generateCoachDietPlan({
    required String goalType, // fat_loss/muscle_gain/shape/maintain/fitness
    required int durationDays,
    required String gender,
    required int age,
    required double height,
    required double weight,
    required String fitnessLevel,
    String? dietType,
    List<String>? dietaryRestrictions,
    List<String>? allergies,
    String? tastePreference,
    double? targetWeight,
  }) async {
    // 输入验证和边界处理
    const validGoalTypes = ['fat_loss', 'muscle_gain', 'shape', 'maintain', 'fitness'];
    final validatedGoalType = validGoalTypes.contains(goalType) ? goalType : 'fat_loss';
    final validatedDurationDays = durationDays.clamp(1, 365) as int;
    final validatedWeight = weight.clamp(30, 200).toDouble();
    double? validatedTargetWeight;
    if (targetWeight != null) {
      validatedTargetWeight = targetWeight.clamp(30, 200).toDouble();
    }

    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认饮食计划');
      return _getDefaultDietPlan(
        goalType: validatedGoalType,
        durationDays: validatedDurationDays,
        weight: validatedWeight,
        gender: gender,
        targetWeight: validatedTargetWeight,
      );
    }

    final prompt = _buildCoachDietPlanPrompt(
      goalType: validatedGoalType,
      durationDays: validatedDurationDays,
      gender: gender,
      age: age,
      height: height,
      weight: validatedWeight,
      fitnessLevel: fitnessLevel,
      dietType: dietType,
      dietaryRestrictions: dietaryRestrictions,
      allergies: allergies,
      tastePreference: tastePreference,
      targetWeight: validatedTargetWeight,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      return _parseDietPlanJSON(response);
    } catch (e) {
      debugPrint('AI生成饮食计划失败，使用默认计划: $e');
      return _getDefaultDietPlan(
        goalType: validatedGoalType,
        durationDays: validatedDurationDays,
        weight: validatedWeight,
        gender: gender,
        targetWeight: validatedTargetWeight,
      );
    }
  }

  /// 生成训练计划调整建议
  ///
  /// 基于用户反馈生成调整后的训练计划
  Future<String> generateWorkoutAdjustment({
    required String currentPlan,
    required String feedback, // 如"动作太难"、"时间不够"等
  }) async {
    if (!isConfigured) {
      throw Exception('API Key 未配置');
    }

    final prompt = '''用户对当前训练计划有以下反馈：$feedback

当前训练计划：
$currentPlan

请根据反馈调整训练计划，保持原有的JSON格式，只返回调整后的JSON数据。

调整原则：
- 如果觉得太难，降低动作难度或减少训练量
- 如果觉得时间不够，缩短训练时长
- 如果觉得某部位太疲劳，调整训练部位安排
- 始终保持计划的科学性和安全性''';

    return await _callChatAPIWithRetry(prompt, maxTokens: 3000);
  }

  /// 生成饮食计划调整建议
  ///
  /// 基于用户反馈生成调整后的饮食计划
  Future<String> generateDietAdjustment({
    required String currentPlan,
    required String feedback, // 如"食材买不到"、"太难做"等
  }) async {
    if (!isConfigured) {
      throw Exception('API Key 未配置');
    }

    final prompt = '''用户对当前饮食计划有以下反馈：$feedback

当前饮食计划：
$currentPlan

请根据反馈调整饮食计划，保持原有的JSON格式，只返回调整后的JSON数据。

调整原则：
- 如果食材买不到，提供易获得的替代食材
- 如果觉得难做，简化烹饪步骤
- 如果吃不饱，增加饱腹感强的食物
- 始终保持营养均衡和目标导向''';

    return await _callChatAPIWithRetry(prompt, maxTokens: 3000);
  }

  /// 替换单个训练动作
  ///
  /// 基于原动作信息生成替代动作
  Future<Map<String, dynamic>> replaceExercise({
    required String currentExerciseName,
    required String exerciseType, // warm_up/main/stretch
    required String targetMuscle, // 目标肌肉部位
    required String equipmentType, // 器械类型
    required String reason, // 替换原因
    String? difficulty, // 难度级别
  }) async {
    if (!isConfigured) {
      return _getDefaultReplacementExercise(
        exerciseType: exerciseType,
        targetMuscle: targetMuscle,
        equipmentType: equipmentType,
        reason: reason,
      );
    }

    final prompt = _buildReplaceExercisePrompt(
      currentExerciseName: currentExerciseName,
      exerciseType: exerciseType,
      targetMuscle: targetMuscle,
      equipmentType: equipmentType,
      reason: reason,
      difficulty: difficulty,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 1000);
      return _parseSingleExerciseJSON(response);
    } catch (e) {
      debugPrint('AI替换动作失败，使用默认动作: $e');
      return _getDefaultReplacementExercise(
        exerciseType: exerciseType,
        targetMuscle: targetMuscle,
        equipmentType: equipmentType,
        reason: reason,
      );
    }
  }

  /// 替换单个食材
  ///
  /// 基于原食材信息生成替代食材
  Future<Map<String, dynamic>> replaceFoodItem({
    required String currentFoodName,
    required String mealType, // breakfast/lunch/dinner/snack
    required String reason, // 替换原因
    double? targetCalories, // 目标热量
    double? targetProtein, // 目标蛋白质
    List<String>? allergies, // 过敏食材
    List<String>? dietaryRestrictions, // 饮食禁忌
  }) async {
    if (!isConfigured) {
      return _getDefaultReplacementFood(
        mealType: mealType,
        targetCalories: targetCalories,
        currentFoodName: currentFoodName,
      );
    }

    final prompt = _buildReplaceFoodPrompt(
      currentFoodName: currentFoodName,
      mealType: mealType,
      reason: reason,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      allergies: allergies,
      dietaryRestrictions: dietaryRestrictions,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 1000);
      return _parseSingleFoodJSON(response);
    } catch (e) {
      debugPrint('AI替换食材失败，使用默认食材: $e');
      return _getDefaultReplacementFood(
        mealType: mealType,
        targetCalories: targetCalories,
        currentFoodName: currentFoodName,
      );
    }
  }

  /// ==================== API调用与重试 ====================

  /// 调用 DeepSeek Chat API（带重试）
  Future<String> _callChatAPIWithRetry(
    String prompt, {
    int maxTokens = 1000,
    int retries = 3,
  }) async {
    if (!isConfigured) {
      throw Exception('API Key 未配置');
    }

    Exception? lastException;

    for (int i = 0; i < retries; i++) {
      try {
        return await _callChatAPI(prompt, maxTokens: maxTokens);
      } on SocketException catch (e) {
        lastException = Exception('网络连接失败: ${e.message}');
        debugPrint('网络连接失败，重试 ${i + 1}/$retries');
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: 2));
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          lastException = Exception('请求超时，重试 ${i + 1}/$retries');
          debugPrint('请求超时，重试 ${i + 1}/$retries');
          if (i < retries - 1) {
            await Future.delayed(Duration(seconds: 2));
          }
        } else if (e.response?.statusCode == 429) {
          lastException = Exception('API 请求频率过高');
          debugPrint('API限流，等待后重试');
          if (i < retries - 1) {
            await Future.delayed(const Duration(seconds: 5));
          } else {
            rethrow;
          }
        } else if (e.response?.statusCode == 401) {
          throw Exception('API Key 无效，请检查配置');
        } else {
          lastException = Exception('API请求失败: ${e.message}');
          if (i < retries - 1) {
            await Future.delayed(Duration(seconds: 2));
          } else {
            rethrow;
          }
        }
      } catch (e) {
        lastException = Exception('未知错误: $e');
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }

    throw lastException ?? Exception('请求失败，请重试');
  }

  /// 调用 DeepSeek Chat API
  Future<String> _callChatAPI(String prompt, {int maxTokens = 1000}) async {
    if (!isConfigured) {
      throw Exception('API Key 未配置');
    }

    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的运动教练和健康顾问，擅长制定运动计划和分析运动数据。请严格按照用户要求的格式返回数据，不要添加任何额外的说明文字。',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'max_tokens': maxTokens,
        'temperature': 0.7,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content != null) {
        return content.trim();
      }
    }

    throw Exception('API 响应格式错误');
  }

  /// ==================== 默认数据方法 ====================

  /// 获取默认运动小结
  String _getDefaultWorkoutSummary({
    required String workoutType,
    required int durationMinutes,
    int? sets,
    int? reps,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== 运动小结 ====');
    buffer.writeln();
    buffer.writeln('**运动概况**：今天完成了$workoutType训练，运动时长$durationMinutes分钟。');
    if (sets != null && sets > 0) {
      buffer.writeln('**训练量**：共$sets组训练');
    }
    buffer.writeln();
    buffer.writeln('**小结**：今天的训练帮助您保持了运动习惯，坚持下去会看到效果！');
    buffer.writeln();
    buffer.writeln('**下次建议**：注意训练后的拉伸和休息，保持充足睡眠。');

    return buffer.toString();
  }

  /// 获取默认早安问候
  String _getDefaultMorningGreeting(
    List<String> todayTasks,
    String userName,
    String? weather,
  ) {
    final taskInfo = todayTasks.isEmpty
        ? '今天没有什么特别安排，保持节奏就好。'
        : '今天有 ${todayTasks.length} 项任务要完成哦！';

    final weatherInfo = weather != null ? '今天$weather，' : '';

    return '早安，$userName！☀\n\n$weatherInfo又是充满活力的一天！\n\n**今日重点**：$taskInfo\n\n加油，让我们开始吧！';
  }

  /// 获取默认训练计划
  Map<String, dynamic> _getDefaultWorkoutPlan({
    required String goalType,
    required int durationDays,
    required String equipmentType,
    required String fitnessLevel,
    int? dailyWorkoutMinutes,
    int? age,
    double? height,
    double? weight,
  }) {
    // 计算强度系数（如果有参数）
    double intensityFactor = 1.0;
    if (age != null && height != null && weight != null) {
      final bmi = _calculateBMI(weight, height);
      final ageFactor = _getAgeIntensityFactor(age);
      final bmiFactor = _getBMIIntensityFactor(bmi);
      intensityFactor = ageFactor * bmiFactor;
    }

    // 调整每日训练时长
    final adjustedMinutes = dailyWorkoutMinutes != null
        ? ((dailyWorkoutMinutes * intensityFactor).round()).clamp(15, 60)
        : 30;

    final planNames = {
      'fat_loss': '燃脂塑形计划',
      'muscle_gain': '增肌强体计划',
      'shape': '体态优化计划',
      'maintain': '健康保持计划',
      'fitness': '体能提升计划',
    };

    final descriptions = {
      'fat_loss': '结合有氧和力量训练，帮助您高效燃烧脂肪，塑造紧致线条',
      'muscle_gain': '科学的力量训练方案，帮助您增加肌肉量，提升力量水平',
      'shape': '改善身体姿态，优化肌肉线条，让您的体态更加挺拔优美',
      'maintain': '保持当前身材和健康状态，适度的运动让您充满活力',
      'fitness': '全面提升心肺功能和运动能力，增强体质和耐力',
    };

    final planName = planNames[goalType] ?? '综合训练计划';
    final description = descriptions[goalType] ?? '科学合理的训练计划，帮助您达成健身目标';

    // 生成每日训练
    final List<Map<String, dynamic>> days = [];

    // 获取器械类型专属的训练重点模式
    final focusPatterns = _getFocusPatternsForGoal(goalType, equipmentType);

    // 从模式中循环取训练重点
    final focuses = focusPatterns.take(durationDays).toList();

    for (int day = 1; day <= durationDays; day++) {
      final focusIndex = (day - 1) % focuses.length;
      days.add(_getDefaultWorkoutDay(
        day: day,
        focus: focuses[focusIndex],
        equipmentType: equipmentType,
        fitnessLevel: fitnessLevel,
        dailyWorkoutMinutes: adjustedMinutes,
      ));
    }

    // 统计实际训练天数（排除休息日）
    final actualWorkoutDays = days.where((day) => !(day['isRestDay'] as bool)).length;

    return {
      'planName': planName,
      'description': description,
      'totalWorkouts': actualWorkoutDays,
      'days': days,
    };
  }

  /// 计算 BMI
  double _calculateBMI(double weightKg, double heightCm) {
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// 根据 BMI 获取强度系数
  double _getBMIIntensityFactor(double bmi) {
    if (bmi < 18.5) return 0.9; // 偏瘦：降低强度
    if (bmi < 24) return 1.0; // 正常：标准强度
    if (bmi < 28) return 0.9; // 超重：降低强度
    return 0.8; // 肥胖：显著降低强度
  }

  /// 根据年龄获取强度系数
  double _getAgeIntensityFactor(int age) {
    if (age < 30) return 1.0;
    if (age < 40) return 0.95;
    if (age < 50) return 0.9;
    return 0.85;
  }

  /// 获取器械和目标类型专属的训练重点模式
  List<String> _getFocusPatternsForGoal(String goalType, String equipmentType) {
    // 为每种器械类型定义专属的训练重点模式
    switch (equipmentType) {
      case 'none':
        // 无器械 - 全身循环为主
        switch (goalType) {
          case 'fat_loss':
            return ['全身循环', 'HIIT燃脂', '核心爆发', '有氧耐力', '全身自重', '主动恢复', '休息', '全身循环', 'HIIT燃脂', '核心爆发'];
          case 'muscle_gain':
            return ['全身力量', '上肢推', '下肢力量', '核心强化', '全身爆发', '主动恢复', '休息', '全身力量', '上肢推', '下肢力量'];
          case 'shape':
            return ['体态优化', '核心塑形', '全身紧致', '臀部强化', '上肢塑形', '主动恢复', '休息', '体态优化', '核心塑形', '全身紧致'];
          case 'fitness':
            return ['耐力循环', '敏捷训练', '核心爆发', '全身协调', '有氧间歇', '主动恢复', '休息', '耐力循环', '敏捷训练', '核心爆发'];
          default:
            return ['全身循环', '核心训练', '下肢力量', '上肢力量', '有氧燃脂', '主动恢复'];
        }
      case 'home_minimal':
        // 家用小器械 - 上下肢分化
        switch (goalType) {
          case 'fat_loss':
            return ['全身循环', '上肢燃脂', '下肢燃脂', 'HIIT训练', '核心有氧', '主动恢复', '休息', '全身循环', '上肢燃脂', '下肢燃脂'];
          case 'muscle_gain':
            return ['胸背训练', '肩臂训练', '腿部力量', '核心训练', '全身循环', '主动恢复', '休息', '胸背训练', '肩臂训练', '腿部力量'];
          case 'shape':
            return ['上肢塑形', '下肢塑形', '核心紧致', '全身线条', '体态优化', '主动恢复', '休息', '上肢塑形', '下肢塑形', '核心紧致'];
          case 'fitness':
            return ['力量耐力', '有氧力量', '敏捷训练', '全身循环', '核心稳定', '主动恢复', '休息', '力量耐力', '有氧力量', '敏捷训练'];
          default:
            return ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '全身燃脂', '主动恢复'];
        }
      case 'home_full':
        // 家庭健身器材 - 推拉腿分化
        switch (goalType) {
          case 'fat_loss':
            return ['壶铃燃脂', '全身循环', '上肢HIIT', '下肢HIIT', '核心爆发', '主动恢复', '休息', '壶铃燃脂', '全身循环', '上肢HIIT'];
          case 'muscle_gain':
            return ['推力训练', '拉力训练', '腿部力量', '壶铃爆发', '核心力量', '主动恢复', '休息', '推力训练', '拉力训练', '腿部力量'];
          case 'shape':
            return ['体态雕塑', '臀部专项', '核心紧致', '全身线条', '上肢塑形', '主动恢复', '休息', '体态雕塑', '臀部专项', '核心紧致'];
          case 'fitness':
            return ['爆发力训练', '全身协调', '壶铃耐力', '核心稳定', '敏捷爆发', '主动恢复', '休息', '爆发力训练', '全身协调', '壶铃耐力'];
          default:
            return ['推力训练', '拉力训练', '腿部训练', '核心训练', '壶铃燃脂', '主动恢复'];
        }
      case 'gym_full':
        // 健身房全套器械 - 部位专项
        switch (goalType) {
          case 'fat_loss':
            return ['全身循环', '大重量燃脂', '有氧器械', 'HIIT训练', '核心强化', '主动恢复', '休息', '全身循环', '大重量燃脂', '有氧器械'];
          case 'muscle_gain':
            return ['胸肌专项', '背部专项', '腿部力量', '肩部专项', '手臂专项', '主动恢复', '休息', '胸肌专项', '背部专项', '腿部力量'];
          case 'shape':
            return ['体态雕塑', '肌肉线条', '核心定义', '臀部力量', '全身协调', '主动恢复', '休息', '体态雕塑', '肌肉线条', '核心定义'];
          case 'fitness':
            return ['力量耐力', '有氧功率', '爆发力训练', '核心稳定', '全身循环', '主动恢复', '休息', '力量耐力', '有氧功率', '爆发力训练'];
          default:
            return ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '有氧燃脂', '主动恢复'];
        }
      default:
        // 默认模式（兼容旧版本）
        switch (goalType) {
          case 'fat_loss':
            return ['全身燃脂', 'HIIT训练', '有氧燃脂', '核心循环', '全身循环', '主动恢复', '休息', '有氧燃脂', '全身燃脂', 'HIIT训练'];
          case 'muscle_gain':
            return ['胸背训练', '肩臂训练', '休息', '腿部训练', '核心训练', '全身循环', '休息', '胸背训练', '肩臂训练', '腿部训练'];
          case 'shape':
            return ['臀腿训练', '上肢塑形', '核心训练', '全身塑形', '有氧拉伸', '主动恢复', '休息', '臀腿训练', '上肢塑形', '核心训练'];
          case 'fitness':
            return ['耐力训练', '力量爆发', '敏捷训练', '全身循环', '有氧间歇', '主动恢复', '休息', '耐力训练', '力量爆发', '敏捷训练'];
          default:
            return ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '全身燃脂', '主动恢复'];
        }
    }
  }

  /// 计算动作预估时间（秒）
  ///
  /// 根据组数、次数、休息时间和难度计算完成该动作所需的总时间
  int _calculateExerciseSeconds({
    required int sets,
    required String reps,
    required int restSeconds,
    required String difficulty,
  }) {
    // 根据难度确定每组动作时间
    final secondsPerSet = switch (difficulty) {
      'easy' => 40,
      'medium' => 50,
      'hard' => 60,
      _ => 50,
    };

    // 如果 reps 是时间格式（如 "30-45秒"），直接解析
    if (reps.contains('秒')) {
      final match = RegExp(r'(\d+)').firstMatch(reps);
      if (match != null) {
        final secondsPerRep = int.parse(match.group(1)!);
        // 取时间范围的平均值（如 "30-45秒" 取37.5秒）
        final rangeMatch = RegExp(r'(\d+)-(\d+)').firstMatch(reps);
        if (rangeMatch != null) {
          final min = int.parse(rangeMatch.group(1)!);
          final max = int.parse(rangeMatch.group(2)!);
          return ((min + max) / 2 * sets).round();
        }
        return secondsPerRep * sets;
      }
    }

    // 如果 reps 是分钟格式（如 "5分钟"）
    if (reps.contains('分钟')) {
      final match = RegExp(r'(\d+)').firstMatch(reps);
      if (match != null) {
        return int.parse(match.group(1)!) * 60;
      }
    }

    // 否则使用公式：每组时间 × 组数 + 休息时间 × (组数-1)
    return (secondsPerSet * sets) + (restSeconds * (sets - 1));
  }

  /// 获取默认单日训练
  Map<String, dynamic> _getDefaultWorkoutDay({
    required int day,
    required String focus,
    required String equipmentType,
    required String fitnessLevel,
    int? dailyWorkoutMinutes,
  }) {
    // 根据运动基础获取强度配置
    final levelConfig = {
      'beginner': {'setsMultiplier': 0.7, 'repsAdjust': '+2', 'restMultiplier': 1.2},
      'novice': {'setsMultiplier': 0.85, 'repsAdjust': '+1', 'restMultiplier': 1.1},
      'intermediate': {'setsMultiplier': 1.0, 'repsAdjust': '0', 'restMultiplier': 1.0},
      'advanced': {'setsMultiplier': 1.15, 'repsAdjust': '-1', 'restMultiplier': 0.85},
    };
    final level = levelConfig[fitnessLevel] ?? levelConfig['novice']!;
    final setsMultiplier = level['setsMultiplier'] as double;
    final repsAdjust = level['repsAdjust'] as String;
    final restMultiplier = level['restMultiplier'] as double;

    final exercises = <Map<String, dynamic>>[];

    // 计算时间分配（热身12.5% + 拉伸12.5% = 25%，主训练75%）
    final totalMinutes = dailyWorkoutMinutes ?? 30;
    final totalSeconds = totalMinutes * 60;
    final warmupSeconds = (totalMinutes * 0.125).round() * 60; // 12.5%
    final stretchSeconds = (totalMinutes * 0.125).round() * 60; // 12.5%
    final mainTrainingSeconds = totalSeconds - warmupSeconds - stretchSeconds;

    // 热身动作（固定）
    exercises.add({
      'order': 1,
      'name': '关节活动热身',
      'description': '转动肩、髋、膝、踝关节，手臂环绕，高抬腿',
      'sets': 1,
      'reps': '$warmupSeconds秒',
      'restSeconds': 0,
      'estimatedSeconds': warmupSeconds,
      'equipment': '无',
      'difficulty': 'easy',
      'exerciseType': 'warm_up',
    });

    // 获取可用的主训练动作模板
    final exerciseTemplates = _getExerciseTemplatesForFocus(focus, equipmentType);

    // 如果是休息日或没有动作模板，返回休息日数据
    if (focus.contains('休息') || exerciseTemplates.isEmpty) {
      return {
        'day': day,
        'dayName': '第${day}天 - 休息日',
        'trainingFocus': '休息',
        'estimatedMinutes': 0,
        'exercises': [],
        'isRestDay': true,
      };
    }

    // 添加动作，使用实际计算的时间，循环复用动作模板直到接近目标时间
    int currentMainTime = 0;
    int exerciseIndex = 0;

    while (currentMainTime < mainTrainingSeconds * 0.95) {
      // 循环使用动作模板
      final template = exerciseTemplates[exerciseIndex % exerciseTemplates.length];

      // 根据运动基础调整动作参数
      final adjustedSets = ((template['sets'] as int) * setsMultiplier).round().clamp(1, 6);
      final adjustedRestSeconds = ((template['restSeconds'] as int) * restMultiplier).round().clamp(30, 180);

      // 调整次数 (reps是字符串格式，如 "10-15" 或 "12-15")
      String adjustedReps = template['reps'] as String;
      if (adjustedReps.contains('-')) {
        final parts = adjustedReps.split('-');
        if (parts.length == 2) {
          final min = int.tryParse(parts[0]) ?? 10;
          final max = int.tryParse(parts[1]) ?? 15;
          if (repsAdjust != '0') {
            final newMin = (min + int.parse(repsAdjust)).clamp(5, 20);
            final newMax = (max + int.parse(repsAdjust)).clamp(8, 25);
            adjustedReps = '$newMin-$newMax';
          }
        }
      }

      // 计算这个动作的实际时间（使用调整后的参数）
      final exerciseTime = _calculateExerciseSeconds(
        sets: adjustedSets,
        reps: adjustedReps,
        restSeconds: adjustedRestSeconds,
        difficulty: template['difficulty'] as String,
      );

      // 检查添加这个动作后是否超过目标时间
      if (currentMainTime + exerciseTime > mainTrainingSeconds * 1.05) {
        // 如果超过太多，停止添加
        break;
      }

      // 计算这是第几次做这个动作（用于显示组数调整）
      final roundNumber = (exerciseIndex / exerciseTemplates.length).floor() + 1;

      exercises.add({
        'order': exercises.length + 1,
        'name': template['name'],
        'description': template['description'],
        'sets': adjustedSets,
        'reps': adjustedReps,
        'restSeconds': adjustedRestSeconds,
        'estimatedSeconds': exerciseTime, // 使用实际计算的时间
        'equipment': template['equipment'],
        'difficulty': template['difficulty'],
        'exerciseType': 'main',
        'round': roundNumber, // 记录第几轮
      });

      currentMainTime += exerciseTime;
      exerciseIndex++;

      // 安全限制：最多添加30个动作
      if (exerciseIndex >= 30) {
        break;
      }
    }

    // 拉伸动作（固定）
    exercises.add({
      'order': exercises.length + 1,
      'name': '全身拉伸',
      'description': '放松各部位肌肉，每组动作保持15-30秒',
      'sets': 1,
      'reps': '$stretchSeconds秒',
      'restSeconds': 0,
      'estimatedSeconds': stretchSeconds,
      'equipment': '无',
      'difficulty': 'easy',
      'exerciseType': 'stretch',
    });

    return {
      'day': day,
      'dayName': '第${day}天 - $focus',
      'trainingFocus': focus.replaceAll('训练', '').trim(),
      'estimatedMinutes': totalMinutes,
      'exercises': exercises,
    };
  }

  /// 获取特定训练重点的动作模板（根据器械类型）
  List<Map<String, dynamic>> _getExerciseTemplatesForFocus(String focus, String equipmentType) {
    final allExercises = <Map<String, dynamic>>[];

    // 胸背训练动作
    if (focus.contains('胸背') || focus.contains('全身') || focus.contains('上肢') || focus.contains('力量') || focus.contains('塑形')) {
      switch (equipmentType) {
        case 'none':
          // 无器械 - 自重训练为主
          allExercises.addAll([
            {'name': '俯卧撑', 'description': '双手略宽于肩，身体保持一条直线', 'sets': 3, 'reps': '10-15', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '俯卧划船', 'description': '趴在地上，双手拉起重物或使用水瓶', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '水瓶', 'difficulty': 'easy'},
            {'name': '平板支撑', 'description': '用前臂和脚尖支撑身体，保持身体平直', 'sets': 3, 'reps': '30秒', 'restSeconds': 45, 'equipment': '无', 'difficulty': 'medium'},
          ]);
          break;
        case 'home_minimal':
          // 家用小器械 - 哑铃+弹力带
          allExercises.addAll([
            {'name': '哑铃卧推', 'description': '躺于凳上，推举哑铃，感受胸肌收缩', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '哑铃划船', 'description': '单手支撑，另一手拉举哑铃', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '弹力带夹胸', 'description': '站立，弹力带固定于身后，双手夹胸', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '弹力带', 'difficulty': 'easy'},
            {'name': '哑铃推举', 'description': '坐姿或站姿推举哑铃', 'sets': 3, 'reps': '10-12', 'restSeconds': 75, 'equipment': '哑铃', 'difficulty': 'medium'},
          ]);
          break;
        case 'home_full':
          // 家庭健身器材 - +健身椅+壶铃
          allExercises.addAll([
            {'name': '上斜哑铃卧推', 'description': '健身椅调整至30度角，上斜推举哑铃', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '健身椅+哑铃', 'difficulty': 'medium'},
            {'name': '哑铃飞鸟', 'description': '健身椅上躺卧，哑铃弧线下放', 'sets': 3, 'reps': '12-15', 'restSeconds': 75, 'equipment': '健身椅+哑铃', 'difficulty': 'medium'},
            {'name': '壶铃摆动', 'description': '双脚开立，摆动壶铃至髋部高度', 'sets': 3, 'reps': '15-20', 'restSeconds': 90, 'equipment': '壶铃', 'difficulty': 'hard'},
            {'name': '哑铃划船', 'description': '健身椅支撑，单手拉举哑铃', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '健身椅+哑铃', 'difficulty': 'medium'},
          ]);
          break;
        case 'gym_full':
          // 健身房全套器械 - 杠铃+史密斯机+器械
          allExercises.addAll([
            {'name': '杠铃卧推', 'description': '杠铃卧推，感受胸肌发力', 'sets': 4, 'reps': '8-12', 'restSeconds': 120, 'equipment': '杠铃+卧推架', 'difficulty': 'hard'},
            {'name': '哑铃卧推', 'description': '哑铃卧推，弥补杠铃活动范围限制', 'sets': 3, 'reps': '10-12', 'restSeconds': 90, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '高位下拉', 'description': '高位下拉器械，锻炼背阔肌', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '高位下拉机', 'difficulty': 'medium'},
            {'name': '坐姿划船', 'description': '坐姿划船器械，感受背部收缩', 'sets': 3, 'reps': '12-15', 'restSeconds': 75, 'equipment': '坐姿划船机', 'difficulty': 'easy'},
            {'name': '绳索面拉', 'description': '绳索面拉，强化后肩和上背', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '绳索', 'difficulty': 'easy'},
          ]);
          break;
      }
    }

    // 肩臂训练动作
    if (focus.contains('肩臂') || focus.contains('全身') || focus.contains('上肢') || focus.contains('力量') || focus.contains('塑形')) {
      switch (equipmentType) {
        case 'none':
          allExercises.addAll([
            {'name': '臂屈伸', 'description': '双手撑在椅子边缘，身体下沉后推起', 'sets': 3, 'reps': '10-15', 'restSeconds': 60, 'equipment': '椅子', 'difficulty': 'easy'},
            {'name': '水瓶弯举', 'description': '手持水瓶弯举，刺激二头肌', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '水瓶', 'difficulty': 'easy'},
            {'name': '俯卧撑变式', 'description': '窄距俯卧撑，刺激三头肌', 'sets': 3, 'reps': '8-12', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'medium'},
          ]);
          break;
        case 'home_minimal':
          allExercises.addAll([
            {'name': '臂屈伸', 'description': '双手撑在椅子边缘，身体下沉后推起', 'sets': 3, 'reps': '10-15', 'restSeconds': 60, 'equipment': '椅子', 'difficulty': 'easy'},
            {'name': '哑铃弯举', 'description': '弯举动作，刺激二头肌', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '哑铃', 'difficulty': 'easy'},
            {'name': '哑铃侧平举', 'description': '侧平举哑铃至肩高', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '哑铃', 'difficulty': 'easy'},
            {'name': '弹力带面拉', 'description': '弹力带面拉，强化后肩', 'sets': 3, 'reps': '15-20', 'restSeconds': 45, 'equipment': '弹力带', 'difficulty': 'easy'},
          ]);
          break;
        case 'home_full':
          allExercises.addAll([
            {'name': '哑铃推举', 'description': '坐姿或站姿推举哑铃', 'sets': 4, 'reps': '10-12', 'restSeconds': 90, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '上斜侧平举', 'description': '健身椅上斜位侧平举', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '健身椅+哑铃', 'difficulty': 'medium'},
            {'name': '壶铃推举', 'description': '壶铃推举，核心稳定训练', 'sets': 3, 'reps': '8-10', 'restSeconds': 90, 'equipment': '壶铃', 'difficulty': 'hard'},
            {'name': '弹力带面拉', 'description': '弹力带面拉，强化后肩', 'sets': 3, 'reps': '15-20', 'restSeconds': 45, 'equipment': '弹力带', 'difficulty': 'easy'},
          ]);
          break;
        case 'gym_full':
          allExercises.addAll([
            {'name': '杠铃推举', 'description': '站姿杠铃推举，核心收紧', 'sets': 4, 'reps': '8-10', 'restSeconds': 120, 'equipment': '杠铃', 'difficulty': 'hard'},
            {'name': '哑铃侧平举', 'description': '侧平举哑铃至肩高', 'sets': 4, 'reps': '12-15', 'restSeconds': 60, 'equipment': '哑铃', 'difficulty': 'easy'},
            {'name': '绳索弯举', 'description': '绳索弯举，持续张力', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '绳索', 'difficulty': 'easy'},
            {'name': '双杠臂屈伸', 'description': '双杠支撑臂屈伸', 'sets': 3, 'reps': '8-12', 'restSeconds': 90, 'equipment': '双杠', 'difficulty': 'hard'},
          ]);
          break;
      }
    }

    // 腿部训练动作
    if (focus.contains('腿部') || focus.contains('全身') || focus.contains('臀腿') || focus.contains('塑形') || focus.contains('力量')) {
      switch (equipmentType) {
        case 'none':
          allExercises.addAll([
            {'name': '深蹲', 'description': '双脚与肩同宽，下蹲至大腿与地面平行', 'sets': 3, 'reps': '15-20', 'restSeconds': 90, 'equipment': '无', 'difficulty': 'easy'},
            {'name': '箭步蹲', 'description': '交替向前跨步下蹲，保持身体稳定', 'sets': 3, 'reps': '每侧10-15次', 'restSeconds': 75, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '臀桥', 'description': '仰卧，双脚踩地，抬起臀部至身体成一直线', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'easy'},
            {'name': '提踵', 'description': '踮起脚尖再放下，锻炼小腿肌肉', 'sets': 3, 'reps': '20-25', 'restSeconds': 45, 'equipment': '无', 'difficulty': 'easy'},
          ]);
          break;
        case 'home_minimal':
          allExercises.addAll([
            {'name': '哑铃深蹲', 'description': '双手持哑铃进行深蹲', 'sets': 4, 'reps': '12-15', 'restSeconds': 90, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '箭步蹲', 'description': '手持哑铃交替向前跨步下蹲', 'sets': 3, 'reps': '每侧10-12次', 'restSeconds': 75, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '臀桥', 'description': '哑铃置于髋部进行臀桥', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '弹力带深蹲', 'description': '弹力带绕膝进行深蹲', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '弹力带', 'difficulty': 'easy'},
          ]);
          break;
        case 'home_full':
          allExercises.addAll([
            {'name': '保加利亚分腿蹲', 'description': '后脚置于健身椅上进行分腿蹲', 'sets': 3, 'reps': '每侧10-12次', 'restSeconds': 90, 'equipment': '健身椅+哑铃', 'difficulty': 'hard'},
            {'name': '壶铃深蹲', 'description': '双手持壶铃进行深蹲', 'sets': 4, 'reps': '12-15', 'restSeconds': 90, 'equipment': '壶铃', 'difficulty': 'medium'},
            {'name': '壶铃摆动', 'description': '双脚开立，摆动壶铃至髋部高度', 'sets': 3, 'reps': '15-20', 'restSeconds': 90, 'equipment': '壶铃', 'difficulty': 'hard'},
            {'name': '负重臀桥', 'description': '健身椅上负重进行臀桥', 'sets': 3, 'reps': '12-15', 'restSeconds': 75, 'equipment': '健身椅+壶铃', 'difficulty': 'medium'},
          ]);
          break;
        case 'gym_full':
          allExercises.addAll([
            {'name': '杠铃深蹲', 'description': '杠铃深蹲，核心收紧，下蹲至大腿平行', 'sets': 4, 'reps': '8-10', 'restSeconds': 150, 'equipment': '杠铃+深蹲架', 'difficulty': 'hard'},
            {'name': '腿举', 'description': '腿举器械，大重量训练', 'sets': 4, 'reps': '10-12', 'restSeconds': 120, 'equipment': '腿举机', 'difficulty': 'medium'},
            {'name': '腿弯举', 'description': '俯卧腿弯举器械', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '腿弯举机', 'difficulty': 'easy'},
            {'name': '腿屈伸', 'description': '坐姿腿屈伸器械', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '腿屈伸机', 'difficulty': 'easy'},
            {'name': '硬拉', 'description': '杠铃硬拉，后链训练', 'sets': 3, 'reps': '6-8', 'restSeconds': 180, 'equipment': '杠铃', 'difficulty': 'hard'},
          ]);
          break;
      }
    }

    // 核心训练动作
    if (focus.contains('核心') || focus.contains('全身') || focus.contains('循环') || focus.contains('塑形')) {
      switch (equipmentType) {
        case 'none':
          allExercises.addAll([
            {'name': '平板支撑', 'description': '用前臂和脚尖支撑身体，保持身体平直', 'sets': 3, 'reps': '30-45秒', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '卷腹', 'description': '仰卧，双手扶耳，用腹部力量卷起上半身', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'easy'},
            {'name': '俄罗斯转体', 'description': '坐姿，双手握拳左右转动身体', 'sets': 3, 'reps': '20次', 'restSeconds': 45, 'equipment': '无', 'difficulty': 'easy'},
            {'name': '死虫', 'description': '仰卧，对侧手脚伸展', 'sets': 3, 'reps': '每侧10次', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'easy'},
          ]);
          break;
        case 'home_minimal':
          allExercises.addAll([
            {'name': '平板支撑', 'description': '用前臂和脚尖支撑身体，保持身体平直', 'sets': 3, 'reps': '45-60秒', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '哑铃卷腹', 'description': '手持哑铃进行卷腹', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '哑铃', 'difficulty': 'medium'},
            {'name': '俄罗斯转体', 'description': '坐姿，手持哑铃左右转动身体', 'sets': 3, 'reps': '每侧15次', 'restSeconds': 45, 'equipment': '哑铃', 'difficulty': 'easy'},
            {'name': '死虫', 'description': '仰卧，对侧手脚伸展', 'sets': 3, 'reps': '每侧10次', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'easy'},
          ]);
          break;
        case 'home_full':
          allExercises.addAll([
            {'name': '健身椅卷腹', 'description': '健身椅上斜位进行卷腹', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '健身椅', 'difficulty': 'medium'},
            {'name': '壶铃风车', 'description': '壶铃风车，核心稳定训练', 'sets': 3, 'reps': '每侧8-10次', 'restSeconds': 75, 'equipment': '壶铃', 'difficulty': 'hard'},
            {'name': '俄罗斯转体', 'description': '坐姿，手持壶铃左右转动身体', 'sets': 3, 'reps': '每侧15次', 'restSeconds': 45, 'equipment': '壶铃', 'difficulty': 'medium'},
            {'name': '负重平板支撑', 'description': '背部负重进行平板支撑', 'sets': 3, 'reps': '30-45秒', 'restSeconds': 75, 'equipment': '壶铃', 'difficulty': 'hard'},
          ]);
          break;
        case 'gym_full':
          allExercises.addAll([
            {'name': '器械卷腹', 'description': '卷腹器械，专注腹肌训练', 'sets': 3, 'reps': '15-20', 'restSeconds': 60, 'equipment': '卷腹机', 'difficulty': 'medium'},
            {'name': '悬垂举腿', 'description': '悬挂在单杠上进行举腿', 'sets': 3, 'reps': '10-15', 'restSeconds': 90, 'equipment': '单杠', 'difficulty': 'hard'},
            {'name': '绳索卷腹', 'description': '跪姿绳索卷腹', 'sets': 3, 'reps': '12-15', 'restSeconds': 60, 'equipment': '绳索', 'difficulty': 'medium'},
            {'name': '平板支撑', 'description': '用前臂和脚尖支撑身体，保持身体平直', 'sets': 3, 'reps': '60秒', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'medium'},
          ]);
          break;
      }
    }

    // 有氧燃脂动作
    if (focus.contains('燃脂') || focus.contains('恢复') || focus.contains('HIIT') || focus.contains('有氧') || focus.contains('间歇') || focus.contains('耐力') || focus.contains('拉伸') || focus.contains('敏捷')) {
      switch (equipmentType) {
        case 'none':
        case 'home_minimal':
        case 'home_full':
          allExercises.addAll([
            {'name': '开合跳', 'description': '双脚开合跳跃，同时双手在头顶击掌', 'sets': 1, 'reps': '3-5分钟', 'restSeconds': 0, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '高抬腿', 'description': '原地快速抬腿，膝盖尽量抬高', 'sets': 1, 'reps': '3-5分钟', 'restSeconds': 0, 'equipment': '无', 'difficulty': 'medium'},
            {'name': '波比跳', 'description': '俯卧撑起跳，全身燃脂动作', 'sets': 3, 'reps': '10-15', 'restSeconds': 60, 'equipment': '无', 'difficulty': 'hard'},
          ]);
          break;
        case 'gym_full':
          allExercises.addAll([
            {'name': '跑步机', 'description': '跑步机有氧训练', 'sets': 1, 'reps': '20-30分钟', 'restSeconds': 0, 'equipment': '跑步机', 'difficulty': 'easy'},
            {'name': '椭圆机', 'description': '椭圆机全身有氧', 'sets': 1, 'reps': '20-30分钟', 'restSeconds': 0, 'equipment': '椭圆机', 'difficulty': 'easy'},
            {'name': '划船机', 'description': '划船机全身燃脂', 'sets': 1, 'reps': '15-20分钟', 'restSeconds': 0, 'equipment': '划船机', 'difficulty': 'medium'},
          ]);
          break;
      }
    }

    return allExercises;
  }

  /// 获取默认饮食计划
  Map<String, dynamic> _getDefaultDietPlan({
    required String goalType,
    required int durationDays,
    required double weight,
    required String gender,
    double? targetWeight,
  }) {
    // 计算每日热量需求
    final baseCalories = gender == 'male' ? 1800 : 1500;
    double dailyCalories = baseCalories.toDouble();

    switch (goalType) {
      case 'fat_loss':
        dailyCalories -= 300;
        break;
      case 'muscle_gain':
        dailyCalories += 300;
        break;
      case 'shape':
      case 'fitness':
      case 'maintain':
      default:
        break;
    }

    // 根据目标体重计算额外热量调整
    if (targetWeight != null && targetWeight != weight) {
      final weightDiffKg = targetWeight - weight;
      // 每1kg体重差异约需7700卡热量
      final totalCalorieAdjustment = weightDiffKg * 7700;
      final dailyAdjustment = totalCalorieAdjustment / durationDays;

      // 安全限制：每日体重变化不宜超过0.5kg（约385卡热量调整）
      const maxDailyCalorieAdjustment = 385.0;
      final safeAdjustment = dailyAdjustment.clamp(-maxDailyCalorieAdjustment, maxDailyCalorieAdjustment);

      dailyCalories += safeAdjustment;
    }

    // 安全限制：确保每日热量不低于最低标准
    final minCalories = gender == 'male' ? 1500 : 1200;
    final maxCalories = gender == 'male' ? 3000 : 2500;
    dailyCalories = dailyCalories.clamp(minCalories, maxCalories).toDouble();

    // 统一的营养素比例配置（按热量百分比）
    // 蛋白质: 30%, 碳水: 45%, 脂肪: 25%
    const proteinRatio = 0.30;
    const carbsRatio = 0.45;
    const fatRatio = 0.25;

    // 按统一比例计算每日营养素
    final dailyProtein = (dailyCalories * proteinRatio / 4).round();
    final dailyCarbs = (dailyCalories * carbsRatio / 4).round();
    final dailyFat = (dailyCalories * fatRatio / 9).round();

    // 根据目标类型定义饮食计划名称
    final dietPlanNames = {
      'fat_loss': '燃脂塑形饮食计划',
      'muscle_gain': '增肌强体饮食计划',
      'shape': '体态优化饮食计划',
      'maintain': '健康保持饮食计划',
      'fitness': '体能提升饮食计划',
    };

    final dietDescriptions = {
      'fat_loss': '控制热量摄入，高蛋白低脂肪，配合训练高效燃脂',
      'muscle_gain': '增加热量摄入，高蛋白支持肌肉生长',
      'shape': '均衡营养，改善体态，优化身体线条',
      'maintain': '均衡营养，保持健康体魄和活力',
      'fitness': '科学配比营养，支持体能训练和恢复',
    };

    final planName = dietPlanNames[goalType] ?? '均衡饮食计划';
    final description = dietDescriptions[goalType] ?? '科学均衡的饮食方案，帮助您达成健身目标';

    final List<Map<String, dynamic>> days = [];
    for (int day = 1; day <= durationDays; day++) {
      days.add({
        'day': day,
        'meals': [
          _getDefaultBreakfast(dailyCalories * 0.3),
          _getDefaultLunch(dailyCalories * 0.4),
          _getDefaultDinner(dailyCalories * 0.3),
        ],
      });
    }

    return {
      'planName': planName,
      'description': description,
      'dailyCalories': dailyCalories.round(),
      'dailyProtein': dailyProtein.round(),
      'dailyCarbs': dailyCarbs.round(),
      'dailyFat': dailyFat.round(),
      'days': days,
    };
  }

  Map<String, dynamic> _getDefaultBreakfast(double calories) {
    // 使用统一的营养素比例：蛋白质30%, 碳水45%, 脂肪25%
    return {
      'mealType': 'breakfast',
      'mealName': '营养早餐',
      'eatingTime': '07:30',
      'calories': calories,
      'protein': calories * 0.30 / 4,
      'carbs': calories * 0.45 / 4,
      'fat': calories * 0.25 / 9,
      'items': [
        {
          'order': 1,
          'foodName': '燕麦片',
          'amount': '50g',
          'weightGrams': 50,
          'calories': calories * 0.4,
          'protein': 6,
          'carbs': 30,
          'fat': 3,
          'cookingMethod': '用热水或热牛奶冲泡',
        },
        {
          'order': 2,
          'foodName': '鸡蛋',
          'amount': '2个',
          'weightGrams': 100,
          'calories': calories * 0.3,
          'protein': 12,
          'carbs': 1,
          'fat': 10,
          'cookingMethod': '水煮或煎制',
        },
        {
          'order': 3,
          'foodName': '牛奶/豆浆',
          'amount': '250ml',
          'weightGrams': 250,
          'calories': calories * 0.3,
          'protein': 8,
          'carbs': 10,
          'fat': 5,
          'cookingMethod': '直接饮用',
        },
      ],
    };
  }

  Map<String, dynamic> _getDefaultLunch(double calories) {
    // 使用统一的营养素比例：蛋白质30%, 碳水45%, 脂肪25%
    return {
      'mealType': 'lunch',
      'mealName': '均衡午餐',
      'eatingTime': '12:00',
      'calories': calories,
      'protein': calories * 0.30 / 4,
      'carbs': calories * 0.45 / 4,
      'fat': calories * 0.25 / 9,
      'items': [
        {
          'order': 1,
          'foodName': '米饭',
          'amount': '150g',
          'weightGrams': 150,
          'calories': calories * 0.28,
          'protein': 4,
          'carbs': 40,
          'fat': 0.5,
          'cookingMethod': '蒸煮',
        },
        {
          'order': 2,
          'foodName': '鸡胸肉/瘦牛肉',
          'amount': '150g',
          'weightGrams': 150,
          'calories': calories * 0.25,
          'protein': 31,
          'carbs': 0,
          'fat': 4,
          'cookingMethod': '煎炒或水煮',
        },
        {
          'order': 3,
          'foodName': '西兰花/青菜',
          'amount': '200g',
          'weightGrams': 200,
          'calories': calories * 0.1,
          'protein': 4,
          'carbs': 10,
          'fat': 1,
          'cookingMethod': '焯水后凉拌',
        },
      ],
    };
  }

  Map<String, dynamic> _getDefaultDinner(double calories) {
    // 使用统一的营养素比例：蛋白质30%, 碳水45%, 脂肪25%
    return {
      'mealType': 'dinner',
      'mealName': '轻食晚餐',
      'eatingTime': '18:30',
      'calories': calories,
      'protein': calories * 0.30 / 4,
      'carbs': calories * 0.45 / 4,
      'fat': calories * 0.25 / 9,
      'items': [
        {
          'order': 1,
          'foodName': '红薯/紫薯',
          'amount': '150g',
          'weightGrams': 150,
          'calories': calories * 0.26,
          'protein': 2,
          'carbs': 30,
          'fat': 0.2,
          'cookingMethod': '蒸煮',
        },
        {
          'order': 2,
          'foodName': '蒸鱼/虾仁',
          'amount': '150g',
          'weightGrams': 150,
          'calories': calories * 0.36,
          'protein': 25,
          'carbs': 0,
          'fat': 5,
          'cookingMethod': '清蒸',
        },
        {
          'order': 3,
          'foodName': '青菜/菌菇',
          'amount': '200g',
          'weightGrams': 200,
          'calories': calories * 0.1,
          'protein': 3,
          'carbs': 10,
          'fat': 1,
          'cookingMethod': '清炒',
        },
      ],
    };
  }

  /// 获取默认替换动作
  Map<String, dynamic> _getDefaultReplacementExercise({
    required String exerciseType,
    required String targetMuscle,
    required String equipmentType,
    required String reason,
  }) {
    final Map<String, Map<String, dynamic>> replacements = {
      'warm_up': {
        'chest': {
          'none': {
            'name': '原地慢跑',
            'description': '原地慢跑，活动关节和心肺',
            'sets': 1,
            'reps': '3分钟',
            'restSeconds': 0,
            'equipment': '无',
            'difficulty': 'easy',
            'exerciseType': 'warm_up',
          },
        },
      },
      'main': {
        'chest': {
          'none': {
            'name': '俯卧撑（跪姿）',
            'description': '膝盖着地，做俯卧撑动作，难度较低',
            'sets': 3,
            'reps': '10-12',
            'restSeconds': 60,
            'equipment': '无',
            'difficulty': 'easy',
            'exerciseType': 'main',
          },
        },
        'back': {
          'none': {
            'name': '地面划船',
            'description': '俯卧，双手拉起重物，感受背部发力',
            'sets': 3,
            'reps': '12-15',
            'restSeconds': 60,
            'equipment': '水瓶',
            'difficulty': 'easy',
            'exerciseType': 'main',
          },
        },
        'leg': {
          'none': {
            'name': '墙壁深蹲',
            'description': '背靠墙壁做深蹲，保持正确姿势',
            'sets': 3,
            'reps': '15',
            'restSeconds': 60,
            'equipment': '无',
            'difficulty': 'easy',
            'exerciseType': 'main',
          },
        },
      },
      'stretch': {
        'all': {
          'none': {
            'name': '全身拉伸',
            'description': '从头到脚依次拉伸各部位',
            'sets': 1,
            'reps': '5分钟',
            'restSeconds': 0,
            'equipment': '无',
            'difficulty': 'easy',
            'exerciseType': 'stretch',
          },
        },
      },
    };

    return replacements[exerciseType]?[targetMuscle.toLowerCase()]?['none'] ??
        replacements['main']?['leg']?['none']!;
  }

  /// 获取默认替换食材
  Map<String, dynamic> _getDefaultReplacementFood({
    required String mealType,
    double? targetCalories,
    required String currentFoodName,
  }) {
    final Map<String, Map<String, dynamic>> replacements = {
      'breakfast': {
        '燕麦片': {
          'foodName': '全麦面包',
          'amount': '2片',
          'weightGrams': 60,
          'calories': 150,
          'protein': 5,
          'carbs': 30,
          'fat': 2,
          'cookingMethod': '直接食用或烤制',
        },
        '鸡蛋': {
          'foodName': '豆腐',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 120,
          'protein': 10,
          'carbs': 5,
          'fat': 8,
          'cookingMethod': '煎制或凉拌',
        },
      },
      'lunch': {
        '米饭': {
          'foodName': '糙米饭',
          'amount': '150g',
          'weightGrams': 150,
          'calories': 170,
          'protein': 3,
          'carbs': 36,
          'fat': 1,
          'cookingMethod': '蒸煮',
        },
        '鸡胸肉': {
          'foodName': '瘦牛肉',
          'amount': '120g',
          'weightGrams': 120,
          'calories': 180,
          'protein': 28,
          'carbs': 0,
          'fat': 8,
          'cookingMethod': '炒制',
        },
      },
      'dinner': {
        '米饭': {
          'foodName': '玉米',
          'amount': '1根',
          'weightGrams': 200,
          'calories': 180,
          'protein': 4,
          'carbs': 40,
          'fat': 2,
          'cookingMethod': '蒸煮',
        },
        '鱼肉': {
          'foodName': '虾仁',
          'amount': '120g',
          'weightGrams': 120,
          'calories': 110,
          'protein': 24,
          'carbs': 0,
          'fat': 2,
          'cookingMethod': '炒制',
        },
      },
    };

    return replacements[mealType]?[currentFoodName] ?? {
      'foodName': '豆腐',
      'amount': '150g',
      'weightGrams': 150,
      'calories': 120,
      'protein': 10,
      'carbs': 5,
      'fat': 8,
      'cookingMethod': '煎制或凉拌',
    };
  }

  /// ==================== 提示词构建方法 ====================

  /// 构建运动计划生成提示词
  String _buildWorkoutPlanPrompt({
    required String goal,
    required int durationDays,
    required String currentLevel,
    required int availableDays,
    required int availableTime,
  }) {
    return '''请帮我制定一个为期 $durationDays 天的运动计划。

**用户目标**：$goal

**当前水平**：$currentLevel

**时间安排**：每周可运动 $availableDays 天，每次约 $availableTime 分钟

请生成一个结构化的运动计划，格式如下：

=== {目标名称} ====

**阶段划分**：
- 第1-2周：[阶段目标]
- 第3-X周：[阶段目标]
...

**每周安排**：
第1周：
- 周一：[运动类型] - [具体内容]
- 周三：[运动类型] - [具体内容]
- 周五：[运动类型] - [具体内容]
...

**注意事项**：
- [注意事项1]
- [注意事项2]

**预期效果**：
- [预期达成效果]

请用简洁、激励的语气生成计划。''';
  }

  /// 构建运动小结生成提示词
  String _buildWorkoutSummaryPrompt({
    required String workoutType,
    required int durationMinutes,
    String? notes,
    String? feeling,
    int? sets,
    int? reps,
    double? weight,
  }) {
    final details = StringBuffer();
    details.writeln('运动类型：$workoutType');
    details.writeln('运动时长：$durationMinutes 分钟');

    if (sets != null && sets > 0) {
      details.writeln('组数：$sets 组');
    }
    if (reps != null && reps > 0) {
      details.writeln('次数：$reps 次');
    }
    if (weight != null && weight > 0) {
      details.writeln('重量：$weight kg');
    }
    if (feeling != null && feeling!.isNotEmpty) {
      final feelingMap = {
        'great': '很棒',
        'good': '不错',
        'normal': '适中',
        'tired': '疲惫',
        'exhausted': '力竭',
      };
      details.writeln('运动感受：${feelingMap[feeling] ?? feeling}');
    }
    if (notes != null && notes!.isNotEmpty) {
      details.writeln('备注：$notes');
    }

    return '''请根据以下运动数据生成一篇简短的运动小结（用于笔记）：

运动数据：
$details

请生成一篇简洁的运动小结，格式如下：

=== 运动小结 ====

**运动概况**：[一句话总结今天的运动]

**数据记录**：
- 运动类型：$workoutType
- 运动时长：$durationMinutes 分钟
${sets != null && sets! > 0 ? '- 训练量：$sets 组' : ''}

**小结**：[2-3句话总结今天的训练效果和感受]

**下次建议**：[1-2句话下次训练的建议]

请用鼓励、积极的语气，字数控制在200字以内。''';
  }

  /// 构建AI教练训练计划提示词
  String _buildCoachWorkoutPlanPrompt({
    required String goalType,
    required int durationDays,
    required String gender,
    required int age,
    required double height,
    required double weight,
    required String fitnessLevel,
    required String equipmentType,
    String? dietType,
    List<String>? dietaryRestrictions,
    List<String>? injuries,
    int? dailyWorkoutMinutes,
    List<String>? preferredWorkouts,
    List<String>? dislikedWorkouts,
  }) {
    // 目标特定配置 - 充分发挥AI的关键
    final goalConfig = {
      'fat_loss': {
        'name': '减脂',
        'focus': ['燃脂有氧', '全身循环', 'HIIT', '核心强化'],
        'focusRatio': '40%有氧 + 40%力量 + 20%核心',
        'intensity': '中高强度，短休息间歇',
        'restAdvice': '组间休息30-60秒，保持心率 elevated',
        'weeklyPattern': ['有氧燃脂', '上肢力量', '下肢力量', 'HIIT', '全身循环', '主动恢复', '休息'],
      },
      'muscle_gain': {
        'name': '增肌',
        'focus': ['复合动作', '渐进超负荷', '分化训练'],
        'focusRatio': '80%力量 + 10%有氧 + 10%核心',
        'intensity': '高负荷，充分休息',
        'restAdvice': '大肌群90-120秒，小肌群60-90秒',
        'weeklyPattern': ['胸+三头', '背+二头', '休息', '腿+肩', '核心', '辅助肌群', '休息'],
      },
      'shape': {
        'name': '塑形',
        'focus': ['线条雕刻', '臀部塑形', '核心稳定'],
        'focusRatio': '50%力量 + 30%有氧 + 20%拉伸',
        'intensity': '中等强度，控制动作质量',
        'restAdvice': '组间休息45-75秒，注重动作标准',
        'weeklyPattern': ['臀腿', '上肢塑形', '有氧拉伸', '核心+臀部', '全身循环', '瑜伽拉伸', '休息'],
      },
      'maintain': {
        'name': '维持',
        'focus': ['全身均衡', '适度有氧', '灵活性'],
        'focusRatio': '50%力量 + 30%有氧 + 20%灵活',
        'intensity': '中等强度，保持习惯',
        'restAdvice': '组间休息60-75秒，舒适节奏',
        'weeklyPattern': ['全身', '有氧', '上肢', '下肢', 'HIIT', '户外活动', '休息'],
      },
      'fitness': {
        'name': '体能提升',
        'focus': ['耐力', '爆发力', '敏捷性', '心肺功能'],
        'focusRatio': '40%力量 + 40%有氧 + 20%功能性',
        'intensity': '变化强度，挑战极限',
        'restAdvice': '根据训练类型调整，有氧短歇，力量长歇',
        'weeklyPattern': ['耐力训练', '力量爆发', '有氧间歇', '敏捷训练', '长距离有氧', '功能性', '休息'],
      },
    };

    final goal = goalConfig[goalType] ?? goalConfig['maintain']!;
    final goalPatternList = goal!['weeklyPattern'] as List;
    final goalPattern = goalPatternList.join(' → ');
    final firstFocus = goalPatternList[0] as String;
    final secondFocus = goalPatternList.length > 1 ? goalPatternList[1] as String : firstFocus;
    final goalName = goal['name'] as String;
    final goalFocus = (goal['focus'] as List).join('、');
    final goalRatio = goal['focusRatio'] as String;
    final goalIntensity = goal['intensity'] as String;
    final goalRest = goal['restAdvice'] as String;

    // 运动基础配置 - 影响组数、次数、休息时间
    final levelConfig = {
      'beginner': {'name': '零基础', 'sets': 2, 'reps': '12-15', 'rest': 90, 'description': '新手需要更多时间适应动作和学习姿势', 'difficulties': ['easy', 'easy', 'medium']},
      'novice': {'name': '新手', 'sets': 3, 'reps': '10-12', 'rest': 75, 'description': '有一定基础，可以增加训练量', 'difficulties': ['easy', 'medium', 'medium']},
      'intermediate': {'name': '有基础', 'sets': 3, 'reps': '8-12', 'rest': 60, 'description': '训练经验丰富，追求质量', 'difficulties': ['medium', 'medium', 'hard']},
      'advanced': {'name': '资深', 'sets': 4, 'reps': '6-10', 'rest': 45, 'description': '老手恢复能力强，可缩短休息', 'difficulties': ['medium', 'hard', 'hard']},
    };
    final level = levelConfig[fitnessLevel] ?? levelConfig['novice']!;
    final levelName = level!['name'] as String;
    final levelSets = level['sets'] as int;
    final levelReps = level['reps'] as String;
    final levelRest = level['rest'] as int;
    final levelDesc = level['description'] as String;
    final levelDifficulties = (level['difficulties'] as List).join(' → ');

    // 器械配置 - 影响可选动作
    final equipmentConfig = {
      'none': {
        'name': '无器械（自重训练）',
        'equipment': ['无'],
        'examples': {
          'upper_body': ['俯卧撑', '钻石俯卧撑', '宽距俯卧撑', '倒V俯卧撑', '平板支撑', '侧平板', '臂屈伸(椅子)'],
          'lower_body': ['深蹲', '箭步蹲', '臀桥', '单腿臀桥', '提踵', '深蹲跳', '箭步蹲跳'],
          'core': ['平板支撑', '侧平板', '卷腹', '抬腿', '俄罗斯转体', '登山者', '死虫'],
          'cardio': ['开合跳', '高抬腿', '波比跳', '登山者', '深蹲跳', '前后跳', '快速踏步'],
        },
      },
      'home_minimal': {
        'name': '家用小器械（哑铃、弹力带等）',
        'equipment': ['无', '哑铃', '弹力带', '水瓶', '椅子'],
        'examples': {
          'upper_body': ['俯卧撑', '哑铃卧推', '哑铃飞鸟', '哑铃划船', '哑铃推举', '哑铃侧平举', '弹力带划船', '臂屈伸'],
          'lower_body': ['深蹲', '哑铃深蹲', '箭步蹲', '持铃箭步蹲', '臀桥', '负重臀桥', '提踵', '哑铃硬拉'],
          'core': ['平板支撑', '哑铃卷腹', '俄罗斯转体(持铃)', '侧平板', '死虫', '平板支撑(负重)'],
          'cardio': ['开合跳', '高抬腿', '波比跳', '登山者', '哑铃摆动', '深酌跳'],
        },
      },
      'home_full': {
        'name': '家庭健身器材',
        'equipment': ['无', '哑铃', '弹力带', '水瓶', '椅子', '健身椅', '壶铃'],
        'examples': {
          'upper_body': ['俯卧撑', '哑铃卧推(健身椅)', '上斜哑铃飞鸟', '哑铃划船', '哑铃推举', '壶铃摆动', '壶铃推举'],
          'lower_body': ['深蹲', '哑铃深蹲', '箭步蹲', '保加利亚分腿蹲(椅子)', '臀桥', '壶铃摆动', '壶铃深蹲'],
          'core': ['平板支撑', '健身椅卷腹', '俄罗斯转体', '壶铃风车', '死虫'],
          'cardio': ['开合跳', '高抬腿', '波比跳', '壶铃摆动', '登山者'],
        },
      },
      'gym_full': {
        'name': '健身房全套器械',
        'equipment': ['无', '哑铃', '杠铃', '器械', '绳索', '史密斯机', '壶铃'],
        'examples': {
          'upper_body': ['杠铃卧推', '哑铃卧推', '高位下拉', '坐姿划船', '哑铃推举', '绳索面拉', '杠铃划船', '双杠臂屈伸'],
          'lower_body': ['杠铃深蹲', '腿举', '腿弯举', '腿屈伸', '箭步蹲', '硬拉', '坐姿提踵', '髋内收/外展'],
          'core': ['平板支撑', '卷腹(器械)', '悬垂举腿', '绳索卷腹', '俄罗斯转体'],
          'cardio': ['跑步机', '椭圆机', '划船机', '单车', '跳绳', '波比跳'],
        },
      },
    };
    final equipment = equipmentConfig[equipmentType] ?? equipmentConfig['none']!;
    final equipmentName = equipment!['name'] as String;
    final equipmentList = (equipment['equipment'] as List).join('、');
    final exExamples = equipment['examples'] as Map;

    // 计算时间分配
    final totalMinutes = dailyWorkoutMinutes ?? 60;
    final totalSeconds = totalMinutes * 60;
    final warmupMin = (totalMinutes * 0.12).toInt();
    final warmupMax = (totalMinutes * 0.15).toInt();
    final stretchMin = (totalMinutes * 0.12).toInt();
    final stretchMax = (totalMinutes * 0.15).toInt();
    final warmupSeconds = ((warmupMin + warmupMax) / 2 * 60).toInt();
    final stretchSeconds = ((stretchMin + stretchMax) / 2 * 60).toInt();
    final mainTrainingSeconds = totalSeconds - warmupSeconds - stretchSeconds;

    // 根据训练目标确定合理的动作数量（不是简单用时间除！）
    final exerciseCountRange = switch (goalType) {
      'muscle_gain' => '4-6个',  // 力量训练：少数动作，多组数
      'fat_loss' => '8-12个',     // 燃脂：多个动作，循环训练
      'shape' => '6-10个',        // 塑形：中等数量
      'fitness' => '8-12个',      // 体能：多样性训练
      _ => '6-10个',              // 维持：中等数量
    };

    final buffer = StringBuffer();
    buffer.writeln('# 慧记AI健身教练 - 训练计划生成');
    buffer.writeln();
    buffer.writeln('请根据用户画像生成专业的训练计划JSON。');
    buffer.writeln();
    buffer.writeln('## 📋 用户画像');
    buffer.writeln();
    buffer.writeln('**基本信息**：');
    buffer.writeln('- 性别：${gender == "male" ? "男" : "女"} | 年龄：$age岁 | 身高：${height}cm | 体重：${weight}kg');
    buffer.writeln();
    buffer.writeln('**健身目标**：$goalName');
    buffer.writeln('- 训练重点：$goalFocus');
    buffer.writeln('- 训练比例：$goalRatio');
    buffer.writeln('- 强度建议：$goalIntensity');
    buffer.writeln('- 休息建议：$goalRest');
    buffer.writeln('- 周期模式：$goalPattern');
    buffer.writeln();
    buffer.writeln('**运动基础**：$levelName');
    buffer.writeln('- 推荐组数：$levelSets组');
    buffer.writeln('- 推荐次数：$levelReps次');
    buffer.writeln('- 组间休息：$levelRest秒');
    buffer.writeln('- 说明：$levelDesc');
    buffer.writeln('- 难度递进：$levelDifficulties');
    buffer.writeln();
    buffer.writeln('**器械情况**：$equipmentName');
    buffer.writeln('- 可用器械：$equipmentList');
    buffer.writeln('- 上肢示例：${(exExamples['upper_body'] as List).take(4).join('、')}');
    buffer.writeln('- 下肢示例：${(exExamples['lower_body'] as List).take(4).join('、')}');
    buffer.writeln('- 核心示例：${(exExamples['core'] as List).take(4).join('、')}');
    buffer.writeln('- 有氧示例：${(exExamples['cardio'] as List).take(4).join('、')}');
    buffer.writeln();
    buffer.writeln('**其他信息**：');
    buffer.writeln('- 每日时长：$totalMinutes 分钟');
    if (dietType != null && dietType != 'none') buffer.writeln('- 饮食类型：$dietType');
    if (dietaryRestrictions != null && dietaryRestrictions!.isNotEmpty) buffer.writeln('- 饮食禁忌：${dietaryRestrictions.join('、')}');
    if (injuries != null && injuries!.isNotEmpty) buffer.writeln('- 运动损伤：${injuries.join('、')}（需避开相关部位）');
    if (preferredWorkouts != null && preferredWorkouts!.isNotEmpty) buffer.writeln('- 偏好运动：${preferredWorkouts.join('、')}');
    if (dislikedWorkouts != null && dislikedWorkouts!.isNotEmpty) buffer.writeln('- 避开运动：${dislikedWorkouts.join('、')}');
    buffer.writeln();
    buffer.writeln('## 📐 JSON格式规范');
    buffer.writeln();
    buffer.writeln('```json');
    buffer.writeln('{');
    buffer.writeln('  "planName": "计划名称（包含目标和时长）",');
    buffer.writeln('  "description": "计划的简短描述（1-2句话说明训练重点）",');
    buffer.writeln('  "totalWorkouts": $durationDays,');
    buffer.writeln('  "days": [');
    // 第1天示例
    buffer.writeln('    {');
    buffer.writeln('      "day": 1,');
    buffer.writeln('      "dayName": "第1天 - $firstFocus",');
    buffer.writeln('      "trainingFocus": "${_getFocusEn(firstFocus)}",');
    buffer.writeln('      "estimatedMinutes": $totalMinutes,');
    buffer.writeln('      "exercises": [');
    // 热身
    buffer.writeln('        {');
    buffer.writeln('          "order": 1,');
    buffer.writeln('          "name": "关节活动热身",');
    buffer.writeln('          "description": "转动肩、髋、膝、踝关节各30秒，手臂环绕，高抬腿",');
    buffer.writeln('          "sets": 1,');
    buffer.writeln('          "reps": "$warmupMin-$warmupMax分钟",');
    buffer.writeln('          "restSeconds": 0,');
    buffer.writeln('          "estimatedSeconds": $warmupSeconds,');
    buffer.writeln('          "equipment": "无",');
    buffer.writeln('          "difficulty": "easy",');
    buffer.writeln('          "exerciseType": "warm_up"');
    buffer.writeln('        },');
    // 主训练占位
    buffer.writeln('        {');
    buffer.writeln('          "order": 2,');
    buffer.writeln('          "name": "主训练动作名称",');
    buffer.writeln('          "description": "标准动作描述，包含起始姿势、动作要点、呼吸节奏",');
    buffer.writeln('          "sets": $levelSets,');
    buffer.writeln('          "reps": "$levelReps",');
    buffer.writeln('          "restSeconds": $levelRest,');
    buffer.writeln('          "estimatedSeconds": ${_calcExampleSeconds(levelSets, levelReps, levelRest, 'medium')},');
    buffer.writeln('          "equipment": "选择可用器械",');
    buffer.writeln('          "difficulty": "medium",');
    buffer.writeln('          "exerciseType": "main"');
    buffer.writeln('        },');
    // 拉伸
    buffer.writeln('        {');
    buffer.writeln('          "order": 99,');
    buffer.writeln('          "name": "全身拉伸放松",');
    buffer.writeln('          "description": "拉伸各主要肌群，每个动作保持15-30秒",');
    buffer.writeln('          "sets": 1,');
    buffer.writeln('          "reps": "$stretchMin-$stretchMax分钟",');
    buffer.writeln('          "restSeconds": 0,');
    buffer.writeln('          "estimatedSeconds": $stretchSeconds,');
    buffer.writeln('          "equipment": "无",');
    buffer.writeln('          "difficulty": "easy",');
    buffer.writeln('          "exerciseType": "stretch"');
    buffer.writeln('        }');
    buffer.writeln('      ]');
    buffer.writeln('    },');
    // 第2天示例
    buffer.writeln('    {');
    buffer.writeln('      "day": 2,');
    buffer.writeln('      "dayName": "第2天 - $secondFocus",');
    buffer.writeln('      "trainingFocus": "${_getFocusEn(secondFocus)}",');
    buffer.writeln('      "estimatedMinutes": $totalMinutes,');
    buffer.writeln('      "exercises": [');
    buffer.writeln('        /* 同上结构，根据第2天训练重点选择动作 */');
    buffer.writeln('      ]');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('**示例说明**：以上示例中第1天的estimatedSeconds计算');
    buffer.writeln('- 热身：$warmupSeconds秒');
    buffer.writeln('- 主训练：需要约${mainTrainingSeconds}秒（可根据动作数量分配）');
    buffer.writeln('- 拉伸：$stretchSeconds秒');
    buffer.writeln('- **总计**：${warmupSeconds + mainTrainingSeconds + stretchSeconds}秒 = ${totalMinutes}分钟 ✓');
    buffer.writeln();
    buffer.writeln('**注意**：如果添加N个主训练动作，每个动作的时间约为 ${mainTrainingSeconds ~/ 5}-${mainTrainingSeconds ~/ 3} 秒，确保总和为${mainTrainingSeconds}秒');
    buffer.writeln();
    buffer.writeln('## ⏱️ 时间计算规则（必须严格遵守）');
    buffer.writeln();
    buffer.writeln('**公式**：`estimatedSeconds = 每组秒数 × sets + restSeconds × (sets - 1)`');
    buffer.writeln();
    buffer.writeln('**每组时间估算**：');
    buffer.writeln('- easy（简单动作）：40秒/组');
    buffer.writeln('- medium（标准动作）：50秒/组');
    buffer.writeln('- hard（高难度动作）：60秒/组');
    buffer.writeln('- 时间类（秒）：直接使用秒数，如"30秒" = 30秒，"5分钟" = 300秒');
    buffer.writeln();
    buffer.writeln('**计算示例**（以${levelSets}组、${levelRest}秒休息为例）：');
    final exampleTime = _calcExampleSeconds(levelSets, levelReps, levelRest, 'medium');
    buffer.writeln('- 热身（1组，30秒，休息0秒）：40 × 1 + 0 × 0 = $warmupSeconds秒');
    buffer.writeln('- 主训练动作（${levelSets}组，medium难度，休息${levelRest}秒）：50 × ${levelSets} + ${levelRest} × ${levelSets - 1} = $exampleTime秒');
    buffer.writeln('- 拉伸（1组，${stretchMin}-${stretchMax}分钟，休息0秒）：$stretchSeconds秒');
    buffer.writeln();
    buffer.writeln('**时间分配**（总$totalMinutes分钟 = $totalSeconds秒）：');
    buffer.writeln('- 热身：$warmupMin-$warmupMax 分钟 = $warmupSeconds秒');
    buffer.writeln('- 主训练：约${mainTrainingSeconds ~/ 60}分钟 = $mainTrainingSeconds秒（${mainTrainingSeconds ~/ 60}分${mainTrainingSeconds % 60}秒）');
    buffer.writeln('- 拉伸：$stretchMin-$stretchMax 分钟 = $stretchSeconds秒');
    buffer.writeln('- **总计**：$totalSeconds秒 = $totalMinutes分钟 ✓');
    buffer.writeln();
    buffer.writeln('**⚠️ 核心要求（必须满足）**：');
    buffer.writeln('1. 每天的 `estimatedMinutes` 必须等于 $totalMinutes');
    buffer.writeln('2. 每天所有动作的 `estimatedSeconds` 之和必须等于 $totalSeconds 秒');
    buffer.writeln('3. 主训练所有动作的时间总和必须约为 $mainTrainingSeconds 秒（${mainTrainingSeconds ~/ 60}分钟）');
    buffer.writeln('4. 计算estimatedSeconds时必须严格按照公式，不能估算');
    buffer.writeln();
    buffer.writeln('**⚠️ 动作数量要求**：');
    buffer.writeln('- 主训练动作数量：**$exerciseCountRange**（根据目标类型自动调整）');
    buffer.writeln('- 力量训练目标：4-6个动作，每个动作4-5组，组间休息90-120秒');
    buffer.writeln('- 燃脂训练目标：8-12个动作，每个动作2-3组，组间休息30-60秒，可循环做');
    buffer.writeln('- **关键**：通过**调整组数**来填满时间，不是增加动作数量！');
    buffer.writeln('  - 力量训练：4个动作 × 5组 × 2分钟 = 40分钟');
    buffer.writeln('  - 燃脂训练：8个动作 × 3组循环 × 1.5分钟 = 36分钟');
    buffer.writeln();
    buffer.writeln('## 🎯 动作选择指南');
    buffer.writeln();
    buffer.writeln('**根据器械类型过滤**：只能选择用户可用器械对应的动作');
    buffer.writeln('**根据运动基础调整**：使用对应的组数、次数、休息时间');
    buffer.writeln('**根据目标分配重点**：按照目标特点安排有氧/力量比例');
    buffer.writeln('**难度递进**：同一天内动作难度按 $levelDifficulties 交替');
    buffer.writeln();
    buffer.writeln('## 📝 字段说明');
    buffer.writeln();
    buffer.writeln('| 字段 | 类型 | 说明 | 可选值 |');
    buffer.writeln('|------|------|------|--------|');
    buffer.writeln('| trainingFocus | string | 训练重点 | upper_body, lower_body, core, cardio, full_body, hiit, yoga, rest |');
    buffer.writeln('| exerciseType | string | 动作类型 | warm_up, main, cardio, stretch |');
    buffer.writeln('| difficulty | string | 动作难度 | easy, medium, hard |');
    buffer.writeln('| equipment | string | 所需器械 | 从用户可用器械中选择 |');
    buffer.writeln('| restSeconds | int | 组间休息 | 根据运动基础配置，热身/拉伸为0 |');
    buffer.writeln();
    buffer.writeln('## ✅ 完成要求');
    buffer.writeln();
    buffer.writeln('1. **严格JSON格式**：只返回JSON，无任何额外文字');
    buffer.writeln('2. **时间准确**：每天estimatedSeconds总和必须 = $totalSeconds秒');
    buffer.writeln('3. **动作数量**：每天必须包含：1-2个热身动作 + **$exerciseCountRange主训练动作** + 1-2个拉伸动作');
    buffer.writeln('4. **动作匹配**：所有动作器械必须在 [$equipmentList] 范围内');
    buffer.writeln('5. **参数匹配**：组数$levelSets，次数$levelReps，休息$levelRest秒（可根据动作调整）');
    buffer.writeln('6. **目标导向**：按"$goalPattern"模式安排${durationDays}天');
    buffer.writeln('7. **避开禁忌**：有损伤时避开相关部位，不喜欢的动作类型不出现');
    buffer.writeln('8. **完整性**：$durationDays天每天都要有完整训练（包含热身、主训练、拉伸）');
    buffer.writeln();
    buffer.writeln('**⚠️ 时间达标的关键**：');
    buffer.writeln('- 力量训练：4-5个动作，每个4-5组，休息90-120秒 → 自然填满40分钟');
    buffer.writeln('- 燃脂训练：8-10个动作，每个2-3组，休息30-45秒，可循环2-3轮 → 填满40分钟');
    buffer.writeln('- **错误示例**：5个动作 × 3组 × 60秒 = 仅15分钟，远远不够！');
    buffer.writeln('- **正确示例**：5个动作 × 5组 × 120秒(含休息) = 50分钟 ✓');
    buffer.writeln();
    buffer.writeln('请生成训练计划JSON：');

    return buffer.toString();
  }

  /// 辅助方法：获取训练重点的英文标识
  String _getFocusEn(String focus) {
    final map = {
      '有氧燃脂': 'cardio',
      '上肢力量': 'upper_body',
      '下肢力量': 'lower_body',
      '胸+三头': 'upper_body',
      '背+二头': 'upper_body',
      '腿+肩': 'lower_body',
      '臀腿': 'lower_body',
      '全身': 'full_body',
      '全身循环': 'full_body',
      '核心': 'core',
      '核心强化': 'core',
      '核心+臀部': 'core',
      'HIIT': 'hiit',
      '主动恢复': 'yoga',
      '有氧': 'cardio',
      '有氧间歇': 'cardio',
      '耐力训练': 'cardio',
      '力量爆发': 'full_body',
      '敏捷训练': 'cardio',
      '功能性': 'full_body',
      '户外活动': 'cardio',
      '上肢塑形': 'upper_body',
      '有氧拉伸': 'yoga',
      '瑜伽拉伸': 'yoga',
      '辅助肌群': 'full_body',
      '休息': 'rest',
    };
    return map[focus] ?? 'full_body';
  }

  /// 辅助方法：计算示例动作时间
  int _calcExampleSeconds(int sets, String reps, int rest, String difficulty) {
    final secondsPerSet = switch (difficulty) {
      'easy' => 40,
      'medium' => 50,
      'hard' => 60,
      _ => 50,
    };
    return (secondsPerSet * sets) + (rest * (sets - 1));
  }

  /// 构建AI教练饮食计划提示词
  String _buildCoachDietPlanPrompt({
    required String goalType,
    required int durationDays,
    required String gender,
    required int age,
    required double height,
    required double weight,
    required String fitnessLevel,
    String? dietType,
    List<String>? dietaryRestrictions,
    List<String>? allergies,
    String? tastePreference,
    double? targetWeight,
  }) {
    final goalMap = {
      'fat_loss': '减脂（需要热量缺口）',
      'muscle_gain': '增肌（需要高蛋白）',
      'shape': '塑形（控制热量+高蛋白）',
      'maintain': '维持体重（平衡饮食）',
      'fitness': '提升体能（均衡饮食+充足碳水）',
    };

    final buffer = StringBuffer();
    buffer.writeln('请为以下用户生成一个为期 $durationDays 天的结构化饮食计划，');
    buffer.writeln('返回严格的JSON格式，不要包含任何其他文字。');
    buffer.writeln();
    buffer.writeln('**用户信息**：');
    buffer.writeln('- 目标：${goalMap[goalType] ?? goalType}');
    buffer.writeln('- 性别：${gender == "male" ? "男" : "女"}');
    buffer.writeln('- 年龄：$age 岁');
    buffer.writeln('- 身高：$height cm');
    buffer.writeln('- 体重：$weight kg');
    if (targetWeight != null) {
      final weightDiff = targetWeight - weight;
      if (weightDiff.abs() > 0.5) {
        final diffText = weightDiff > 0 ? '需增重${weightDiff.toStringAsFixed(1)}kg' : '需减重${(-weightDiff).toStringAsFixed(1)}kg';
        buffer.writeln('- 目标体重：$targetWeight kg ($diffText)');
      } else {
        buffer.writeln('- 目标体重：$targetWeight kg (维持体重)');
      }
    }
    buffer.writeln('- 运动基础：$fitnessLevel');
    if (dietType != null && dietType != 'none') {
      buffer.writeln('- 饮食类型：$dietType');
    }
    if (dietaryRestrictions != null && dietaryRestrictions!.isNotEmpty) {
      buffer.writeln('- 饮食禁忌：${dietaryRestrictions.join('、')}');
    }
    if (allergies != null && allergies!.isNotEmpty) {
      buffer.writeln('- 过敏食材：${allergies.join('、')}');
    }
    if (tastePreference != null) {
      buffer.writeln('- 口味偏好：$tastePreference');
    }

    buffer.writeln();
    buffer.writeln('**营养配比指南**：');
    buffer.writeln('- 蛋白质：30%热量（每克4卡）');
    buffer.writeln('- 碳水化合物：45%热量（每克4卡）');
    buffer.writeln('- 脂肪：25%热量（每克9卡）');
    buffer.writeln();
    buffer.writeln('**每日热量参考**：');
    buffer.writeln('- 男性：基础约1800卡，减脂1500卡，增肌2100卡');
    buffer.writeln('- 女性：基础约1500卡，减脂1200卡，增肌1800卡');
    buffer.writeln('- 根据目标体重调整：每1kg差异约±385卡/天（安全范围）');
    buffer.writeln();
    buffer.writeln('**餐次安排建议**：');
    buffer.writeln('- 早餐：07:00-08:00（约30%热量）');
    buffer.writeln('- 午餐：12:00-13:00（约40%热量）');
    buffer.writeln('- 晚餐：18:00-19:00（约30%热量）');
    buffer.writeln('- 加餐：15:00-16:00（可选，约100-150卡）');
    buffer.writeln();
    buffer.writeln('**推荐食材库**：');
    buffer.writeln('- 蛋白质：鸡胸肉、鸡蛋、豆腐、鱼肉、牛肉、虾、脱脂奶');
    buffer.writeln('- 碳水：燕麦、糙米、红薯、全麦面包、玉米、藜麦');
    buffer.writeln('- 蔬菜：西兰花、菠菜、胡萝卜、番茄、黄瓜、芹菜');
    buffer.writeln('- 水果：苹果、香蕉、蓝莓、橙子、猕猴桃');
    buffer.writeln('- 健康脂肪：牛油果、坚果、橄榄油、深海鱼');
    buffer.writeln();
    buffer.writeln('**JSON格式要求**：');
    buffer.writeln('''```json
{
  "planName": "计划名称（如：30天减脂饮食计划）",
  "description": "计划简短描述",
  "dailyCalories": 1800,
  "dailyProtein": 120,
  "dailyCarbs": 200,
  "dailyFat": 60,
  "days": [
    {
      "day": 1,
      "meals": [
        {
          "mealType": "breakfast",
          "mealName": "燕麦蓝莓早餐",
          "eatingTime": "07:30",
          "calories": 400,
          "protein": 20,
          "carbs": 60,
          "fat": 12,
          "items": [
            {
              "order": 1,
              "foodName": "燕麦片",
              "amount": "50g",
              "weightGrams": 50,
              "calories": 180,
              "protein": 6,
              "carbs": 32,
              "fat": 3,
              "cookingMethod": "用热水或热牛奶冲泡"
            }
          ]
        }
      ]
    }
  ]
}
```''');

    buffer.writeln();
    buffer.writeln('**要求**：');
    buffer.writeln('1. 每天包含：早餐、午餐、晚餐，可选加餐');
    buffer.writeln('2. mealType可选值：breakfast、lunch、dinner、snack');
    buffer.writeln('3. 根据目标计算合理的热量和营养配比');
    buffer.writeln('4. 避开用户的过敏食材和饮食禁忌');
    buffer.writeln('5. 考虑用户的口味偏好');
    buffer.writeln('6. 提供简单的烹饪方法');
    buffer.writeln('7. 只返回JSON，不要有其他说明文字');

    return buffer.toString();
  }

  /// 构建替换动作提示词
  String _buildReplaceExercisePrompt({
    required String currentExerciseName,
    required String exerciseType,
    required String targetMuscle,
    required String equipmentType,
    required String reason,
    String? difficulty,
  }) {
    final typeMap = {
      'warm_up': '热身',
      'main': '主训练',
      'stretch': '拉伸',
      'cardio': '有氧',
    };

    final buffer = StringBuffer();
    buffer.writeln('请为以下动作生成一个替代动作，返回严格的JSON格式：');
    buffer.writeln();
    buffer.writeln('- 原动作：$currentExerciseName');
    buffer.writeln('- 动作类型：${typeMap[exerciseType] ?? exerciseType}');
    buffer.writeln('- 目标部位：$targetMuscle');
    buffer.writeln('- 器械情况：$equipmentType');
    buffer.writeln('- 替换原因：$reason');
    if (difficulty != null) {
      buffer.writeln('- 难度要求：$difficulty');
    }
    buffer.writeln();
    buffer.writeln('**JSON格式**：');
    buffer.writeln('''```json
{
  "name": "替代动作名称",
  "description": "标准做法描述",
  "sets": 3,
  "reps": "12-15",
  "restSeconds": 60,
  "equipment": "所需器械",
  "difficulty": "medium",
  "exerciseType": "$exerciseType"
}
```''');
    buffer.writeln();
    buffer.writeln('**要求**：');
    buffer.writeln('1. 替代动作应训练相同的肌肉部位');
    buffer.writeln('2. 符合用户的器械条件');
    buffer.writeln('3. 根据替换原因调整难度');
    buffer.writeln('4. 只返回JSON，不要有其他说明文字');

    return buffer.toString();
  }

  /// 构建替换食材提示词
  String _buildReplaceFoodPrompt({
    required String currentFoodName,
    required String mealType,
    required String reason,
    double? targetCalories,
    double? targetProtein,
    List<String>? allergies,
    List<String>? dietaryRestrictions,
  }) {
    final mealMap = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐',
    };

    final buffer = StringBuffer();
    buffer.writeln('请为以下食材生成一个替代食材，返回严格的JSON格式：');
    buffer.writeln();
    buffer.writeln('- 原食材：$currentFoodName');
    buffer.writeln('- 餐次：${mealMap[mealType] ?? mealType}');
    buffer.writeln('- 替换原因：$reason');
    if (targetCalories != null) {
      buffer.writeln('- 目标热量：约 ${targetCalories.toStringAsFixed(0)} kcal');
    }
    if (targetProtein != null) {
      buffer.writeln('- 目标蛋白质：约 ${targetProtein.toStringAsFixed(1)} g');
    }
    if (allergies != null && allergies.isNotEmpty) {
      buffer.writeln('- 过敏食材：${allergies.join('、')}');
    }
    if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
      buffer.writeln('- 饮食禁忌：${dietaryRestrictions.join('、')}');
    }
    buffer.writeln();
    buffer.writeln('**JSON格式**：');
    buffer.writeln('''```json
{
  "foodName": "替代食材名称",
  "amount": "用量描述",
  "weightGrams": 100,
  "calories": ${targetCalories ?? 150},
  "protein": ${targetProtein ?? 15},
  "carbs": 20,
  "fat": 5,
  "cookingMethod": "简单烹饪方法"
}
```''');
    buffer.writeln();
    buffer.writeln('**要求**：');
    buffer.writeln('1. 替代食材营养价值相近');
    buffer.writeln('2. 易于购买和烹饪');
    buffer.writeln('3. 避开过敏和禁忌食材');
    buffer.writeln('4. 只返回JSON，不要有其他说明文字');

    return buffer.toString();
  }

  /// ==================== JSON解析方法 ====================

  /// 解析训练计划JSON
  Map<String, dynamic> _parseWorkoutPlanJSON(
    String response, {
    String? goalType,
    int? durationDays,
    String? equipmentType,
    String? fitnessLevel,
    int? dailyWorkoutMinutes,
  }) {
    try {
      String jsonStr = response;

      // 移除可能的markdown代码块标记
      if (response.contains('```json')) {
        final start = response.indexOf('```json') + 7;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      } else if (response.contains('```')) {
        final start = response.indexOf('```') + 3;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      }

      // 查找第一个 { 和最后一个 }
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 时间校验与修正
      if (dailyWorkoutMinutes != null) {
        final expectedMinutes = dailyWorkoutMinutes!;
        final expectedSeconds = expectedMinutes * 60;
        final warmupSeconds = ((expectedMinutes * 0.12).toInt() + (expectedMinutes * 0.15).toInt()) ~/ 2 * 60;
        final stretchSeconds = ((expectedMinutes * 0.12).toInt() + (expectedMinutes * 0.15).toInt()) ~/ 2 * 60;
        final mainTrainingSeconds = expectedSeconds - warmupSeconds - stretchSeconds;

        // 检查并修正每天的时间和动作
        if (data['days'] is List) {
          final days = data['days'] as List;
          for (var day in days) {
            if (day is Map) {
              // 修正 estimatedMinutes
              final currentMinutes = day['estimatedMinutes'] as int?;
              if (currentMinutes != null && currentMinutes != expectedMinutes) {
                debugPrint('⏰ 修正第${day['day']}天 estimatedMinutes: $currentMinutes → $expectedMinutes');
                day['estimatedMinutes'] = expectedMinutes;
              }

              // 计算并修正动作的 estimatedSeconds
              if (day['exercises'] is List) {
                final exercises = day['exercises'] as List;

                // 分类动作
                final warmupExercises = <Map>[];
                final mainExercises = <Map>[];
                final stretchExercises = <Map>[];

                for (var ex in exercises) {
                  if (ex is Map) {
                    final type = ex['exerciseType'] as String?;
                    if (type == 'warm_up') {
                      warmupExercises.add(ex);
                    } else if (type == 'stretch') {
                      stretchExercises.add(ex);
                    } else {
                      mainExercises.add(ex);
                    }
                  }
                }

                // 计算实际可分配的时间（只计算有动作的类型）
                int actualWarmupSeconds = 0;
                int actualMainSeconds = 0;
                int actualStretchSeconds = 0;

                // 如果没有热身动作，需要添加
                if (warmupExercises.isEmpty) {
                  debugPrint('⚠️ 第${day['day']}天缺少热身动作，需要添加');
                  // 保持原计划的时间分配
                  actualWarmupSeconds = warmupSeconds;
                  actualMainSeconds = mainTrainingSeconds;
                  actualStretchSeconds = stretchSeconds;
                } else if (stretchExercises.isEmpty) {
                  debugPrint('⚠️ 第${day['day']}天缺少拉伸动作，需要添加');
                  actualWarmupSeconds = warmupSeconds;
                  actualMainSeconds = mainTrainingSeconds;
                  actualStretchSeconds = stretchSeconds;
                } else {
                  // 所有类型都存在，按原计划分配
                  actualWarmupSeconds = warmupSeconds;
                  actualMainSeconds = mainTrainingSeconds;
                  actualStretchSeconds = stretchSeconds;
                }

                // 修正热身动作时间
                if (warmupExercises.isNotEmpty) {
                  final avgWarmupTime = actualWarmupSeconds ~/ warmupExercises.length;
                  for (var ex in warmupExercises) {
                    ex['estimatedSeconds'] = avgWarmupTime;
                  }
                }

                // 修正主训练动作时间
                if (mainExercises.isNotEmpty) {
                  final avgMainTime = actualMainSeconds ~/ mainExercises.length;
                  for (var ex in mainExercises) {
                    ex['estimatedSeconds'] = avgMainTime;
                  }
                }

                // 修正拉伸动作时间
                if (stretchExercises.isNotEmpty) {
                  final avgStretchTime = actualStretchSeconds ~/ stretchExercises.length;
                  for (var ex in stretchExercises) {
                    ex['estimatedSeconds'] = avgStretchTime;
                  }
                }

                // 计算实际总时间
                final actualTotalSeconds = actualWarmupSeconds + actualMainSeconds + actualStretchSeconds;
                debugPrint('⏰ 第${day['day']}天时间修正: 热身${actualWarmupSeconds}s(${warmupExercises.length}个) + 主训练${actualMainSeconds}s(${mainExercises.length}个) + 拉伸${actualStretchSeconds}s(${stretchExercises.length}个) = $actualTotalSeconds秒 (目标$expectedSeconds秒)');

                // 如果差异超过10秒，记录警告
                if ((actualTotalSeconds - expectedSeconds).abs() > 10) {
                  debugPrint('⚠️ 第${day['day']}天时间差异: ${actualTotalSeconds - expectedSeconds}秒');
                }
              }
            }
          }
        }
      }

      return data;
    } catch (e) {
      debugPrint('解析训练计划JSON失败: $e');
      // 返回默认计划而不是抛出异常，使用原始参数而非硬编码
      return _getDefaultWorkoutPlan(
        goalType: goalType ?? 'fat_loss',
        durationDays: durationDays ?? 30,
        equipmentType: equipmentType ?? 'none',
        fitnessLevel: fitnessLevel ?? 'novice',
        dailyWorkoutMinutes: dailyWorkoutMinutes,
      );
    }
  }

  /// 解析饮食计划JSON
  Map<String, dynamic> _parseDietPlanJSON(String response) {
    try {
      String jsonStr = response;

      if (response.contains('```json')) {
        final start = response.indexOf('```json') + 7;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      } else if (response.contains('```')) {
        final start = response.indexOf('```') + 3;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      }

      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('解析饮食计划JSON失败: $e');
      // 返回默认计划而不是抛出异常
      return _getDefaultDietPlan(
        goalType: 'maintain',
        durationDays: 30,
        weight: 65,
        gender: 'male',
      );
    }
  }

  /// 解析单个动作JSON
  Map<String, dynamic> _parseSingleExerciseJSON(String response) {
    try {
      String jsonStr = response;

      if (response.contains('```json')) {
        final start = response.indexOf('```json') + 7;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      } else if (response.contains('```')) {
        final start = response.indexOf('```') + 3;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      }

      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('解析动作JSON失败: $e');
      return _getDefaultExercise();
    }
  }

  /// 解析单个食材JSON
  Map<String, dynamic> _parseSingleFoodJSON(String response) {
    try {
      String jsonStr = response;

      if (response.contains('```json')) {
        final start = response.indexOf('```json') + 7;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      } else if (response.contains('```')) {
        final start = response.indexOf('```') + 3;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      }

      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('解析食材JSON失败: $e');
      return _getDefaultFood();
    }
  }

  /// 获取默认动作（解析失败时使用）
  Map<String, dynamic> _getDefaultExercise() {
    return {
      'name': '开合跳',
      'description': '双脚开立，双手向上跳起时在头顶击掌',
      'sets': 2,
      'reps': '30',
      'restSeconds': 30,
      'equipment': '无',
      'difficulty': 'easy',
      'exerciseType': 'warm_up',
    };
  }

  /// 获取默认食材（解析失败时使用）
  Map<String, dynamic> _getDefaultFood() {
    return {
      'foodName': '鸡蛋',
      'amount': '2个',
      'weightGrams': 100,
      'calories': 140,
      'protein': 12,
      'carbs': 1,
      'fat': 10,
      'cookingMethod': '水煮或煎制',
    };
  }

  /// ==================== 计划迭代功能 ====================

  /// 基于用户反馈生成迭代后的训练计划
  ///
  /// [currentPlan] 当前训练计划数据（JSON格式）
  /// [userFeedbacks] 用户反馈列表，包含反馈原因和原始项目
  /// [userProfile] 用户画像信息
  /// [iterationCount] 当前迭代次数（用于调整计划复杂度）
  Future<Map<String, dynamic>> generateIteratedWorkoutPlan({
    required Map<String, dynamic> currentPlan,
    required List<Map<String, dynamic>> userFeedbacks,
    required Map<String, dynamic> userProfile,
    int iterationCount = 1,
  }) async {
    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认迭代计划');
      return _getDefaultIteratedWorkoutPlan(
        currentPlan: currentPlan,
        iterationCount: iterationCount,
      );
    }

    final prompt = _buildIterationWorkoutPlanPrompt(
      currentPlan: currentPlan,
      userFeedbacks: userFeedbacks,
      userProfile: userProfile,
      iterationCount: iterationCount,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      // 从用户画像中提取参数用于时间校验
      final dailyWorkoutMinutes = userProfile['daily_workout_minutes'] as int?;
      return _parseWorkoutPlanJSON(
        response,
        dailyWorkoutMinutes: dailyWorkoutMinutes,
      );
    } catch (e) {
      debugPrint('AI生成迭代训练计划失败，使用默认迭代计划: $e');
      return _getDefaultIteratedWorkoutPlan(
        currentPlan: currentPlan,
        iterationCount: iterationCount,
      );
    }
  }

  /// 基于用户反馈生成迭代后的饮食计划
  ///
  /// [currentPlan] 当前饮食计划数据（JSON格式）
  /// [userFeedbacks] 用户反馈列表
  /// [userProfile] 用户画像信息
  /// [iterationCount] 当前迭代次数
  Future<Map<String, dynamic>> generateIteratedDietPlan({
    required Map<String, dynamic> currentPlan,
    required List<Map<String, dynamic>> userFeedbacks,
    required Map<String, dynamic> userProfile,
    int iterationCount = 1,
  }) async {
    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认迭代饮食计划');
      return _getDefaultIteratedDietPlan(
        currentPlan: currentPlan,
        iterationCount: iterationCount,
      );
    }

    final prompt = _buildIterationDietPlanPrompt(
      currentPlan: currentPlan,
      userFeedbacks: userFeedbacks,
      userProfile: userProfile,
      iterationCount: iterationCount,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      return _parseDietPlanJSON(response);
    } catch (e) {
      debugPrint('AI生成迭代饮食计划失败，使用默认迭代饮食计划: $e');
      return _getDefaultIteratedDietPlan(
        currentPlan: currentPlan,
        iterationCount: iterationCount,
      );
    }
  }

  /// 生成计划优化建议
  ///
  /// 分析用户反馈，生成具体的优化建议
  Future<List<Map<String, dynamic>>> generatePlanOptimizationSuggestions({
    required List<Map<String, dynamic>> userFeedbacks,
    required String planType, // 'workout' 或 'diet'
    required int daysSinceUpdate,
  }) async {
    if (!isConfigured) {
      return _getDefaultOptimizationSuggestions(planType, daysSinceUpdate);
    }

    final prompt = _buildOptimizationSuggestionsPrompt(
      userFeedbacks: userFeedbacks,
      planType: planType,
      daysSinceUpdate: daysSinceUpdate,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 1500);
      return _parseOptimizationSuggestions(response);
    } catch (e) {
      debugPrint('AI生成优化建议失败，使用默认建议: $e');
      return _getDefaultOptimizationSuggestions(planType, daysSinceUpdate);
    }
  }

  /// ==================== 迭代提示词构建 ====================

  /// 构建迭代训练计划提示词
  String _buildIterationWorkoutPlanPrompt({
    required Map<String, dynamic> currentPlan,
    required List<Map<String, dynamic>> userFeedbacks,
    required Map<String, dynamic> userProfile,
    required int iterationCount,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('您是一位专业的健身教练。用户对当前的训练计划提供了反馈，');
    buffer.writeln('请根据反馈生成优化后的训练计划，返回严格的JSON格式。');
    buffer.writeln();

    // 用户信息
    buffer.writeln('**用户画像**：');
    buffer.writeln('- 目标：${userProfile['goal_type'] ?? '保持健康'}');
    buffer.writeln('- 运动基础：${userProfile['fitness_level'] ?? '新手'}');
    buffer.writeln('- 器械情况：${userProfile['equipment_type'] ?? '无器械'}');
    if (userProfile['injuries'] != null) {
      buffer.writeln('- 运动损伤：${userProfile['injuries']}');
    }
    buffer.writeln();

    // 当前计划概要
    buffer.writeln('**当前计划**：');
    buffer.writeln('- 计划名称：${currentPlan['planName'] ?? '训练计划'}');
    buffer.writeln('- 总天数：${currentPlan['totalWorkouts'] ?? currentPlan['days']?.length ?? 30}');
    buffer.writeln('- 迭代次数：第 $iterationCount 次迭代');
    buffer.writeln();

    // 用户反馈汇总
    if (userFeedbacks.isNotEmpty) {
      buffer.writeln('**用户反馈汇总**：');

      // 按原因分类
      final feedbackByReason = <String, List<String>>{};
      for (final feedback in userFeedbacks) {
        final reason = feedback['reason'] as String? ?? 'unknown';
        final originalName = feedback['original_name'] as String? ?? '';
        if (originalName.isNotEmpty) {
          feedbackByReason.putIfAbsent(reason, () => []).add(originalName);
        }
      }

      feedbackByReason.forEach((reason, items) {
        final reasonText = _getFeedbackReasonText(reason);
        buffer.writeln('- $reasonText：${items.join('、')}');
      });
      buffer.writeln();
    }

    // 迭代原则
    buffer.writeln('**迭代原则**：');
    buffer.writeln('1. 根据反馈调整计划难度和内容');
    buffer.writeln('2. 替换用户反馈不喜欢的动作/项目');
    buffer.writeln('3. 如果反馈"太难"，降低整体强度');
    buffer.writeln('4. 如果反馈"太简单"，增加训练量或难度');
    buffer.writeln('5. 如果反馈"没有器械"，替换为自重训练');
    buffer.writeln('6. 考虑迭代次数，适当引入新变化保持趣味性');
    buffer.writeln('7. 保持计划结构的合理性');

    buffer.writeln();
    buffer.writeln('**JSON格式要求**：');
    buffer.writeln('''```json
{
  "planName": "计划名称（第X版）",
  "description": "优化说明",
  "totalWorkouts": 天数,
  "days": [
    {
      "day": 1,
      "dayName": "第1天 - 训练重点",
      "trainingFocus": "训练重点",
      "estimatedMinutes": 45,
      "exercises": [
        {
          "order": 1,
          "name": "动作名称",
          "description": "动作描述",
          "sets": 3,
          "reps": "12-15",
          "restSeconds": 60,
          "equipment": "所需器械",
          "difficulty": "medium",
          "exerciseType": "warm_up"
        }
      ]
    }
  ]
}
```''');
    buffer.writeln();
    buffer.writeln('只返回JSON，不要有其他说明文字。');

    return buffer.toString();
  }

  /// 构建迭代饮食计划提示词
  String _buildIterationDietPlanPrompt({
    required Map<String, dynamic> currentPlan,
    required List<Map<String, dynamic>> userFeedbacks,
    required Map<String, dynamic> userProfile,
    required int iterationCount,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('您是一位专业的营养师。用户对当前的饮食计划提供了反馈，');
    buffer.writeln('请根据反馈生成优化后的饮食计划，返回严格的JSON格式。');
    buffer.writeln();

    // 用户信息
    buffer.writeln('**用户画像**：');
    buffer.writeln('- 目标：${userProfile['goal_type'] ?? '保持健康'}');
    buffer.writeln('- 体重：${userProfile['weight'] ?? '未知'}kg');
    if (userProfile['diet_type'] != null && userProfile['diet_type'] != 'none') {
      buffer.writeln('- 饮食类型：${userProfile['diet_type']}');
    }
    if (userProfile['dietary_restrictions'] != null) {
      buffer.writeln('- 饮食禁忌：${userProfile['dietary_restrictions']}');
    }
    if (userProfile['allergies'] != null) {
      buffer.writeln('- 过敏食材：${userProfile['allergies']}');
    }
    buffer.writeln();

    // 当前计划概要
    buffer.writeln('**当前计划**：');
    buffer.writeln('- 计划名称：${currentPlan['planName'] ?? '饮食计划'}');
    buffer.writeln('- 总天数：${currentPlan['days']?.length ?? 30}');
    buffer.writeln('- 每日热量：${currentPlan['dailyCalories'] ?? '未指定'}');
    buffer.writeln('- 迭代次数：第 $iterationCount 次迭代');
    buffer.writeln();

    // 用户反馈汇总
    if (userFeedbacks.isNotEmpty) {
      buffer.writeln('**用户反馈汇总**：');

      final feedbackByReason = <String, List<String>>{};
      for (final feedback in userFeedbacks) {
        final reason = feedback['reason'] as String? ?? 'unknown';
        final originalName = feedback['original_name'] as String? ?? '';
        if (originalName.isNotEmpty) {
          feedbackByReason.putIfAbsent(reason, () => []).add(originalName);
        }
      }

      feedbackByReason.forEach((reason, items) {
        final reasonText = _getFoodFeedbackReasonText(reason);
        buffer.writeln('- $reasonText：${items.join('、')}');
      });
      buffer.writeln();
    }

    // 迭代原则
    buffer.writeln('**迭代原则**：');
    buffer.writeln('1. 替换用户反馈"买不到"或"太贵"的食材');
    buffer.writeln('2. 简化用户反馈"太难做"的烹饪方法');
    buffer.writeln('3. 避开用户反馈"过敏"或"不喜欢"的食材');
    buffer.writeln('4. 保持营养均衡和热量目标');
    buffer.writeln('5. 提供易获得、易烹饪的替代方案');
    buffer.writeln('6. 根据迭代次数适当增加变化');

    buffer.writeln();
    buffer.writeln('**JSON格式要求**：');
    buffer.writeln('''```json
{
  "planName": "计划名称（第X版）",
  "description": "优化说明",
  "dailyCalories": 1800,
  "dailyProtein": 120,
  "dailyCarbs": 200,
  "dailyFat": 60,
  "days": [
    {
      "day": 1,
      "meals": [
        {
          "mealType": "breakfast",
          "mealName": "餐次名称",
          "eatingTime": "07:30",
          "calories": 400,
          "protein": 20,
          "carbs": 60,
          "fat": 12,
          "items": [
            {
              "order": 1,
              "foodName": "食材名称",
              "amount": "用量",
              "weightGrams": 100,
              "calories": 150,
              "protein": 6,
              "carbs": 20,
              "fat": 3,
              "cookingMethod": "烹饪方法"
            }
          ]
        }
      ]
    }
  ]
}
```''');
    buffer.writeln();
    buffer.writeln('只返回JSON，不要有其他说明文字。');

    return buffer.toString();
  }

  /// 构建优化建议提示词
  String _buildOptimizationSuggestionsPrompt({
    required List<Map<String, dynamic>> userFeedbacks,
    required String planType,
    required int daysSinceUpdate,
  }) {
    final planTypeName = planType == 'workout' ? '训练计划' : '饮食计划';

    final buffer = StringBuffer();
    buffer.writeln('请分析以下用户反馈，为$planTypeName的优化生成具体建议。');
    buffer.writeln();

    buffer.writeln('**背景信息**：');
    buffer.writeln('- 计划已执行 $daysSinceUpdate 天');
    buffer.writeln('- 收到 ${userFeedbacks.length} 条用户反馈');
    buffer.writeln();

    if (userFeedbacks.isNotEmpty) {
      buffer.writeln('**用户反馈详情**：');
      for (var i = 0; i < userFeedbacks.length; i++) {
        final feedback = userFeedbacks[i];
        final reason = planType == 'workout'
            ? _getFeedbackReasonText(feedback['reason'] ?? '')
            : _getFoodFeedbackReasonText(feedback['reason'] ?? '');
        buffer.writeln('${i + 1}. ${feedback['original_name']} - $reason');
      }
      buffer.writeln();
    }

    buffer.writeln('**输出要求**：');
    buffer.writeln('返回3-5条具体优化建议，每条建议包含：');
    buffer.writeln('- 优先级（high/medium/low）');
    buffer.writeln('- 建议内容（一句话）');
    buffer.writeln('- 具体措施');
    buffer.writeln();
    buffer.writeln('**输出格式（JSON数组）**：');
    buffer.writeln('''```json
[
  {
    "priority": "high",
    "title": "降低动作难度",
    "description": "根据反馈将部分高难度动作替换为简单版本",
    "category": "difficulty"
  },
  {
    "priority": "medium",
    "title": "增加训练多样性",
    "description": "引入新的训练动作保持趣味性",
    "category": "variety"
  }
]
```''');
    buffer.writeln();
    buffer.writeln('只返回JSON数组，不要有其他说明文字。');

    return buffer.toString();
  }

  /// ==================== 默认迭代数据 ====================

  /// 获取默认迭代训练计划
  Map<String, dynamic> _getDefaultIteratedWorkoutPlan({
    required Map<String, dynamic> currentPlan,
    required int iterationCount,
  }) {
    final planName = currentPlan['planName'] as String? ?? '训练计划';
    final days = currentPlan['days'] as List<dynamic>? ?? [];

    // 简单调整：在计划名称后添加版本号
    return {
      'planName': '$planName（第${iterationCount + 1}版）',
      'description': '根据您的反馈优化了训练内容和难度',
      'totalWorkouts': days.length,
      'days': days,
    };
  }

  /// 获取默认迭代饮食计划
  Map<String, dynamic> _getDefaultIteratedDietPlan({
    required Map<String, dynamic> currentPlan,
    required int iterationCount,
  }) {
    final planName = currentPlan['planName'] as String? ?? '饮食计划';
    final days = currentPlan['days'] as List<dynamic>? ?? [];

    return {
      'planName': '$planName（第${iterationCount + 1}版）',
      'description': '根据您的反馈优化了食材选择和烹饪方法',
      'dailyCalories': currentPlan['dailyCalories'] ?? 1800,
      'dailyProtein': currentPlan['dailyProtein'] ?? 120,
      'dailyCarbs': currentPlan['dailyCarbs'] ?? 200,
      'dailyFat': currentPlan['dailyFat'] ?? 60,
      'days': days,
    };
  }

  /// 获取默认优化建议
  List<Map<String, dynamic>> _getDefaultOptimizationSuggestions(
    String planType,
    int daysSinceUpdate,
  ) {
    if (planType == 'workout') {
      return [
        {
          'priority': 'high',
          'title': '适当调整训练强度',
          'description': '根据您的反馈调整训练强度，确保训练效果与身体承受能力匹配',
          'category': 'intensity',
        },
        {
          'priority': 'medium',
          'title': '增加训练多样性',
          'description': '引入新的训练动作和训练方式，保持训练的趣味性',
          'category': 'variety',
        },
        {
          'priority': 'medium',
          'title': '优化训练时间安排',
          'description': '根据您的日程调整训练时长和训练频率',
          'category': 'schedule',
        },
      ];
    } else {
      return [
        {
          'priority': 'high',
          'title': '替换不易获得的食材',
          'description': '使用更常见、易购买的食材替代原有的食材',
          'category': 'ingredients',
        },
        {
          'priority': 'medium',
          'title': '简化烹饪方法',
          'description': '提供更简单快捷的烹饪方案，节省准备时间',
          'category': 'cooking',
        },
        {
          'priority': 'medium',
          'title': '增加食谱多样性',
          'description': '提供更多口味和做法的选择，避免饮食单调',
          'category': 'variety',
        },
      ];
    }
  }

  /// 解析优化建议JSON
  List<Map<String, dynamic>> _parseOptimizationSuggestions(String response) {
    try {
      String jsonStr = response;

      if (response.contains('```json')) {
        final start = response.indexOf('```json') + 7;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      } else if (response.contains('```')) {
        final start = response.indexOf('```') + 3;
        final end = response.lastIndexOf('```');
        if (end > start) {
          jsonStr = response.substring(start, end).trim();
        }
      }

      final firstBracket = jsonStr.indexOf('[');
      final lastBracket = jsonStr.lastIndexOf(']');
      if (firstBracket >= 0 && lastBracket > firstBracket) {
        jsonStr = jsonStr.substring(firstBracket, lastBracket + 1);
      }

      final data = jsonDecode(jsonStr) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('解析优化建议JSON失败: $e');
      return [];
    }
  }

  /// 获取训练反馈原因文本
  String _getFeedbackReasonText(String reason) {
    const map = {
      'too_hard': '太难',
      'too_easy': '太简单',
      'dislike': '不喜欢',
      'no_equipment': '没器械',
      'injury': '身体不适合',
    };
    return map[reason] ?? reason;
  }

  /// 获取饮食反馈原因文本
  String _getFoodFeedbackReasonText(String reason) {
    const map = {
      'unavailable': '买不到',
      'too_hard': '太难做',
      'dislike': '不喜欢',
      'allergy': '过敏',
      'too_expensive': '太贵',
    };
    return map[reason] ?? reason;
  }
}

/// AI 服务异常
class AIServiceException implements Exception {
  final String message;
  final String? details;

  const AIServiceException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}
