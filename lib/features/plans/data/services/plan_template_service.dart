/// 计划模板库服务
/// 提供预设计划模板的查询、筛选和搜索功能

import 'package:flutter/foundation.dart';
import 'package:thick_notepad/features/plans/data/models/plan_template.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// 计划模板库服务
class PlanTemplateService {
  /// 获取所有模板
  static List<PlanTemplate> getAllTemplates() {
    return [
      ..._getStudyTemplates(),
      ..._getFitnessTemplates(),
      ..._getWorkTemplates(),
      ..._getLifeTemplates(),
    ];
  }

  /// 按分类获取模板
  static List<PlanTemplate> getTemplatesByCategory(PlanTemplateCategory category) {
    return getAllTemplates().where((t) => t.category == category).toList();
  }

  /// 按难度获取模板
  static List<PlanTemplate> getTemplatesByDifficulty(TemplateDifficulty difficulty) {
    return getAllTemplates().where((t) => t.difficulty == difficulty).toList();
  }

  /// 搜索模板
  static List<PlanTemplate> searchTemplates(String query) {
    final lowercaseQuery = query.toLowerCase();
    return getAllTemplates().where((t) {
      return t.name.toLowerCase().contains(lowercaseQuery) ||
          t.description.toLowerCase().contains(lowercaseQuery) ||
          t.tasks.any((task) => task.title.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// 根据ID获取模板
  static PlanTemplate? getTemplateById(String id) {
    try {
      return getAllTemplates().firstWhere((t) => t.id == id);
    } catch (e) {
      debugPrint('模板未找到: $id');
      return null;
    }
  }

  /// 获取推荐模板
  static List<PlanTemplate> getRecommendedTemplates({int limit = 3}) {
    final templates = getAllTemplates().where((t) => t.recommendation != null).toList();
    templates.shuffle();
    return templates.take(limit).toList();
  }

  /// 从模板创建计划数据
  static PlansCompanion createPlanFromTemplate(PlanTemplate template) {
    final now = DateTime.now();
    final targetDate = now.add(Duration(days: template.estimatedDays));

    return PlansCompanion.insert(
      title: template.name,
      category: template.category.value,
      description: drift.Value(template.description),
      startDate: now,
      targetDate: targetDate,
    );
  }

  /// 从模板创建任务数据列表
  static List<PlanTasksCompanion> createTasksFromTemplate(
    PlanTemplate template,
    int planId,
  ) {
    final now = DateTime.now();
    final daysPerTask = template.estimatedDays / template.tasks.length;

    return template.tasks.asMap().entries.map((entry) {
      final index = entry.key;
      final task = entry.value;

      // 根据任务顺序分配日期
      final scheduledDate = now.add(Duration(days: (index * daysPerTask).floor()));

      return PlanTasksCompanion.insert(
        planId: planId,
        title: task.title,
        scheduledDate: scheduledDate,
        taskType: task.taskType ?? template.category.value,
        isCompleted: const drift.Value(false),
      );
    }).toList();
  }

  // ==================== 学习类模板 ====================

  static List<PlanTemplate> _getStudyTemplates() {
    return [
      PlanTemplate(
        id: 'exam_prep_30',
        name: '考试复习计划（30天）',
        description: '系统化的30天考试复习计划，帮助你高效备考，覆盖基础巩固、重点突破和模拟冲刺阶段。',
        category: PlanTemplateCategory.study,
        estimatedDays: 30,
        difficulty: TemplateDifficulty.hard,
        icon: 'school',
        recommendation: '适合即将参加重要考试的用户，科学安排复习节奏',
        tasks: [
          TemplateTask(
            title: '制定详细复习大纲',
            description: '列出所有考试科目和重点内容',
            order: 1,
            taskType: 'study',
            isMilestone: true,
            tags: ['规划', '基础'],
          ),
          TemplateTask(
            title: '第一轮：基础知识复习',
            description: '系统梳理所有基础知识，查漏补缺',
            order: 2,
            taskType: 'study',
            tags: ['复习', '基础'],
          ),
          TemplateTask(
            title: '完成历年真题（近3年）',
            description: '熟悉考试题型和出题规律',
            order: 3,
            taskType: 'study',
            tags: ['真题', '练习'],
          ),
          TemplateTask(
            title: '第二轮：重点难点突破',
            description: '针对薄弱环节进行专项训练',
            order: 4,
            taskType: 'study',
            tags: ['重点', '突破'],
          ),
          TemplateTask(
            title: '整理错题本',
            description: '记录和分析所有错题，避免重复犯错',
            order: 5,
            taskType: 'study',
            tags: ['总结', '反思'],
          ),
          TemplateTask(
            title: '第三轮：模拟考试训练',
            description: '全真模拟考试环境，检验复习成果',
            order: 6,
            taskType: 'study',
            isMilestone: true,
            tags: ['模拟', '冲刺'],
          ),
          TemplateTask(
            title: '最后冲刺：回归基础',
            description: '回顾重点公式、概念和错题',
            order: 7,
            taskType: 'study',
            tags: ['冲刺', '基础'],
          ),
          TemplateTask(
            title: '调整心态，准备考试',
            description: '保持良好作息，以最佳状态迎接考试',
            order: 8,
            taskType: 'study',
            tags: ['心态', '准备'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'skill_learn_21',
        name: '技能学习计划（21天）',
        description: '基于21天习惯养成原理，帮助你系统学习一项新技能，从零基础到入门掌握。',
        category: PlanTemplateCategory.study,
        estimatedDays: 21,
        difficulty: TemplateDifficulty.medium,
        icon: 'code',
        recommendation: '21天养成一个习惯，适合学习编程、设计等新技能',
        tasks: [
          TemplateTask(
            title: '确定学习目标和资源',
            description: '明确要学什么，收集学习资料',
            order: 1,
            taskType: 'study',
            isMilestone: true,
            tags: ['规划', '目标'],
          ),
          TemplateTask(
            title: '第1-7天：基础入门',
            description: '学习基本概念和操作，每天至少1小时',
            order: 2,
            taskType: 'study',
            tags: ['基础', '入门'],
          ),
          TemplateTask(
            title: '第8-14天：进阶实践',
            description: '完成一个小项目，边学边做',
            order: 3,
            taskType: 'study',
            tags: ['进阶', '实践'],
          ),
          TemplateTask(
            title: '第15-21天：巩固提升',
            description: '深入学习高级技巧，完善项目',
            order: 4,
            taskType: 'study',
            tags: ['巩固', '提升'],
          ),
          TemplateTask(
            title: '总结学习成果',
            description: '整理学习笔记，展示你的作品',
            order: 5,
            taskType: 'study',
            isMilestone: true,
            tags: ['总结', '展示'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'english_learn_90',
        name: '英语学习计划（90天）',
        description: '90天英语综合提升计划，涵盖听说读写四个方面，适合有一定基础希望进一步提高的学习者。',
        category: PlanTemplateCategory.study,
        estimatedDays: 90,
        difficulty: TemplateDifficulty.hard,
        icon: 'language',
        recommendation: '三个月系统提升英语能力，适合备考或工作需要',
        tasks: [
          TemplateTask(
            title: '英语水平自测',
            description: '测试当前英语水平，制定个性化学习计划',
            order: 1,
            taskType: 'study',
            isMilestone: true,
            tags: ['测评', '规划'],
          ),
          TemplateTask(
            title: '第1月：词汇积累',
            description: '每天记忆30个新单词，使用间隔重复法',
            order: 2,
            taskType: 'study',
            tags: ['词汇', '记忆'],
          ),
          TemplateTask(
            title: '每日听力训练',
            description: '每天至少30分钟听力练习',
            order: 3,
            taskType: 'study',
            tags: ['听力', '练习'],
          ),
          TemplateTask(
            title: '第2月：阅读强化',
            description: '每周阅读2篇英文文章，积累表达',
            order: 4,
            taskType: 'study',
            tags: ['阅读', '强化'],
          ),
          TemplateTask(
            title: '口语练习计划',
            description: '每周至少3次口语练习',
            order: 5,
            taskType: 'study',
            tags: ['口语', '练习'],
          ),
          TemplateTask(
            title: '第3月：写作提升',
            description: '每周完成1篇英语写作',
            order: 6,
            taskType: 'study',
            tags: ['写作', '提升'],
          ),
          TemplateTask(
            title: '综合模拟测试',
            description: '进行一次全面的英语能力测试',
            order: 7,
            taskType: 'study',
            isMilestone: true,
            tags: ['测试', '总结'],
          ),
        ],
      ),
    ];
  }

  // ==================== 健身类模板 ====================

  static List<PlanTemplate> _getFitnessTemplates() {
    return [
      PlanTemplate(
        id: 'fat_loss_30',
        name: '减脂计划（30天）',
        description: '科学减脂30天计划，结合合理饮食和运动，帮助你健康减脂，塑造理想身材。',
        category: PlanTemplateCategory.fitness,
        estimatedDays: 30,
        difficulty: TemplateDifficulty.medium,
        icon: 'fitness_center',
        recommendation: '健康减脂不反弹，结合饮食和运动',
        tasks: [
          TemplateTask(
            title: '记录初始体重和体脂率',
            description: '拍照记录，设定目标',
            order: 1,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['记录', '目标'],
          ),
          TemplateTask(
            title: '制定饮食计划',
            description: '计算每日所需热量，规划健康饮食',
            order: 2,
            taskType: 'fitness',
            tags: ['饮食', '规划'],
          ),
          TemplateTask(
            title: '第1周：适应期训练',
            description: '每天30分钟中等强度有氧运动',
            order: 3,
            taskType: 'fitness',
            tags: ['有氧', '适应'],
          ),
          TemplateTask(
            title: '第2周：加量期训练',
            description: '每天45分钟有氧+力量训练',
            order: 4,
            taskType: 'fitness',
            tags: ['力量', '加量'],
          ),
          TemplateTask(
            title: '第3周：强化期训练',
            description: '加入HIIT训练，提升燃脂效率',
            order: 5,
            taskType: 'fitness',
            tags: ['HIIT', '强化'],
          ),
          TemplateTask(
            title: '第4周：冲刺期训练',
            description: '增加训练强度，冲刺最后阶段',
            order: 6,
            taskType: 'fitness',
            tags: ['冲刺', '强化'],
          ),
          TemplateTask(
            title: '测量最终成果',
            description: '对比初始数据，评估效果',
            order: 7,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['测量', '总结'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'muscle_gain_60',
        name: '增肌计划（60天）',
        description: '60天增肌训练计划，科学安排训练和营养，帮助你有效增加肌肉量。',
        category: PlanTemplateCategory.fitness,
        estimatedDays: 60,
        difficulty: TemplateDifficulty.hard,
        icon: 'accessibility_new',
        recommendation: '系统增肌训练，适合健身爱好者',
        tasks: [
          TemplateTask(
            title: '制定增肌目标和训练计划',
            description: '确定重点训练部位和训练频率',
            order: 1,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['规划', '目标'],
          ),
          TemplateTask(
            title: '计算蛋白质摄入量',
            description: '增肌期需要足够的蛋白质支持',
            order: 2,
            taskType: 'fitness',
            tags: ['营养', '蛋白质'],
          ),
          TemplateTask(
            title: '第1-4周：基础力量训练',
            description: '每周4次力量训练，全面发展',
            order: 3,
            taskType: 'fitness',
            tags: ['力量', '基础'],
          ),
          TemplateTask(
            title: '第5-8周：分化训练',
            description: '采用分化训练，重点突破薄弱部位',
            order: 4,
            taskType: 'fitness',
            tags: ['分化', '突破'],
          ),
          TemplateTask(
            title: '定期测量和调整',
            description: '每2周测量体重和围度，调整计划',
            order: 5,
            taskType: 'fitness',
            tags: ['测量', '调整'],
          ),
          TemplateTask(
            title: '最终评估',
            description: '对比训练前后的变化',
            order: 6,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['评估', '总结'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'habit_form_21',
        name: '习惯养成计划（21天）',
        description: '21天养成一个好习惯，帮你建立健康的生活方式。',
        category: PlanTemplateCategory.fitness,
        estimatedDays: 21,
        difficulty: TemplateDifficulty.easy,
        icon: 'check_circle',
        recommendation: '从小习惯开始，21天养成受益终身的好习惯',
        tasks: [
          TemplateTask(
            title: '选择要养成的习惯',
            description: '选择一个具体的、可执行的习惯',
            order: 1,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['规划', '目标'],
          ),
          TemplateTask(
            title: '第1-7天：起步阶段',
            description: '每天坚持，建立初步习惯',
            order: 2,
            taskType: 'fitness',
            tags: ['坚持', '起步'],
          ),
          TemplateTask(
            title: '第8-14天：强化阶段',
            description: '克服困难，巩固习惯',
            order: 3,
            taskType: 'fitness',
            tags: ['强化', '坚持'],
          ),
          TemplateTask(
            title: '第15-21天：稳定阶段',
            description: '习惯逐渐稳定，准备长期坚持',
            order: 4,
            taskType: 'fitness',
            tags: ['稳定', '坚持'],
          ),
          TemplateTask(
            title: '习惯养成成功',
            description: '庆祝你的成功，继续保持',
            order: 5,
            taskType: 'fitness',
            isMilestone: true,
            tags: ['成功', '庆祝'],
          ),
        ],
      ),
    ];
  }

  // ==================== 工作类模板 ====================

  static List<PlanTemplate> _getWorkTemplates() {
    return [
      PlanTemplate(
        id: 'project_dev_14',
        name: '项目开发计划（14天）',
        description: '14天敏捷项目开发计划，适合中小型项目的快速开发和交付。',
        category: PlanTemplateCategory.work,
        estimatedDays: 14,
        difficulty: TemplateDifficulty.medium,
        icon: 'work',
        recommendation: '敏捷开发模式，快速完成项目交付',
        tasks: [
          TemplateTask(
            title: '需求分析和任务拆解',
            description: '明确项目需求，拆解开发任务',
            order: 1,
            taskType: 'work',
            isMilestone: true,
            tags: ['需求', '规划'],
          ),
          TemplateTask(
            title: '第1-3天：设计和原型',
            description: '完成UI设计和交互原型',
            order: 2,
            taskType: 'work',
            tags: ['设计', '原型'],
          ),
          TemplateTask(
            title: '第4-8天：核心功能开发',
            description: '开发项目核心功能模块',
            order: 3,
            taskType: 'work',
            tags: ['开发', '核心'],
          ),
          TemplateTask(
            title: '第9-11天：完善和优化',
            description: '完善功能细节，优化用户体验',
            order: 4,
            taskType: 'work',
            tags: ['完善', '优化'],
          ),
          TemplateTask(
            title: '第12-13天：测试和修复',
            description: '全面测试，修复bug',
            order: 5,
            taskType: 'work',
            tags: ['测试', '修复'],
          ),
          TemplateTask(
            title: '第14天：部署和交付',
            description: '项目部署，准备交付文档',
            order: 6,
            taskType: 'work',
            isMilestone: true,
            tags: ['部署', '交付'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'quarter_goal_90',
        name: '季度目标计划（90天）',
        description: '90天季度目标规划，帮助你设定和实现长期目标。',
        category: PlanTemplateCategory.work,
        estimatedDays: 90,
        difficulty: TemplateDifficulty.medium,
        icon: 'flag',
        recommendation: '季度目标管理，适合职场和个人发展',
        tasks: [
          TemplateTask(
            title: '设定季度核心目标',
            description: '设定3-5个最重要的季度目标',
            order: 1,
            taskType: 'work',
            isMilestone: true,
            tags: ['目标', '规划'],
          ),
          TemplateTask(
            title: '第1月：目标启动',
            description: '制定详细行动计划，开始执行',
            order: 2,
            taskType: 'work',
            tags: ['启动', '执行'],
          ),
          TemplateTask(
            title: '第2月：持续推进',
            description: '保持动力，克服困难',
            order: 3,
            taskType: 'work',
            tags: ['推进', '坚持'],
          ),
          TemplateTask(
            title: '月度回顾和调整',
            description: '每月回顾进度，必要时调整计划',
            order: 4,
            taskType: 'work',
            tags: ['回顾', '调整'],
          ),
          TemplateTask(
            title: '第3月：冲刺收尾',
            description: '全力冲刺，确保目标达成',
            order: 5,
            taskType: 'work',
            tags: ['冲刺', '收尾'],
          ),
          TemplateTask(
            title: '季度总结和复盘',
            description: '总结成果和经验，规划下一季度',
            order: 6,
            taskType: 'work',
            isMilestone: true,
            tags: ['总结', '复盘'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'weekly_work_7',
        name: '周工作计划（7天）',
        description: '一周工作计划模板，帮助你高效安排每周工作。',
        category: PlanTemplateCategory.work,
        estimatedDays: 7,
        difficulty: TemplateDifficulty.easy,
        icon: 'calendar_today',
        recommendation: '高效管理每周工作，提升工作效率',
        tasks: [
          TemplateTask(
            title: '周一：规划本周任务',
            description: '列出本周要完成的所有任务',
            order: 1,
            taskType: 'work',
            isMilestone: true,
            tags: ['规划', '任务'],
          ),
          TemplateTask(
            title: '周二-周四：专注执行',
            description: '按计划完成任务，避免拖延',
            order: 2,
            taskType: 'work',
            tags: ['执行', '专注'],
          ),
          TemplateTask(
            title: '周五：进度检查',
            description: '检查本周任务完成情况',
            order: 3,
            taskType: 'work',
            tags: ['检查', '进度'],
          ),
          TemplateTask(
            title: '周六：收尾工作',
            description: '完成未完成的任务',
            order: 4,
            taskType: 'work',
            tags: ['收尾', '完成'],
          ),
          TemplateTask(
            title: '周日：休息和规划',
            description: '充分休息，为下周做准备',
            order: 5,
            taskType: 'work',
            isMilestone: true,
            tags: ['休息', '规划'],
          ),
        ],
      ),
    ];
  }

  // ==================== 生活类模板 ====================

  static List<PlanTemplate> _getLifeTemplates() {
    return [
      PlanTemplate(
        id: 'early_sleep_14',
        name: '早睡早起计划（14天）',
        description: '14天早睡早起挑战，帮你调整作息，养成健康的生活习惯。',
        category: PlanTemplateCategory.life,
        estimatedDays: 14,
        difficulty: TemplateDifficulty.medium,
        icon: 'bedtime',
        recommendation: '改善睡眠质量，提升精神状态',
        tasks: [
          TemplateTask(
            title: '设定目标作息时间',
            description: '确定理想的入睡和起床时间',
            order: 1,
            taskType: 'life',
            isMilestone: true,
            tags: ['规划', '目标'],
          ),
          TemplateTask(
            title: '准备睡眠环境',
            description: '调整卧室环境，准备助眠物品',
            order: 2,
            taskType: 'life',
            tags: ['环境', '准备'],
          ),
          TemplateTask(
            title: '第1-7天：调整期',
            description: '每天提前15分钟睡觉，逐步调整',
            order: 3,
            taskType: 'life',
            tags: ['调整', '适应'],
          ),
          TemplateTask(
            title: '建立睡前仪式',
            description: '培养固定的睡前习惯',
            order: 4,
            taskType: 'life',
            tags: ['习惯', '仪式'],
          ),
          TemplateTask(
            title: '第8-14天：巩固期',
            description: '坚持目标作息，巩固习惯',
            order: 5,
            taskType: 'life',
            tags: ['巩固', '坚持'],
          ),
          TemplateTask(
            title: '评估睡眠改善',
            description: '记录睡眠质量和精神状态变化',
            order: 6,
            taskType: 'life',
            isMilestone: true,
            tags: ['评估', '总结'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'reading_30',
        name: '阅读计划（30天）',
        description: '30天阅读挑战，培养阅读习惯，拓宽知识视野。',
        category: PlanTemplateCategory.life,
        estimatedDays: 30,
        difficulty: TemplateDifficulty.easy,
        icon: 'menu_book',
        recommendation: '每天30分钟，30天养成阅读习惯',
        tasks: [
          TemplateTask(
            title: '选择阅读书目',
            description: '选择2-3本想读的书',
            order: 1,
            taskType: 'life',
            isMilestone: true,
            tags: ['规划', '选书'],
          ),
          TemplateTask(
            title: '设定阅读时间',
            description: '确定每天固定的阅读时段',
            order: 2,
            taskType: 'life',
            tags: ['规划', '时间'],
          ),
          TemplateTask(
            title: '第1-10天：启动阅读',
            description: '每天阅读30分钟，培养阅读习惯',
            order: 3,
            taskType: 'life',
            tags: ['阅读', '习惯'],
          ),
          TemplateTask(
            title: '第11-20天：深入阅读',
            description: '增加阅读时间到45分钟',
            order: 4,
            taskType: 'life',
            tags: ['阅读', '深入'],
          ),
          TemplateTask(
            title: '记录阅读笔记',
            description: '记录有启发的内容和心得',
            order: 5,
            taskType: 'life',
            tags: ['笔记', '心得'],
          ),
          TemplateTask(
            title: '第21-30天：完成阅读',
            description: '完成至少一本书的阅读',
            order: 6,
            taskType: 'life',
            tags: ['阅读', '完成'],
          ),
          TemplateTask(
            title: '分享阅读收获',
            description: '总结阅读心得，分享给朋友',
            order: 7,
            taskType: 'life',
            isMilestone: true,
            tags: ['分享', '总结'],
          ),
        ],
      ),
      PlanTemplate(
        id: 'saving_90',
        name: '存钱计划（90天）',
        description: '90天存钱挑战，帮助你培养理财意识，积累储蓄。',
        category: PlanTemplateCategory.life,
        estimatedDays: 90,
        difficulty: TemplateDifficulty.medium,
        icon: 'savings',
        recommendation: '三个月养成理财习惯，积累第一桶金',
        tasks: [
          TemplateTask(
            title: '分析收支情况',
            description: '记录近期收支，了解消费习惯',
            order: 1,
            taskType: 'life',
            isMilestone: true,
            tags: ['分析', '财务'],
          ),
          TemplateTask(
            title: '设定存钱目标',
            description: '确定90天存钱金额目标',
            order: 2,
            taskType: 'life',
            tags: ['目标', '规划'],
          ),
          TemplateTask(
            title: '制定预算计划',
            description: '规划每月各项支出预算',
            order: 3,
            taskType: 'life',
            tags: ['预算', '规划'],
          ),
          TemplateTask(
            title: '第1月：减少不必要支出',
            description: '识别并减少非必要消费',
            order: 4,
            taskType: 'life',
            tags: ['节约', '消费'],
          ),
          TemplateTask(
            title: '建立储蓄账户',
            description: '开设专门的储蓄账户',
            order: 5,
            taskType: 'life',
            tags: ['储蓄', '账户'],
          ),
          TemplateTask(
            title: '第2月：增加储蓄比例',
            description: '提高每月储蓄金额',
            order: 6,
            taskType: 'life',
            tags: ['储蓄', '增加'],
          ),
          TemplateTask(
            title: '寻找额外收入来源',
            description: '考虑副业或兼职增加收入',
            order: 7,
            taskType: 'life',
            tags: ['收入', '副业'],
          ),
          TemplateTask(
            title: '第3月：冲刺目标',
            description: '全力冲刺存钱目标',
            order: 8,
            taskType: 'life',
            tags: ['冲刺', '目标'],
          ),
          TemplateTask(
            title: '总结存钱成果',
            description: '评估存钱成果，规划下一步',
            order: 9,
            taskType: 'life',
            isMilestone: true,
            tags: ['总结', '规划'],
          ),
        ],
      ),
    ];
  }

  /// 获取所有分类
  static List<PlanTemplateCategory> getAllCategories() {
    return PlanTemplateCategory.values;
  }

  /// 获取所有难度等级
  static List<TemplateDifficulty> getAllDifficulties() {
    return TemplateDifficulty.values;
  }
}
