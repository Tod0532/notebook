/// 抽卡动画组件
/// 实现抽卡时的翻转、闪光、粒子等动画效果
/// 集成音效和震动反馈增强体验
///
/// 增强功能：
/// - 粒子特效系统（根据稀有度显示不同效果）
/// - 增强3D翻转效果（卡牌厚度感）
/// - 闪光特效（星光闪烁、光环脉冲）
/// - 优化动画曲线（elasticOut、easeOutCubic）

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/services/gacha/gacha_service.dart';
import 'package:thick_notepad/services/audio/gacha_sound_manager.dart';

// ==================== 粒子特效系统 ====================

/// 粒子数据模型
class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double life;
  double maxLife;
  Color color;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.maxLife,
    required this.color,
    this.rotation = 0,
    this.rotationSpeed = 0,
  }) : life = maxLife;

  /// 更新粒子状态
  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 30 * dt; // 重力
    life -= dt;
    rotation += rotationSpeed * dt;
    return life > 0;
  }

  /// 获取当前透明度
  double get opacity => (life / maxLife).clamp(0.0, 1.0);
}

/// 粒子配置
class _ParticleConfig {
  final int count;
  final double minSpeed;
  final double maxSpeed;
  final double minSize;
  final double maxSize;
  final List<Color> colors;
  final double emitDuration;
  final bool hasRotation;
  final bool burstMode;
  final bool hasTrail;

  const _ParticleConfig({
    required this.count,
    required this.minSpeed,
    required this.maxSpeed,
    required this.minSize,
    required this.maxSize,
    required this.colors,
    required this.emitDuration,
    this.hasRotation = false,
    this.burstMode = false,
    this.hasTrail = false,
  });
}

/// 粒子特效组件 - 根据稀有度显示不同的粒子效果
class GachaParticleSystem extends StatefulWidget {
  final GachaRarity rarity;
  final Size size;

  const GachaParticleSystem({
    super.key,
    required this.rarity,
    required this.size,
  });

  @override
  State<GachaParticleSystem> createState() => _GachaParticleSystemState();
}

