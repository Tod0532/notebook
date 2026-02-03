/// AI教练计划生成页面
/// 显示生成进度并处理计划创建

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/core/config/router.dart';
import 'package:thick_notepad/features/coach/domain/services/coach_service.dart';
import 'package:thick_notepad/features/coach/data/repositories/user_profile_repository.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';

/// 生成结果
class GenerationResult {
  final int? workoutPlanId;
  final int? dietPlanId;

  GenerationResult({this.workoutPlanId, this.dietPlanId});
}

/// AI教练计划生成页面
class CoachPlanGenerationPage extends ConsumerStatefulWidget {
  final int userProfileId;

  const CoachPlanGenerationPage({
    super.key,
    required this.userProfileId,
  });

  @override
  ConsumerState<CoachPlanGenerationPage> createState() => _CoachPlanGenerationPageState();
}

class _CoachPlanGenerationPageState extends ConsumerState<CoachPlanGenerationPage> {
  bool _isGenerating = false;
  String _statusMessage = '准备生成...';
  List<String> _progressLog = [];
  String? _error;
  GenerationResult? _result;

  @override
  void initState() {
    super.initState();
    // 延迟一下再开始生成，让UI先渲染
    Future.delayed(const Duration(milliseconds: 500), _startGeneration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI教练计划生成'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorView();
    }

    if (_result != null) {
      return _buildSuccessView();
    }

    return _buildProgressView();
  }

  /// 进度视图
  Widget _buildProgressView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI动画图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            // 状态文字
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 进度指示器
            if (_isGenerating)
              const Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'AI正在为您生成个性化计划...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            // 进度日志
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _progressLog.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _progressLog[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off,
                size: 40,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI连接遇到问题',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              '别担心！我们为您准备了一套科学有效的默认计划',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '同样能帮您达成健身目标',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            // 使用默认计划按钮 - 更突出
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _useDefaultPlan,
                icon: const Icon(Icons.fitness_center),
                label: const Text('使用默认计划'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('稍后再试'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 成功视图
  Widget _buildSuccessView() {
    final workoutPlanId = _result!.workoutPlanId;
    final dietPlanId = _result!.dietPlanId;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '计划生成完成！',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              '您的个性化训练计划和饮食计划已准备好',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 查看训练计划按钮
            if (workoutPlanId != null)
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push(AppRoutes.workoutPlanDisplay
                        .replaceAll(':planId', workoutPlanId.toString()));
                  },
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('查看训练计划'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (workoutPlanId != null && dietPlanId != null)
              const SizedBox(height: 12),
            // 查看饮食计划按钮
            if (dietPlanId != null)
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push(AppRoutes.dietPlanDisplay
                        .replaceAll(':planId', dietPlanId.toString()));
                  },
                  icon: const Icon(Icons.restaurant),
                  label: const Text('查看饮食计划'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  /// 开始生成
  Future<void> _startGeneration() async {
    // 检查AI配置
    final aiService = DeepSeekService.instance;
    await aiService.init();

    setState(() {
      _isGenerating = true;
      _progressLog = ['开始生成AI教练计划...'];
      _error = null;
    });

    try {
      // 初始化服务
      final coachService = CoachService();
      coachService.initRepositories(
        userProfileRepo: ref.read(userProfileRepositoryProvider),
        workoutPlanRepo: ref.read(workoutPlanRepositoryProvider),
        dietPlanRepo: ref.read(dietPlanRepositoryProvider),
      );

      // 生成计划
      final result = await coachService.generateCompleteCoachPlan(
        userProfileId: widget.userProfileId,
        onProgress: (message) {
          setState(() {
            _statusMessage = message;
            _progressLog.add(message);
          });
        },
      );

      // 检查是否有计划生成成功
      final workoutPlanId = result['workoutPlanId'];
      final dietPlanId = result['dietPlanId'];

      if (workoutPlanId == null && dietPlanId == null) {
        // 两个计划都失败，自动使用默认计划
        throw Exception('AI生成失败，正在切换到默认计划...');
      }

      // 生成成功（至少有一个成功）
      setState(() {
        _isGenerating = false;
        _result = GenerationResult(
          workoutPlanId: workoutPlanId,
          dietPlanId: dietPlanId,
        );
      });

    } catch (e) {
      // AI 生成失败，自动使用默认计划
      debugPrint('AI生成失败，使用默认计划: $e');
      await _useDefaultPlan();
    }
  }

  /// 使用默认计划
  Future<void> _useDefaultPlan() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _statusMessage = '正在生成默认计划...';
      _progressLog = ['正在为您准备科学有效的训练计划...'];
    });

    try {
      final coachService = CoachService();
      coachService.initRepositories(
        userProfileRepo: ref.read(userProfileRepositoryProvider),
        workoutPlanRepo: ref.read(workoutPlanRepositoryProvider),
        dietPlanRepo: ref.read(dietPlanRepositoryProvider),
      );

      final result = await coachService.generateDefaultCoachPlan(
        userProfileId: widget.userProfileId,
        onProgress: (message) {
          setState(() {
            _statusMessage = message;
            _progressLog.add(message);
          });
        },
      );

      // 检查结果
      if (result['workoutPlanId'] == null && result['dietPlanId'] == null) {
        throw Exception('默认计划生成失败');
      }

      setState(() {
        _isGenerating = false;
        _result = GenerationResult(
          workoutPlanId: result['workoutPlanId'],
          dietPlanId: result['dietPlanId'],
        );
      });
    } catch (e) {
      debugPrint('默认计划生成失败: $e');
      setState(() {
        _isGenerating = false;
        _error = '抱歉，计划生成遇到问题：${e.toString()}';
      });
    }
  }
}
