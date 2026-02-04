/// 抽卡动画组件
/// 实现抽卡时的翻转、闪光等动画效果

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';

/// 抽卡卡片动画组件
class GachaCardAnimation extends StatefulWidget {
  final GachaResult result;
  final VoidCallback? onAnimationComplete;

  const GachaCardAnimation({
    super.key,
    required this.result,
    this.onAnimationComplete,
  });

  @override
  State<GachaCardAnimation> createState() => _GachaCardAnimationState();
}

class _GachaCardAnimationState extends State<GachaCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _flipAnimation;
  late Animation<double> _shineAnimation;
  late Animation<double> _revealAnimation;

  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeInOut),
      ),
    );

    _shineAnimation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeInOut),
      ),
    );

    _revealAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _isRevealed = true;
        });
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(widget.result.rarity);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0)
              ..setEntry(0, 0, math.cos(_flipAnimation.value))
              ..setEntry(0, 2, math.sin(_flipAnimation.value))
              ..setEntry(2, 0, -math.sin(_flipAnimation.value))
              ..setEntry(2, 2, math.cos(_flipAnimation.value)),
            child: _buildCard(rarityColor),
          ),
        );
      },
    );
  }

  Widget _buildCard(Color rarityColor) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withOpacity(0.8),
            rarityColor.withOpacity(0.4),
            rarityColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 光效动画
          if (_controller.value < 1.0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Opacity(
                  opacity: _shineAnimation.value.abs() * 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.8),
                          Colors.transparent,
                        ],
                        stops: [
                          _shineAnimation.value - 0.3,
                          _shineAnimation.value,
                          _shineAnimation.value + 0.3,
                        ].where((s) => s >= 0 && s <= 1).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 卡片内容
          if (_isRevealed)
            Center(
              child: Opacity(
                opacity: _revealAnimation.value,
                child: _buildCardContent(),
              ),
            )
          else
            Center(
              child: Opacity(
                opacity: 1 - _flipAnimation.value.clamp(0.0, 1.0),
                child: _buildCardBack(),
              ),
            ),
        ],
      ),
    );
  }

  /// 卡片背面（未揭示时）
  Widget _buildCardBack() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.card_giftcard_rounded,
          size: 64,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '? ? ?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  /// 卡片内容（揭示后）
  Widget _buildCardContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 稀有度标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            widget.result.rarity.displayName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 物品图标
        _buildItemIcon(),
        const SizedBox(height: AppSpacing.md),
        // 物品名称
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            widget.result.item.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.result.isNew) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              'NEW!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 物品图标
  Widget _buildItemIcon() {
    IconData icon;
    switch (widget.result.item.type) {
      case GachaItemType.title:
        icon = Icons.military_tech_rounded;
        break;
      case GachaItemType.theme:
        icon = Icons.palette_rounded;
        break;
      case GachaItemType.icon:
        icon = Icons.emoji_emotions_rounded;
        break;
      case GachaItemType.badge:
        icon = Icons.workspace_premium_rounded;
        break;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  /// 获取稀有度颜色
  Color _getRarityColor(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return const Color(0xFF9E9E9E);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }
}

/// 十连抽结果展示
class TenDrawResultWidget extends StatelessWidget {
  final List<GachaResult> results;
  final VoidCallback? onClose;

  const TenDrawResultWidget({
    super.key,
    required this.results,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '抽卡结果',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // 结果网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.8,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _buildMiniCard(result, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(GachaResult result, int index) {
    final color = _getRarityColor(result.rarity);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getItemIcon(result.item.type),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              result.item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (result.isNew)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getItemIcon(GachaItemType type) {
    switch (type) {
      case GachaItemType.title:
        return Icons.military_tech_rounded;
      case GachaItemType.theme:
        return Icons.palette_rounded;
      case GachaItemType.icon:
        return Icons.emoji_emotions_rounded;
      case GachaItemType.badge:
        return Icons.workspace_premium_rounded;
    }
  }

  Color _getRarityColor(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return const Color(0xFF9E9E9E);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }
}
