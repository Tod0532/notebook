/// 现代进度组件库
/// 包含环形进度条、波浪动画等可视化组件

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

// ==================== 环形进度条 ====================

/// 环形进度条 - 现代风格
class CircularProgress extends StatefulWidget {
  final double progress; // 0.0 - 1.0
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color? progressColor;
  final Gradient? gradient;
  final Widget? center;
  final bool animate;
  final Duration animationDuration;

  const CircularProgress({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 8,
    this.backgroundColor,
    this.progressColor,
    this.gradient,
    this.center,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<CircularProgress> createState() => _CircularProgressState();
}

class _CircularProgressState extends State<CircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _animation.value, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _CircularProgressPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              backgroundColor: widget.backgroundColor ?? AppColors.surfaceVariant,
              progressColor: widget.progressColor ?? AppColors.primary,
              gradient: widget.gradient,
            ),
            child: widget.center != null
                ? Center(child: widget.center)
                : null,
          );
        },
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Gradient? gradient;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景圆环
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    // 进度圆环
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweepAngle = 2 * math.pi * progress;
      final startAngle = -math.pi / 2; // 从顶部开始

      final progressPaint = Paint()
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (gradient != null) {
        progressPaint.shader = gradient!.createShader(rect);
      } else {
        progressPaint.color = progressColor;
      }

      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.gradient != gradient;
  }
}

// ==================== 波浪动画 ====================

/// 波浪动画组件
class WaveAnimation extends StatefulWidget {
  final double waveHeight;
  final Color? color;
  final Gradient? gradient;
  final Widget? child;
  final Duration duration;

  const WaveAnimation({
    super.key,
    this.waveHeight = 20,
    this.color,
    this.gradient,
    this.child,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            animation: _controller.value,
            waveHeight: widget.waveHeight,
            color: widget.color ?? AppColors.primary,
            gradient: widget.gradient,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animation;
  final double waveHeight;
  final Color color;
  final Gradient? gradient;

  _WavePainter({
    required this.animation,
    required this.waveHeight,
    required this.color,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    if (gradient != null) {
      paint.shader = gradient!.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      paint.color = color;
    }

    final path = Path();

    // 第一层波浪
    final wave1Y = size.height * 0.7 + math.sin(animation * 2 * math.pi) * waveHeight;
    path.moveTo(0, size.height);
    path.lineTo(0, wave1Y);

    for (double x = 0; x <= size.width; x += 5) {
      final y = wave1Y + math.sin((x / size.width) * 2 * math.pi + animation * 2 * math.pi) * waveHeight * 0.5;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // 绘制半透明波浪
    canvas.drawPath(path, paint);

    // 第二层波浪（稍微偏移）
    final wave2Y = size.height * 0.75 + math.sin(animation * 2 * math.pi + math.pi / 2) * waveHeight;
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, wave2Y);

    for (double x = 0; x <= size.width; x += 5) {
      final y = wave2Y + math.sin((x / size.width) * 2 * math.pi + animation * 2 * math.pi + math.pi / 2) * waveHeight * 0.3;
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    paint.color = color.withValues(alpha: 0.3);
    if (gradient != null) {
      paint.shader = null;
      paint.color = color.withValues(alpha: 0.3);
    }
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// ==================== 线性进度条 ====================

/// 现代线性进度条
class LinearProgress extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final String? label;
  final bool showPercentage;

  const LinearProgress({
    super.key,
    required this.progress,
    this.height = 8,
    this.backgroundColor,
    this.progressColor,
    this.gradient,
    this.borderRadius,
    this.label,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppRadius.smRadius;
    final effectiveProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label ?? '${(effectiveProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceVariant,
              borderRadius: effectiveBorderRadius,
            ),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: height,
                ),
                FractionallySizedBox(
                  widthFactor: effectiveProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: gradient ?? AppColors.primaryGradient,
                      borderRadius: effectiveBorderRadius,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 进度卡片 ====================

/// 带环形进度的统计卡片
class ProgressCard extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final IconData icon;
  final Gradient? gradient;
  final Color? iconColor;

  const ProgressCard({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.icon,
    this.gradient,
    this.iconColor,
  });

  /// 主色进度卡片
  factory ProgressCard.primary({
    required String label,
    required String value,
    required double progress,
    required IconData icon,
  }) {
    return ProgressCard(
      label: label,
      value: value,
      progress: progress,
      icon: icon,
      gradient: AppColors.primaryGradient,
    );
  }

  /// 辅助色进度卡片
  factory ProgressCard.secondary({
    required String label,
    required String value,
    required double progress,
    required IconData icon,
  }) {
    return ProgressCard(
      label: label,
      value: value,
      progress: progress,
      icon: icon,
      gradient: AppColors.secondaryGradient,
    );
  }

  /// 成功色进度卡片
  factory ProgressCard.success({
    required String label,
    required String value,
    required double progress,
    required IconData icon,
  }) {
    return ProgressCard(
      label: label,
      value: value,
      progress: progress,
      icon: icon,
      gradient: AppColors.successGradient,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.light,
        border: Border.all(
          color: AppColors.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 环形进度条
          CircularProgress(
            progress: progress,
            size: 70,
            strokeWidth: 6,
            gradient: gradient,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 标签
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ==================== 步进进度 ====================

/// 步进进度指示器
class StepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final Color? activeColor;
  final Color? inactiveColor;

  const StepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels = const [],
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;
        final isLast = index == totalSteps - 1;

        return Expanded(
          child: Row(
            children: [
              // 步骤圆圈
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isCompleted || isCurrent
                      ? (activeColor != null ? null : AppColors.primaryGradient)
                      : null,
                  color: isCompleted || isCurrent
                      ? (activeColor ?? AppColors.primary)
                      : (inactiveColor ?? AppColors.surfaceVariant),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCompleted || isCurrent
                                ? Colors.white
                                : AppColors.textHint,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              // 连接线（最后一个不显示）
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? (activeColor ?? AppColors.primary)
                          : (inactiveColor ?? AppColors.surfaceVariant),
                      borderRadius: AppRadius.smRadius,
                    ),
                  ),
                ),
              // 标签
              if (labels.length > index)
                Expanded(
                  child: Text(
                    labels[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isCompleted || isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
