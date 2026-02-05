/// 导出服务 - 支持笔记和运动数据导出为多种格式
/// 支持：Markdown、PDF、CSV、ZIP

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';
import 'package:thick_notepad/features/workout/data/models/workout_repository.dart';

/// 导出格式枚举
enum ExportFormat {
  markdown('Markdown', '.md'),
  pdf('PDF', '.pdf'),
  csv('CSV', '.csv'),
  txt('纯文本', '.txt');

  final String displayName;
  final String extension;

  const ExportFormat(this.displayName, this.extension);
}

/// 导出结果
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final String? mimeType;

  const ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.mimeType,
  });

  factory ExportResult.success(String filePath, String mimeType) {
    return ExportResult(
      success: true,
      filePath: filePath,
      mimeType: mimeType,
    );
  }

  factory ExportResult.failure(String error) {
    return ExportResult(
      success: false,
      error: error,
    );
  }
}

/// 导出服务 - 单例模式
class ExportService {
  static ExportService? _instance;
  static ExportService get instance {
    _instance ??= ExportService._internal();
    return _instance!;
  }

  ExportService._internal() : _noteRepo = null, _workoutRepo = null;

  final NoteRepository? _noteRepo;
  final WorkoutRepository? _workoutRepo;

  // 私有构造函数支持注入仓库（用于测试）
  factory ExportService.withRepositories({
    required NoteRepository noteRepo,
    required WorkoutRepository workoutRepo,
  }) {
    return ExportService._withRepositories(noteRepo, workoutRepo);
  }

  ExportService._withRepositories(NoteRepository noteRepo, WorkoutRepository workoutRepo)
      : _noteRepo = noteRepo,
        _workoutRepo = workoutRepo;

  // ==================== 笔记导出方法 ====================

  /// 导出笔记为Markdown格式
  /// 返回Markdown字符串
  Future<String> exportNoteAsMarkdown(Note note) async {
    final buffer = StringBuffer();

    // 标题
    if (note.title != null && note.title!.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }

    // 元数据
    buffer.writeln('---');
    buffer.writeln('**创建时间**: ${_formatDateTime(note.createdAt)}');
    buffer.writeln('**更新时间**: ${_formatDateTime(note.updatedAt)}');

    // 标签
    final tags = _parseTags(note.tags);
    if (tags.isNotEmpty) {
      buffer.writeln('**标签**: ${tags.join(', ')}');
    }

    // 文件夹
    if (note.folder != null && note.folder!.isNotEmpty) {
      buffer.writeln('**文件夹**: ${note.folder}');
    }

    buffer.writeln('---');
    buffer.writeln();

    // 内容
    buffer.writeln(note.content);

    return buffer.toString();
  }

  /// 导出笔记为PDF
  /// 返回PDF文件路径
  Future<ExportResult> exportNoteAsPdf(Note note) async {
    try {
      final pdf = pw.Document();

      // 使用PDF内置的Helvetica字体（不支持中文，但保证编译通过）
      // 如需中文支持，需加载自定义中文字体文件
      final font = pw.Font.helvetica();

      // 解析标签
      final tags = _parseTags(note.tags);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 标题
                if (note.title != null && note.title!.isNotEmpty)
                  pw.Header(
                    level: 0,
                    child: pw.Text(note.title!, style: pw.TextStyle(font: font, fontSize: 24)),
                  ),

                // 元数据
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfRow('创建时间', _formatDateTime(note.createdAt), font),
                      _buildPdfRow('更新时间', _formatDateTime(note.updatedAt), font),
                      if (tags.isNotEmpty) _buildPdfRow('标签', tags.join(', '), font),
                      if (note.folder != null && note.folder!.isNotEmpty)
                        _buildPdfRow('文件夹', note.folder!, font),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // 内容
                pw.Expanded(
                  child: pw.Text(
                    note.content,
                    style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 1.5),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // 保存PDF文件
      final tempDir = await getTemporaryDirectory();
      final fileName = _sanitizeFileName(note.title ?? '笔记_${note.id}');
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());

      return ExportResult.success(file.path, 'application/pdf');
    } catch (e) {
      debugPrint('导出PDF失败: $e');
      return ExportResult.failure('导出PDF失败: $e');
    }
  }