class _GachaParticleSystemState extends State<GachaParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  late math.Random _random;

  // 稀有度对应的粒子配置
  static const Map<GachaRarity, _ParticleConfig> _configs = {
    GachaRarity.common: _ParticleConfig(
      count: 15,
      minSpeed: 50,
      maxSpeed: 100,
      minSize: 2,
      maxSize: 4,
      colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
      emitDuration: 0.3,
    ),
    GachaRarity.rare: _ParticleConfig(
      count: 30,
      minSpeed: 80,
      maxSpeed: 150,
      minSize: 3,
      maxSize: 6,
      colors: [Color(0xFF2196F3), Color(0xFF64B5F6), Color(0xFF90CAF9)],
      emitDuration: 0.5,
      hasRotation: true,
    ),
    GachaRarity.epic: _ParticleConfig(
      count: 50,
      minSpeed: 120,
      maxSpeed: 200,
      minSize: 4,
      maxSize: 8,
      colors: [Color(0xFF9C27B0), Color(0xFFBA68C8), Color(0xFFE1BEE7)],
      emitDuration: 0.6,
      hasRotation: true,
      burstMode: true,
    ),
    GachaRarity.legendary: _ParticleConfig(
      count: 80,
      minSpeed: 150,
      maxSpeed: 300,
      minSize: 5,
      maxSize: 10,
      colors: [
        Color(0xFFFFD700),
        Color(0xFFFFEB3B),
        Color(0xFFFFF59D),
        Color(0xFFFFFFFF),
      ],
      emitDuration: 0.8,
      hasRotation: true,
      burstMode: true,
      hasTrail: true,
    ),
  };

  @override
  void initState() {
    super.initState();
    _random = math.Random(math.Random().nextInt(99999));
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.addListener(_updateParticles);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;

    final config = _configs[widget.rarity]!;
    final progress = _controller.value;
    final dt = 0.016; // 约60fps

    // 发射新粒子
    if (progress < config.emitDuration) {
      final emitRate = config.count / (config.emitDuration / dt);
      final emitCount = (emitRate * dt).round();

      for (int i = 0; i < emitCount && _particles.length < config.count; i++) {
        _emitParticle(config);
      }
    }

    // 更新现有粒子
    _particles.removeWhere((p) => !p.update(dt));

    if (_particles.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  void _emitParticle(_ParticleConfig config) {
    final width = widget.size.width;
    final height = widget.size.height;

    // 发射位置（中心或随机）
    double x, y;
    if (config.burstMode) {
      x = width / 2;
      y = height / 2;
    } else {
      x = _random.nextDouble() * width;
      y = height + 10;
    }

    // 速度
    final speed = config.minSpeed + _random.nextDouble() * (config.maxSpeed - config.minSpeed);
    final angle = config.burstMode
        ? _random.nextDouble() * math.pi * 2 // 全方向爆发
        : -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi / 3; // 向上喷射

    final vx = math.cos(angle) * speed;
    final vy = math.sin(angle) * speed - 100; // 向上初始速度

    // 颜色
    final color = config.colors[_random.nextInt(config.colors.length)];

    _particles.add(_Particle(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      size: config.minSize + _random.nextDouble() * (config.maxSize - config.minSize),
      maxLife: 1.5 + _random.nextDouble() * 0.5,
      color: color,
      rotation: config.hasRotation ? _random.nextDouble() * math.pi * 2 : 0,
      rotationSpeed: config.hasRotation ? (_random.nextDouble() - 0.5) * 10 : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widget.size,
      painter: _ParticlePainter(
        particles: _particles,
        rarity: widget.rarity,
      ),
    );
  }
}

/// 粒子绘制器
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final GachaRarity rarity;

  _ParticlePainter({
    required this.particles,
    required this.rarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation);

      // 根据稀有度绘制不同形状
      _drawParticle(canvas, particle, paint);

      canvas.restore();
    }
  }

  void _drawParticle(Canvas canvas, _Particle particle, Paint paint) {
    switch (rarity) {
      case GachaRarity.common:
        // 普通绘制小圆点
        canvas.drawCircle(Offset.zero, particle.size, paint);
        break;

      case GachaRarity.limited:
        // 限定绘制星形（与史诗相同）
        _drawStar(canvas, particle.size, paint);
        break;

      case GachaRarity.rare:
        // 稀有绘制菱形
        final path = Path()
          ..moveTo(0, -particle.size)
          ..lineTo(particle.size, 0)
          ..lineTo(0, particle.size)
          ..lineTo(-particle.size, 0)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case GachaRarity.epic:
        // 史诗绘制星形
        _drawStar(canvas, particle.size, paint);
        break;

      case GachaRarity.legendary:
        // 传说绘制发光星形 + 光晕
        _drawGlowingStar(canvas, particle, paint);
        break;
    }
  }

  void _drawStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final r = i % 2 == 0 ? radius : radius * 0.5;
      final angle = (i * math.pi) / points - math.pi / 2;
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawGlowingStar(Canvas canvas, _Particle particle, Paint paint) {
    // 外发光
    final glowPaint = Paint()
      ..color = particle.color.withOpacity(particle.opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, particle.size * 2, glowPaint);

    // 星形
    _drawStar(canvas, particle.size, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.particles.length != particles.length ||
        oldDelegate.rarity != rarity;
  }
}

// ==================== 闪光特效组件 ====================

/// 闪光特效组件 - 根据稀有度显示不同效果
class GachaShineEffect extends StatefulWidget {
  final GachaRarity rarity;
  final Size size;
  final bool isActive;

  const GachaShineEffect({
    super.key,
    required this.rarity,
    required this.size,
    this.isActive = true,
  });

  @override
  State<GachaShineEffect> createState() => _GachaShineEffectState();
}

class _GachaShineEffectState extends State<GachaShineEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();

    final duration = _getAnimationDuration();
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _shineAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GachaShineEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _getAnimationDuration() {
    switch (widget.rarity) {
      case GachaRarity.common:
        return const Duration(milliseconds: 1200);
      case GachaRarity.limited:
        return const Duration(milliseconds: 2200);
      case GachaRarity.rare:
        return const Duration(milliseconds: 1000);
      case GachaRarity.epic:
        return const Duration(milliseconds: 800);
      case GachaRarity.legendary:
        return const Duration(milliseconds: 600);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shineAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: widget.size,
          painter: _ShinePainter(
            shinePosition: _shineAnimation.value,
            rarity: widget.rarity,
          ),
        );
      },
    );
  }
}

/// 闪光绘制器
class _ShinePainter extends CustomPainter {
  final double shinePosition;
  final GachaRarity rarity;

