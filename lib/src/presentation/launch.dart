import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.showReadyHint = false});

  final bool showReadyHint;

  @override
  Widget build(BuildContext context) {
    return SplashPage(showReadyHint: showReadyHint);
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.showReadyHint = false,
    this.displayDuration = const Duration(milliseconds: 2600),
    this.onCompleted,
  });

  final bool showReadyHint;
  final Duration displayDuration;
  final VoidCallback? onCompleted;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _completionTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _SplashBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 620;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: compact ? 18 : 28,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SplashAnimationStage(controller: _controller),
                        SizedBox(height: compact ? 22 : 30),
                        const _SplashBrandCopy(),
                        SizedBox(height: compact ? 18 : 26),
                        _SplashLoadingHint(showReadyHint: widget.showReadyHint),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.38),
            colorScheme.surface,
            const Color(0xFFFFF7D8).withValues(alpha: 0.56),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -86,
            right: -54,
            child: _SplashAura(
              size: 240,
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -102,
            left: -62,
            child: _SplashAura(
              size: 280,
              color: const Color(0xFFF5C84C).withValues(alpha: 0.16),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SplashAnimationStage extends StatelessWidget {
  const _SplashAnimationStage({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.18,
        child: AnimatedBuilder(
          key: const ValueKey('splash-animation-stage'),
          animation: controller,
          builder: (context, _) {
            final colorScheme = Theme.of(context).colorScheme;
            final t = controller.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SplashOrbitPainter(
                      progress: t,
                      color: colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                _AnimatedProductChip(
                  progress: t,
                  delay: 0,
                  label: 'Frutas',
                  icon: Icons.spa_rounded,
                  color: const Color(0xFFF2B84B),
                  begin: const Alignment(-1.02, -0.76),
                  end: const Alignment(-0.26, -0.08),
                ),
                _AnimatedProductChip(
                  progress: t,
                  delay: 0.12,
                  label: 'Leite',
                  icon: Icons.local_drink_rounded,
                  color: const Color(0xFF4F9EDB),
                  begin: const Alignment(1.04, -0.55),
                  end: const Alignment(0.2, -0.02),
                ),
                _AnimatedProductChip(
                  progress: t,
                  delay: 0.24,
                  label: 'Paes',
                  icon: Icons.bakery_dining_rounded,
                  color: const Color(0xFFD9A45B),
                  begin: const Alignment(-1.08, 0.44),
                  end: const Alignment(-0.08, 0.1),
                ),
                _AnimatedProductChip(
                  progress: t,
                  delay: 0.34,
                  label: 'Legumes',
                  icon: Icons.eco_rounded,
                  color: const Color(0xFF55A66F),
                  begin: const Alignment(1.08, 0.34),
                  end: const Alignment(0.18, 0.08),
                ),
                _ShoppingBagMark(progress: t),
                _ChecklistCard(progress: t),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedProductChip extends StatelessWidget {
  const _AnimatedProductChip({
    required this.progress,
    required this.delay,
    required this.label,
    required this.icon,
    required this.color,
    required this.begin,
    required this.end,
  });

  final double progress;
  final double delay;
  final String label;
  final IconData icon;
  final Color color;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    final local = ((progress - delay) / 0.48).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    final fadeOut = ((progress - delay - 0.46) / 0.16).clamp(0.0, 1.0);
    final opacity = sin(local * pi).clamp(0.0, 1.0) * (1 - fadeOut);
    final alignment = Alignment.lerp(begin, end, eased) ?? end;
    final scale = 0.84 + (0.16 * sin(local * pi).clamp(0.0, 1.0));

    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: _ProductChip(label: label, icon: icon, color: color),
        ),
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: colorScheme.shadow.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingBagMark extends StatelessWidget {
  const _ShoppingBagMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pulse = sin(progress * pi * 2).clamp(-1.0, 1.0);
    final checkProgress = ((progress - 0.54) / 0.2).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, pulse * 3),
      child: Transform.scale(
        scale: 0.96 + (checkProgress * 0.04),
        child: DecoratedBox(
          key: const ValueKey('splash-shopping-bag'),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                blurRadius: 38,
                spreadRadius: 1,
                offset: const Offset(0, 20),
                color: colorScheme.primary.withValues(alpha: 0.22),
              ),
            ],
          ),
          child: SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: colorScheme.onPrimary,
                  size: 70,
                ),
                Positioned(
                  bottom: 35,
                  child: Opacity(
                    opacity: checkProgress,
                    child: Transform.scale(
                      scale: Curves.elasticOut.transform(checkProgress),
                      child: Icon(
                        Icons.check_rounded,
                        color: const Color(0xFFFFE08A),
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final local = ((progress - 0.58) / 0.34).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    return Align(
      alignment: const Alignment(0.72, 0.64),
      child: Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - eased)),
          child: DecoratedBox(
            key: const ValueKey('splash-checklist'),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                  color: colorScheme.shadow.withValues(alpha: 0.10),
                ),
              ],
            ),
            child: const SizedBox(
              width: 112,
              child: Padding(
                padding: EdgeInsets.all(13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChecklistRow(widthFactor: 0.9),
                    SizedBox(height: 9),
                    _ChecklistRow(widthFactor: 0.7),
                    SizedBox(height: 9),
                    _ChecklistRow(widthFactor: 0.82),
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const SizedBox(height: 5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashBrandCopy extends StatelessWidget {
  const _SplashBrandCopy();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Minha Lista de Compras',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Organize suas compras de forma simples',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SplashLoadingHint extends StatelessWidget {
  const _SplashLoadingHint({required this.showReadyHint});

  final bool showReadyHint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: showReadyHint
          ? _SplashStatusRow(
              key: const ValueKey('splash-ready'),
              icon: Icons.sync_rounded,
              iconColor: colorScheme.primary,
              label: 'Sincronizando suas compras...',
            )
          : _SplashStatusRow(
              key: const ValueKey('splash-loading'),
              leading: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: colorScheme.primary,
                ),
              ),
              label: 'Abrindo seu painel...',
            ),
    );
  }
}

class _SplashStatusRow extends StatelessWidget {
  const _SplashStatusRow({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.leading,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leadingWidget = leading ?? Icon(icon, color: iconColor, size: 18);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leadingWidget,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashAura extends StatelessWidget {
  const _SplashAura({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: SizedBox(width: size, height: size),
    );
  }
}

class _SplashOrbitPainter extends CustomPainter {
  const _SplashOrbitPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = min(size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: shortest * 0.38),
      -pi / 2,
      pi * 1.35 * progress,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: shortest * 0.29),
      pi * 0.18,
      pi * 1.1 * (1 - progress),
      false,
      paint..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class AppGradientScene extends StatelessWidget {
  const AppGradientScene({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.12),
            colorScheme.surface,
            colorScheme.secondaryContainer.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -40,
                  child: _SceneAura(
                    size: 220,
                    color: colorScheme.primary.withValues(alpha: 0.09),
                  ),
                ),
                Positioned(
                  bottom: -90,
                  left: -46,
                  child: _SceneAura(
                    size: 260,
                    color: colorScheme.tertiary.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SceneAura extends StatelessWidget {
  const _SceneAura({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: SizedBox(width: size, height: size),
    );
  }
}
