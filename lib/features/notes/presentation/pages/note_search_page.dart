/// 笔记搜索页面 - 带高亮显示、标签筛选和搜索历史

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/shared/widgets/empty_state_widget.dart';
import 'package:thick_notepad/shared/widgets/skeleton_loading.dart';
import 'package:intl/intl.dart';

/// 搜索历史服务
class SearchHistoryService {
  static const String _key = 'search_history';
  static const int _maxHistory = 10;

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    // 移除重复项
    history.remove(keyword);
    // 添加到开头
    history.insert(0, keyword);
    // 限制数量
    final limited = history.take(_maxHistory).toList();
    await prefs.setString(_key, jsonEncode(limited));
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> removeHistory(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.remove(keyword);
    await prefs.setString(_key, jsonEncode(history));
  }
}

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
  String? _selectedTag;
  List<String> _searchHistory = [];
  List<String> _allTags = [];
  bool _showHistory = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await SearchHistoryService.getHistory();
    final tags = await ref.read(allTagsProvider.future);
    if (mounted) {
      setState(() {
        _searchHistory = history;
        _allTags = tags;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = _keyword.isEmpty && _selectedTag == null
        ? null
        : ref.watch(searchNotesProvider(_keyword));

    // 当搜索关键词变化时，保存到历史
    if (_keyword.isNotEmpty && _showHistory) {
      _showHistory = false;
      SearchHistoryService.addHistory(_keyword);
    }

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
          decoration: InputDecoration(
            hintText: '搜索笔记...',
            border: InputBorder.none,
            suffixIcon: _selectedTag != null
                ? IconButton(
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(_selectedTag!, style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          const SizedBox(width: 4),
                          Icon(Icons.close, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedTag = null;
                      });
                    },
                  )
                : null,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          onChanged: (value) {
            setState(() => _keyword = value);
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _focusNode.unfocus();
              SearchHistoryService.addHistory(value);
            }
          },
        ),
        actions: [
          if (_keyword.isNotEmpty || _selectedTag != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _keyword = '';
                  _selectedTag = null;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 标签云筛选
          if (_allTags.isNotEmpty) _buildTagCloud(),
          // 搜索内容
          Expanded(
            child: _keyword.isEmpty && _selectedTag == null
                ? _buildSearchSuggestions()
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
          ),
        ],
      ),
    );
  }

  /// 构建标签云
  Widget _buildTagCloud() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _allTags.length,
        itemBuilder: (context, index) {
          final tag = _allTags[index];
          final isSelected = _selectedTag == tag;
          final tagColor = AppColors.getTagColor(tag);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTag = selected ? tag : null;
                });
              },
              selectedColor: tagColor.withOpacity(0.3),
              checkmarkColor: tagColor,
              labelStyle: TextStyle(
                color: isSelected ? tagColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppColors.surfaceVariant,
              side: BorderSide(
                color: isSelected ? tagColor : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建搜索建议（历史记录 + 热门标签）
  Widget _buildSearchSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 搜索历史
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              TextButton(
                onPressed: () async {
                  await SearchHistoryService.clearHistory();
                  setState(() => _searchHistory = []);
                },
                child: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _searchHistory.take(8).map((keyword) {
              return GestureDetector(
                onTap: () {
                  _controller.text = keyword;
                  setState(() => _keyword = keyword);
                },
                child: Chip(
                  label: Text(keyword),
                  avatar: const Icon(Icons.history, size: 16),
                  onDeleted: () async {
                    await SearchHistoryService.removeHistory(keyword);
                    final updated = await SearchHistoryService.getHistory();
                    setState(() => _searchHistory = updated);
                  },
                  deleteIcon: const Icon(Icons.close, size: 16),
                  backgroundColor: AppColors.surfaceVariant,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // 热门标签
        if (_allTags.isNotEmpty) ...[
          Text(
            '热门标签',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _allTags.take(10).map((tag) {
              final tagColor = AppColors.getTagColor(tag);
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedTag = tag);
                },
                child: Chip(
                  label: Text(tag),
                  avatar: Icon(Icons.tag, size: 16, color: tagColor),
                  backgroundColor: tagColor.withOpacity(0.1),
                  side: BorderSide(color: tagColor.withOpacity(0.3)),
                  labelStyle: TextStyle(color: tagColor),
                ),
              );
            }).toList(),
          ),
        ],
      ],
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