  _ShinePainter({
    required this.shinePosition,
    required this.rarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    switch (rarity) {
      case GachaRarity.common:
        _drawSimpleShine(canvas, width, height);
        break;

      case GachaRarity.limited:
        // 限定使用史诗闪光效果
        _drawRotatingAura(canvas, width, height);
        break;

      case GachaRarity.rare:
        _drawPulsingGlow(canvas, width, height);
        break;

      case GachaRarity.epic:
        _drawRotatingAura(canvas, width, height);
        break;

      case GachaRarity.legendary:
        _drawStarlightSparkle(canvas, width, height);
        break;
    }
  }

  /// 普通稀有度 - 简单闪光
  void _drawSimpleShine(Canvas canvas, double width, double height) {
    if (shinePosition < -1 || shinePosition > 2) return;

    final normalizedPos = (shinePosition + 1) / 3; // 归一化到0-1
    final opacity = (1 - (normalizedPos - 0.5).abs() * 2).clamp(0.0, 0.5);
    final x = normalizedPos * width;

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(Offset(x, height / 2), 30, paint);
  }

  /// 稀有 - 光环脉冲
  void _drawPulsingGlow(Canvas canvas, double width, double height) {
    final center = Offset(width / 2, height / 2);
    final normalizedPos = (shinePosition + 1.5) / 4;
    final pulse = (math.sin(normalizedPos * math.pi * 4) + 1) / 2;

    // 外层光晕
    final outerPaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.2 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, width * 0.4, outerPaint);

    // 内层光晕
    final innerPaint = Paint()
      ..color = const Color(0xFF64B5F6).withOpacity(0.3 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, width * 0.25, innerPaint);
  }

  /// 史诗 - 旋转光环
  void _drawRotatingAura(Canvas canvas, double width, double height) {
    final center = Offset(width / 2, height / 2);
    final normalizedPos = (shinePosition + 1.5) / 4;
    final rotation = normalizedPos * math.pi * 2;

    for (int i = 0; i < 3; i++) {
      final angle = rotation + (i * math.pi * 2 / 3);
      final radius = width * 0.35;

      final paint = Paint()
        ..color = const Color(0xFF9C27B0).withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      canvas.drawCircle(Offset(x, y), 25, paint);
    }

    // 中心光环
    final centerPaint = Paint()
      ..color = const Color(0xFFE1BEE7).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, width * 0.3, centerPaint);
  }

  /// 传说 - 星光闪烁
  void _drawStarlightSparkle(Canvas canvas, double width, double height) {
    final center = Offset(width / 2, height / 2);
    final normalizedPos = (shinePosition + 1.5) / 4;
    final sparkle = (math.sin(normalizedPos * math.pi * 8) + 1) / 2;

    // 多层金色光晕
    for (int i = 3; i >= 0; i--) {
      final radius = width * (0.2 + i * 0.1);
      final blur = 10.0 + i * 5;
      final paint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.1 * sparkle / (i + 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawCircle(center, radius, paint);
    }

    // 星星闪烁
    final random = math.Random(42); // 固定种子保证位置一致
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + normalizedPos * math.pi * 2;
      final distance = width * 0.35;
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final starSize = 3 + random.nextDouble() * 5;
      final starOpacity = sparkle * (0.5 + random.nextDouble() * 0.5);

      _drawStar(canvas, Offset(x, y), starSize, Colors.white.withOpacity(starOpacity));
    }

    // 中心亮斑
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.6 * sparkle)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 15, centerPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    const points = 4;
    for (int i = 0; i < points * 2; i++) {
      final r = i % 2 == 0 ? radius : radius * 0.4;
      final angle = (i * math.pi) / points - math.pi / 2;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) {
    return oldDelegate.shinePosition != shinePosition ||
        oldDelegate.rarity != rarity;
  }
}

// ==================== 3D卡牌组件（带厚度感）====================

/// 3D卡牌组件 - 增强版，带有厚度感
class Gacha3DCard extends StatelessWidget {
  final GachaRarity rarity;
  final Widget front;
  final Widget back;
  final double flipProgress;
  final double width;
  final double height;

