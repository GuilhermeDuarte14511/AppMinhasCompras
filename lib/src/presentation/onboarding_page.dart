import 'package:flutter/material.dart';

import 'onboarding/onboarding_styles.dart';
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

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _isBusy = false;

  static const List<_OnboardingStepData> _steps = <_OnboardingStepData>[
    _OnboardingStepData(
      title: 'Organize suas compras',
      subtitle:
          'Crie listas, acompanhe totais e controle orçamento em tempo real.',
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
      bullets: <String>[
        'Modo offline-first com sincronização automática.',
        'Notificações de lembrete e status de sincronização.',
        'Tema claro/escuro para usar do seu jeito.',
      ],
    ),
  ];

  bool get _isLastPage => _pageIndex == _steps.length - 1;

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
  void dispose() {
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
    final styles = OnboardingStyles(context);
    return Scaffold(
      backgroundColor: styles.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: styles.outline.withValues(alpha: .3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: styles.outline.withValues(alpha: .3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Voltar',
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 40,
                          ),
                          onPressed: _pageIndex == 0 || _isBusy
                              ? null
                              : () => _pageController.previousPage(
                                  duration: AppTokens.motionSlow,
                                  curve: Curves.easeOutCubic,
                                ),
                          icon: Icon(
                            const IconData(
                              0xe5c4,
                              fontFamily: 'MercadoSymbols',
                            ),
                            color: styles.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Minhas Compras',
                            style: styles.headline(24),
                          ),
                        ),
                        if (!_isLastPage)
                          TextButton(
                            onPressed: _isBusy ? null : _handleSkip,
                            style: TextButton.styleFrom(
                              foregroundColor: styles.secondary,
                              textStyle: styles
                                  .body(14)
                                  .copyWith(fontWeight: FontWeight.w500),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: const Text('Pular'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: _isBusy
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: _steps.length,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      itemBuilder: (context, index) => SingleChildScrollView(
                        key: PageStorageKey('onboarding_step_$index'),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'PRIMEIROS PASSOS',
                                    style: styles
                                        .body(12)
                                        .copyWith(
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: .6,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Passo ${index + 1} de ${_steps.length}',
                                  style: styles.body(12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Semantics(
                              label: 'Passo ${index + 1} de ${_steps.length}',
                              child: Row(
                                children: List.generate(
                                  _steps.length,
                                  (segment) => Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        right: segment == _steps.length - 1
                                            ? 0
                                            : 6,
                                      ),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color: segment <= index
                                            ? styles.primary
                                            : styles.outline.withValues(
                                                alpha: .4,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _steps[index].title,
                              style: styles.headline(24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _steps[index].subtitle,
                              style: styles.body(14),
                            ),
                            const SizedBox(height: 20),
                            ...List.generate(
                              _steps[index].bullets.length,
                              (bullet) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      bullet == _steps[index].bullets.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _OnboardingFeature(
                                  styles: styles,
                                  title: _featureTitles[index][bullet],
                                  description: _steps[index].bullets[bullet],
                                  icon: index == 0
                                      ? const IconData(
                                          0xe6b1,
                                          fontFamily: 'MercadoSymbols',
                                        )
                                      : index == 1
                                      ? const IconData(
                                          0xe1a1,
                                          fontFamily: 'MercadoSymbols',
                                        )
                                      : const IconData(
                                          0xe32a,
                                          fontFamily: 'MercadoSymbols',
                                        ),
                                ),
                              ),
                            ),
                            if (index == _steps.length - 1) ...[
                              const SizedBox(height: 20),
                              Divider(
                                height: 1,
                                color: styles.outline.withValues(alpha: .3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'PREFERÊNCIA DE TEMA DA INTERFACE',
                                style: styles
                                    .body(12)
                                    .copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: .6,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OnboardingThemeOption(
                                      label: 'Claro',
                                      selected:
                                          widget.themeMode == ThemeMode.light ||
                                          (widget.themeMode ==
                                                  ThemeMode.system &&
                                              !styles.dark),
                                      icon: const IconData(
                                        0xe518,
                                        fontFamily: 'MercadoSymbols',
                                      ),
                                      styles: styles,
                                      onPressed: _isBusy
                                          ? null
                                          : () => widget.onThemeModeChanged(
                                              ThemeMode.light,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OnboardingThemeOption(
                                      label: 'Escuro',
                                      selected:
                                          widget.themeMode == ThemeMode.dark ||
                                          (widget.themeMode ==
                                                  ThemeMode.system &&
                                              styles.dark),
                                      icon: const IconData(
                                        0xe51c,
                                        fontFamily: 'MercadoSymbols',
                                      ),
                                      styles: styles,
                                      onPressed: _isBusy
                                          ? null
                                          : () => widget.onThemeModeChanged(
                                              ThemeMode.dark,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: styles.outline.withValues(alpha: .4),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLastPage) ...[
                          Text(
                            'Conclua para entrar no app ou crie sua primeira lista agora.',
                            textAlign: TextAlign.center,
                            style: styles.body(12),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _isBusy
                                ? null
                                : () => _handleComplete(createFirstList: true),
                            style: styles.button(filled: true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isBusy) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                const Flexible(
                                  child: Text(
                                    'Concluir e Criar Lista',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  IconData(
                                    0xe5c8,
                                    fontFamily: 'MercadoSymbols',
                                  ),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _isBusy
                                ? null
                                : () => _handleComplete(createFirstList: false),
                            style: styles.button(height: 40),
                            child: const Text('Concluir'),
                          ),
                        ] else
                          FilledButton(
                            onPressed: _isBusy ? null : _goToNextPage,
                            style: styles.button(filled: true),
                            child: Text(_nextButtonLabel),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _isLastPage
                              ? 'Você pode revisar este Onboarding em Opções.'
                              : 'Dica: você pode pular agora e revisar depois em Opções.',
                          textAlign: TextAlign.center,
                          style: styles.body(12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _featureTitles = [
    ['Listas por contexto', 'Resumo da lista', 'Fechamento e histórico'],
    ['Catálogo de produtos', 'Código de barras', 'Importação de cupom'],
    ['Uso offline e sincronização', 'Lembretes e status', 'Tema da interface'],
  ];
}

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({
    required this.styles,
    required this.title,
    required this.description,
    required this.icon,
  });
  final OnboardingStyles styles;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: styles.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: styles.outline.withValues(alpha: .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: styles.muted,
          ),
          child: Icon(icon, size: 18, color: styles.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: styles
                    .headline(18)
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(description, style: styles.body(12)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OnboardingStepData {
  const _OnboardingStepData({
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final List<String> bullets;
}
