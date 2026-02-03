/// 笔记模块页面 - 带搜索功能
/// 无 Scaffold，用于在 HomePage 的 ShellRoute 内部显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:intl/intl.dart';

/// 笔记视图（无 Scaffold，在 ShellRoute 内部显示）
class NotesViewSearchable extends ConsumerStatefulWidget {
  const NotesViewSearchable({super.key});

  @override
  ConsumerState<NotesViewSearchable> createState() => _NotesViewSearchableState();
}

class _NotesViewSearchableState extends ConsumerState<NotesViewSearchable> {
  String? _searchKeyword;
  String? _selectedFolder;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context),
          // 搜索结果显示（搜索时显示）
          if (_searchKeyword != null && _searchKeyword!.isNotEmpty)
            _buildSearchBar(context),
          // 笔记列表
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                // 获取所有文件夹列表
                final allFolders = notes
                    .map((n) => n.folder)
                    .where((f) => f != null && f.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                // 过滤笔记
                final filteredNotes = _filterNotes(notes, _searchKeyword, _selectedFolder);
                final hasFilter = _searchKeyword != null && _searchKeyword!.isNotEmpty || _selectedFolder != null;
                final displayedNotes = hasFilter ? filteredNotes : notes;

                if (displayedNotes.isEmpty) {
                  return _EmptyState(
                    onTap: () => context.push(AppRoutes.noteEdit),
                    message: _searchKeyword != null && _searchKeyword!.isNotEmpty
                        ? '没有找到匹配的笔记'
                        : null,
                  );
                }

                // 分离置顶和普通笔记
                final pinnedNotes = displayedNotes.where((n) => n.isPinned).toList();
                final normalNotes = displayedNotes.where((n) => !n.isPinned).toList();

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
                          _searchKeyword != null && _searchKeyword!.isNotEmpty
                              ? '搜索结果 (${filteredNotes.length})'
                              : '全部笔记',
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
                        onTogglePin: () => _togglePin(note),
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

  /// 过滤笔记
  List<dynamic> _filterNotes(List<dynamic> notes, String? keyword, String? folder) {
    var filtered = notes;

    // 文件夹筛选
    if (folder != null && folder.isNotEmpty) {
      filtered = filtered.where((note) => note.folder == folder).toList();
    }

    // 关键词搜索
    if (keyword != null && keyword.isNotEmpty) {
      final lowerKeyword = keyword.toLowerCase();
      filtered = filtered.where((note) {
        final title = (note.title as String? ?? '').toLowerCase();
        final content = (note.content as String? ?? '').toLowerCase();
        final tags = (note.tags as String? ?? '').toLowerCase();

        return title.contains(lowerKeyword) ||
            content.contains(lowerKeyword) ||
            tags.contains(lowerKeyword);
      }).toList();
    }

    return filtered;
  }

  /// 搜索栏
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '搜索关键词：$_searchKeyword',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() => _searchKeyword = null);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      onPressed: () => _performSearch(context),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 文件夹筛选
          if (notesAsync.hasValue)
            SizedBox(
              height: 36,
              child: notesAsync.whenOrNull(
                data: (notes) {
                  final allFolders = notes
                      .map((n) => n.folder)
                      .where((f) => f != null && f.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();

                  if (allFolders.isEmpty) return const SizedBox.shrink();

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allFolders.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      // 全部选项
                      if (index == 0) {
                        final isSelected = _selectedFolder == null;
                        return _FolderFilterChip(
                          label: '全部',
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedFolder = null);
                          },
                        );
                      }

                      final folder = allFolders[index - 1];
                      final isSelected = _selectedFolder == folder;
                      return _FolderFilterChip(
                        label: folder,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedFolder = folder);
                        },
                      );
                    },
                  );
                },
              ) ?? const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  void _showNoteDetail(BuildContext context, int id) {
    context.push('/notes/$id');
  }

  void _togglePin(note) {
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

  void _performSearch(BuildContext context) async {
    final keyword = await showDialog<String>(
      context: context,
      builder: (context) => const _SearchDialog(),
    );
    if (keyword != null) {
      setState(() => _searchKeyword = keyword);
    }
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
                          color: AppColors.primary,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    // 文件夹标签
                    if (note.folder != null && note.folder!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 10,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              note.folder!,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Text(
                        ((note.title as String?)?.isEmpty ?? true) ? '无标题' : (note.title as String? ?? '无标题'),
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
                if (((note.content as String?)?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    note.content as String? ?? '',
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
                    children: _tagList.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // 底部信息
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.label_outline,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeFormat.format(note.createdAt),
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
      color: AppColors.textSecondary,
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(AppSpacing.xs),
      onSelected: (value) {
        switch (value) {
          case 'toggle_pin':
            onTogglePin();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle_pin',
          child: Row(
            children: [
              Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_out,
                size: 16,
                color: note.isPinned ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(note.isPinned ? '取消置顶' : '置顶'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              const Text('删除'),
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
  final String? message;

  const _EmptyState({required this.onTap, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_outlined,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? '还没有笔记',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '点击右下角按钮创建',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('创建笔记'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 错误视图
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
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
          hintText: '输入关键词（标题、内容、标签）...',
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

/// 文件夹筛选芯片
class _FolderFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.dividerColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }
}
