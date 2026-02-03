/// 最近动态组件
/// 显示最近的笔记、运动、任务完成记录

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/date_formatter.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';

/// 动态数据模型
class ActivityItem {
  final String id;
  final String type; // 'note', 'workout', 'task'
  final String title;
  final String? description;
  final DateTime time;
  final IconData icon;
  final Color color;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.time,
    required this.icon,
    required this.color,
  });
}

/// 最近动态 Provider
/// 优化：使用并行加载提升性能
final recentActivitiesProvider = FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final activities = <ActivityItem>[];

  // 并行获取所有数据源（性能优化）
  final results = await Future.wait([
    // 获取最近的笔记
    ref.watch(allNotesProvider.future).then((notes) {
      final items = <ActivityItem>[];
      for (final note in notes.take(5)) {
        items.add(ActivityItem(
          id: 'note_${note.id}',
          type: 'note',
          title: note.title ?? '无标题',
          description: _getPreview(note.content ?? ''),
          time: note.updatedAt,
          icon: Icons.edit_note_outlined,
          color: AppColors.primary,
        ));
      }
      return items;
    }).catchError((_) => <ActivityItem>[]),

    // 获取最近的运动
    ref.watch(allWorkoutsProvider.future).then((workouts) {
      final items = <ActivityItem>[];
      final typeMap = {
        '跑步': '跑步',
        '骑行': '骑行',
        '游泳': '游泳',
        '力量训练': '力量训练',
        '瑜伽': '瑜伽',
        '健身操': '健身操',
      };
      for (final workout in workouts.take(5)) {
        items.add(ActivityItem(
          id: 'workout_${workout.id}',
          type: 'workout',
          title: typeMap[workout.type] ?? workout.type,
          description: '${workout.durationMinutes}分钟',
          time: workout.startTime,
          icon: Icons.fitness_center_outlined,
          color: AppColors.secondary,
        ));
      }
      return items;
    }).catchError((_) => <ActivityItem>[]),

    // 获取今日任务
    ref.watch(todayTasksProvider.future).then((tasks) {
      final items = <ActivityItem>[];
      for (final task in tasks.take(5)) {
        if (task.isCompleted) {
          items.add(ActivityItem(
            id: 'task_${task.id}',
            type: 'task',
            title: task.title,
            description: '已完成',
            time: task.scheduledDate,
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ));
        }
      }
      return items;
    }).catchError((_) => <ActivityItem>[]),
  ]);

  // 合并所有结果
  for (final result in results) {
    activities.addAll(result);
  }

  // 按时间排序（最新的在前）
  activities.sort((a, b) => b.time.compareTo(a.time));

  // 返回最近10条
  return activities.take(10).toList();
});

/// 最近动态列表组件
class RecentActivitiesList extends ConsumerWidget {
  const RecentActivitiesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return _EmptyState();
        }
        return Column(
          children: activities.map((activity) => _ActivityTile(activity: activity)).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => _EmptyState(),
    );
  }
}

/// 动态列表项
class _ActivityTile extends StatelessWidget {
  final ActivityItem activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activity.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(activity.icon, color: activity.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activity.description != null && activity.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        activity.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(activity.time),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              _getTypeIcon(activity.type),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getTypeIcon(String type) {
    switch (type) {
      case 'note':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('笔记', style: TextStyle(fontSize: 10, color: AppColors.primary)),
        );
      case 'workout':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('运动', style: TextStyle(fontSize: 10, color: AppColors.secondary)),
        );
      case 'task':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('任务', style: TextStyle(fontSize: 10, color: AppColors.success)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime time) {
    return DateFormatter.formatRelative(time);
  }

  void _handleTap(BuildContext context) {
    // 根据类型跳转到不同页面
    switch (activity.type) {
      case 'note':
        // 解析笔记ID并跳转到详情页
        final noteIdStr = activity.id.replaceFirst('note_', '');
        final noteId = int.tryParse(noteIdStr);
        if (noteId != null) {
          context.push('/notes/$noteId');
        }
        break;
      case 'workout':
        // 跳转到运动页面
        context.push('/workout');
        break;
      case 'task':
        // 跳转到计划页面
        context.push('/plans');
        break;
    }
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无动态',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '开始记录你的活动吧',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

/// 获取笔记预览文本
String _getPreview(String? content) {
  if (content == null || content.isEmpty) return '无内容';
  // 移除 Markdown 标记
  String cleaned = content
      .replaceAll(RegExp(r'#+\s*'), '')
      .replaceAll(RegExp(r'\*\*'), '')
      .replaceAll(RegExp(r'- '), '')
      .replaceAll(RegExp(r'\n'), ' ');
  if (cleaned.length > 30) {
    cleaned = cleaned.substring(0, 30) + '...';
  }
  return cleaned.trim();
}
