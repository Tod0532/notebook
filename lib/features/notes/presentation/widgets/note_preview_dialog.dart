/// 笔记预览对话框 - 长按预览笔记内容

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/shared/widgets/modern_cards.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';

/// 笔记预览对话框
class NotePreviewDialog {
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> note,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NotePreviewSheet(note: note),
    );
  }
}

class _NotePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> note;

  const _NotePreviewSheet({required this.note});

  String get _title {
    final t = note['title'] as String?;
    return (t?.isEmpty ?? true) ? '无标题' : t!;
  }

  String get _content {
    return note['content'] as String? ?? '';
  }

  DateTime get _createdAt => note['createdAt'] as DateTime;

  List<String> get _tags {
    final tags = note['tags'] as String? ?? '';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部拖动条
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 元数据
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(_createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.label_outline, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          '${_tags.length} 个标签',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 标签
                    if (_tags.isNotEmpty) ...[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 4,
                        children: _tags.take(5).map((tag) {
                          final tagColor = AppColors.getTagColor(tag);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
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
                      const SizedBox(height: 16),
                    ],

                    // 内容
                    if (_content.isNotEmpty) ...[
                      Text(
                        '内容',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 底部操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                border: Border(
                  top: BorderSide(color: AppColors.dividerColor.withOpacity(0.3)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: ModernCard(
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/notes/${note['id']}');
                        },
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        borderRadius: AppRadius.fullRadius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: const Text(
                            '编辑',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ModernCard(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.surfaceVariant,
                        borderRadius: AppRadius.fullRadius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: const Text(
                            '关闭',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
