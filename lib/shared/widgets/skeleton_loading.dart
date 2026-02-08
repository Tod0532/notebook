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
