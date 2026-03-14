/// 统一的骨架屏组件
/// 用于各模块的加载状态展示

import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';

/// 列表项骨架屏
class ListItemSkeleton extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int subtitleLines;

  const ListItemSkeleton({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          if (hasLeading) ...[
            _ShimmerBox(
              width: 48,
              height: 48,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  subtitleLines,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _ShimmerBox(
                      width: 200 + (index * 40.0),
                      height: 12,
                      borderRadius: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            _ShimmerBox(
              width: 40,
              height: 24,
              borderRadius: 4,
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片骨架屏
class CardSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const CardSkeleton({
    super.key,
    this.width,
    this.height = 120,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            width: 40,
            height: 40,
            borderRadius: 8,
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
            width: 120,
            height: 16,
            borderRadius: 4,
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            width: double.infinity,
            height: 12,
            borderRadius: 4,
          ),
          const Spacer(),
          Row(
            children: [
              _ShimmerBox(
                width: 60,
                height: 24,
                borderRadius: 4,
              ),
              const Spacer(),
              _ShimmerBox(
                width: 60,
                height: 12,
                borderRadius: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 统计卡片骨架屏
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            width: 24,
            height: 24,
            shape: BoxShape.circle,
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
            width: 40,
            height: 24,
            borderRadius: 4,
          ),
          const SizedBox(height: 4),
          _ShimmerBox(
            width: 80,
            height: 12,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// 圆形头像骨架屏
class CircleAvatarSkeleton extends StatelessWidget {
  final double size;

  const CircleAvatarSkeleton({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }
}

/// 文本骨架屏
class TextSkeleton extends StatelessWidget {
  final double width;
  final double height;

  const TextSkeleton({
    super.key,
    this.width = 100,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: width,
      height: height,
      borderRadius: 4,
    );
  }
}

/// 骨架屏列表（用于列表加载）
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final bool hasLeading;
  final bool hasTrailing;

  const SkeletonListView({
    super.key,
    this.itemCount = 5,
    this.hasLeading = true,
    this.hasTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ListItemSkeleton(
          hasLeading: hasLeading,
          hasTrailing: hasTrailing,
        );
      },
    );
  }
}

/// 骨架屏网格（用于网格加载）
class SkeletonGridView extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;

  const SkeletonGridView({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.aspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const CardSkeleton();
      },
    );
  }
}

/// 笔记列表骨架屏
/// 模拟笔记卡片的布局，包括标题、内容预览、标签和日期
class NoteListSkeleton extends StatelessWidget {
  const NoteListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          height: 160,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行骨架
              Row(
                children: [
                  Expanded(
                    child: _ShimmerBox(
                      width: 150,
                      height: 16,
                      borderRadius: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ShimmerBox(
                    width: 32,
                    height: 32,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 内容预览骨架
              _ShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              _ShimmerBox(
                width: 240,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              _ShimmerBox(
                width: 180,
                height: 12,
                borderRadius: 4,
              ),
              const Spacer(),
              // 标签骨架
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  _ShimmerBox(
                    width: 50,
                    height: 24,
                    borderRadius: 4,
                  ),
                  _ShimmerBox(
                    width: 60,
                    height: 24,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 日期骨架
              Row(
                children: [
                  _ShimmerBox(
                    width: 12,
                    height: 12,
                    shape: BoxShape.circle,
                  ),
                  const SizedBox(width: 4),
                  _ShimmerBox(
                    width: 80,
                    height: 12,
                    borderRadius: 4,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 提醒列表骨架屏
/// 模拟提醒卡片的布局，包括完成按钮、标题和时间标签
class ReminderListSkeleton extends StatelessWidget {
  const ReminderListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              // 完成按钮骨架
              _ShimmerBox(
                width: 28,
                height: 28,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: AppSpacing.md),
              // 内容骨架
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: 120,
                      height: 16,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      width: 80,
                      height: 24,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== 新增骨架屏类型 ====================

/// 统计图表骨架屏（用于统计页面）
class ChartSkeleton extends StatelessWidget {
  final ChartType chartType;

  const ChartSkeleton({
    super.key,
    this.chartType = ChartType.bar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题骨架
          _ShimmerBox(
            width: 100,
            height: 16,
            borderRadius: 4,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 图表内容
          Expanded(
            child: _buildChartContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent() {
    switch (chartType) {
      case ChartType.bar:
        return _BarChartSkeleton();
      case ChartType.line:
        return _LineChartSkeleton();
      case ChartType.pie:
        return _PieChartSkeleton();
    }
  }
}

/// 柱状图骨架
class _BarChartSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        7,
        (index) => _ShimmerBox(
          width: 24,
          height: 40 + (index * 15) % 100,
          borderRadius: 4,
        ),
      ),
    );
  }
}

/// 折线图骨架
class _LineChartSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _LineSkeletonPainter(),
    );
  }
}

/// 饼图骨架
class _PieChartSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: _ShimmerBox(
        width: 120,
        height: 120,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 地图骨架屏（用于GPS追踪页面）
class MapSkeleton extends StatelessWidget {
  final bool showStats;

  const MapSkeleton({
    super.key,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 地图区域
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.3),
              borderRadius: AppRadius.lgRadius,
            ),
            child: Stack(
              children: [
                // 地图背景骨架
                const _MapGridSkeleton(),
                // 路线骨架
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapRouteSkeletonPainter(),
                  ),
                ),
                // 位置标记骨架
                Positioned(
                  top: 60,
                  left: 80,
                  child: _ShimmerBox(
                    width: 32,
                    height: 32,
                    shape: BoxShape.circle,
                  ),
                ),
                Positioned(
                  top: 120,
                  right: 60,
                  child: _ShimmerBox(
                    width: 32,
                    height: 32,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 统计信息骨架
        if (showStats) _buildStatsRow(context),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: index == 1 ? AppSpacing.sm : 0,
              ),
              child: Container(
                height: 60,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerBox(
                      width: 40,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 4),
                    _ShimmerBox(
                      width: 60,
                      height: 12,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 地图网格骨架
class _MapGridSkeleton extends StatelessWidget {
  const _MapGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MapGridPainter(),
    );
  }
}

/// 运动列表骨架屏（用于运动记录页面）
class WorkoutListSkeleton extends StatelessWidget {
  const WorkoutListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          height: 100,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              // 图标骨架
              _ShimmerBox(
                width: 48,
                height: 48,
                borderRadius: 12,
              ),
              const SizedBox(width: AppSpacing.md),
              // 内容骨架
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerBox(
                      width: 100,
                      height: 16,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ShimmerBox(
                          width: 60,
                          height: 12,
                          borderRadius: 4,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ShimmerBox(
                          width: 40,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 数值骨架
              _ShimmerBox(
                width: 50,
                height: 20,
                borderRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 计划列表骨架屏（用于计划页面）
class PlanListSkeleton extends StatelessWidget {
  const PlanListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          height: 140,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceVariant.withOpacity(0.3),
                AppColors.surfaceVariant.withOpacity(0.1),
              ],
            ),
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ShimmerBox(
                    width: 32,
                    height: 32,
                    shape: BoxShape.circle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ShimmerBox(
                      width: 120,
                      height: 16,
                      borderRadius: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _ShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 8),
              // 进度条骨架
              _ShimmerBox(
                width: double.infinity,
                height: 8,
                borderRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== 自定义绘制器 ====================

/// 折线图骨架绘制器
class _LineSkeletonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textHint.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final points = <Offset>[
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.25, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.55, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.4),
      Offset(size.width * 0.85, size.height * 0.2),
    ];

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // 绘制点
    for (final point in points) {
      canvas.drawCircle(point, 4, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 地图网格绘制器
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dividerColor.withOpacity(0.2)
      ..strokeWidth = 1;

    final gridSize = 40.0;

    // 绘制垂直线
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 绘制水平线
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 地图路线骨架绘制器
class _MapRouteSkeletonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.3);
    path.cubicTo(
      size.width * 0.3, size.height * 0.2,
      size.width * 0.5, size.height * 0.4,
      size.width * 0.6, size.height * 0.3,
    );
    path.cubicTo(
      size.width * 0.7, size.height * 0.2,
      size.width * 0.8, size.height * 0.5,
      size.width * 0.75, size.height * 0.7,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== 枚举定义 ====================

/// 图表类型
enum ChartType { bar, line, pie }

/// 闪烁效果盒子
class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BoxShape? shape;
  final double? borderRadius;

  const _ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.shape,
    this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.textHint.withOpacity(_animation.value),
            shape: widget.shape ?? BoxShape.rectangle,
            borderRadius: widget.shape != null
                ? null
                : BorderRadius.circular((widget.borderRadius ?? AppRadius.smRadius) as double),
          ),
        );
      },
    );
  }
}
