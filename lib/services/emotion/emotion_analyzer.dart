/// 情绪分析服务 - 基于关键词的本地NLP实现
/// 从笔记内容中分析用户的情绪状态

/// 情绪类型枚举
enum EmotionType {
  /// 开心 - 积极正面的情绪
  happy('开心', [
    '开心', '快乐', '高兴', '幸福', '满足', '棒', '好', '不错', '愉快',
    '喜悦', '愉快', '振奋', '兴奋', '喜欢', '爱', '享受', '开心极了',
    '超级开心', '太好了', '真棒', '顺利', '成功', '完成', '做到了',
  ]),

  /// 悲伤 - 消极低落的情绪
  sad('悲伤', [
    '难过', '伤心', '不开心', '沮丧', '失望', '郁闷', '悲伤',
    '痛苦', '难受', '失落', '抑郁', '想哭', '哭', '糟糕', '失败',
    '完蛋', '没希望', '灰心', '丧气', '心碎', '痛心',
  ]),

  /// 焦虑 - 紧张不安的情绪
  anxious('焦虑', [
    '焦虑', '担心', '紧张', '不安', '害怕', '恐惧',
    '恐慌', '忧虑', '发愁', '忐忑', '慌', '担忧', '怕', '可怕',
    '压力大', '承受不了', '受不了', '紧张死了', '担心死',
  ]),

  /// 疲惫 - 身心疲惫的状态
  tired('疲惫', [
    '累', '疲惫', '困', '乏', '没精神', '累死了', '好累',
    '筋疲力尽', '没力气', '无力', '疲劳', '倦', '累瘫', '不想动',
    '休息', '需要休息', '太累了', '身体不适',
  ]),

  /// 压力 - 感到压抑烦躁
  stressed('压力', [
    '压力', '烦', '烦躁', '压抑', '崩溃', '受不了',
    '烦死了', '太烦了', '暴躁', '郁闷', '憋屈', '压抑',
    '想发泄', '憋闷', '压力山大', '心烦',
  ]),

  /// 平静 - 平和安静的状态
  calm('平静', [
    '平静', '安静', '放松', '轻松', '淡定', '宁静',
    '平和', '安详', '舒适', '惬意', '悠闲', '自在',
    '平静的一天', '平淡', '安稳', '舒心',
  ]),

  /// 兴奋 - 高度积极活跃
  excited('兴奋', [
    '兴奋', '激动', '期待', '充满干劲', '有活力', '活力四射',
    '精神饱满', '热情', '热血', '斗志昂扬', '跃跃欲试',
    '超级棒', '太爽了', '给力', '正能量',
  ]);

  final String displayName;
  final List<String> keywords;

  const EmotionType(this.displayName, this.keywords);

  /// 从字符串获取情绪类型
  static EmotionType fromString(String value) {
    return EmotionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmotionType.calm,
    );
  }

  /// 获取情绪对应的颜色
  String get colorHex {
    switch (this) {
      case EmotionType.happy:
        return '#FFD700'; // 金黄色
      case EmotionType.sad:
        return '#6B7280'; // 灰色
      case EmotionType.anxious:
        return '#F59E0B'; // 橙色
      case EmotionType.tired:
        return '#8B5CF6'; // 紫色
      case EmotionType.stressed:
        return '#EF4444'; // 红色
      case EmotionType.calm:
        return '#3B82F6'; // 蓝色
      case EmotionType.excited:
        return '#EC4899'; // 粉色
    }
  }
}

/// 情绪分析结果
class EmotionResult {
  /// 主要情绪类型
  final EmotionType emotion;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 匹配到的关键词
  final List<String> matchedKeywords;

  /// 所有检测到的情绪及分数（用于次要情绪分析）
  final Map<EmotionType, double> allScores;

  const EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.matchedKeywords,
    required this.allScores,
  });

  @override
  String toString() {
    return 'EmotionResult(emotion: $emotion, confidence: $confidence, keywords: $matchedKeywords)';
  }
}

