/// AI 设置页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';

/// AI 设置页面
class AISettingsPage extends ConsumerStatefulWidget {
  const AISettingsPage({super.key});

  @override
  ConsumerState<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends ConsumerState<AISettingsPage> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String _testResult = '';
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final service = DeepSeekService.instance;
    await service.init();
    setState(() {
      _isConfigured = service.isConfigured;
      _apiKeyController.text = service.apiKey ?? '';
    });
  }

  Future<void> _saveConfig() async {
    await HapticHelper.lightTap();
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      // 清除配置
      await DeepSeekService.instance.clearApiKey();
      setState(() {
        _isConfigured = false;
        _testResult = 'API Key 已清除';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key 已清除')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DeepSeekService.instance.setApiKey(apiKey);
      setState(() {
        _isConfigured = true;
        _testResult = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API Key 已保存'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    await HapticHelper.lightTap();
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      setState(() => _testResult = '请先输入 API Key');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = '正在连接...';
    });

    try {
      await DeepSeekService.instance.setApiKey(apiKey);

      // 测试调用 - 生成一个简单的运动小结
      final result = await DeepSeekService.instance.generateWorkoutSummary(
        workoutType: '跑步',
        durationMinutes: 30,
      );

      setState(() {
        _testResult = '连接成功！\n\n测试结果：\n$result';
        _isConfigured = true;
      });
    } catch (e) {
      setState(() => _testResult = '连接失败：$e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 功能设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(context),
          const SizedBox(height: 24),
          _buildApiKeySection(context),
          const SizedBox(height: 16),
          _buildTestSection(context),
          const SizedBox(height: 24),
          _buildFeaturesSection(context),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DeepSeek AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isConfigured ? '已配置' : '未配置',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
              if (_isConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✓ 已连接',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Key 配置',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dividerColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入 DeepSeek API Key',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                  hintStyle: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: _apiKeyController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _apiKeyController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '获取 API Key：访问 deepseek.com 注册账号',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConfig,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存配置', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestSection(BuildContext context) {
    if (!_isConfigured) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '测试连接',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dividerColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.sync_alt, size: 18),
                label: const Text('测试连接'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (_testResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult.contains('成功')
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _testResult.contains('成功')
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _testResult,
                    style: TextStyle(
                      color: _testResult.contains('成功')
                          ? AppColors.success
                          : AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI 功能列表',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: Column(
            children: [
              _FeatureTile(
                icon: Icons.fitness_center_rounded,
                title: 'AI 运动小结',
                description: '运动后自动生成训练小结笔记',
                available: _isConfigured,
              ),
              const Divider(height: 1),
              _FeatureTile(
                icon: Icons.calendar_month_rounded,
                title: 'AI 计划生成',
                description: '根据目标自动生成运动计划',
                available: _isConfigured,
              ),
              const Divider(height: 1),
              _FeatureTile(
                icon: Icons.sentiment_satisfied_rounded,
                title: '情绪分析',
                description: '分析笔记内容判断情绪状态',
                available: _isConfigured,
              ),
              const Divider(height: 1),
              _FeatureTile(
                icon: Icons.wb_sunny_rounded,
                title: '早安问候',
                description: 'AI 生成个性化早安问候',
                available: _isConfigured,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool available;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: available
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.textHint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: available ? AppColors.primary : AppColors.textHint,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: available ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 12,
          color: available ? AppColors.textSecondary : AppColors.textHint.withValues(alpha: 0.6),
        ),
      ),
      trailing: available
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '可用',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '需配置',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ),
    );
  }
}
