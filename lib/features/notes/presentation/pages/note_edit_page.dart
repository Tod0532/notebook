/// 笔记编辑页

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/features/notes/presentation/widgets/image_preview_grid.dart';
import 'package:thick_notepad/features/notes/utils/image_utils.dart';
import 'package:thick_notepad/features/emotion/presentation/providers/emotion_providers.dart';
import 'package:thick_notepad/features/emotion/presentation/widgets/emotion_insight_card.dart';
import 'package:thick_notepad/features/speech/presentation/widgets/voice_floating_button.dart';
import 'package:thick_notepad/features/speech/presentation/providers/speech_providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
import 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';
import 'package:thick_notepad/services/image/image_service.dart';
import 'package:thick_notepad/features/notes/presentation/widgets/export_bottom_sheet.dart';
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
  final List<String> _images = [];
  String? _selectedFolder;
  bool _isLoading = false;
  Note? _existingNote;
  EmotionResult? _emotionAnalysis;

  // 图片服务
  final _imageService = ImageService.instance;

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
      _selectedFolder = _existingNote!.folder;
      _images.addAll(ImageUtils.parseImages(_existingNote!.images));
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
          // 语音输入按钮
          _VoiceInputButton(
            contentController: _contentController,
            titleController: _titleController,
          ),
          // 情绪分析按钮
          IconButton(
            icon: const Icon(Icons.mood),
            onPressed: _analyzeEmotion,
            tooltip: '分析情绪',
          ),
          // 导出按钮（仅编辑模式显示）
          if (widget.noteId != null && _existingNote != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () => _showExportSheet(context),
              tooltip: '导出',
            ),
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
                      // 图片预览区域
                      if (_images.isNotEmpty)
                        ImagePreviewGrid(
                          imagePaths: _images,
                          onImagesChanged: (images) {
                            setState(() => _images.clear());
                            _images.addAll(images);
                          },
                        ),
                      // 富文本格式工具栏
                      _buildFormatToolbar(context),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: '开始写下你的想法...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => _onContentChanged(),
                      ),
                      // 情绪分析结果
                      if (_emotionAnalysis != null) _buildEmotionResult(context),
                    ],
                  ),
                ),
                _buildFolderBar(context),
                _buildTagsBar(context),
                _buildImageBar(context),
              ],
            ),
    );
  }

  Widget _buildFolderBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text(
            '文件夹',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
          const Spacer(),
          InkWell(
            onTap: _showFolderSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedFolder ?? '未分类',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _selectedFolder != null
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                  ),
                  if (_selectedFolder != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() => _selectedFolder = null);
                        HapticHelper.lightTap();
                      },
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
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

  /// 构建图片操作栏
  Widget _buildImageBar(BuildContext context) {
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
        child: Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.textHint),
            const SizedBox(width: 8),
            Text(
              '图片',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            const Spacer(),
            // 多选图片按钮
            _buildImageButton(
              icon: Icons.photo_library,
              label: '相册',
              onTap: _pickMultiImage,
            ),
            const SizedBox(width: 8),
            // 拍照按钮
            _buildImageButton(
              icon: Icons.camera_alt,
              label: '拍照',
              onTap: _takePhoto,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建图片操作按钮
  Widget _buildImageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择多张图片
  Future<void> _pickMultiImage() async {
    HapticHelper.lightTap();

    if (_images.length >= ImageConfig.maxImagesPerNote) {
      _showSnackBar('最多只能添加 ${ImageConfig.maxImagesPerNote} 张图片');
      return;
    }

    final pickedImages = await _imageService.pickMultiImage();

    if (pickedImages.isEmpty) {
      return;
    }

    // 检查数量限制
    final availableSlots = ImageConfig.maxImagesPerNote - _images.length;
    final imagesToAdd = pickedImages.take(availableSlots).toList();

    setState(() {
      _images.addAll(imagesToAdd);
    });

    if (pickedImages.length > availableSlots) {
      _showSnackBar('已添加 $availableSlots 张图片（达到上限）');
    } else {
      _showSnackBar('已添加 ${imagesToAdd.length} 张图片');
    }
  }

  /// 拍照
  Future<void> _takePhoto() async {
    HapticHelper.lightTap();

    if (_images.length >= ImageConfig.maxImagesPerNote) {
      _showSnackBar('最多只能添加 ${ImageConfig.maxImagesPerNote} 张图片');
      return;
    }

    final imagePath = await _imageService.takePhoto();

    if (imagePath != null) {
      setState(() {
        _images.add(imagePath);
      });
      _showSnackBar('已添加图片');
    }
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

  void _showFolderSelector() async {
    HapticHelper.lightTap();
    final allNotes = await ref.read(allNotesProvider.future);
    final folders = allNotes
        .map((n) => n.folder)
        .where((f) => f != null && f.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _FolderSelectorDialog(
        currentFolder: _selectedFolder,
        existingFolders: folders,
        onSelect: (folder) {
          setState(() => _selectedFolder = folder);
        },
      ),
    );
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _images.isEmpty) {
      _showSnackBar('请输入标题、内容或添加图片');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tagsJson = _formatTags(_tags);
      final imagesJson = ImageUtils.formatImages(_images);
      int? savedNoteId;

      if (widget.noteId == null) {
        savedNoteId = await ref.read(createNoteProvider.notifier).create(
              NotesCompanion.insert(
                title: drift.Value(title.isEmpty ? null : title),
                content: content,
                tags: drift.Value(tagsJson),
                folder: _selectedFolder != null ? drift.Value(_selectedFolder) : const drift.Value(null),
                images: drift.Value(imagesJson),
              ),
            );
        ref.invalidate(allNotesProvider);

        // 保存后自动分析情绪
        if (content.isNotEmpty && savedNoteId != null) {
          await ref.read(createEmotionRecordProvider.notifier).createFromNote(savedNoteId, content);
        }
      } else {
        await ref.read(updateNoteProvider.notifier).update(
              _existingNote!.copyWith(
                title: title.isEmpty ? const drift.Value(null) : drift.Value(title),
                content: content,
                tags: tagsJson,
                folder: _selectedFolder != null ? drift.Value(_selectedFolder) : const drift.Value(null),
                images: drift.Value(imagesJson),
                updatedAt: DateTime.now(),
              ),
            );
        ref.invalidate(allNotesProvider);
        savedNoteId = widget.noteId;

        // 更新后重新分析情绪
        if (content.isNotEmpty) {
          // 先删除旧的记录
          await ref.read(createEmotionRecordProvider.notifier).deleteByNote(widget.noteId!);
          // 创建新的分析记录
          await ref.read(createEmotionRecordProvider.notifier).createFromNote(widget.noteId!, content);
        }
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

  /// 分析情绪
  void _analyzeEmotion() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('请先输入笔记内容');
      return;
    }

    HapticHelper.lightTap();
    final result = EmotionAnalyzer.analyze(content);
    setState(() => _emotionAnalysis = result);

    // 显示分析结果对话框
    if (mounted) {
      _showEmotionDialog(result);
    }
  }

  /// 内容变化时自动分析情绪（防抖）
  DateTime? _lastAnalysisTime;
  void _onContentChanged() {
    final now = DateTime.now();
    if (_lastAnalysisTime != null &&
        now.difference(_lastAnalysisTime!).inSeconds < 2) {
      return;
    }

    final content = _contentController.text.trim();
    if (content.length > 10) {
      _lastAnalysisTime = now;
      final result = EmotionAnalyzer.analyze(content);
      setState(() => _emotionAnalysis = result);
    }
  }

  /// 显示情绪分析结果对话框
  void _showEmotionDialog(EmotionResult result) {
    showDialog(
      context: context,
      builder: (context) => _EmotionResultDialog(result: result),
    );
  }

  /// 构建情绪分析结果卡片
  Widget _buildEmotionResult(BuildContext context) {
    final result = _emotionAnalysis!;
    final color = Color(
      int.parse(result.emotion.colorHex.replaceFirst('#', '0xFF')),
    );
    final recommendation = EmotionWorkoutMapper.getBestRecommendation(result.emotion);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmotionIcon(emotion: result.emotion, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '检测到：${result.emotion.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '置信度 ${(result.confidence * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.withOpacity(0.8),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _emotionAnalysis = null),
                color: color.withOpacity(0.6),
              ),
            ],
          ),
          if (result.matchedKeywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.matchedKeywords.take(5).map((keyword) {
                return Chip(
                  label: Text(keyword),
                  labelStyle: TextStyle(fontSize: 12, color: color),
                  backgroundColor: color.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: AppRadius.mdRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_run, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '推荐：${recommendation.workoutType.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                Text(
                  recommendation.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  /// 显示导出底部表单
  void _showExportSheet(BuildContext context) {
    if (_existingNote == null) return;
    HapticHelper.lightTap();
    ExportBottomSheet.show(
      context: context,
      note: _existingNote!,
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

  /// 应用Markdown格式到选中文本
  void _applyFormat(String format) {
    HapticHelper.lightTap();
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (!selection.isValid) {
      // 没有选中文本，在光标位置插入格式标记
      final cursorPos = selection.baseOffset;
      final formatStr = _getFormatString(format);
      final newText = text.substring(0, cursorPos) +
                      formatStr['prefix']! +
                      formatStr['suffix']! +
                      text.substring(cursorPos);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + formatStr['prefix']!.length,
        ),
      );
      return;
    }

    // 有选中文本，包裹选中内容
    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);
    final formatStr = _getFormatString(format);

    // 如果选中文本已经被该格式包裹，则移除格式
    if (selectedText.startsWith(formatStr['prefix']!) &&
        selectedText.endsWith(formatStr['suffix']!) &&
        selectedText.length >= formatStr['prefix']!.length + formatStr['suffix']!.length) {
      final unformattedText = selectedText.substring(
        formatStr['prefix']!.length,
        selectedText.length - formatStr['suffix']!.length,
      );
      final newText = text.substring(0, start) +
                      unformattedText +
                      text.substring(end);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + unformattedText.length),
      );
      return;
    }

    // 添加格式包裹
    final newText = text.substring(0, start) +
                    formatStr['prefix']! +
                    selectedText +
                    formatStr['suffix']! +
                    text.substring(end);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: end + formatStr['prefix']!.length + formatStr['suffix']!.length,
      ),
    );
  }

  /// 获取格式标记前缀和后缀
  Map<String, String> _getFormatString(String format) {
    switch (format) {
      case 'bold':
        return {'prefix': '**', 'suffix': '**'};
      case 'italic':
        return {'prefix': '*', 'suffix': '*'};
      case 'strikethrough':
        return {'prefix': '~~', 'suffix': '~~'};
      case 'heading':
        return {'prefix': '## ', 'suffix': ''};
      case 'list':
        return {'prefix': '- ', 'suffix': ''};
      case 'quote':
        return {'prefix': '> ', 'suffix': ''};
      case 'code':
        return {'prefix': '`', 'suffix': '`'};
      case 'hr':
        return {'prefix': '\n---\n', 'suffix': ''};
      default:
        return {'prefix': '', 'suffix': ''};
    }
  }

  /// 构建格式工具栏
  Widget _buildFormatToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _formatButtons.map((btn) {
          return _buildFormatButton(
            context: context,
            icon: btn.icon,
            label: btn.label,
            format: btn.format,
            tooltip: btn.tooltip,
          );
        }).toList(),
      ),
    );
  }

  /// 构建单个格式按钮
  Widget _buildFormatButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String format,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _applyFormat(format),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 情绪分析结果对话框
