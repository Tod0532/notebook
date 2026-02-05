/// 导出选择底部表单 - 用于选择导出格式和执行导出
///
/// 支持的导出格式：
/// - Markdown (.md)
/// - PDF (.pdf)
/// - 纯文本 (.txt)
/// - 批量导出为ZIP

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/export/export_service.dart';

/// 导出选项类型
enum ExportOption {
  markdown,
  pdf,
  text,
  copy,
  share;

  String get displayName {
    switch (this) {
      case ExportOption.markdown:
        return 'Markdown';
      case ExportOption.pdf:
        return 'PDF';
      case ExportOption.text:
        return '纯文本';
      case ExportOption.copy:
        return '复制到剪贴板';
      case ExportOption.share:
        return '直接分享';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportOption.markdown:
        return Icons.code;
      case ExportOption.pdf:
        return Icons.picture_as_pdf;
      case ExportOption.text:
        return Icons.text_snippet;
      case ExportOption.copy:
        return Icons.copy;
      case ExportOption.share:
        return Icons.share;
    }
  }

  Color get color {
    switch (this) {
      case ExportOption.markdown:
        return const Color(0xFF4A5568);
      case ExportOption.pdf:
        return const Color(0xFFE53E3E);
      case ExportOption.text:
        return const Color(0xFF3182CE);
      case ExportOption.copy:
        return AppColors.primary;
      case ExportOption.share:
        return AppColors.success;
    }
  }
}

/// 导出加载状态
enum ExportLoadingState {
  idle,
  exporting,
  success,
  error,
}

/// 导出选择底部表单
class ExportBottomSheet extends StatefulWidget {
  final Note note;
  final List<Note>? notes; // 用于批量导出
  final bool showBatchOptions; // 是否显示批量导出选项

  const ExportBottomSheet({
    super.key,
    required this.note,
    this.notes,
    this.showBatchOptions = false,
  });

