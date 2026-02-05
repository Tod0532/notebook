/// 计划模板数据模型
/// 用于预设计划模板，方便用户快速创建常见类型的计划

/// 计划模板分类
enum PlanTemplateCategory {
  /// 学习类
  study('study', '学习'),

  /// 健身类
  fitness('fitness', '健身'),

  /// 工作类
  work('work', '工作'),

  /// 生活类
  life('life', '生活');

  final String value;
  final String label;

  const PlanTemplateCategory(this.value, this.label);

  static PlanTemplateCategory fromValue(String value) {
    return PlanTemplateCategory.values.firstWhere(
      (cat) => cat.value == value,
      orElse: () => PlanTemplateCategory.life,
    );
  }
}

/// 模板难度
enum TemplateDifficulty {
  /// 简单
  easy('easy', '简单'),

  /// 中等
  medium('medium', '中等'),

  /// 困难
  hard('hard', '困难');

  final String value;
  final String label;

  const TemplateDifficulty(this.value, this.label);

  static TemplateDifficulty fromValue(String value) {
    return TemplateDifficulty.values.firstWhere(
      (diff) => diff.value == value,
      orElse: () => TemplateDifficulty.medium,
    );
  }
}

/// 计划模板
class PlanTemplate {
  /// 模板ID
  final String id;

  /// 模板名称
  final String name;

  /// 模板描述
  final String description;

  /// 模板分类
  final PlanTemplateCategory category;

  /// 模板任务列表
  final List<TemplateTask> tasks;

  /// 预估天数
  final int estimatedDays;

  /// 难度等级
  final TemplateDifficulty difficulty;

  /// 图标（可选）
  final String? icon;

  /// 推荐理由
  final String? recommendation;

  const PlanTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tasks,
    required this.estimatedDays,
    required this.difficulty,
    this.icon,
    this.recommendation,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.value,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'estimatedDays': estimatedDays,
      'difficulty': difficulty.value,
      'icon': icon,
      'recommendation': recommendation,
    };
  }

  /// 从 JSON 转换
  factory PlanTemplate.fromJson(Map<String, dynamic> json) {
    return PlanTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: PlanTemplateCategory.fromValue(json['category'] as String),
      tasks: (json['tasks'] as List)
          .map((t) => TemplateTask.fromJson(t as Map<String, dynamic>))
          .toList(),
      estimatedDays: json['estimatedDays'] as int,
      difficulty: TemplateDifficulty.fromValue(json['difficulty'] as String),
      icon: json['icon'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }

  /// 复制并修改部分属性
  PlanTemplate copyWith({
    String? id,
    String? name,
    String? description,
    PlanTemplateCategory? category,
    List<TemplateTask>? tasks,
    int? estimatedDays,
    TemplateDifficulty? difficulty,
    String? icon,
    String? recommendation,
  }) {
    return PlanTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      tasks: tasks ?? this.tasks,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      difficulty: difficulty ?? this.difficulty,
      icon: icon ?? this.icon,
      recommendation: recommendation ?? this.recommendation,
    );
  }
}

/// 模板任务
class TemplateTask {
  /// 任务标题
  final String title;

  /// 任务描述（可选）
  final String? description;

  /// 顺序
  final int order;

  /// 任务类型（可选）
  final String? taskType;

  /// 是否为里程碑任务
  final bool isMilestone;

  /// 任务标签（可选）
  final List<String>? tags;

  const TemplateTask({
    required this.title,
    this.description,
    required this.order,
    this.taskType,
    this.isMilestone = false,
    this.tags,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'order': order,
      'taskType': taskType,
      'isMilestone': isMilestone,
      'tags': tags,
    };
  }

  /// 从 JSON 转换
  factory TemplateTask.fromJson(Map<String, dynamic> json) {
    return TemplateTask(
      title: json['title'] as String,
      description: json['description'] as String?,
      order: json['order'] as int,
      taskType: json['taskType'] as String?,
      isMilestone: json['isMilestone'] as bool? ?? false,
      tags: json['tags'] as List<String>?,
    );
  }

  /// 复制并修改部分属性
  TemplateTask copyWith({
    String? title,
    String? description,
    int? order,
    String? taskType,
    bool? isMilestone,
    List<String>? tags,
  }) {
    return TemplateTask(
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      taskType: taskType ?? this.taskType,
      isMilestone: isMilestone ?? this.isMilestone,
      tags: tags ?? this.tags,
    );
  }
}
