/// 笔记编辑页

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// 笔记编辑页
class NoteEditPage extends ConsumerStatefulWidget {
  final int? noteId;

  const NoteEditPage({super.key, this.noteId});

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _tags = [];
  bool _isLoading = false;
  Note? _existingNote;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    _existingNote = await ref.read(noteProvider(widget.noteId!).future);
    if (_existingNote != null) {
      _titleController.text = _existingNote!.title ?? '';
      _contentController.text = _existingNote!.content;
      _tags.addAll(_parseTags(_existingNote!.tags));
    }
    setState(() => _isLoading = false);
  }

  List<String> _parseTags(String tagsJson) {
    if (tagsJson.isEmpty || tagsJson == '[]') return [];
    try {
      final clean = tagsJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
      if (clean.isEmpty) return [];
      return clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? '新建笔记' : '编辑笔记'),
        actions: [
          if (widget.noteId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNote(context),
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _titleController,
                        style: Theme.of(context).textTheme.titleLarge,
                        decoration: const InputDecoration(
                          hintText: '标题',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                      ),
                      const Divider(height: 32),
                      TextField(
                        controller: _contentController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: '开始写下你的想法...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                      ),
                    ],
                  ),
                ),
                _buildTagsBar(context),
              ],
            ),
    );
  }

  Widget _buildTagsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tag, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  '标签',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _addTag,
                  child: const Text('添加'),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: AppColors.getTagColor(tag).withOpacity(0.15),
                    deleteIconColor: AppColors.getTagColor(tag),
                    onDeleted: () {
                      setState(() => _tags.remove(tag));
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (context) => _AddTagDialog(
        existingTags: _tags,
        onAdd: (tag) {
          setState(() => _tags.add(tag));
        },
      ),
    );
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      _showSnackBar('请输入标题或内容');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tagsJson = _formatTags(_tags);

      if (widget.noteId == null) {
        await ref.read(createNoteProvider.notifier).create(
              NotesCompanion.insert(
                title: drift.Value(title.isEmpty ? null : title),
                content: content,
                tags: drift.Value(tagsJson),
              ),
            );
        ref.invalidate(allNotesProvider);
      } else {
        await ref.read(updateNoteProvider.notifier).update(
              _existingNote!.copyWith(
                title: title.isEmpty ? const drift.Value(null) : drift.Value(title),
                content: content,
                tags: tagsJson,
                updatedAt: DateTime.now(),
              ),
            );
        ref.invalidate(allNotesProvider);
      }

      if (mounted) {
        _showSnackBar('保存成功');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteNote(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(updateNoteProvider.notifier).delete(widget.noteId!);
              ref.invalidate(allNotesProvider);
              if (mounted) {
                context.pop();
              }
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

  String _formatTags(List<String> tags) {
    if (tags.isEmpty) return '[]';
    return '[${tags.map((e) => '"$e"').join(',')}]';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// 添加标签对话框
class _AddTagDialog extends StatefulWidget {
  final List<String> existingTags;
  final ValueChanged<String> onAdd;

  const _AddTagDialog({
    required this.existingTags,
    required this.onAdd,
  });

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _controller = TextEditingController();
  String _selectedTag = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入标签名称',
            ),
            onChanged: (value) => _selectedTag = value.trim(),
            onSubmitted: (_) => _confirmAdd(),
          ),
          const SizedBox(height: 16),
          if (widget.existingTags.isEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['工作', '生活', '学习', '想法', '待办'].map((tag) {
                return ActionChip(
                  label: Text(tag),
                  onPressed: () => _selectTag(tag),
                );
              }).toList(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedTag.isEmpty ? null : _confirmAdd,
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _selectTag(String tag) {
    _controller.text = tag;
    _selectedTag = tag;
  }

  void _confirmAdd() {
    if (_selectedTag.isEmpty) return;
    if (_selectedTag.length > AppConstants.maxTagNameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签名称太长')),
      );
      return;
    }
    if (widget.existingTags.contains(_selectedTag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签已存在')),
      );
      return;
    }
    widget.onAdd(_selectedTag);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
