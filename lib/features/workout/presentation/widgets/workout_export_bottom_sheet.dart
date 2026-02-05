/// 运动记录导出底部表单 - 用于选择导出格式和执行导出
///
/// 支持的导出格式：
/// - CSV (.csv)
/// - PDF (.pdf)
/// - JSON (.json)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/core/utils/date_formatter.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/export/export_service.dart';

/// 运动导出选项类型
enum WorkoutExportOption {
  csv,
  pdf,
  json,
  copy,
  share;

  String get displayName {
    switch (this) {
      case WorkoutExportOption.csv:
        return 'CSV 表格';
      case WorkoutExportOption.pdf:
        return 'PDF 报告';
      case WorkoutExportOption.json:
        return 'JSON 数据';
      case WorkoutExportOption.copy:
        return '复制数据';
      case WorkoutExportOption.share:
        return '直接分享';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutExportOption.csv:
        return Icons.table_chart;
      case WorkoutExportOption.pdf:
        return Icons.picture_as_pdf;
      case WorkoutExportOption.json:
        return Icons.code;
      case WorkoutExportOption.copy:
        return Icons.copy;
      case WorkoutExportOption.share:
        return Icons.share;
    }
  }

  Color get color {
    switch (this) {
      case WorkoutExportOption.csv:
        return const Color(0xFF10B981);
      case WorkoutExportOption.pdf:
        return const Color(0xFFEF4444);
      case WorkoutExportOption.json:
        return const Color(0xFFF59E0B);
      case WorkoutExportOption.copy:
        return AppColors.primary;
      case WorkoutExportOption.share:
        return AppColors.success;
    }
  }
}

/// 运动记录导出底部表单
class WorkoutExportBottomSheet extends StatefulWidget {
  final Workout workout;
  final List<Workout>? workouts; // 用于批量导出

  const WorkoutExportBottomSheet({
    super.key,
    required this.workout,
    this.workouts,
  });

  /// 显示导出底部表单
  static Future<void> show({
    required BuildContext context,
    required Workout workout,
    List<Workout>? workouts,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WorkoutExportBottomSheet(
        workout: workout,
        workouts: workouts,
      ),
    );
  }

  @override
  State<WorkoutExportBottomSheet> createState() => _WorkoutExportBottomSheetState();
}

class _WorkoutExportBottomSheetState extends State<WorkoutExportBottomSheet> {
  final ExportService _exportService = ExportService.instance;

  bool _isExporting = false;

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
                    '导出运动记录',
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

            // 运动记录预览
            _buildWorkoutPreview(context),

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