/// 情绪分析器 - 基于关键词频率的情绪分析
class EmotionAnalyzer {
  /// 分析文本内容，返回情绪分析结果
  ///
  /// 算法说明：
  /// 1. 统计文本中各情绪关键词的出现次数
  /// 2. 计算每种情绪的得分（关键词数量 × 权重）
  /// 3. 选择得分最高的情绪作为主要情绪
  /// 4. 置信度 = 最高分 / (最高分 + 次高分)
  static EmotionResult analyze(String text) {
    if (text.isEmpty) {
      // 空文本默认返回平静情绪
      return const EmotionResult(
        emotion: EmotionType.calm,
        confidence: 0.5,
        matchedKeywords: [],
        allScores: {},
      );
    }

    final lowerText = text.toLowerCase();
    final scores = <EmotionType, double>{};
    final allMatchedKeywords = <EmotionType, List<String>>{};

    // 计算每种情绪的得分
    for (final emotion in EmotionType.values) {
      int count = 0;
      final matched = <String>[];

      for (final keyword in emotion.keywords) {
        final keywordLower = keyword.toLowerCase();
        // 使用正则表达式匹配整个单词，避免部分匹配
        final pattern = RegExp('(?<!\\w)$keywordLower(?!\\w)');
        final matches = pattern.allMatches(lowerText);
        final matchCount = matches.length;
        if (matchCount > 0) {
          count += matchCount;
          matched.add(keyword);
        }
      }

      // 如果有关键词匹配，记录分数
      if (count > 0) {
        scores[emotion] = count.toDouble();
        allMatchedKeywords[emotion] = matched;
      }
    }

    // 如果没有检测到任何情绪关键词
    if (scores.isEmpty) {
      return const EmotionResult(
        emotion: EmotionType.calm,
        confidence: 0.3,
        matchedKeywords: [],
        allScores: {},
      );
    }

    // 按分数排序
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 获取主要情绪
    final primaryEmotion = sortedEntries.first.key;
    final primaryScore = sortedEntries.first.value;
    final primaryKeywords = allMatchedKeywords[primaryEmotion]!;

    // 计算置信度
    double confidence;
    if (sortedEntries.length == 1) {
      confidence = 0.8;
    } else {
      final secondScore = sortedEntries[1].value;
      confidence = (primaryScore / (primaryScore + secondScore)).clamp(0.5, 1.0);
    }

    return EmotionResult(
      emotion: primaryEmotion,
      confidence: confidence,
      matchedKeywords: primaryKeywords,
      allScores: scores,
    );
  }

  /// 批量分析多条文本
  static List<EmotionResult> analyzeBatch(List<String> texts) {
    return texts.map((text) => analyze(text)).toList();
  }

  /// 获取文本的情绪摘要
  static String getSummary(EmotionResult result) {
    final emotion = result.emotion;
    final keywords = result.matchedKeywords;

    if (keywords.isEmpty) {
      return '情绪状态：${emotion.displayName}';
    }

    return '检测到${emotion.displayName}情绪，关键词：${keywords.join('、')}';
  }

  /// 计算情绪的积极程度 (-1.0 到 1.0)
  /// 负值表示消极，正值表示积极
  static double getSentimentScore(EmotionType emotion) {
    switch (emotion) {
      case EmotionType.happy:
      case EmotionType.excited:
        return 1.0;
      case EmotionType.calm:
        return 0.5;
      case EmotionType.tired:
        return -0.2;
      case EmotionType.anxious:
      case EmotionType.stressed:
        return -0.7;
      case EmotionType.sad:
        return -1.0;
    }
  }

  /// 获取情绪建议
  static String getSuggestion(EmotionType emotion) {
    switch (emotion) {
      case EmotionType.happy:
        return '保持好心情，继续保持积极的生活方式！';
      case EmotionType.sad:
        return '尝试户外活动或轻度运动，有助于改善心情。';
      case EmotionType.anxious:
        return '建议进行呼吸练习或冥想，帮助缓解焦虑。';
      case EmotionType.tired:
        return '身体需要休息，保证充足睡眠很重要。';
      case EmotionType.stressed:
        return '尝试放松运动如瑜伽或拉伸，释放压力。';
      case EmotionType.calm:
        return '状态不错，适合进行各类运动。';
      case EmotionType.excited:
        return '能量满满，适合挑战高强度运动！';
    }
  }
}