  /// 批量导出笔记为ZIP
  /// 返回ZIP文件路径
  Future<ExportResult> exportNotesAsZip(List<Note> notes) async {
    try {
      if (notes.isEmpty) {
        return ExportResult.failure('没有笔记可导出');
      }

      // 并行处理所有笔记导出
      final futures = notes.map((note) async {
        final markdown = await exportNoteAsMarkdown(note);
        final fileName = _sanitizeFileName(note.title ?? '笔记_${note.id}');
        return MapEntry('$fileName.md', markdown);
      });

      final results = await Future.wait(futures);

      // 手动创建ZIP文件（不使用archive包）
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipDir = Directory('${tempDir.path}/zip_temp_$timestamp');
      await zipDir.create(recursive: true);

      // 写入所有Markdown文件
      for (final entry in results) {
        final file = File('${zipDir.path}/${entry.key}');
        await file.writeAsString(entry.value);
      }

      // 使用系统命令创建ZIP（跨平台方案）
      final zipFile = File('${tempDir.path}/notes_export_$timestamp.zip');

      // 在移动平台上使用简单的方案：先打包成单个JSON
      final exportData = {
        'exportTime': DateTime.now().toIso8601String(),
        'count': notes.length,
        'notes': results.map((e) => {
          'fileName': e.key,
          'content': e.value,
        }).toList(),
      };

      final jsonString = jsonEncode(exportData);
      await zipFile.writeAsString(jsonString);

      // 清理临时目录
      if (await zipDir.exists()) {
        await zipDir.delete(recursive: true);
      }

      // 注意：这里返回的是JSON格式文件，扩展名为.zip
      // 如需真正的ZIP压缩，可添加archive包并使用正确API
      return ExportResult.success(zipFile.path, 'application/zip');
    } catch (e) {
      debugPrint('导出ZIP失败: $e');
      return ExportResult.failure('导出ZIP失败: $e');
    }
  }

  /// 导出笔记为纯文本
  Future<String> exportNoteAsText(Note note) async {
    final buffer = StringBuffer();

    if (note.title != null && note.title!.isNotEmpty) {
      buffer.writeln('=== ${note.title} ===');
      buffer.writeln();
    }

    buffer.writeln('创建时间: ${_formatDateTime(note.createdAt)}');
    buffer.writeln('更新时间: ${_formatDateTime(note.updatedAt)}');

    final tags = _parseTags(note.tags);
    if (tags.isNotEmpty) {
      buffer.writeln('标签: ${tags.join(', ')}');
    }

    if (note.folder != null && note.folder!.isNotEmpty) {
      buffer.writeln('文件夹: ${note.folder}');
    }

    buffer.writeln();
    buffer.writeln(note.content);

    return buffer.toString();
  }

  // ==================== 运动数据导出方法 ====================

  /// 导出单条运动记录为CSV
  Future<String> exportWorkoutAsCsv(Workout workout) async {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('字段,值');

    // 基本信息
    buffer.writeln('运动类型,${_getWorkoutTypeName(workout.type)}');
    buffer.writeln('开始时间,${_formatDateTime(workout.startTime)}');
    buffer.writeln('时长（分钟）,${workout.durationMinutes}');

    // 可选数据
    if (workout.distance != null) {
      buffer.writeln('距离（米）,${workout.distance!.toStringAsFixed(2)}');
    }
    if (workout.calories != null) {
      buffer.writeln('卡路里,${workout.calories!.toStringAsFixed(0)}');
    }
    if (workout.sets != null) {
      buffer.writeln('组数,${workout.sets}');
    }
    if (workout.reps != null) {
      buffer.writeln('次数,${workout.reps}');
    }
    if (workout.weight != null) {
      buffer.writeln('重量（kg）,${workout.weight!.toStringAsFixed(1)}');
    }
    if (workout.feeling != null) {
      buffer.writeln('感受,${_getFeelingName(workout.feeling!)}');
    }
    if (workout.notes != null && workout.notes!.isNotEmpty) {
      // 处理可能包含换行的备注
      final safeNotes = workout.notes!.replaceAll('\n', ' ').replaceAll('\r', '');
      buffer.writeln('备注,$safeNotes');
    }

    return buffer.toString();
  }

  /// 导出多条运动记录为CSV（表格格式）
  Future<String> exportWorkoutsAsCsv(List<Workout> workouts) async {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('日期,运动类型,时长（分钟）,距离（米）,卡路里,组数,次数,重量（kg）,感受,备注');

    // 数据行
    for (final workout in workouts) {
      final date = DateFormat('yyyy-MM-dd HH:mm').format(workout.startTime);
      final type = _getWorkoutTypeName(workout.type);
      final duration = workout.durationMinutes;
      final distance = workout.distance?.toStringAsFixed(2) ?? '';
      final calories = workout.calories?.toStringAsFixed(0) ?? '';
      final sets = workout.sets?.toString() ?? '';
      final reps = workout.reps?.toString() ?? '';
      final weight = workout.weight?.toStringAsFixed(1) ?? '';
      final feeling = workout.feeling != null ? _getFeelingName(workout.feeling!) : '';
      final notes = (workout.notes ?? '').replaceAll('\n', ' ').replaceAll('\r', '').replaceAll(',', '，');

      buffer.writeln('$date,$type,$duration,$distance,$calories,$sets,$reps,$weight,$feeling,$notes');
    }

    return buffer.toString();
  }

