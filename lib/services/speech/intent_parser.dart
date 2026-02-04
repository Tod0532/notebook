/// 意图解析服务 - 解析用户语音指令
/// 支持多种意图类型：创建笔记、运动打卡、查询进度、创建提醒等

import 'dart:async';
import 'package:flutter/foundation.dart';

// ==================== 意图类型 ====================

/// 意图类型枚举
enum IntentType {
  createNote,        // 创建笔记
  logWorkout,        // 运动打卡
  queryProgress,     // 查询进度
  createReminder,    // 创建提醒
  quickMemo,         // 快速记事
  unknown,           // 未知意图
}

// ==================== 运动类型 ====================

/// 运动类型枚举
enum WorkoutType {
  running,           // 跑步
  walking,           // 步行
  cycling,           // 骑行
  swimming,          // 游泳
  fitness,           // 健身
  yoga,              // 瑜伽
  basketball,        // 篮球
  football,          // 足球
  badminton,         // 羽毛球
  other,             // 其他
}

// ==================== 意图模型 ====================

/// 语音意图模型
class VoiceIntent {
  final IntentType type;             // 意图类型
  final String? content;             // 内容（笔记、提醒等）
  final WorkoutType? workoutType;    // 运动类型
  final Map<String, dynamic>? data;  // 附加数据
  final String originalText;         // 原始文本
  final double confidence;           // 置信度

  VoiceIntent({
    required this.type,
    this.content,
    this.workoutType,
    this.data,
    required this.originalText,
    this.confidence = 0.0,
  });

  @override
  String toString() {
    return 'VoiceIntent{type: $type, content: $content, workoutType: $workoutType, data: $data}';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'content': content,
      'workoutType': workoutType?.name,
      'data': data,
      'originalText': originalText,
      'confidence': confidence,
    };
  }
}

// ==================== 运动数据模型 ====================

/// 运动数据
class WorkoutData {
  final WorkoutType type;           // 运动类型
  final double? distance;           // 距离（公里）
  final int? duration;              // 时长（分钟）
  final int? calories;              // 卡路里
  final String? notes;              // 备注

  WorkoutData({
    required this.type,
    this.distance,
    this.duration,
    this.calories,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'distance': distance,
      'duration': duration,
      'calories': calories,
      'notes': notes,
    };
  }
}

// ==================== 提醒数据模型 ====================

/// 提醒数据
class ReminderData {
  final String content;             // 提醒内容
  final DateTime? time;             // 提醒时间
  final bool isRepeating;           // 是否重复

  ReminderData({
    required this.content,
    this.time,
    this.isRepeating = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'time': time?.toIso8601String(),
      'isRepeating': isRepeating,
    };
  }
}

// ==================== 意图解析服务 ====================

/// 意图解析服务 - 单例模式
class IntentParser {
  // 单例模式
  static IntentParser? _instance;
  static final _lock = Object();