                  // 导出选项
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _WorkoutExportOptionTile(
                        option: WorkoutExportOption.csv,
                        onTap: () => _handleExport(WorkoutExportOption.csv),
                        isLoading: _isExporting,
                      ),
                      _WorkoutExportOptionTile(
                        option: WorkoutExportOption.pdf,
                        onTap: () => _handleExport(WorkoutExportOption.pdf),
                        isLoading: _isExporting,
                      ),
                      _WorkoutExportOptionTile(
                        option: WorkoutExportOption.json,
                        onTap: () => _handleExport(WorkoutExportOption.json),
                        isLoading: _isExporting,
                      ),
                      _WorkoutExportOptionTile(
                        option: WorkoutExportOption.copy,
                        onTap: () => _handleExport(WorkoutExportOption.copy),
                        isLoading: _isExporting,
                      ),
                      _WorkoutExportOptionTile(
                        option: WorkoutExportOption.share,
                        onTap: () => _handleExport(WorkoutExportOption.share),
                        isLoading: _isExporting,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 批量导出选项
            if (widget.workouts != null && widget.workouts!.length > 1)
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

  Widget _buildWorkoutPreview(BuildContext context) {
    final workoutType = WorkoutType.fromString(widget.workout.type);
    final typeName = workoutType?.displayName ?? widget.workout.type;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Row(
        children: [
          // 运动类型图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getWorkoutTypeColor(widget.workout.type).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _getWorkoutTypeIcon(widget.workout.type),
                color: _getWorkoutTypeColor(widget.workout.type),
                size: 28,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 运动信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormatter.formatDateTime(widget.workout.startTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      context,
                      icon: Icons.access_time,
                      label: '${widget.workout.durationMinutes}分钟',
                    ),
                    const SizedBox(width: 8),
                    if (widget.workout.calories != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.local_fire_department,
                        label: '${widget.workout.calories!.toStringAsFixed(0)}千卡',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchExportSection(BuildContext context) {
    final workoutCount = widget.workouts?.length ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: _isExporting ? null : _handleBatchExportCsv,
        borderRadius: AppRadius.mdRadius,
        child: Row(
          children: [
            Icon(Icons.table_chart, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '批量导出为 CSV',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '导出 $workoutCount 条运动记录',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(WorkoutExportOption option) async {
    HapticHelper.mediumTap();

    setState(() => _isExporting = true);

    try {
      switch (option) {
        case WorkoutExportOption.csv:
          await _exportAsCsv();
          break;
        case WorkoutExportOption.pdf:
          await _exportAsPdf();
          break;
        case WorkoutExportOption.json:
          await _exportAsJson();
          break;
        case WorkoutExportOption.copy:
          await _copyToClipboard();
          break;
        case WorkoutExportOption.share:
          await _shareWorkout();
          break;
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportAsCsv() async {
    final csv = await _exportService.exportWorkoutAsCsv(widget.workout);
    final fileName = widget.workout.getSafeFileName();

    await _exportService.exportAndShare(
      content: csv,
      fileName: '$fileName.csv',
      mimeType: 'text/csv',
    );

    if (mounted) {
      _showSuccessSnackBar('CSV 导出成功');
    }
  }

  Future<void> _exportAsPdf() async {
    final result = await _exportService.exportWorkoutAsPdf(widget.workout);

    if (!result.success) {
      throw Exception(result.error ?? 'PDF 导出失败');
    }

    if (result.filePath != null) {
      await Share.shareXFiles(
        [XFile(result.filePath!)],
        text: '分享运动记录 PDF',
      );
    }

    if (mounted) {
      _showSuccessSnackBar('PDF 导出成功');
    }
  }

  Future<void> _exportAsJson() async {
    final json = _workoutToJson(widget.workout);
    final fileName = widget.workout.getSafeFileName();

    await _exportService.exportAndShare(
      content: json,
      fileName: '$fileName.json',
      mimeType: 'application/json',
    );

    if (mounted) {
      _showSuccessSnackBar('JSON 导出成功');
    }
  }

  Future<void> _copyToClipboard() async {
    final csv = await _exportService.exportWorkoutAsCsv(widget.workout);

    await Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      _showSuccessSnackBar('已复制到剪贴板');
    }
  }

  Future<void> _shareWorkout() async {
    final csv = await _exportService.exportWorkoutAsCsv(widget.workout);

    final workoutType = WorkoutType.fromString(widget.workout.type)?.displayName ?? widget.workout.type;
    final shareText = '$workoutType - ${widget.workout.durationMinutes}分钟\n$csv';

    await Share.share(
      shareText,
      subject: '运动记录分享',
    );

    if (mounted) {
      _showSuccessSnackBar('分享成功');
    }
  }

  Future<void> _handleBatchExportCsv() async {
    HapticHelper.mediumTap();

    final workouts = widget.workouts;
    if (workouts == null || workouts.isEmpty) {
      if (mounted) {
        _showErrorSnackBar('没有运动记录可导出');
      }
      return;
    }

    setState(() => _isExporting = true);

    try {
      final csv = await _exportService.exportWorkoutsAsCsv(workouts);

      await _exportService.exportAndShare(
        content: csv,
        fileName: '运动记录_${DateTime.now().millisecondsSinceEpoch}.csv',
        mimeType: 'text/csv',
      );

      setState(() => _isExporting = false);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('已导出 ${workouts.length} 条运动记录');
      }
    } catch (e) {
      setState(() => _isExporting = false);

      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    }
  }

  String _workoutToJson(Workout workout) {
    final workoutType = WorkoutType.fromString(workout.type);
    final buffer = StringBuffer();

    buffer.writeln('{');
    buffer.writeln('  "id": ${workout.id},');
    buffer.writeln('  "type": "${workout.type}",');
    buffer.writeln('  "typeName": "${workoutType?.displayName ?? workout.type}",');
    buffer.writeln('  "startTime": "${workout.startTime.toIso8601String()}",');
    buffer.writeln('  "durationMinutes": ${workout.durationMinutes},');

    if (workout.distance != null) {
      buffer.writeln('  "distance": ${workout.distance},');
    }
    if (workout.calories != null) {
      buffer.writeln('  "calories": ${workout.calories},');
    }
    if (workout.sets != null) {
      buffer.writeln('  "sets": ${workout.sets},');
    }
    if (workout.reps != null) {
      buffer.writeln('  "reps": ${workout.reps},');
    }
    if (workout.weight != null) {
      buffer.writeln('  "weight": ${workout.weight},');
    }
    if (workout.feeling != null) {
      buffer.writeln('  "feeling": "${workout.feeling}",');
    }
    if (workout.notes != null) {
      buffer.writeln('  "notes": "${workout.notes!.replaceAll('"', '\\"')}",');
    }

    buffer.writeln('  "linkedPlanId": ${workout.linkedPlanId},');
    buffer.writeln('  "linkedNoteId": ${workout.linkedNoteId}');
    buffer.writeln('}');

    return buffer.toString();
  }

  Color _getWorkoutTypeColor(String type) {
    final workoutType = WorkoutType.fromString(type);
    if (workoutType == null) return AppColors.primary;

    switch (workoutType.category) {
      case 'cardio':
        return const Color(0xFFEF4444);
      case 'strength':
        return const Color(0xFFF59E0B);
      case 'sports':
        return const Color(0xFF10B981);
      default:
        return AppColors.primary;
    }
  }

  IconData _getWorkoutTypeIcon(String type) {
    final workoutType = WorkoutType.fromString(type);
    if (workoutType == null) return Icons.fitness_center;

    switch (workoutType.category) {
      case 'cardio':
        return Icons.directions_run;
      case 'strength':
        return Icons.fitness_center;
      case 'sports':
        return Icons.sports_basketball;
      default:
        return Icons.self_improvement;
    }
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

/// 运动导出选项卡片
class _WorkoutExportOptionTile extends StatelessWidget {
  final WorkoutExportOption option;
  final VoidCallback onTap;
  final bool isLoading;

  const _WorkoutExportOptionTile({
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