class _EmotionResultDialog extends StatelessWidget {
  final EmotionResult result;

  const _EmotionResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(result.emotion.colorHex.replaceFirst('#', '0xFF')),
    );
    final recommendation = EmotionWorkoutMapper.getBestRecommendation(result.emotion);
    final suggestion = EmotionAnalyzer.getSuggestion(result.emotion);

    return AlertDialog(
      title: Row(
        children: [
          EmotionIcon(emotion: result.emotion, size: 28),
          const SizedBox(width: 12),
          Text('情绪分析'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主要情绪
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Column(
                children: [
                  Text(
                    result.emotion.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '置信度 ${(result.confidence * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 匹配关键词
            if (result.matchedKeywords.isNotEmpty) ...[
              Text(
                '检测到的关键词',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.matchedKeywords.map((keyword) {
                  return Chip(
                    label: Text(keyword),
                    backgroundColor: color.withOpacity(0.15),
                    labelStyle: TextStyle(color: color),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 情绪建议
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 运动推荐
            Text(
              '推荐运动',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: AppRadius.mdRadius,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_run, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        recommendation.workoutType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getIntensityLabel(recommendation.intensity),
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation.reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (recommendation.suggestedDuration != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '建议时长：${recommendation.suggestedDuration}分钟',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  String _getIntensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return '轻松';
      case 2:
        return '轻度';
      case 3:
        return '中等';
      case 4:
        return '较强';
      case 5:
        return '高强度';
      default:
        return '';
    }
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

/// 格式按钮数据类
class _FormatButton {
  final IconData icon;
  final String label;
  final String format;
  final String tooltip;

  const _FormatButton({
    required this.icon,
    required this.label,
    required this.format,
    required this.tooltip,
  });
}

/// 格式按钮列表
const List<_FormatButton> _formatButtons = [
  _FormatButton(
    icon: Icons.format_bold,
    label: 'B',
    format: 'bold',
    tooltip: '粗体',
  ),
  _FormatButton(
    icon: Icons.format_italic,
    label: 'I',
    format: 'italic',
    tooltip: '斜体',
  ),
  _FormatButton(
    icon: Icons.strikethrough_s,
    label: 'S',
    format: 'strikethrough',
    tooltip: '删除线',
  ),
  _FormatButton(
    icon: Icons.title,
    label: '',
    format: 'heading',
    tooltip: '标题',
  ),
  _FormatButton(
    icon: Icons.format_list_bulleted,
    label: '',
    format: 'list',
    tooltip: '列表',
  ),
  _FormatButton(
    icon: Icons.format_quote,
    label: '',
    format: 'quote',
    tooltip: '引用',
  ),
  _FormatButton(
    icon: Icons.code,
    label: '',
    format: 'code',
    tooltip: '代码',
  ),
  _FormatButton(
    icon: Icons.horizontal_rule,
    label: '',
    format: 'hr',
    tooltip: '分割线',
  ),
];

/// 文件夹选择对话框
class _FolderSelectorDialog extends StatefulWidget {
  final String? currentFolder;
  final List<String> existingFolders;
  final ValueChanged<String> onSelect;

  const _FolderSelectorDialog({
    required this.currentFolder,
    required this.existingFolders,
    required this.onSelect,
  });

  @override
  State<_FolderSelectorDialog> createState() => _FolderSelectorDialogState();
}

class _FolderSelectorDialogState extends State<_FolderSelectorDialog> {
  final _controller = TextEditingController();
  String _inputFolder = '';

  @override
  void initState() {
    super.initState();
    if (widget.currentFolder != null) {
      _controller.text = widget.currentFolder!;
      _inputFolder = widget.currentFolder!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择文件夹'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入或选择文件夹名称',
                suffixIcon: _inputFolder.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _confirmSelect,
                      )
                    : null,
              ),
              onChanged: (value) => _inputFolder = value.trim(),
              onSubmitted: (_) => _confirmSelect(),
            ),
            const SizedBox(height: 16),
            if (widget.existingFolders.isNotEmpty) ...[
              Text(
                '现有文件夹',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textHint,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.existingFolders.map((folder) {
                  final isSelected = folder == _inputFolder;
                  return FilterChip(
                    label: Text(folder),
                    selected: isSelected,
                    onSelected: (_) => _selectFolder(folder),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '常用文件夹',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['工作', '生活', '学习', '日记', '项目', '灵感'].map((folder) {
                final isSelected = folder == _inputFolder;
                return FilterChip(
                  label: Text(folder),
                  selected: isSelected,
                  onSelected: (_) => _selectFolder(folder),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (widget.currentFolder != null)
          TextButton(
            onPressed: () {
              widget.onSelect('');
              HapticHelper.lightTap();
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
        TextButton(
          onPressed: _inputFolder.isEmpty ? null : _confirmSelect,
          child: const Text('确定'),
        ),
      ],
    );
  }

  void _selectFolder(String folder) {
    setState(() {
      _controller.text = folder;
      _inputFolder = folder;
    });
    HapticHelper.lightTap();
  }

  void _confirmSelect() {
    if (_inputFolder.isEmpty) return;
    widget.onSelect(_inputFolder);
    HapticHelper.lightTap();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// 语音输入按钮 - 使用原生 Android RecognizerIntent
class _VoiceInputButton extends StatefulWidget {
  final TextEditingController contentController;
  final TextEditingController? titleController;

  const _VoiceInputButton({
    required this.contentController,
    this.titleController,
  });

  @override
  State<_VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<_VoiceInputButton> {
  bool _isTitleInput = false;

  Future<void> _startNativeSpeechRecognition() async {
    try {
      // 检查麦克风权限
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (mounted) {
            _showErrorSnackBar('需要麦克风权限');
          }
          return;
        }
      }

      // 显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isTitleInput ? '正在输入标题...' : '正在输入内容...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 调用原生语音识别
      const channel = MethodChannel('com.thicknotepad.thick_notepad/speech');
      final result = await channel.invokeMethod('startSpeechRecognition', {
        'language': 'zh-CN',
      });

      if (result is Map && result['text'] != null) {
        final text = result['text'] as String;
        if (text.isNotEmpty) {
          _handleVoiceResult(text);
        }
      }
    } catch (e) {
      debugPrint('原生语音识别失败: $e');
      if (mounted) {
        _showErrorSnackBar('语音识别失败: $e');
      }
    }
  }

  void _handleVoiceResult(String text) {
    if (text.trim().isEmpty) return;

    HapticHelper.lightTap();

    // 如果是标题输入
    if (_isTitleInput && widget.titleController != null) {
      widget.titleController!.text = text.trim();
    } else {
      // 内容输入
      final currentContent = widget.contentController.text;
      final cursorPosition = widget.contentController.selection.baseOffset;

      String newContent;
      if (cursorPosition >= 0 && cursorPosition < currentContent.length) {
        // 在光标位置插入
        newContent = currentContent.substring(0, cursorPosition) +
                     '\n$text' +
                     currentContent.substring(cursorPosition);
      } else {
        // 追加到末尾
        newContent = currentContent.isEmpty ? text : '$currentContent\n\n$text';
      }

      widget.contentController.value = TextEditingValue(
        text: newContent,
        selection: TextSelection.collapsed(
          offset: newContent.length,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isTitleInput ? '标题已添加' : '内容已添加'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '重试',
          textColor: Colors.white,
          onPressed: () => _startNativeSpeechRecognition(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.mic,
        color: AppColors.textPrimary,
      ),
      tooltip: '语音输入',
      onSelected: (value) {
        setState(() {
          _isTitleInput = value == 'title';
        });
        _startNativeSpeechRecognition();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'title',
          child: Row(
            children: const [
              Icon(Icons.title, size: 18),
              SizedBox(width: 8),
              Text('语音输入标题'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'content',
          child: Row(
            children: const [
              Icon(Icons.edit_note, size: 18),
              SizedBox(width: 8),
              Text('语音输入内容'),
            ],
          ),
        ),
      ],
    );
  }
}
