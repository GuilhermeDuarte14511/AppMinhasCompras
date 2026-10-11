import 'dart:async';

import 'package:flutter/material.dart';

import 'theme/editorial_workspace_theme.dart';
import 'splash/notebook_painter.dart';
import 'splash/splash_motion.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.showReadyHint = false});

  final bool showReadyHint;

  @override
  Widget build(BuildContext context) =>
      SplashPage(showReadyHint: showReadyHint);
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
  Timer? _completionTimer;
  late final AnimationController _entrance;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: SplashMotion.duration,
    );
    if (widget.onCompleted != null) {
      _completionTimer = Timer(widget.displayDuration, () {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      if (_entrance.value < 1 && !_entrance.isAnimating) _entrance.forward();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final reduceMotion = _reduceMotion;
          return Scaffold(
            body: CustomPaint(
              painter: _NotebookLines(
                colors.outlineVariant.withValues(alpha: .13),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 620;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: compact ? 24 : 48,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RepaintBoundary(
                                      child: AnimatedBuilder(
                                        animation: _entrance,
                                        builder: (context, _) {
                                          final entry = SplashMotion.entrance
                                              .transform(_entrance.value);
                                          return Opacity(
                                            opacity: entry,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                12 * (1 - entry),
                                              ),
                                              child: SizedBox(
                                                key: const ValueKey(
                                                  'splash-notebook',
                                                ),
                                                width: 180,
                                                height: 156,
                                                child: CustomPaint(
                                                  painter:
                                                      SplashNotebookPainter(
                                                        colors: colors,
                                                        progress:
                                                            _entrance.value,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Minhas Compras',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontSize: 38,
                                            height: 1.25,
                                            letterSpacing: -.85,
                                            fontWeight: FontWeight.w400,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Planeje. Marque. Leve.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.showReadyHint
                                  ? 'Sincronizando compras'
                                  : 'Preparando sua lista...',
                              key: ValueKey(
                                widget.showReadyHint
                                    ? 'splash-ready'
                                    : 'splash-loading',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            key: const ValueKey('splash-animation-stage'),
                            width: 160,
                            height: 2,
                            child: reduceMotion
                                ? _StaticLoadingTrack(colors: colors)
                                : LinearProgressIndicator(
                                    color: colors.primary,
                                    backgroundColor: colors.outlineVariant
                                        .withValues(alpha: .35),
                                    minHeight: 2,
                                  ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StaticLoadingTrack extends StatelessWidget {
  const _StaticLoadingTrack({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    // This segment is a quiet activity cue, never a claimed load percentage.
    return ExcludeSemantics(
      child: ColoredBox(
        color: colors.outlineVariant.withValues(alpha: .35),
        child: Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: .28,
            heightFactor: 1,
            child: ColoredBox(color: colors.primary),
          ),
        ),
      ),
    );
  }
}

class _NotebookLines extends CustomPainter {
  const _NotebookLines(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 31.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_NotebookLines oldDelegate) => oldDelegate.color != color;
}

class AppGradientScene extends StatelessWidget {
  const AppGradientScene({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: child,
    );
  }
}
