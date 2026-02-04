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

  // 移除默认 API Key，要求用户自己配置
  // static const String _defaultApiKey = 'sk-c854090502824575a257bc6da42f485f';

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

  /// 默认 API Key - 已移除硬编码
  /// 用户必须在设置中配置自己的 API Key
  static const String _defaultApiKey = '';

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
    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认训练计划');
      return _getDefaultWorkoutPlan(
        goalType: goalType,
        durationDays: durationDays,
        equipmentType: equipmentType,
      );
    }

    final prompt = _buildCoachWorkoutPlanPrompt(
      goalType: goalType,
      durationDays: durationDays,
      gender: gender,
      age: age,
      height: height,
      weight: weight,
      fitnessLevel: fitnessLevel,
      equipmentType: equipmentType,
      dietType: dietType,
      dietaryRestrictions: dietaryRestrictions,
      injuries: injuries,
      dailyWorkoutMinutes: dailyWorkoutMinutes,
      preferredWorkouts: preferredWorkouts,
      dislikedWorkouts: dislikedWorkouts,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      return _parseWorkoutPlanJSON(response);
    } catch (e) {
      debugPrint('AI生成训练计划失败，使用默认计划: $e');
      return _getDefaultWorkoutPlan(
        goalType: goalType,
        durationDays: durationDays,
        equipmentType: equipmentType,
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
  }) async {
    if (!isConfigured) {
      debugPrint('API Key 未配置，使用默认饮食计划');
      return _getDefaultDietPlan(
        goalType: goalType,
        durationDays: durationDays,
        weight: weight,
        gender: gender,
      );
    }

    final prompt = _buildCoachDietPlanPrompt(
      goalType: goalType,
      durationDays: durationDays,
      gender: gender,
      age: age,
      height: height,
      weight: weight,
      fitnessLevel: fitnessLevel,
      dietType: dietType,
      dietaryRestrictions: dietaryRestrictions,
      allergies: allergies,
      tastePreference: tastePreference,
    );

    try {
      final response = await _callChatAPIWithRetry(prompt, maxTokens: 4000, retries: 2);
      return _parseDietPlanJSON(response);
    } catch (e) {
      debugPrint('AI生成饮食计划失败，使用默认计划: $e');
      return _getDefaultDietPlan(
        goalType: goalType,
        durationDays: durationDays,
        weight: weight,
        gender: gender,
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
  }) {
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
    final focuses = ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '全身燃脂', '主动恢复'];
    final isBodyweightOnly = equipmentType == 'none';

    for (int day = 1; day <= durationDays; day++) {
      final focusIndex = (day - 1) % focuses.length;
      days.add(_getDefaultWorkoutDay(
        day: day,
        focus: focuses[focusIndex],
        isBodyweightOnly: isBodyweightOnly,
      ));
    }

    return {
      'planName': planName,
      'description': description,
      'totalWorkouts': durationDays,
      'days': days,
    };
  }

  /// 获取默认单日训练
  Map<String, dynamic> _getDefaultWorkoutDay({
    required int day,
    required String focus,
    required bool isBodyweightOnly,
  }) {
    final exercises = <Map<String, dynamic>>[];

    // 热身
    exercises.add({
      'order': 1,
      'name': '关节活动热身',
      'description': '转动肩、髋、膝、踝关节，手臂环绕，高抬腿',
      'sets': 2,
      'reps': '30秒',
      'restSeconds': 30,
      'equipment': '无',
      'difficulty': 'easy',
      'exerciseType': 'warm_up',
    });

    // 主训练（根据训练重点）
    if (focus.contains('胸背') || focus.contains('全身')) {
      if (isBodyweightOnly) {
        exercises.addAll([
          {
            'order': exercises.length + 1,
            'name': '俯卧撑',
            'description': '双手略宽于肩，身体保持一条直线，胸部贴近地面后推起',
            'sets': 3,
            'reps': '10-15',
            'restSeconds': 60,
            'equipment': '无',
            'difficulty': 'medium',
            'exerciseType': 'main',
          },
          {
            'order': exercises.length + 1,
            'name': '俯卧划船',
            'description': '趴在地上，双手拉起重物或使用水瓶，感受背部发力',
            'sets': 3,
            'reps': '12-15',
            'restSeconds': 60,
            'equipment': '无/水瓶',
            'difficulty': 'easy',
            'exerciseType': 'main',
          },
        ]);
      } else {
        exercises.addAll([
          {
            'order': exercises.length + 1,
            'name': '哑铃卧推',
            'description': '躺于凳上，推举哑铃，感受胸肌收缩',
            'sets': 4,
            'reps': '10-12',
            'restSeconds': 90,
            'equipment': '哑铃',
            'difficulty': 'medium',
            'exerciseType': 'main',
          },
          {
            'order': exercises.length + 1,
            'name': '哑铃划船',
            'description': '单手支撑，另一手拉举哑铃，感受背部肌群发力',
            'sets': 4,
            'reps': '10-12',
            'restSeconds': 90,
            'equipment': '哑铃',
            'difficulty': 'medium',
            'exerciseType': 'main',
          },
        ]);
      }
    }

    if (focus.contains('肩臂') || focus.contains('全身')) {
      exercises.addAll([
        {
          'order': exercises.length + 1,
          'name': '臂屈伸',
          'description': '双手撑在椅子边缘，身体下沉后推起',
          'sets': 3,
          'reps': '10-15',
          'restSeconds': 60,
          'equipment': '椅子',
          'difficulty': 'easy',
          'exerciseType': 'main',
        },
        {
          'order': exercises.length + 1,
          'name': '哑铃弯举',
          'description': '双手持哑铃做弯举动作，刺激二头肌',
          'sets': 3,
          'reps': '12-15',
          'restSeconds': 60,
          'equipment': isBodyweightOnly ? '水瓶' : '哑铃',
          'difficulty': 'easy',
          'exerciseType': 'main',
        },
      ]);
    }

    if (focus.contains('腿部') || focus.contains('全身')) {
      exercises.addAll([
        {
          'order': exercises.length + 1,
          'name': '深蹲',
          'description': '双脚与肩同宽，下蹲至大腿与地面平行',
          'sets': 3,
          'reps': '15-20',
          'restSeconds': 90,
          'equipment': '无',
          'difficulty': 'easy',
          'exerciseType': 'main',
        },
        {
          'order': exercises.length + 1,
          'name': '箭步蹲',
          'description': '交替向前跨步下蹲，保持身体稳定',
          'sets': 3,
          'reps': '每侧10-15次',
          'restSeconds': 60,
          'equipment': '无',
          'difficulty': 'medium',
          'exerciseType': 'main',
        },
        {
          'order': exercises.length + 1,
          'name': '臀桥',
          'description': '仰卧，双脚踩地，抬起臀部至身体成一直线',
          'sets': 3,
          'reps': '15-20',
          'restSeconds': 45,
          'equipment': '无',
          'difficulty': 'easy',
          'exerciseType': 'main',
        },
      ]);
    }

    if (focus.contains('核心') || focus.contains('全身')) {
      exercises.addAll([
        {
          'order': exercises.length + 1,
          'name': '平板支撑',
          'description': '用前臂和脚尖支撑身体，保持身体平直',
          'sets': 3,
          'reps': '30-45秒',
          'restSeconds': 60,
          'equipment': '无',
          'difficulty': 'medium',
          'exerciseType': 'main',
        },
        {
          'order': exercises.length + 1,
          'name': '卷腹',
          'description': '仰卧，双手扶耳，用腹部力量卷起上半身',
          'sets': 3,
          'reps': '15-20',
          'restSeconds': 45,
          'equipment': '无',
          'difficulty': 'easy',
          'exerciseType': 'main',
        },
      ]);
    }

    if (focus.contains('燃脂')) {
      exercises.add({
        'order': exercises.length + 1,
        'name': '开合跳',
        'description': '双脚开合跳跃，同时双手在头顶击掌',
        'sets': 1,
        'reps': '5分钟',
        'restSeconds': 0,
        'equipment': '无',
        'difficulty': 'medium',
        'exerciseType': 'cardio',
      });
    }

    // 拉伸
    exercises.add({
      'order': exercises.length + 1,
      'name': '全身拉伸',
      'description': '放松各部位肌肉，每组动作保持15-30秒',
      'sets': 1,
      'reps': '5分钟',
      'restSeconds': 0,
      'equipment': '无',
      'difficulty': 'easy',
      'exerciseType': 'stretch',
    });

    return {
      'day': day,
      'dayName': '第${day}天 - $focus',
      'trainingFocus': focus.replaceAll('训练', '').trim(),
      'estimatedMinutes': 30,
      'exercises': exercises,
    };
  }

  /// 获取默认饮食计划
  Map<String, dynamic> _getDefaultDietPlan({
    required String goalType,
    required int durationDays,
    required double weight,
    required String gender,
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

    final dailyProtein = weight * 1.5;
    final dailyCarbs = dailyCalories * 0.45 / 4;
    final dailyFat = dailyCalories * 0.25 / 9;

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
      'planName': '均衡饮食计划',
      'description': '科学均衡的饮食方案，帮助您达成健身目标',
      'dailyCalories': dailyCalories.round(),
      'dailyProtein': dailyProtein.round(),
      'dailyCarbs': dailyCarbs.round(),
      'dailyFat': dailyFat.round(),
      'days': days,
    };
  }

  Map<String, dynamic> _getDefaultBreakfast(double calories) {
    return {
      'mealType': 'breakfast',
      'mealName': '营养早餐',
      'eatingTime': '07:30',
      'calories': calories,
      'protein': calories * 0.25 / 4,
      'carbs': calories * 0.50 / 4,
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
    return {
      'mealType': 'lunch',
      'mealName': '均衡午餐',
      'eatingTime': '12:00',
      'calories': calories,
      'protein': calories * 0.25 / 4,
      'carbs': calories * 0.50 / 4,
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
    return {
      'mealType': 'dinner',
      'mealName': '轻食晚餐',
      'eatingTime': '18:30',
      'calories': calories,
      'protein': calories * 0.25 / 4,
      'carbs': calories * 0.50 / 4,
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
    final goalMap = {
      'fat_loss': '减脂',
      'muscle_gain': '增肌',
      'shape': '塑形',
      'maintain': '维持体重',
      'fitness': '提升体能',
    };

    final levelMap = {
      'beginner': '零基础',
      'novice': '新手',
      'intermediate': '有基础',
      'advanced': '资深',
    };

    final equipmentMap = {
      'none': '无器械（自重训练）',
      'home_minimal': '家用小器械（哑铃、弹力带等）',
      'home_full': '家庭健身器材（跑步机、单车等）',
      'gym_full': '健身房全套器械',
    };

    final buffer = StringBuffer();
    buffer.writeln('请为以下用户生成一个为期 $durationDays 天的结构化训练计划，');
    buffer.writeln('返回严格的JSON格式，不要包含任何其他文字。');
    buffer.writeln();
    buffer.writeln('**用户信息**：');
    buffer.writeln('- 目标：${goalMap[goalType] ?? goalType}');
    buffer.writeln('- 性别：${gender == "male" ? "男" : "女"}');
    buffer.writeln('- 年龄：$age 岁');
    buffer.writeln('- 身高：$height cm');
    buffer.writeln('- 体重：$weight kg');
    buffer.writeln('- 运动基础：${levelMap[fitnessLevel] ?? fitnessLevel}');
    buffer.writeln('- 器械情况：${equipmentMap[equipmentType] ?? equipmentType}');
    if (dailyWorkoutMinutes != null) {
      buffer.writeln('- 每日可运动时长：$dailyWorkoutMinutes 分钟');
    }
    if (dietType != null && dietType != 'none') {
      buffer.writeln('- 饮食类型：$dietType');
    }
    if (dietaryRestrictions != null && dietaryRestrictions!.isNotEmpty) {
      buffer.writeln('- 饮食禁忌：${dietaryRestrictions.join('、')}');
    }
    if (injuries != null && injuries!.isNotEmpty) {
      buffer.writeln('- 运动损伤：${injuries.join('、')}');
    }
    if (preferredWorkouts != null && preferredWorkouts!.isNotEmpty) {
      buffer.writeln('- 喜欢的运动：${preferredWorkouts.join('、')}');
    }
    if (dislikedWorkouts != null && dislikedWorkouts!.isNotEmpty) {
      buffer.writeln('- 不喜欢的运动：${dislikedWorkouts.join('、')}');
    }

    buffer.writeln();
    buffer.writeln('**JSON格式要求**：');
    buffer.writeln('''```json
{
  "planName": "计划名称（如：30天减脂训练计划）",
  "description": "计划简短描述",
  "totalWorkouts": $durationDays,
  "days": [
    {
      "day": 1,
      "dayName": "第1天 - 上肢力量训练",
      "trainingFocus": "upper_body",
      "estimatedMinutes": 45,
      "exercises": [
        {
          "order": 1,
          "name": "动作名称",
          "description": "标准做法描述",
          "sets": 3,
          "reps": "12-15",
          "restSeconds": 60,
          "equipment": "所需器械",
          "difficulty": "easy",
          "exerciseType": "warm_up"
        }
      ]
    }
  ]
}
```''');

    buffer.writeln();
    buffer.writeln('**要求**：');
    buffer.writeln('1. 每天包含：热身(5-10分钟) + 主训练 + 拉伸(5-10分钟)');
    buffer.writeln('2. 按用户运动基础调整动作难度');
    buffer.writeln('3. 考虑用户的器械情况');
    buffer.writeln('4. 避开用户不喜欢的运动类型');
    buffer.writeln('5. 有损伤时避开相关部位动作');
    buffer.writeln('6. exerciseType可选值：warm_up(热身)、main(主训练)、cardio(有氧)、stretch(拉伸)');
    buffer.writeln('7. difficulty可选值：easy、medium、hard');
    buffer.writeln('8. 只返回JSON，不要有其他说明文字');

    return buffer.toString();
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
  Map<String, dynamic> _parseWorkoutPlanJSON(String response) {
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
      return data;
    } catch (e) {
      debugPrint('解析训练计划JSON失败: $e');
      // 返回默认计划而不是抛出异常
      return _getDefaultWorkoutPlan(
        goalType: 'fat_loss',
        durationDays: 30,
        equipmentType: 'none',
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
      return _parseWorkoutPlanJSON(response);
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
