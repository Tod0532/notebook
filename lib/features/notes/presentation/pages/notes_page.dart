/// 笔记模块页面 - 现代渐变风格
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/features/notes/presentation/widgets/note_preview_dialog.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:intl/intl.dart';

/// 笔记视图（无 Scaffold，在 ShellRoute 内部）
class NotesView extends ConsumerWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);

    return Stack(
      children: [
        Column(
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
                    // 预估卡片高度，提升滚动性能
                    itemExtent: 160,
                    cacheExtent: 500, // 缓存更多屏幕外的item
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
                        child: _SwipeableNoteCard(
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
        // 新建笔记悬浮按钮
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xl,
          child: FloatingActionButton.extended(
            onPressed: () => context.push(AppRoutes.noteEdit),
            icon: const Icon(Icons.add),
            label: const Text('新建'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
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
          Row(
            children: [
              // 导出按钮
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: () => context.push(AppRoutes.noteExport),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  constraints: const BoxConstraints(),
                  tooltip: '导出笔记',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 回收站按钮
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.mdRadius,
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => context.push(AppRoutes.recycleBin),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  constraints: const BoxConstraints(),
                  tooltip: '回收站',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 搜索按钮
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
    context.push(AppRoutes.noteSearch);
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

  // 缓存标签列表解析结果 - 使用LRU策略限制大小
  static final Map<String, List<String>> _tagCache = {};
  static const int _maxCacheSize = 50;
  static final List<String> _cacheKeys = [];

  List<String> get _tagList {
    final tags = note.tags as String? ?? '';
    if (tags.isEmpty || tags == '[]') return [];

    // 使用缓存
    if (_tagCache.containsKey(tags)) {
      // 更新LRU顺序
      _cacheKeys.remove(tags);
      _cacheKeys.add(tags);
      return _tagCache[tags]!;
    }

    try {
      final clean = tags.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      if (clean.isEmpty) return [];
      final result = clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // LRU淘汰策略
      if (_tagCache.length >= _maxCacheSize) {
        final oldestKey = _cacheKeys.removeAt(0);
        _tagCache.remove(oldestKey);
      }

      _tagCache[tags] = result;
      _cacheKeys.add(tags);
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // 预先计算常用值
    final title = (note.title as String?)?.isEmpty ?? true ? '无标题' : (note.title as String? ?? '无标题');
    final content = note.content as String? ?? '';
    final hasContent = content.isNotEmpty;
    final createdAt = note.createdAt;
    final isPinned = note.isPinned ?? false;

    // 使用静态格式化器避免重复创建
    final dateTimeStr = '${DateFormat('M月d日').format(createdAt)} ${DateFormat('HH:mm').format(createdAt)}';

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
        child: GestureDetector(
          onLongPress: () => _showPreview(context),
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
                    if (isPinned)
                      Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
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
                if (hasContent) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    content,
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
                          color: tagColor.withValues(alpha: 0.12),
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
                    const Icon(
                      Icons.schedule_outlined,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateTimeStr,
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
      ),
    );
  }

  void _showPreview(BuildContext context) {
    NotePreviewDialog.show(
      context: context,
      note: note,
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
              Icon((note.isPinned ?? false) ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 8),
              Text((note.isPinned ?? false) ? '取消置顶' : '置顶'),
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

/// 可滑动删除的笔记卡片
class _SwipeableNoteCard extends StatelessWidget {
  final dynamic note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _SwipeableNoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.7,
      },
      background: _buildDismissableBackground(),
      onDismissed: (_) {
        onDelete();
      },
      child: _NoteCard(
        note: note,
        onTap: onTap,
        onTogglePin: onTogglePin,
        onDelete: onDelete,
      ),
    );
  }

  Widget _buildDismissableBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppRadius.lgRadius,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 32),
          SizedBox(height: 4),
          Text(
            '删除',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
