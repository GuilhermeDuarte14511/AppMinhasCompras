import 'dart:math';

import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.showReadyHint = false});

  final bool showReadyHint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _LaunchExperience(
        showReadyHint: showReadyHint,
        title: 'Minhas Compras',
      ),
    );
  }
}

class _LaunchExperience extends StatefulWidget {
  const _LaunchExperience({required this.showReadyHint, required this.title});

  final bool showReadyHint;
  final String title;

  @override
  State<_LaunchExperience> createState() => _LaunchExperienceState();
}

class _LaunchExperienceState extends State<_LaunchExperience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..forward();
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final t = _curved.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final laneWidth = constraints.maxWidth + 220;
            final primaryX =
                -110 + laneWidth * Curves.easeOutCubic.transform(t);
            final secondaryProgress = (t * 1.1).clamp(0.0, 1.0);
            final secondaryX =
                constraints.maxWidth +
                80 -
                laneWidth * Curves.easeInOut.transform(secondaryProgress);
            final tertiaryProgress = ((t - 0.12) / 0.88).clamp(0.0, 1.0);
            final tertiaryX =
                -90 +
                laneWidth * Curves.easeInOutCubic.transform(tertiaryProgress);
            final quaternaryProgress = (t * 0.92).clamp(0.0, 1.0);
            final quaternaryX =
                constraints.maxWidth +
                120 -
                laneWidth * Curves.easeOutQuart.transform(quaternaryProgress);
            final laneBottom = constraints.maxHeight * 0.22;
            final orbitA = sin(t * pi * 2.0) * 9;
            final orbitB = cos(t * pi * 2.4) * 7;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.88),
                    colorScheme.secondaryContainer.withValues(alpha: 0.76),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -90 + (1 - t) * 60,
                    right: -50,
                    child: _LaunchBlob(
                      size: 240,
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  Positioned(
                    bottom: -80 + (1 - t) * 45,
                    left: -40,
                    child: _LaunchBlob(
                      size: 190,
                      color: colorScheme.tertiary.withValues(alpha: 0.14),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: laneBottom + 4,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: colorScheme.primary.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: laneBottom + 42,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: colorScheme.secondary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    left: primaryX,
                    bottom: laneBottom + sin(t * pi * 2.3) * 6,
                    child: _LaunchCart(
                      color: colorScheme.primary.withValues(alpha: 0.9),
                      size: 34,
                    ),
                  ),
                  Positioned(
                    left: secondaryX,
                    bottom: laneBottom + 36 + sin((t + 0.35) * pi * 2.0) * 4,
                    child: _LaunchCart(
                      color: colorScheme.tertiary.withValues(alpha: 0.9),
                      size: 28,
                    ),
                  ),
                  Positioned(
                    left: tertiaryX,
                    bottom: laneBottom + 72 + sin((t + 0.5) * pi * 1.8) * 4,
                    child: _LaunchCart(
                      color: colorScheme.secondary.withValues(alpha: 0.88),
                      size: 24,
                    ),
                  ),
                  Positioned(
                    left: quaternaryX,
                    bottom: laneBottom - 14 + sin((t + 0.22) * pi * 1.4) * 5,
                    child: _LaunchCart(
                      color: colorScheme.primary.withValues(alpha: 0.76),
                      size: 20,
                    ),
                  ),
                  Positioned(
                    top: constraints.maxHeight * 0.2 + orbitA,
                    left: constraints.maxWidth * 0.17,
                    child: Opacity(
                      opacity: (t * 1.2).clamp(0.0, 1.0),
                      child: _LaunchFloatingIcon(
                        icon: Icons.shopping_bag_rounded,
                        size: 26,
                        color: colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Positioned(
                    top: constraints.maxHeight * 0.16 + orbitB,
                    right: constraints.maxWidth * 0.2,
                    child: Opacity(
                      opacity: ((t - 0.15) * 1.3).clamp(0.0, 1.0),
                      child: _LaunchFloatingIcon(
                        icon: Icons.local_grocery_store_rounded,
                        size: 22,
                        color: colorScheme.tertiary.withValues(alpha: 0.33),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 24),
                      child: Opacity(
                        opacity: t,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 0.78 + (t * 0.22),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.78,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 36,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 14),
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Icon(
                                    Icons.shopping_bag_rounded,
                                    size: 44,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Organize, compare e compre sem perder tempo.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: widget.showReadyHint
                                  ? Row(
                                      key: const ValueKey('launch-ready'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cloud_done_rounded,
                                          color: colorScheme.primary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Preparando seu painel de compras...',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    )
                                  : const SizedBox(
                                      key: ValueKey('launch-loading'),
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LaunchBlob extends StatelessWidget {
  const _LaunchBlob({required this.size, required this.color});

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

class _LaunchCart extends StatelessWidget {
  const _LaunchCart({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.shopping_cart_rounded, color: color, size: size);
  }
}

class _LaunchFloatingIcon extends StatelessWidget {
  const _LaunchFloatingIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: size);
  }
}

class AppGradientScene extends StatelessWidget {
  const AppGradientScene({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.11),
            colorScheme.surface,
            colorScheme.secondaryContainer.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: child,
    );
  }
}
