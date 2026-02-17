import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'launch.dart';
import 'theme/app_tokens.dart';

typedef OnboardingCompleteCallback =
    Future<void> Function({required bool createFirstList});

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSkip,
    required this.onComplete,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onSkip;
  final OnboardingCompleteCallback onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _floatController;
  int _pageIndex = 0;
  bool _isBusy = false;

  static const List<_OnboardingStepData> _steps = <_OnboardingStepData>[
    _OnboardingStepData(
      title: 'Organize suas compras',
      subtitle:
          'Crie listas, acompanhe totais e controle orçamento em tempo real.',
      icon: Icons.playlist_add_check_circle_rounded,
      accent: Color(0xFF0EA5A0),
      bullets: <String>[
        'Listas separadas por contexto (mercado, farmácia, casa).',
        'Resumo com itens, pendências e valor total.',
        'Fechamento e histórico mensal para comparar gastos.',
      ],
    ),
    _OnboardingStepData(
      title: 'Adicione produtos mais rápido',
      subtitle:
          'Use catálogo, código de barras e importação de cupom para ganhar tempo.',
      icon: Icons.qr_code_scanner_rounded,
      accent: Color(0xFF3B82F6),
      bullets: <String>[
        'Busca inteligente no catálogo local e online.',
        'Scanner de código de barras com preenchimento automático.',
        'Leitura de cupom para importar vários itens de uma vez.',
      ],
    ),
    _OnboardingStepData(
      title: 'Compre com segurança',
      subtitle:
          'Continue offline e sincronize quando a internet voltar, sem perder dados.',
      icon: Icons.security_rounded,
      accent: Color(0xFFF59E0B),
      bullets: <String>[
        'Modo offline-first com sincronização automática.',
        'Notificações de lembrete e status de sincronização.',
        'Tema claro/escuro para usar do seu jeito.',
      ],
    ),
  ];

  bool get _isLastPage => _pageIndex == _steps.length - 1;
  int get _currentStepNumber => _pageIndex + 1;

  String get _nextButtonLabel {
    switch (_pageIndex) {
      case 0:
        return 'Próximo: Produtos';
      case 1:
        return 'Próximo: Segurança';
      default:
        return 'Próximo';
    }
  }

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleSkip() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await widget.onSkip();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _handleComplete({required bool createFirstList}) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await widget.onComplete(createFirstList: createFirstList);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _goToNextPage() async {
    if (_isBusy || _isLastPage) {
      return;
    }
    await _pageController.nextPage(
      duration: AppTokens.motionSlow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: AppGradientScene(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Boas-vindas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (!_isLastPage)
                      TextButton(
                        onPressed: _isBusy ? null : _handleSkip,
                        child: const Text('Pular'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _OnboardingProgressIndicator(
                  stepsCount: _steps.length,
                  activeIndex: _pageIndex,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _steps.length,
                    onPageChanged: (index) {
                      setState(() {
                        _pageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return _OnboardingStepCard(
                        key: ValueKey('onboarding_step_$index'),
                        step: step,
                        animation: _floatController,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (_isLastPage) ...[
                  Text(
                    'Etapa $_currentStepNumber/${_steps.length} • Finalize seu setup',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aparência',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            selected: <ThemeMode>{widget.themeMode},
                            onSelectionChanged: _isBusy
                                ? null
                                : (selection) {
                                    if (selection.isEmpty) {
                                      return;
                                    }
                                    widget.onThemeModeChanged(selection.first);
                                  },
                            segments: const [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded),
                                label: Text('Claro'),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded),
                                label: Text('Escuro'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conclua para entrar no app ou crie sua primeira lista agora.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => _handleComplete(createFirstList: false),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Concluir'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => _handleComplete(createFirstList: true),
                          icon: _isBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Concluir e Criar Lista'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _goToNextPage,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_nextButtonLabel),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _isLastPage
                      ? 'Você pode revisar este onboarding em Opções.'
                      : 'Dica: você pode pular agora e revisar depois em Opções.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    super.key,
    required this.step,
    required this.animation,
  });

  final _OnboardingStepData step;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = math.sin(animation.value * math.pi * 2) * 5;
        return Transform.translate(offset: Offset(0, wave), child: child);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        step.accent.withValues(alpha: 0.32),
                        step.accent.withValues(alpha: 0.12),
                      ],
                    ),
                    border: Border.all(
                      color: step.accent.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(step.icon, size: 54, color: step.accent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                step.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              ...step.bullets.map(
                (bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: step.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProgressIndicator extends StatelessWidget {
  const _OnboardingProgressIndicator({
    required this.stepsCount,
    required this.activeIndex,
  });

  final int stepsCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentStep = activeIndex + 1;
    final progress = currentStep / stepsCount;

    return Column(
      children: [
        Row(
          children: [
            Text(
              'Etapa $currentStep/$stepsCount',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress.clamp(0.0, 1.0),
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.32),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(stepsCount, (index) {
            final active = index == activeIndex;
            return AnimatedContainer(
              duration: AppTokens.motionMedium,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 28 : 9,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _OnboardingStepData {
  const _OnboardingStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> bullets;
}
