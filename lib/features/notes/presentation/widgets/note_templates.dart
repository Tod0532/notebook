/// 笔记模板管理

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';

/// 笔记模板
class NoteTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final String Function(Map<String, dynamic> params) contentBuilder;

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.contentBuilder,
  });

  /// 生成模板内容
  String build([Map<String, dynamic> params = const {}]) {
    return contentBuilder(params);
  }
}

/// 预设模板
class PresetTemplates {
  static const List<NoteTemplate> all = [
    // 日常记录模板
    NoteTemplate(
      id: 'daily',
      name: '日记',
      description: '记录每日生活',
      icon: '📔',
      color: Color(0xFF6366F1),
      contentBuilder: _buildDaily,
    ),

    // 会议记录模板
    NoteTemplate(
      id: 'meeting',
      name: '会议',
      description: '会议记录模板',
      icon: '👥',
      color: Color(0xFF3B82F6),
      contentBuilder: _buildMeeting,
    ),

    // 学习笔记模板
    NoteTemplate(
      id: 'study',
      name: '学习',
      description: '学习笔记模板',
      icon: '📚',
      color: Color(0xFF10B981),
      contentBuilder: _buildStudy,
    ),

    // 项目计划模板
    NoteTemplate(
      id: 'project',
      name: '项目计划',
      description: '项目规划模板',
      icon: '📋',
      color: Color(0xFFF59E0B),
      contentBuilder: _buildProject,
    ),

    // 待办清单模板
    NoteTemplate(
      id: 'todo',
      name: '待办清单',
      description: '待办事项清单',
      icon: '✅',
      color: Color(0xFF8B5CF6),
      contentBuilder: _buildTodo,
    ),

    // 读书笔记模板
    NoteTemplate(
      id: 'reading',
      name: '读书笔记',
      description: '读书心得记录',
      icon: '📖',
      color: Color(0xFFEC4899),
      contentBuilder: _buildReading,
    ),

    // 旅行计划模板
    NoteTemplate(
      id: 'travel',
      name: '旅行计划',
      description: '旅行行程规划',
      icon: '✈️',
      color: Color(0xFF14B8A6),
      contentBuilder: _buildTravel,
    ),

    // 健身记录模板
    NoteTemplate(
      id: 'fitness',
      name: '健身记录',
      description: '运动健身记录',
      icon: '💪',
      color: Color(0xFFEF4444),
      contentBuilder: _buildFitness,
    ),
  ];

  static String _buildDaily(Map<String, dynamic> params) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '''# 日期: $date

## 今日天气

## 今日心情

## 今日完成
-
-
-

## 明日计划
-
-

## 今日感悟

## 其他事项
''';
  }

  static String _buildMeeting(Map<String, dynamic> params) {
    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return '''# 会议记录

**时间**: $date
**地点**:
**参与人**:

## 会议主题

## 会议议程
1.
2.
3.

## 讨论内容

### 议题一
**观点**:
**结论**:

### 议题二
**观点**:
**结论**:

## 行动项
- [ ]
- [ ]
- [ ]

## 下次会议
**时间**:
**地点**:
''';
  }

  static String _buildStudy(Map<String, dynamic> params) {
    return '''# 学习笔记

**科目**:
**章节**:
**日期**: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

## 知识要点

### 要点一
**内容**:
**理解**:
**疑问**:

### 要点二
**内容**:
**理解**:
**疑问**:

## 重点摘录


## 课后总结


## 需要复习的内容

- [ ]
- [ ]
''';
  }

  static String _buildProject(Map<String, dynamic> params) {
    return '''# 项目计划

**项目名称**:
**开始时间**:
**预计完成**:

## 项目目标


## 项目范围


## 任务分解
### 阶段一
- [ ]
- [ ]

### 阶段二
- [ ]
- [ ]

### 阶段三
- [ ]
- [ ]

## 资源需求


## 风险评估


## 进度跟踪
| 阶段 | 计划时间 | 实际时间 | 状态 |
|------|----------|----------|------|
|      |          |          |      |
|      |          |          |      |

## 备注
''';
  }

  static String _buildTodo(Map<String, dynamic> params) {
    return '''# 待办清单
**日期**: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

## 今日任务
- [ ]
- [ ]
- [ ]
- [ ]

## 本周任务
- [ ]
- [ ]
- [ ]

## 长期目标
- [ ]
- [ ]

## 备注
''';
  }

  static String _buildReading(Map<String, dynamic> params) {
    return '''# 读书笔记

**书名**:
**作者**:
**阅读日期**: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

## 书籍简介


## 核心观点

### 观点一


### 观点二


### 观点三


## 精彩摘录


## 个人感悟


## 推荐指数
⭐⭐⭐⭐⭐
''';
  }

  static String _buildTravel(Map<String, dynamic> params) {
    return '''# 旅行计划

**目的地**:
**出发时间**:
**返回时间**:

## 行程安排
### Day 1
**住宿**:
**交通**:
**活动**:
-
-

### Day 2
**住宿**:
**交通**:
**活动**:
-
-

### Day 3
**住宿**:
**交通**:
**活动**:
-
-

## 行前准备
- [ ] 机票/车票
- [ ] 酒店
- [ ] 证件
- [ ] 行李打包

## 装备清单
- [ ]
- [ ]

## 预算规划
| 项目 | 预算 | 实际 |
|------|------|------|
| 交通 |  |  |
| 住宿 |  |  |
| 餐饮 |  |  |
| 门票 |  |  |
| 购物 |  |  |
| 其他 |  |  |

## 注意事项

''';
  }

  static String _buildFitness(Map<String, dynamic> params) {
    return '''# 健身记录

**日期**: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

## 今日训练
**训练部位**:
**训练时长**: 分钟

## 热身运动


## 训练内容
### 动作一
**组数**:
**次数**:
**重量**: kg

### 动作二
**组数**:
**次数**:
**重量**: kg

### 动作三
**组数**:
**次数**:
**重量**: kg

## 有氧运动


## 拉伸放松


## 饮食记录


## 身体数据
**体重**: kg
**体脂率**: %

## 训练心得

## 明日计划
''';
  }
}

/// 模板选择对话框
class NoteTemplateDialog extends StatelessWidget {
  final void Function(String templateId) onSelected;

  const NoteTemplateDialog({
    super.key,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required void Function(String templateId) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NoteTemplateDialog(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖动条
            _buildDragHandle(),

            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.notes, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '选择模板',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 模板网格
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: PresetTemplates.all.length,
                itemBuilder: (context, index) {
                  final template = PresetTemplates.all[index];
                  return _TemplateCard(
                    template: template,
                    onTap: () {
                      onSelected(template.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textHint.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 模板卡片
class _TemplateCard extends StatelessWidget {
  final NoteTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: Container(
        decoration: BoxDecoration(
          color: template.color.withOpacity(0.1),
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: template.color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              template.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: TextStyle(
                color: template.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
