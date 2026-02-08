/// 笔记搜索页面 - 带高亮显示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/empty_state_widget.dart';
import 'package:thick_notepad/shared/widgets/skeleton_loading.dart';
import 'package:intl/intl.dart';

/// 笔记搜索页面
class NoteSearchPage extends ConsumerStatefulWidget {
  const NoteSearchPage({super.key});

  @override
  ConsumerState<NoteSearchPage> createState() => _NoteSearchPageState();
}

class _NoteSearchPageState extends ConsumerState<NoteSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _keyword = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = _keyword.isEmpty
        ? null
        : ref.watch(searchNotesProvider(_keyword));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索笔记...',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          onChanged: (value) {
            setState(() => _keyword = value);
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _focusNode.unfocus();
            }
          },
        ),
        actions: [
          if (_keyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _keyword = '');
              },
            ),
        ],
      ),
      body: _keyword.isEmpty
          ? const EmptyStateWidget.search()
          : resultsAsync!.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return EmptyStateWidget.search(query: _keyword);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    return _SearchResultCard(
                      note: notes[index],
                      keyword: _keyword,
                      onTap: () => context.push('/notes/${notes[index].id}'),
                    );
                  },
                );
              },
              loading: () => const NoteListSkeleton(),
              error: (_, __) => _buildError(),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '搜索出错',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// 搜索结果卡片
class _SearchResultCard extends StatelessWidget {
  final dynamic note;
  final String keyword;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.note,
    required this.keyword,
    required this.onTap,
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

  /// 高亮文本中的关键词
  Widget _buildHighlightedText(String text, String keyword, TextStyle baseStyle) {
    if (keyword.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final matches = _findAllMatches(text.toLowerCase(), keyword.toLowerCase());
    if (matches.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final List<TextSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      // 添加匹配前的文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      // 添加高亮的匹配文本
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: baseStyle.copyWith(
          backgroundColor: AppColors.primary.withOpacity(0.3),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastIndex = match.end;
    }

    // 添加剩余文本
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 查找所有匹配位置
  List<_MatchPosition> _findAllMatches(String text, String pattern) {
    final List<_MatchPosition> positions = [];
    int index = 0;
    while (index < text.length) {
      final found = text.indexOf(pattern, index);
      if (found == -1) break;
      positions.add(_MatchPosition(found, found + pattern.length));
      index = found + pattern.length;
    }
    return positions;
  }

  String get _title {
    final t = note.title as String?;
    return (t?.isEmpty ?? true) ? '无标题' : t!;
  }

  String get _content {
    return note.content as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final contentStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
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
                // 标题（带高亮）
                _buildHighlightedText(_title, keyword, titleStyle!),
                // 内容预览（带高亮）
                if (_content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _buildHighlightedText(_content, keyword, contentStyle!),
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
                          color: tagColor.withOpacity(0.12),
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
                Text(
                  DateFormat('M月d日 HH:mm').format(note.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
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

class _MatchPosition {
  final int start;
  final int end;
  _MatchPosition(this.start, this.end);
}