  /// 显示导出底部表单
  static Future<void> show({
    required BuildContext context,
    required Note note,
    List<Note>? notes,
    bool showBatchOptions = false,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ExportBottomSheet(
        note: note,
        notes: notes,
        showBatchOptions: showBatchOptions,
      ),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  final ExportService _exportService = ExportService.instance;

  ExportLoadingState _state = ExportLoadingState.idle;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖动条
            _buildDragHandle(),

            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.ios_share, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '导出笔记',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 笔记预览
            _buildNotePreview(context),

            const Divider(height: 1),

            // 导出选项网格
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择导出格式',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // 单条导出选项
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _ExportOptionTile(
                        option: ExportOption.markdown,
                        onTap: () => _handleExport(ExportOption.markdown),
                        isLoading: _state == ExportLoadingState.exporting,
                      ),
                      _ExportOptionTile(
                        option: ExportOption.pdf,
                        onTap: () => _handleExport(ExportOption.pdf),
                        isLoading: _state == ExportLoadingState.exporting,
                      ),
                      _ExportOptionTile(
                        option: ExportOption.text,
                        onTap: () => _handleExport(ExportOption.text),
                        isLoading: _state == ExportLoadingState.exporting,
                      ),
                      _ExportOptionTile(
                        option: ExportOption.copy,
                        onTap: () => _handleExport(ExportOption.copy),
                        isLoading: _state == ExportLoadingState.exporting,
                      ),
                      _ExportOptionTile(
                        option: ExportOption.share,
                        onTap: () => _handleExport(ExportOption.share),
                        isLoading: _state == ExportLoadingState.exporting,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 批量导出选项
            if (widget.showBatchOptions && widget.notes != null && widget.notes!.length > 1)
              _buildBatchExportSection(context),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textHint.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildNotePreview(BuildContext context) {
    final title = widget.note.title ?? '无标题';
    final content = widget.note.content;
    final previewContent = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            previewContent,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Icon(Icons.access_time, size: 12, color: AppColors.textHint),
              Text(
                _formatDate(widget.note.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                    ),
              ),
              if (widget.note.folder != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.folder, size: 12, color: AppColors.textHint),
                Text(
                  widget.note.folder!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchExportSection(BuildContext context) {
    final noteCount = widget.notes?.length ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_zip, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '批量导出',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$noteCount 条笔记',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBatchButton(
                  context: context,
                  label: '导出为 ZIP',
                  icon: Icons.archive,
                  onTap: _handleBatchExport,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBatchButton(
                  context: context,
                  label: '导出为 CSV',
                  icon: Icons.table_chart,
                  onTap: _handleExportToCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _state == ExportLoadingState.exporting ? null : onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _state == ExportLoadingState.exporting
              ? AppColors.textHint.withOpacity(0.3)
              : Colors.white,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(ExportOption option) async {
    HapticHelper.mediumTap();

    setState(() {
      _state = ExportLoadingState.exporting;
      _errorMessage = null;
    });

    try {
      switch (option) {
        case ExportOption.markdown:
          await _exportAsMarkdown();
          break;
        case ExportOption.pdf:
          await _exportAsPdf();
          break;
        case ExportOption.text:
          await _exportAsText();
          break;
        case ExportOption.copy:
          await _copyToClipboard();
          break;
        case ExportOption.share:
          await _shareNote();
          break;
      }

      setState(() => _state = ExportLoadingState.success);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _state = ExportLoadingState.error;
        _errorMessage = e.toString();
      });

      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _exportAsMarkdown() async {
    final markdown = await _exportService.exportNoteAsMarkdown(widget.note);
    final fileName = '${widget.note.getSafeFileName()}.md';

    await _exportService.exportAndShare(
      content: markdown,
      fileName: fileName,
      mimeType: 'text/markdown',
    );

    if (mounted) {
      _showSuccessSnackBar('Markdown 导出成功');
    }
  }

  Future<void> _exportAsPdf() async {
    final result = await _exportService.exportNoteAsPdf(widget.note);

    if (!result.success) {
      throw Exception(result.error ?? 'PDF 导出失败');
    }

    if (result.filePath != null) {
      await Share.shareXFiles(
        [XFile(result.filePath!)],
        text: '分享笔记 PDF',
      );
    }

    if (mounted) {
      _showSuccessSnackBar('PDF 导出成功');
    }
  }

  Future<void> _exportAsText() async {
    final text = await _exportService.exportNoteAsText(widget.note);
    final fileName = '${widget.note.getSafeFileName()}.txt';

    await _exportService.exportAndShare(
      content: text,
      fileName: fileName,
      mimeType: 'text/plain',
    );

    if (mounted) {
      _showSuccessSnackBar('文本导出成功');
    }
  }

  Future<void> _copyToClipboard() async {
    final markdown = await _exportService.exportNoteAsMarkdown(widget.note);

    await Clipboard.setData(ClipboardData(text: markdown));

    if (mounted) {
      _showSuccessSnackBar('已复制到剪贴板');
    }
  }

  Future<void> _shareNote() async {
    final markdown = await _exportService.exportNoteAsMarkdown(widget.note);

    await Share.share(
      markdown,
      subject: widget.note.title ?? '笔记分享',
    );

    if (mounted) {
      _showSuccessSnackBar('分享成功');
    }
  }

  Future<void> _handleBatchExport() async {
    HapticHelper.mediumTap();

    final notes = widget.notes;
    if (notes == null || notes.isEmpty) {
      if (mounted) {
        _showErrorSnackBar('没有笔记可导出');
      }
      return;
    }

    setState(() => _state = ExportLoadingState.exporting);

    try {
      final result = await _exportService.exportNotesAsZip(notes);

      if (!result.success) {
        throw Exception(result.error ?? 'ZIP 导出失败');
      }

      if (result.filePath != null) {
        await Share.shareXFiles(
          [XFile(result.filePath!)],
          text: '分享 ${notes.length} 条笔记',
        );
      }

      setState(() => _state = ExportLoadingState.success);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('已导出 ${notes.length} 条笔记');
      }
    } catch (e) {
      setState(() {
        _state = ExportLoadingState.error;
        _errorMessage = e.toString();
      });

      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _handleExportToCsv() async {
    HapticHelper.mediumTap();

    // 简单实现：将笔记导出为CSV格式
    final notes = widget.notes ?? [widget.note];

    final buffer = StringBuffer();
    buffer.writeln('标题,内容,创建时间,更新时间,标签,文件夹');

    for (final note in notes) {
      final title = (note.title ?? '').replaceAll(',', '，').replaceAll('\n', ' ');
      final content = note.content.replaceAll(',', '，').replaceAll('\n', ' ');
      final created = _formatDate(note.createdAt);
      final updated = _formatDate(note.updatedAt);
      final tags = note.tags.replaceAll(',', '、');
      final folder = note.folder ?? '';

      buffer.writeln('$title,$content,$created,$updated,$tags,$folder');
    }

    await _exportService.exportAndShare(
      content: buffer.toString(),
      fileName: '笔记_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
    );

    if (mounted) {
      Navigator.pop(context);
      _showSuccessSnackBar('CSV 导出成功');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// 导出选项卡片
class _ExportOptionTile extends StatelessWidget {
  final ExportOption option;
  final VoidCallback onTap;
  final bool isLoading;

  const _ExportOptionTile({
    required this.option,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        decoration: BoxDecoration(
          color: option.color.withOpacity(0.1),
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: option.color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              color: isLoading ? AppColors.textHint : option.color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              option.displayName,
              style: TextStyle(
                color: isLoading ? AppColors.textHint : option.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
