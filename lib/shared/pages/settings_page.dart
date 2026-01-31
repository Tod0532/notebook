/// 设置页面

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/constants/app_constants.dart';
import 'package:thick_notepad/core/config/router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(context, '关于'),
          _buildTile(
            context,
            icon: Icons.info_outline,
            title: '应用版本',
            trailing: Text(
              '${AppConstants.appName} ${AppConstants.appVersion}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          _buildTile(
            context,
            icon: Icons.description_outlined,
            title: '开发状态',
            trailing: const Text(
              '开发中',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const Divider(height: 32),
          _buildSection(context, '数据'),
          _buildTile(
            context,
            icon: Icons.backup_outlined,
            title: '备份数据',
            onTap: () => _showSnackBar(context, '备份功能开发中'),
          ),
          _buildTile(
            context,
            icon: Icons.restore_outlined,
            title: '恢复数据',
            onTap: () => _showSnackBar(context, '恢复功能开发中'),
          ),
          _buildTile(
            context,
            icon: Icons.delete_outline,
            title: '清除所有数据',
            textColor: AppColors.error,
            onTap: () => _showConfirmDialog(context),
          ),
          const Divider(height: 32),
          _buildSection(context, '外观'),
          _buildTile(
            context,
            icon: Icons.palette_outlined,
            title: '主题选择',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => context.push(AppRoutes.themeSelection),
          ),
          _buildTile(
            context,
            icon: Icons.dark_mode_outlined,
            title: '深色模式',
            trailing: const Text(
              '跟随系统',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => _showSnackBar(context, '深色模式开发中'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('确定要清除所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, '清除功能开发中');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
