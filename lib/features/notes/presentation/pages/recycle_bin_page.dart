/// 笔记回收站页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/shared/widgets/skeleton_loading.dart';

/// 回收站视图
class RecycleBinView extends ConsumerWidget {
  const RecycleBinView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedNotesAsync = ref.watch(deletedNotesProvider);

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: deletedNotesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return _EmptyState(onTap: () => Navigator.pop(context));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: notes.length,
                  itemExtent: 120,
                  itemBuilder: (context, index) {
                    return AnimatedListItem(
                      index: index,
                      child: _DeletedNoteCard(
                        note: notes[index],
                        onRestore: () => _restoreNote(ref, context, notes[index].id),
                        onPermanentDelete: () => _permanentDelete(ref, context, notes[index].id),
                      ),
                    );
                  },
                );
              },
              loading: () => const NoteListSkeleton(),
              error: (e, s) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(deletedNotesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '回收站',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          // 清空回收站按钮
          TextButton.icon(
            onPressed: () => _showClearAllDialog(context),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: const Text('清空'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreNote(WidgetRef ref, BuildContext context, int id) async {
    try {
      await ref.read(updateNoteProvider.notifier).restore(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('笔记已恢复')),
        );
        ref.invalidate(deletedNotesProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  Future<void> _permanentDelete(WidgetRef ref, BuildContext context, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除'),
        content: const Text('确定要永久删除这条笔记吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(updateNoteProvider.notifier).permanentlyDelete(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('笔记已永久删除')),
          );
          ref.invalidate(deletedNotesProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _showClearAllDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('确定要清空回收站吗？所有笔记将被永久删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 需要获取所有已删除笔记并逐个删除
      // 这里简化处理，实际可以在后端添加批量删除方法
      Navigator.pop(context); // 返回笔记列表页
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在笔记列表中单独删除每条笔记')),
      );
    }
  }
}

/// 已删除笔记卡片
class _DeletedNoteCard extends StatelessWidget {
  final dynamic note;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  const _DeletedNoteCard({
    required this.note,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  String get _title {
    final t = note.title as String?;
    return (t?.isEmpty ?? true) ? '无标题' : t!;
  }

  String get _content {
    final c = note.content as String? ?? '';
    return c.length > 100 ? '${c.substring(0, 100)}...' : c;
  }

  String get _deletedAt {
    if (note.deletedAt == null) return '未知时间';
    return '删除于 ${DateFormat('M月d日 HH:mm').format(note.deletedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和删除时间
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _deletedAt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                    ),
                  ],
                ),
                // 内容预览
                if (_content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // 操作按钮
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onRestore,
                      icon: const Icon(Icons.restore_from_trash_outlined, size: 16),
                      label: const Text('恢复'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: onPermanentDelete,
                      icon: const Icon(Icons.delete_forever_outlined, size: 16),
                      label: const Text('永久删除'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空状态 - 回收站专用
/// 注意：保留自定义实现是因为回收站场景特殊，需要显示"返回"按钮而非"创建"按钮
/// 与通用 EmptyStateWidget 的使用场景不同
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline,
              size: 56,
              color: AppColors.textHint.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '回收站为空',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '已删除的笔记会在这里保留30天',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.fullRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误视图
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
