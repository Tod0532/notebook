/// 设置页面 - 现代化设计

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/backup/backup_service.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';
import 'package:thick_notepad/features/notes/presentation/providers/note_providers.dart';
import 'package:thick_notepad/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:thick_notepad/features/workout/presentation/providers/workout_providers.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 自定义顶部导航栏
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '设置',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          // 用户头部卡片
          SliverToBoxAdapter(
            child: _UserHeaderCard(),
          ),
          // 设置列表
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 外观分组
                _SettingsSection(
                  title: '外观',
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_rounded,
                      iconColor: AppColors.primary,
                      title: '主题选择',
                      subtitle: '选择你喜欢的主题风格',
                      trailing: _ThemePreviewIndicator(),
                      onTap: () => context.push(AppRoutes.themeSelection),
                    ),
                    _SettingsTile(
                      icon: Icons.dark_mode_rounded,
                      iconColor: Colors.deepPurple,
                      title: '深色模式',
                      subtitle: '跟随系统设置',
                      trailing: const Text(
                        '自动',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => _showSnackBar(context, '深色模式跟随系统'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 数据分组
                _SettingsSection(
                  title: '数据管理',
                  children: [
                    _SettingsTile(
                      icon: Icons.backup_rounded,
                      iconColor: AppColors.success,
                      title: '备份数据',
                      subtitle: '将数据备份到本地存储',
                      onTap: () => _showBackupDialog(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.restore_rounded,
                      iconColor: AppColors.info,
                      title: '恢复数据',
                      subtitle: '从备份恢复数据',
                      onTap: () => _showRestoreDialog(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppColors.error,
                      title: '清除所有数据',
                      subtitle: '此操作不可恢复',
                      textColor: AppColors.error,
                      onTap: () => _showConfirmDialog(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // AI 功能分组
                _SettingsSection(
                  title: 'AI 功能',
                  children: [
                    _SettingsTile(
                      icon: Icons.fitness_center_rounded,
                      iconColor: AppColors.secondary,
                      title: 'AI 教练',
                      subtitle: '创建个性化训练和饮食计划',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(AppRoutes.userProfileSetup),
                    ),
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.primary,
                      title: 'AI 功能设置',
                      subtitle: '配置 DeepSeek API Key',
                      trailing: _AIStatusIndicator(),
                      onTap: () => context.push(AppRoutes.aiSettings),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 天气功能分组
                _SettingsSection(
                  title: '天气功能',
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_rounded,
                      iconColor: AppColors.info,
                      title: '天气设置',
                      subtitle: '根据天气推荐合适的运动',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(AppRoutes.weatherSettings),
                    ),
                    _SettingsTile(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.success,
                      title: '位置设置',
                      subtitle: '配置地理围栏和位置提醒',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(AppRoutes.locationSettings),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 关于分组
                _SettingsSection(
                  title: '关于',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_rounded,
                      iconColor: AppColors.textSecondary,
                      title: '应用版本',
                      trailing: Text(
                        'v${AppConstants.appVersion}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      iconColor: AppColors.warning,
                      title: '开发状态',
                      trailing: _BuildStatusBadge(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _BackupDialog(ref: ref),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _RestoreDialog(ref: ref),
    );
  }

  void _showConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清除所有数据'),
        content: const Text('确定要清除所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final backupService = BackupService(
      noteRepo: ref.read(noteRepositoryProvider),
      reminderRepo: ref.read(reminderRepositoryProvider),
      workoutRepo: ref.read(workoutRepositoryProvider),
      planRepo: ref.read(planRepositoryProvider),
    );

    try {
      await backupService.clearAllData();
      if (context.mounted) {
        _showSnackBar(context, '所有数据已清除');
        ref.invalidate(allNotesProvider);
        ref.invalidate(allRemindersProvider);
        ref.invalidate(allWorkoutsProvider);
        ref.invalidate(allPlansProvider);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, '清除失败: $e');
      }
    }
  }
}

// ==================== 用户头部卡片 ====================

class _UserHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '老大',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '让每一天都充满活力',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
          // 统计信息
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '动计笔记',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PRO',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 设置分组 ====================

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ==================== 设置列表项 ====================

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              // 标题和副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              // 尾部
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 辅助组件 ====================

/// 主题预览指示器
class _ThemePreviewIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '8 种',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 构建状态徽章
class _BuildStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Text(
        '开发中',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// AI 状态指示器
class _AIStatusIndicator extends StatefulWidget {
  @override
  State<_AIStatusIndicator> createState() => _AIStatusIndicatorState();
}

class _AIStatusIndicatorState extends State<_AIStatusIndicator> {
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final service = DeepSeekService.instance;
    await service.init();
    if (mounted) {
      setState(() => _isConfigured = service.isConfigured);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isConfigured
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.textHint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isConfigured
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.textHint.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        _isConfigured ? '已配置' : '未配置',
        style: TextStyle(
          color: _isConfigured ? AppColors.success : AppColors.textHint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ==================== 备份对话框 ====================

class _BackupDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _BackupDialog({required this.ref});

  @override
  ConsumerState<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<_BackupDialog> {
  bool _isBackingUp = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('备份数据'),
      content: FutureBuilder<BackupStats>(
        future: _getBackupStats(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildContent(snapshot.data!);
          }
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isBackingUp ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isBackingUp ? null : _performBackup,
          child: _isBackingUp
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('开始备份'),
        ),
      ],
    );
  }

  Widget _buildContent(BackupStats stats) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('将当前数据备份到本地存储'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '数据统计',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stats.total} 条',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildStatRow('笔记', stats.notesCount, Icons.edit_note_rounded, AppColors.primary),
              const SizedBox(height: 8),
              _buildStatRow('提醒', stats.remindersCount, Icons.notifications_rounded, AppColors.warning),
              const SizedBox(height: 8),
              _buildStatRow('运动', stats.workoutsCount, Icons.fitness_center_rounded, AppColors.success),
              const SizedBox(height: 8),
              _buildStatRow('计划', stats.plansCount, Icons.calendar_month_rounded, AppColors.info),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          '$count 条',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<BackupStats> _getBackupStats() async {
    final backupService = BackupService(
      noteRepo: widget.ref.read(noteRepositoryProvider),
      reminderRepo: widget.ref.read(reminderRepositoryProvider),
      workoutRepo: widget.ref.read(workoutRepositoryProvider),
      planRepo: widget.ref.read(planRepositoryProvider),
    );
    return await backupService.getBackupStats();
  }

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final backupService = BackupService(
        noteRepo: widget.ref.read(noteRepositoryProvider),
        reminderRepo: widget.ref.read(reminderRepositoryProvider),
        workoutRepo: widget.ref.read(workoutRepositoryProvider),
        planRepo: widget.ref.read(planRepositoryProvider),
      );

      final success = await backupService.saveBackupLocally();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '备份成功！' : '备份失败'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }
}

// ==================== 恢复对话框 ====================

class _RestoreDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _RestoreDialog({required this.ref});

  @override
  ConsumerState<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends ConsumerState<_RestoreDialog> {
  bool _isRestoring = false;
  bool _hasLocalBackup = false;

  @override
  void initState() {
    super.initState();
    _checkLocalBackup();
  }

  Future<void> _checkLocalBackup() async {
    final backupService = BackupService(
      noteRepo: widget.ref.read(noteRepositoryProvider),
      reminderRepo: widget.ref.read(reminderRepositoryProvider),
      workoutRepo: widget.ref.read(workoutRepositoryProvider),
      planRepo: widget.ref.read(planRepositoryProvider),
    );
    final backup = await backupService.getLocalBackup();
    if (mounted) {
      setState(() => _hasLocalBackup = backup != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('恢复数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('从本地备份恢复数据'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasLocalBackup
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasLocalBackup
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _hasLocalBackup ? Icons.check_circle_rounded : Icons.error_outline,
                  color: _hasLocalBackup ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hasLocalBackup ? '找到本地备份' : '没有找到本地备份',
                    style: TextStyle(
                      color: _hasLocalBackup ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '注意：恢复数据将覆盖当前所有数据',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRestoring ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: (_isRestoring || !_hasLocalBackup) ? null : _performRestore,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warning,
          ),
          child: _isRestoring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('开始恢复'),
        ),
      ],
    );
  }

  Future<void> _performRestore() async {
    setState(() => _isRestoring = true);

    try {
      final backupService = BackupService(
        noteRepo: widget.ref.read(noteRepositoryProvider),
        reminderRepo: widget.ref.read(reminderRepositoryProvider),
        workoutRepo: widget.ref.read(workoutRepositoryProvider),
        planRepo: widget.ref.read(planRepositoryProvider),
      );

      final result = await backupService.restoreFromLocal();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        if (result.success) {
          widget.ref.invalidate(allNotesProvider);
          widget.ref.invalidate(allRemindersProvider);
          widget.ref.invalidate(allWorkoutsProvider);
          widget.ref.invalidate(allPlansProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }
}