  factory IntentParser() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= IntentParser._internal();
      });
    }
    return _instance!;
  }

  IntentParser._internal();

  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  // ==================== 关键词配置 ====================

  // 创建笔记关键词
  static const List<String> _noteKeywords = [
    '记', '笔记', '记录', '写下', '写一下', '备忘', '想法',
  ];

  // 运动打卡关键词
  static const List<String> _workoutKeywords = [
    '跑', '运动', '健身', '练', '锻炼', '运动了', '刚刚跑',
  ];

  // 查询进度关键词
  static const List<String> _queryKeywords = [
    '多久', '进度', '统计', '总结', '怎么样', '完成了',
  ];

  // 提醒关键词
  static const List<String> _reminderKeywords = [
    '提醒', '别忘', '记得', '记得要', '不要忘',
  ];

  // 快速记事关键词
  static const List<String> _quickMemoKeywords = [
    '记一下', '记录一下', '快速记',
  ];

  // ==================== 主解析方法 ====================

  /// 解析语音文本，返回意图
  VoiceIntent parse(String text) {
    if (text.isEmpty) {
      return VoiceIntent(
        type: IntentType.unknown,
        originalText: text,
      );
    }

    final cleanText = text.trim();

    // 按优先级匹配意图
    // 1. 查询进度（通常以问号开头或包含疑问词）
    if (_isQueryIntent(cleanText)) {
      return _parseQueryIntent(cleanText);
    }

    // 2. 创建提醒
    if (_isReminderIntent(cleanText)) {
      return _parseReminderIntent(cleanText);
    }

    // 3. 运动打卡
    if (_isWorkoutIntent(cleanText)) {
      return _parseWorkoutIntent(cleanText);
    }

    // 4. 创建笔记/快速记事
    if (_isNoteIntent(cleanText)) {
      return _parseNoteIntent(cleanText);
    }

    // 默认返回未知意图
    return VoiceIntent(
      type: IntentType.unknown,
      originalText: text,
    );
  }

  /// 异步解析（支持更复杂的处理）
  Future<VoiceIntent> parseAsync(String text) async {
    // 可以在这里添加 AI 增强的解析逻辑
    // 目前使用同步解析
    return parse(text);
  }

  // ==================== 意图检测 ====================

  /// 检测是否为查询意图
  bool _isQueryIntent(String text) {
    return _containsAny(text, _queryKeywords) ||
           text.contains('?') ||
           text.contains('？') ||
           text.startsWith('我') && _containsAny(text, ['多少', '怎样']);
  }

  /// 检测是否为提醒意图
  bool _isReminderIntent(String text) {
    return _containsAny(text, _reminderKeywords);
  }

  /// 检测是否为运动意图
  bool _isWorkoutIntent(String text) {
    return _containsAny(text, _workoutKeywords);
  }

  /// 检测是否为笔记意图
  bool _isNoteIntent(String text) {
    return _containsAny(text, _noteKeywords) ||
           _containsAny(text, _quickMemoKeywords);
  }

  // ==================== 意图解析 ====================

  /// 解析查询意图
  VoiceIntent _parseQueryIntent(String text) {
    String? queryType;

    // 检测查询类型
    if (text.contains('运动') || text.contains('健身') || text.contains('跑')) {
      queryType = 'workout';
    } else if (text.contains('笔记') || text.contains('任务')) {
      queryType = 'note';
    } else if (text.contains('计划')) {
      queryType = 'plan';
    }

    return VoiceIntent(
      type: IntentType.queryProgress,
      data: {'queryType': queryType},
      originalText: text,
      confidence: 0.85,
    );
  }

  /// 解析提醒意图
  VoiceIntent _parseReminderIntent(String text) {
    // 提取提醒内容
    String content = _extractContent(text, _reminderKeywords);
    DateTime? reminderTime;

    // 尝试提取时间
    reminderTime = _extractTime(text);

    final reminderData = ReminderData(
      content: content,
      time: reminderTime,
    );

    return VoiceIntent(
      type: IntentType.createReminder,
      content: content,
      data: reminderData.toJson(),
      originalText: text,
      confidence: 0.8,
    );
  }

  /// 解析运动意图
  VoiceIntent _parseWorkoutIntent(String text) {
    // 提取运动类型
    final workoutType = _extractWorkoutType(text);

    // 提取运动数据
    final workoutData = _extractWorkoutData(text, workoutType);

    return VoiceIntent(
      type: IntentType.logWorkout,
      workoutType: workoutType,
      data: workoutData.toJson(),
      originalText: text,
      confidence: 0.85,
    );
  }

  /// 解析笔记意图
  VoiceIntent _parseNoteIntent(String text) {
    // 提取笔记内容
    String content = _extractContent(text, _noteKeywords);

    // 检测是否为快速记事
    final isQuickMemo = _containsAny(text, _quickMemoKeywords);

    return VoiceIntent(
      type: isQuickMemo ? IntentType.quickMemo : IntentType.createNote,
      content: content,
      originalText: text,
      confidence: 0.8,
    );
  }

  // ==================== 数据提取 ====================

  /// 提取运动类型
  WorkoutType _extractWorkoutType(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('跑') && !lowerText.contains('跑步机')) {
      return WorkoutType.running;
    } else if (lowerText.contains('步') || lowerText.contains('走')) {
      return WorkoutType.walking;
    } else if (lowerText.contains('骑') || lowerText.contains('单车')) {
      return WorkoutType.cycling;
    } else if (lowerText.contains('游')) {
      return WorkoutType.swimming;
    } else if (lowerText.contains('瑜伽')) {
      return WorkoutType.yoga;
    } else if (lowerText.contains('球')) {
      if (lowerText.contains('篮')) return WorkoutType.basketball;
      if (lowerText.contains('足')) return WorkoutType.football;
      if (lowerText.contains('羽毛')) return WorkoutType.badminton;
    }

    return WorkoutType.fitness; // 默认健身
  }

  /// 提取运动数据
  WorkoutData _extractWorkoutData(String text, WorkoutType workoutType) {
    double? distance;
    int? duration;
    int? calories;

    // 提取距离（支持"公里"、"千米"、"公里"等）
    final distanceMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:公里|千米|km|KM)').firstMatch(text);
    if (distanceMatch != null) {
      distance = double.tryParse(distanceMatch.group(1)!);
    } else if (text.contains('公里')) {
      // 尝试提取数字+公里的模式
      final simpleMatch = RegExp(r'(\d+)\s*公里').firstMatch(text);
      if (simpleMatch != null) {
        distance = double.tryParse(simpleMatch.group(1)!);
      }
    }

    // 提取时长（支持"分钟"、"小时"等）
    final durationMatch = RegExp(r'(\d+)\s*(?:分钟|分|min)').firstMatch(text);
    if (durationMatch != null) {
      duration = int.tryParse(durationMatch.group(1)!);
    } else {
      final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*小时').firstMatch(text);
      if (hourMatch != null) {
        final hours = double.tryParse(hourMatch.group(1)!);
        duration = hours != null ? (hours * 60).round() : null;
      }
    }

    // 提取卡路里
    final caloriesMatch = RegExp(r'(\d+)\s*(?:卡|卡路里|kcal|KCAL)').firstMatch(text);
    if (caloriesMatch != null) {
      calories = int.tryParse(caloriesMatch.group(1)!);
    }

    // 提取备注
    String? notes = _extractContent(text, ['跑', '运动', '练', '健身']);
    if (notes.isEmpty) {
      notes = _getWorkoutTypeName(workoutType);
    }

    return WorkoutData(
      type: workoutType,
      distance: distance,
      duration: duration,
      calories: calories,
      notes: notes,
    );
  }

  /// 提取时间
  DateTime? _extractTime(String text) {
    final now = DateTime.now();

    // 检测相对时间
    if (text.contains('明天')) {
      return now.add(Duration(days: 1));
    } else if (text.contains('后天')) {
      return now.add(Duration(days: 2));
    } else if (text.contains('下周')) {
      return now.add(Duration(days: 7));
    }

    // 检测具体时间（如"8点"、"下午3点"等）
    final hourMatch = RegExp(r'(\d{1,2})\s*点').firstMatch(text);
    if (hourMatch != null) {
      final hour = int.tryParse(hourMatch.group(1)!);
      if (hour != null && hour >= 0 && hour <= 23) {
        DateTime targetTime = DateTime(now.year, now.month, now.day, hour);

        // 如果时间已过，设置为明天
        if (targetTime.isBefore(now)) {
          targetTime = targetTime.add(Duration(days: 1));
        }

        // 检测分钟
        final minuteMatch = RegExp(r'(\d{1,2})\s*点\s*(\d{1,2})(?:分|分钟)?').firstMatch(text);
        if (minuteMatch != null) {
          final minute = int.tryParse(minuteMatch.group(2)!);
          if (minute != null && minute >= 0 && minute <= 59) {
            targetTime = DateTime(now.year, now.month, now.day, hour, minute);
          }
        }

        return targetTime;
      }
    }

    return null;
  }

  /// 提取内容（去除关键词后的文本）
  String _extractContent(String text, List<String> keywords) {
    String result = text;

    for (final keyword in keywords) {
      result = result.replaceAll(keyword, '');
    }

    // 去除标点和空格
    result = result.replaceAll(RegExp(r'[，。！？、\s]+'), ' ').trim();

    return result;
  }

  // ==================== 辅助方法 ====================

  /// 检测文本是否包含任一关键词
  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// 获取运动类型名称
  String _getWorkoutTypeName(WorkoutType type) {
    switch (type) {
      case WorkoutType.running:
        return '跑步';
      case WorkoutType.walking:
        return '步行';
      case WorkoutType.cycling:
        return '骑行';
      case WorkoutType.swimming:
        return '游泳';
      case WorkoutType.fitness:
        return '健身';
      case WorkoutType.yoga:
        return '瑜伽';
      case WorkoutType.basketball:
        return '篮球';
      case WorkoutType.football:
        return '足球';
      case WorkoutType.badminton:
        return '羽毛球';
      case WorkoutType.other:
        return '其他运动';
    }
  }

  // ==================== 批量解析 ====================

  /// 批量解析多个文本
  List<VoiceIntent> parseBatch(List<String> texts) {
    return texts.map((text) => parse(text)).toList();
  }

  /// 异步批量解析
  Future<List<VoiceIntent>> parseBatchAsync(List<String> texts) async {
    // 并行处理提高性能
    return Future.wait(
      texts.map((text) => parseAsync(text)),
    );
  }
}
