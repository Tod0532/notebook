/// 笔记导出页面 - 支持JSON和Markdown格式

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/skeleton_loading.dart';

/// 笔记导出页面
class NoteExportPage extends ConsumerStatefulWidget {
  const NoteExportPage({super.key});

  @override
  ConsumerState<NoteExportPage> createState() => _NoteExportPageState();
}

class _NoteExportPageState extends ConsumerState<NoteExportPage> {
  bool _isExporting = false;
  int _exportedCount = 0;
  String _selectedFormat = 'markdown'; // 'markdown' or 'json'

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出笔记'),
        actions: [
          TextButton.icon(
            onPressed: _isExporting || notesAsync.value == null
                ? null
                : () => _exportNotes(notesAsync.value!),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            label: Text(_isExporting ? '导出中...' : '导出'),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyState(onTap: () => Navigator.pop(context));
          }
          return _buildContent(notes);
        },
        loading: () => const NoteListSkeleton(),
        error: (e, s) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.refresh(allNotesProvider),
        ),
      ),
    );
  }

  Widget _buildContent(List notes) {
    return Column(
      children: [
        // 格式选择
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '导出格式',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _FormatSelector(
                selected: _selectedFormat,
                onChanged: (format) => setState(() => _selectedFormat = format),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 笔记列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return _ExportNoteCard(
                note: notes[index],
                isSelected: true,
                onToggle: () {}, // 全选功能暂未实现
              );
            },
          ),
        ),
        // 底部统计
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(
              top: BorderSide(color: AppColors.dividerColor.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Text(
                '共 ${notes.length} 条笔记',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_exportedCount > 0)
                Text(
                  '已导出 $_exportedCount 条',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportNotes(List notes) async {
    setState(() => _isExporting = true);

    try {
      String content;
      String fileName;
      String mimeType;

      if (_selectedFormat == 'markdown') {
        content = _exportToMarkdown(notes);
        fileName = '动计笔记_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.md';
        mimeType = 'text/markdown';
      } else {
        content = _exportToJson(notes);
        fileName = '动计笔记_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
        mimeType = 'application/json';
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      // 分享文件
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType)],
          text: '导出 ${notes.length} 条笔记',
        );
        setState(() => _exportedCount = notes.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _exportToMarkdown(List notes) {
    final buffer = StringBuffer();
    buffer.writeln('# 动计笔记导出');
    buffer.writeln('导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('总计: ${notes.length} 条笔记');
    buffer.writeln();
    buffer.writeln('---');

    for (final note in notes) {
      buffer.writeln();
      buffer.writeln('## ${(note.title as String? ?? '无标题')}');
      buffer.writeln();

      // 元数据
      buffer.writeln('> 创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt)}');
      if (note.folder != null && note.folder!.isNotEmpty) {
        buffer.writeln('> 文件夹: ${note.folder}');
      }
      buffer.writeln();

      // 标签
      final tags = _parseTags(note.tags as String? ?? '');
      if (tags.isNotEmpty) {
        buffer.writeln('**标签**: ${tags.join(', ')}');
        buffer.writeln();
      }

      // 内容
      if ((note.content as String? ?? '').isNotEmpty) {
        buffer.writeln(note.content);
        buffer.writeln();
      }

      buffer.writeln('---');
    }

    return buffer.toString();
  }

  String _exportToJson(List notes) {
    final exportData = {
      'exportTime': DateTime.now().toIso8601String(),
      'count': notes.length,
      'notes': notes.map((note) => {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'folder': note.folder,
        'tags': _parseTags(note.tags as String? ?? ''),
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'isPinned': note.isPinned ?? false,
        'color': note.color,
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  List<String> _parseTags(String tagsJson) {
    if (tagsJson.isEmpty || tagsJson == '[]') return [];
    try {
      final clean = tagsJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      if (clean.isEmpty) return [];
      return clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

/// 格式选择器
class _FormatSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FormatSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'markdown',
          label: Text('Markdown'),
          icon: Icon(Icons.description_outlined, size: 18),
        ),
        ButtonSegment(
          value: 'json',
          label: Text('JSON'),
          icon: Icon(Icons.code_outlined, size: 18),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (Set<String> selection) {
        onChanged(selection.first);
      },
    );
  }
}

/// 导出笔记卡片 - 带触摸反馈
class _ExportNoteCard extends StatelessWidget {
  final dynamic note;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ExportNoteCard({
    required this.note,
    required this.isSelected,
    required this.onToggle,
  });

  String get _title {
    final t = note.title as String?;
    return (t?.isEmpty ?? true) ? '无标题' : t!;
  }

  String get _preview {
    final c = note.content as String? ?? '';
    return c.length > 50 ? '${c.substring(0, 50)}...' : c;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: AppColors.dividerColor.withOpacity(0.3),
        ),
      ),
      // 确保最小触控目标尺寸 48x48dp
      constraints: const BoxConstraints(
        minHeight: 48,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdRadius,
        child: InkWell(
          onTap: onToggle,
          borderRadius: AppRadius.mdRadius,
          splashColor: AppColors.primary.withOpacity(0.15),
          highlightColor: AppColors.primary.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _preview,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          Icon(
            Icons.note_outlined,
            size: 64,
            color: AppColors.textHint.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '没有可导出的笔记',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
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