  const Gacha3DCard({
    super.key,
    required this.rarity,
    required this.front,
    required this.back,
    required this.flipProgress,
    this.width = 200,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    // 使用更真实的翻转曲线
    final adjustedProgress = _applyFlipCurve(flipProgress);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 卡牌厚度（阴影层）
          ..._buildCardThickness(adjustedProgress),

          // 主卡牌
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 透视效果
              ..rotateY(adjustedProgress * math.pi),
            child: _buildCardFace(adjustedProgress),
          ),
        ],
      ),
    );
  }

  /// 应用增强的翻转曲线
  double _applyFlipCurve(double t) {
    // 使用easeOutCubic使翻转更自然
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  /// 构建卡牌厚度效果
  List<Widget> _buildCardThickness(double progress) {
    final thickness = 8.0;
    final rarityColor = _getRarityColor(rarity);

    // 根据翻转角度计算阴影偏移
    final flipAngle = progress * math.pi;
    final shadowOffset = math.sin(flipAngle) * thickness;
    final shadowBlur = (math.cos(flipAngle).abs() * 10 + 5).toInt();

    return [
      // 多层阴影营造厚度感
      Positioned(
        left: -shadowBlur / 2,
        right: -shadowBlur / 2,
        top: -shadowBlur / 2,
        bottom: -shadowBlur / 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: rarityColor.withOpacity(0.4),
                blurRadius: shadowBlur.toDouble(),
                spreadRadius: 2,
                offset: Offset(shadowOffset, shadowOffset.abs() * 0.5),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// 构建卡牌面（根据翻转角度显示正面或背面）
  Widget _buildCardFace(double progress) {
    // 判断显示哪一面
    final showFront = (progress * 2) % 2 < 1;

    return AbsorbPointer(
      child: showFront ? front : Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateY(math.pi),
        child: back,
      ),
    );
  }

  Color _getRarityColor(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return const Color(0xFF9E9E9E);
      case GachaRarity.limited:
        return const Color(0xFFFF1744);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }
}

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
  late Animation<double> _particleAnimation;
  late Animation<double> _floatAnimation;

  bool _isRevealed = false;
  bool _soundPlayed = false;

  /// 音效管理器（延迟加载，避免初始化时出错）
  GachaSoundManager get _soundManager => GachaSoundManager.instance;

  @override
  void initState() {
    super.initState();

    // 根据稀有度调整动画时长
    final duration = _getAnimationDuration();

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // 缩放动画 - 使用 elasticOut 增强弹性效果
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    // 翻转动画 - 使用 easeOutCubic
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // 粒子动画 - 在翻转后触发
    _particleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // 浮动动画 - 揭示后的轻微上下浮动
    _floatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
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

    // 添加动画状态监听器
    _controller.addStatusListener(_onAnimationStatusChange);

    // 播放抽卡开始音效和震动
    _playDrawStartEffects();

    _controller.forward();
  }

  Duration _getAnimationDuration() {
    switch (widget.result.rarity) {
      case GachaRarity.common:
        return const Duration(milliseconds: 1200);
      case GachaRarity.limited:
        return const Duration(milliseconds: 2200);
      case GachaRarity.rare:
        return const Duration(milliseconds: 1400);
      case GachaRarity.epic:
        return const Duration(milliseconds: 1600);
      case GachaRarity.legendary:
        return const Duration(milliseconds: 2000);
    }
  }

  /// 动画状态变化回调
  void _onAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _isRevealed = true;
      });

      // 播放揭示音效和震动
      _playRevealEffects();

      widget.onAnimationComplete?.call();
    }
  }

  /// 播放抽卡开始时的音效
  void _playDrawStartEffects() {
    // 播放抽卡音效
    _soundManager.playDrawSound();
  }

  /// 播放揭示时的音效
  void _playRevealEffects() {
    if (_soundPlayed) return;

    final rarity = widget.result.rarity;

    // 根据稀有度播放不同的揭示音效
    if (rarity == GachaRarity.legendary || rarity == GachaRarity.limited) {
      _soundManager.playLegendarySound();
    } else {
      _soundManager.playRevealSound(rarity);
    }

    // 如果是新物品，延迟播放新物品音效
    if (widget.result.isNew) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _soundManager.playNewItemSound();
        }
      });
    }

    _soundPlayed = true;
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
            offset: Offset(0, -math.sin(_floatAnimation.value * math.pi * 2) * 5),
            child: SizedBox(
              width: 300,
              height: 400,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 背景粒子特效
                  if (_particleAnimation.value > 0)
                    Positioned.fill(
                      child: Opacity(
                        opacity: _particleAnimation.value,
                        child: GachaParticleSystem(
                          rarity: widget.result.rarity,
                          size: const Size(300, 400),
                        ),
                      ),
                    ),

                  // 3D卡牌
                  Gacha3DCard(
                    rarity: widget.result.rarity,
                    flipProgress: _flipAnimation.value,
                    front: _buildCardFront(),
                    back: _buildCardBack(),
                  ),

                  // 闪光特效（传说/史诗物品）
                  if (_isRevealed &&
                      (widget.result.rarity == GachaRarity.legendary ||
                          widget.result.rarity == GachaRarity.epic))
                    Positioned.fill(
                      child: GachaShineEffect(
                        rarity: widget.result.rarity,
                        size: const Size(200, 280),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 卡牌背面（未揭示时）
  Widget _buildCardBack() {
    final rarityColor = _getRarityColor(widget.result.rarity);
    return _buildCardContainer(
      rarityColor: rarityColor,
      child: Column(
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
      ),
    );
  }

  /// 卡牌正面（揭示后）
  Widget _buildCardFront() {
    final rarityColor = _getRarityColor(widget.result.rarity);
    return _buildCardContainer(
      rarityColor: rarityColor,
      child: Stack(
        children: [
          // 卡片内容
          Center(
            child: Opacity(
              opacity: _revealAnimation.value,
              child: _buildCardContent(),
            ),
          ),
          // 分享按钮（仅在揭示后显示）
          if (_isRevealed) _buildShareButton(),
        ],
      ),
    );
  }

  /// 卡牌容器
  Widget _buildCardContainer({required Color rarityColor, required Widget child}) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withOpacity(0.9),
            rarityColor.withOpacity(0.6),
            rarityColor.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }

  /// 卡片背面（未揭示时）- 旧版保留兼容
  Widget _buildCardBackLegacy() {
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
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.result.rarity.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
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
              gradient: LinearGradient(
                colors: [
                  AppColors.warning,
                  AppColors.warning.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text(
              'NEW!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
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

    // 根据稀有度添加不同的图标背景效果
    final rarityColor = _getRarityColor(widget.result.rarity);
    final glowIntensity = widget.result.rarity == GachaRarity.legendary
        ? 0.4
        : widget.result.rarity == GachaRarity.epic
            ? 0.3
            : 0.2;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(glowIntensity),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
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
      case GachaRarity.limited:
        return const Color(0xFFFF1744);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }

  /// 构建分享按钮
  Widget _buildShareButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _shareResult,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.share,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// 分享单抽结果
  Future<void> _shareResult() async {
    try {
      final text = _formatShareText(widget.result);
      await Share.share(text, subject: '动计笔记抽卡结果');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  /// 格式化单抽分享文本
  String _formatShareText(GachaResult result) {
    final stars = _getStarsByRarity(result.rarity);
    final newTag = result.isNew ? '\n🎊 是新物品！' : '';

    return '''【动计笔记】抽卡结果 🎴
📦 获得物品：${result.item.name} $stars
💎 稀有度：${result.rarity.displayName}
🏷️ 类型：${result.item.type.displayName}$newTag

📝 描述：${result.item.description}

🔥 来动计笔记体验更多乐趣！''';
  }

  /// 根据稀有度获取星级
  String _getStarsByRarity(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return '⭐';
      case GachaRarity.limited:
        return '⭐⭐⭐⭐⭐⭐';
      case GachaRarity.rare:
        return '⭐⭐';
      case GachaRarity.epic:
        return '⭐⭐⭐';
      case GachaRarity.legendary:
        return '⭐⭐⭐⭐⭐';
    }
  }
}

/// 十连抽结果展示
class TenDrawResultWidget extends StatefulWidget {
  final List<GachaResult> results;
  final VoidCallback? onClose;

  const TenDrawResultWidget({
    super.key,
    required this.results,
    this.onClose,
  });

  @override
  State<TenDrawResultWidget> createState() => _TenDrawResultWidgetState();
}

class _TenDrawResultWidgetState extends State<TenDrawResultWidget> {
  /// 音效管理器
  GachaSoundManager get _soundManager => GachaSoundManager.instance;

  /// 是否已播放完成音效
  bool _completionPlayed = false;

  @override
  void initState() {
    super.initState();
    _playTenDrawEffects();
  }

  /// 播放十连抽音效和震动序列
  void _playTenDrawEffects() async {
    // 延迟播放，让动画先开始
    await Future.delayed(const Duration(milliseconds: 300));

    // 根据最高稀有度播放音效序列
    final highestRarity = _getHighestRarity();

    if (highestRarity == GachaRarity.legendary ||
        highestRarity == GachaRarity.limited) {
      _soundManager.playLegendarySound();
    } else if (highestRarity == GachaRarity.epic) {
      _soundManager.playRevealSound(GachaRarity.epic);
    } else {
      _soundManager.playTenDrawCompleteSound();
    }

    // 如果有新物品，播放新物品音效
    final hasNewItem = widget.results.any((r) => r.isNew);
    if (hasNewItem) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _soundManager.playNewItemSound();
      }
    }

    _completionPlayed = true;
  }

  /// 获取结果中的最高稀有度
  GachaRarity _getHighestRarity() {
    if (widget.results.any((r) =>
        r.rarity == GachaRarity.legendary || r.rarity == GachaRarity.limited)) {
      return GachaRarity.legendary;
    }
    if (widget.results.any((r) => r.rarity == GachaRarity.epic)) {
      return GachaRarity.epic;
    }
    if (widget.results.any((r) => r.rarity == GachaRarity.rare)) {
      return GachaRarity.rare;
    }
    return GachaRarity.common;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '抽卡结果',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 分享按钮
                  IconButton(
                    onPressed: () => _shareResults(context),
                    icon: const Icon(Icons.share),
                    tooltip: '分享结果',
                  ),
                  // 关闭按钮
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
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
            itemCount: widget.results.length,
            itemBuilder: (context, index) {
              final result = widget.results[index];
              return _buildMiniCard(result);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(GachaResult result) {
    final color = _getRarityColor(result.rarity);
    final isHighRarity = result.rarity == GachaRarity.legendary ||
        result.rarity == GachaRarity.epic;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.9),
            color.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isHighRarity
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
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
      case GachaRarity.limited:
        return const Color(0xFFFF1744);
      case GachaRarity.rare:
        return const Color(0xFF2196F3);
      case GachaRarity.epic:
        return const Color(0xFF9C27B0);
      case GachaRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }

  /// 分享十连抽结果
  Future<void> _shareResults(BuildContext context) async {
    try {
      final text = _formatTenDrawShareText(widget.results);
      await Share.share(text, subject: '动计笔记十连抽结果');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  /// 格式化十连抽分享文本
  String _formatTenDrawShareText(List<GachaResult> results) {
    final buffer = StringBuffer();
    buffer.writeln('【动计笔记】十连抽结果 🎴🎴🎴');
    buffer.writeln();

    // 统计各稀有度数量
    final rarityCount = <GachaRarity, int>{};
    for (final result in results) {
      rarityCount[result.rarity] = (rarityCount[result.rarity] ?? 0) + 1;
    }

    // 统计新物品数量
    final newCount = results.where((r) => r.isNew).length;

    // 显示稀有度分布
    if (rarityCount[GachaRarity.legendary]! > 0) {
      buffer.writeln('⭐⭐⭐⭐⭐ 传说 x${rarityCount[GachaRarity.legendary]}');
    }
    if (rarityCount[GachaRarity.epic]! > 0) {
      buffer.writeln('⭐⭐⭐ 史诗 x${rarityCount[GachaRarity.epic]}');
    }
    if (rarityCount[GachaRarity.rare]! > 0) {
      buffer.writeln('⭐⭐ 稀有 x${rarityCount[GachaRarity.rare]}');
    }
    if (rarityCount[GachaRarity.common]! > 0) {
      buffer.writeln('⭐ 普通 x${rarityCount[GachaRarity.common]}');
    }

    if (newCount > 0) {
      buffer.writeln('🎊 新物品: $newCount 个');
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━');
    buffer.writeln('获得物品详情：');
    buffer.writeln();

    // 列出所有物品
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final stars = _getStarsByRarity(result.rarity);
      final newTag = result.isNew ? ' [NEW]' : '';
      buffer.writeln('${i + 1}. ${result.item.name}$newTag $stars');
    }

    buffer.writeln();
    buffer.writeln('🔥 来动计笔记体验更多乐趣！');

    return buffer.toString();
  }

  /// 根据稀有度获取星级
  String _getStarsByRarity(GachaRarity rarity) {
    switch (rarity) {
      case GachaRarity.common:
        return '⭐';
      case GachaRarity.limited:
        return '⭐⭐⭐⭐⭐⭐';
      case GachaRarity.rare:
        return '⭐⭐';
      case GachaRarity.epic:
        return '⭐⭐⭐';
      case GachaRarity.legendary:
        return '⭐⭐⭐⭐⭐';
    }
  }
}
