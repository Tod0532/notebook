/// 笔记模块页面 - 现代渐变风格
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:intl/intl.dart';

/// 笔记视图（无 Scaffold，在 ShellRoute 内部）
class NotesView extends ConsumerWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context),
          // 笔记列表
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return _EmptyState(onTap: () => context.push(AppRoutes.noteEdit));
                }

                // 分离置顶和普通笔记
                final pinnedNotes = notes.where((n) => n.isPinned).toList();
                final normalNotes = notes.where((n) => !n.isPinned).toList();

                // 只有一种类型的笔记时不需要分隔符
                final hasSeparator = pinnedNotes.isNotEmpty && normalNotes.isNotEmpty;
                final separatorOffset = hasSeparator ? 1 : 0;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: pinnedNotes.length + normalNotes.length + separatorOffset,
                  itemBuilder: (context, index) {
                    // 置顶分隔
                    if (hasSeparator && index == pinnedNotes.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          '全部笔记',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      );
                    }

                    final isPinned = index < pinnedNotes.length;
                    final note = isPinned
                        ? pinnedNotes[index]
                        : normalNotes[index - pinnedNotes.length - separatorOffset];

                    return AnimatedListItem(
                      index: index,
                      child: _NoteCard(
                        note: note,
                        onTap: () => _showNoteDetail(context, note.id),
                        onTogglePin: () => _togglePin(ref, note),
                        onDelete: () => _deleteNote(context, ref, note.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(allNotesProvider),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '笔记',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdRadius,
            ),
            child: IconButton(
              icon: const Icon(Icons.search, size: 20),
              onPressed: () => _showSearchDialog(context),
              padding: const EdgeInsets.all(AppSpacing.sm),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteDetail(BuildContext context, int id) {
    context.push('/notes/$id');
  }

  void _togglePin(WidgetRef ref, note) {
    ref.read(updateNoteProvider.notifier).togglePin(note);
  }

  void _deleteNote(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(updateNoteProvider.notifier).delete(id);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _SearchDialog(),
    );
  }
}

/// 笔记卡片
class _NoteCard extends StatelessWidget {
  final dynamic note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  List<String> get _tagList {
    final tags = note.tags as String? ?? '';
    if (tags.isEmpty || tags == '[]') return [];
    try {
      final clean = tags.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      if (clean.isEmpty) return [];
      return clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M月d日');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    if (note.isPinned)
                      Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        (note.title as String?)?.isEmpty ?? true ? '无标题' : note.title as String,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildMenuButton(context),
                  ],
                ),
                // 内容预览
                if ((note.content as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    note.content as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // 标签
                if (_tagList.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: _tagList.take(3).map((tag) {
                      final tagColor = AppColors.getTagColor(tag);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tagColor.withValues(alpha: 0.15),
                              tagColor.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            color: tagColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // 日期
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${dateFormat.format(note.createdAt)} ${timeFormat.format(note.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
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

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            onTogglePin();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 8),
              Text(note.isPinned ? '取消置顶' : '置顶'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 空状态
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
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppShadows.light,
            ),
            child: const Icon(
              Icons.edit_note_outlined,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '还没有笔记',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '记录你的想法和灵感',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('创建笔记'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
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

/// 搜索对话框
class _SearchDialog extends ConsumerStatefulWidget {
  const _SearchDialog();

  @override
  ConsumerState<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<_SearchDialog> {
  final _controller = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索笔记'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '输入关键词...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() => _keyword = value);
        },
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            Navigator.pop(context, value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _keyword.isEmpty ? null : () => Navigator.pop(context, _keyword),
          child: const Text('搜索'),
        ),
      ],
    );
  }
}