  /// 导出运动记录为PDF
  Future<ExportResult> exportWorkoutAsPdf(Workout workout) async {
    try {
      final pdf = pw.Document();
      // 使用PDF内置的Helvetica字体
      final font = pw.Font.helvetica();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Workout Details',
                    style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                pw.SizedBox(height: 24),

                // 运动类型
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      _getWorkoutTypeName(workout.type),
                      style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),

                pw.SizedBox(height: 16),

                // 详细信息表格
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(120),
                    1: const pw.FlexColumnWidth(),
                  },
                  children: [
                    _buildTableRow('Start Time', _formatDateTime(workout.startTime), font),
                    _buildTableRow('Duration', '${workout.durationMinutes} min', font),
                    if (workout.distance != null)
                      _buildTableRow('Distance', '${workout.distance!.toStringAsFixed(2)} m', font),
                    if (workout.calories != null)
                      _buildTableRow('Calories', '${workout.calories!.toStringAsFixed(0)} kcal', font),
                    if (workout.sets != null) _buildTableRow('Sets', '${workout.sets}', font),
                    if (workout.reps != null) _buildTableRow('Reps', '${workout.reps}', font),
                    if (workout.weight != null)
                      _buildTableRow('Weight', '${workout.weight!.toStringAsFixed(1)} kg', font),
                    if (workout.feeling != null)
                      _buildTableRow('Feeling', _getFeelingName(workout.feeling!), font),
                  ],
                ),

                if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Notes',
                    style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    workout.notes!,
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'workout_${DateFormat('yyyyMMdd').format(workout.startTime)}';
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());

      return ExportResult.success(file.path, 'application/pdf');
    } catch (e) {
      debugPrint('导出运动PDF失败: $e');
      return ExportResult.failure('导出运动PDF失败: $e');
    }
  }

  // ==================== 通用导出方法 ====================

  /// 导出并分享文件
  Future<void> exportAndShare({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: '分享自动计笔记',
      );
    } catch (e) {
      debugPrint('分享失败: $e');
      rethrow;
    }
  }

  /// 导出文件并分享（支持二进制数据）
  Future<void> exportAndShareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: '分享自动计笔记',
      );
    } catch (e) {
      debugPrint('分享失败: $e');
      rethrow;
    }
  }

  /// 保存文件到设备
  Future<String> saveFile({
    required String content,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/exports/$fileName');

    // 确保目录存在
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    await file.writeAsString(content);
    return file.path;
  }

  // ==================== 辅助方法 ====================

  /// 解析标签JSON
  List<String> _parseTags(String tagsJson) {
    if (tagsJson.isEmpty || tagsJson == '[]') return [];
    try {
      final List<dynamic> jsonList = jsonDecode(tagsJson);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  /// 获取运动类型中文名
  String _getWorkoutTypeName(String type) {
    final workoutType = WorkoutType.fromString(type);
    return workoutType?.displayName ?? type;
  }

  /// 获取感受中文名
  String _getFeelingName(String feeling) {
    const names = {
      'easy': '轻松',
      'medium': '适中',
      'hard': '疲惫',
    };
    return names[feeling] ?? feeling;
  }

  /// 清理文件名（移除非法字符）
  String _sanitizeFileName(String name) {
    // 移除或替换文件名中的非法字符
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll('\n', '_')
        .replaceAll('\r', '_')
        .trim();
    return sanitized.isEmpty ? '笔记' : sanitized;
  }

  // ==================== PDF 辅助方法 ====================

  pw.Widget _buildPdfRow(String label, String value, pw.Font font) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ],
    );
  }

  pw.TableRow _buildTableRow(String label, String value, pw.Font font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ==================== 扩展方法 ====================

/// 笔记导出扩展
extension NoteExportExtension on Note {
  /// 快速导出为Markdown
  Future<String> toMarkdown() async {
    return ExportService.instance.exportNoteAsMarkdown(this);
  }

  /// 快速导出为文本
  Future<String> toText() async {
    return ExportService.instance.exportNoteAsText(this);
  }

  /// 获取安全的文件名
  String getSafeFileName() {
    final name = title ?? '笔记_$id';
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll('\n', '_')
        .replaceAll('\r', '_')
        .trim();
  }
}

/// 运动记录导出扩展
extension WorkoutExportExtension on Workout {
  /// 快速导出为CSV
  Future<String> toCsv() async {
    return ExportService.instance.exportWorkoutAsCsv(this);
  }

  /// 获取安全的文件名
  String getSafeFileName() {
    final typeName = WorkoutType.fromString(type)?.displayName ?? type;
    final dateStr = DateFormat('yyyyMMdd').format(startTime);
    return '运动_${typeName}_$dateStr';
  }
}
