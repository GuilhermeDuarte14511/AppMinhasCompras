import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/firebase_auth_service.dart';
import 'launch.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();

  bool _isBusy = false;
  bool _isGoogleBusy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_isBusy || _isGoogleBusy) {
      return;
    }
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(_buildAuthErrorMessage(error), type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível concluir o login agora. [$error]',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy || _isGoogleBusy) {
      return;
    }
    setState(() {
      _isGoogleBusy = true;
    });
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(_buildAuthErrorMessage(error), type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Falha ao entrar com Google. [$error]',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleBusy = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(
        'Informe um e-mail válido para recuperar senha.',
        type: AppToastType.warning,
      );
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      _showSnack(
        'Se existir conta com esse e-mail, enviamos o link de recuperação. Verifique caixa de entrada, spam e lixo eletrônico.',
        type: AppToastType.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(_buildAuthErrorMessage(error), type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível enviar o link agora. [$error]',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _openCreateAccount() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => CreateAccountPage(
          authService: _authService,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  void _setTheme(ThemeMode mode) {
    widget.onThemeModeChanged(mode);
  }

  String _buildAuthErrorMessage(FirebaseAuthException error) {
    final friendly = _authService.friendlyError(error);
    final details = (error.message ?? '').trim();
    if (details.isEmpty) {
      return '$friendly [${error.code}]';
    }
    return '$friendly [${error.code}] - $details';
  }

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: AppGradientScene(
        child: Stack(
          children: [
            const _AuthDecorativeBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _AuthStaggerItem(
                      delay: Duration.zero,
                      child: _AuthSurface(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 30),
                                child: _AuthHeader(
                                  title: 'Entrar',
                                  subtitle:
                                      'Acesse sua conta para sincronizar suas listas.',
                                  isDarkMode: isDark,
                                  onThemeModeChanged: _setTheme,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        hintText: 'voce@exemplo.com',
                                        prefixIcon: Icon(
                                          Icons.alternate_email_rounded,
                                        ),
                                      ),
                                      validator: (value) {
                                        final email = (value ?? '').trim();
                                        if (email.isEmpty ||
                                            !email.contains('@')) {
                                          return 'Informe um e-mail valido.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onFieldSubmitted: (_) =>
                                          _signInWithEmail(),
                                      decoration: InputDecoration(
                                        labelText: 'Senha',
                                        prefixIcon: const Icon(
                                          Icons.lock_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Mostrar senha'
                                              : 'Ocultar senha',
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final password = value ?? '';
                                        if (password.length < 6) {
                                          return 'Senha minima de 6 caracteres.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _sendPasswordReset,
                                        child: const Text(
                                          'Esqueci minha senha',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isBusy
                                            ? null
                                            : _signInWithEmail,
                                        icon: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          transitionBuilder:
                                              (child, animation) {
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: ScaleTransition(
                                                    scale: Tween<double>(
                                                      begin: 0.92,
                                                      end: 1,
                                                    ).animate(animation),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          child: _isBusy
                                              ? const SizedBox(
                                                  key: ValueKey('login_busy'),
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.login_rounded,
                                                  key: ValueKey('login_idle'),
                                                ),
                                        ),
                                        label: const Text('Entrar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _AuthStaggerItem(
                                delay: Duration(milliseconds: 120),
                                child: _AuthSeparator(text: 'ou continue com'),
                              ),
                              const SizedBox(height: 16),
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 150),
                                child: _GoogleSignInButton(
                                  onPressed: _isGoogleBusy
                                      ? null
                                      : _signInWithGoogle,
                                  isBusy: _isGoogleBusy,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 180),
                                child: Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Ainda nao tem conta? ',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      TextButton(
                                        onPressed: _openCreateAccount,
                                        child: const Text('Criar conta'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.authService,
    required this.onThemeModeChanged,
  });

  final FirebaseAuthService authService;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_isBusy) {
      return;
    }
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await widget.authService.createAccount(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Conta criada com sucesso.', type: AppToastType.success);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(_buildAuthErrorMessage(error), type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível criar a conta agora. [$error]',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _setTheme(ThemeMode mode) {
    widget.onThemeModeChanged(mode);
  }

  String _buildAuthErrorMessage(FirebaseAuthException error) {
    final friendly = widget.authService.friendlyError(error);
    final details = (error.message ?? '').trim();
    if (details.isEmpty) {
      return '$friendly [${error.code}]';
    }
    return '$friendly [${error.code}] - $details';
  }

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: AppGradientScene(
        child: Stack(
          children: [
            const _AuthDecorativeBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _AuthStaggerItem(
                      delay: Duration.zero,
                      child: _AuthSurface(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 30),
                                child: Row(
                                  children: [
                                    IconButton.filledTonal(
                                      tooltip: 'Voltar',
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _AuthHeader(
                                        title: 'Criar conta',
                                        subtitle:
                                            'Cadastre seu perfil para salvar listas.',
                                        isDarkMode: isDark,
                                        onThemeModeChanged: _setTheme,
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      decoration: const InputDecoration(
                                        labelText: 'Nome completo',
                                        prefixIcon: Icon(Icons.badge_rounded),
                                      ),
                                      validator: (value) {
                                        final name = (value ?? '').trim();
                                        if (name.length < 2) {
                                          return 'Informe seu nome.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        hintText: 'voce@exemplo.com',
                                        prefixIcon: Icon(
                                          Icons.alternate_email_rounded,
                                        ),
                                      ),
                                      validator: (value) {
                                        final email = (value ?? '').trim();
                                        if (email.isEmpty ||
                                            !email.contains('@')) {
                                          return 'Informe um e-mail valido.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Senha',
                                        prefixIcon: const Icon(
                                          Icons.lock_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Mostrar senha'
                                              : 'Ocultar senha',
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final password = value ?? '';
                                        if (password.length < 6) {
                                          return 'Senha minima de 6 caracteres.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      onFieldSubmitted: (_) => _createAccount(),
                                      decoration: InputDecoration(
                                        labelText: 'Confirmar senha',
                                        prefixIcon: const Icon(
                                          Icons.verified_user_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscureConfirmPassword
                                              ? 'Mostrar senha'
                                              : 'Ocultar senha',
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final confirm = value ?? '';
                                        if (confirm !=
                                            _passwordController.text) {
                                          return 'As senhas nao conferem.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _AuthStaggerItem(
                                delay: const Duration(milliseconds: 140),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isBusy ? null : _createAccount,
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.92,
                                              end: 1,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _isBusy
                                          ? const SizedBox(
                                              key: ValueKey('create_busy'),
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_add_alt_1_rounded,
                                              key: ValueKey('create_idle'),
                                            ),
                                    ),
                                    label: const Text('Criar conta'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Ja tenho conta',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSurface extends StatelessWidget {
  const _AuthSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: colorScheme.surface.withValues(alpha: 0.9),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color:
                (brightness == Brightness.dark
                        ? Colors.black
                        : colorScheme.primary)
                    .withValues(
                      alpha: brightness == Brightness.dark ? 0.3 : 0.08,
                    ),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: child,
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
    required this.onThemeModeChanged,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool isDarkMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.shopping_cart_checkout_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: isDarkMode ? 'Usar tema claro' : 'Usar tema escuro',
          onPressed: () {
            onThemeModeChanged(isDarkMode ? ThemeMode.light : ThemeMode.dark);
          },
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}

class _AuthStaggerItem extends StatefulWidget {
  const _AuthStaggerItem({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_AuthStaggerItem> createState() => _AuthStaggerItemState();
}

class _AuthStaggerItemState extends State<_AuthStaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_fade);
    _scale = Tween<double>(
      begin: 0.985,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    Future<void>.delayed(widget.delay, () {
      if (!mounted) {
        return;
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _AuthSeparator extends StatelessWidget {
  const _AuthSeparator({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _AuthDecorativeBackground extends StatelessWidget {
  const _AuthDecorativeBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _GlowOrb(
              size: 220,
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -90,
            child: _GlowOrb(
              size: 200,
              color: colorScheme.tertiary.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, required this.isBusy});

  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF101719) : Colors.white,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.92,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: isBusy
                  ? const SizedBox(
                      key: ValueKey('google_busy'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const _GoogleBrandIcon(
                      key: ValueKey('google_idle'),
                      size: 22,
                    ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continuar com Google',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleBrandIcon extends StatelessWidget {
  const _GoogleBrandIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter(borderColor: border)),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  const _GoogleGlyphPainter({required this.borderColor});

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.18;
    final ringRadius = radius - (stroke / 2) - 0.7;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final borderPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, radius, borderPaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );

    void drawArc(double startAngle, double sweepAngle, Color color) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    drawArc(-0.15 * math.pi, 0.65 * math.pi, const Color(0xFF4285F4));
    drawArc(0.58 * math.pi, 0.5 * math.pi, const Color(0xFF34A853));
    drawArc(1.12 * math.pi, 0.42 * math.pi, const Color(0xFFFBBC05));
    drawArc(1.55 * math.pi, 0.62 * math.pi, const Color(0xFFEA4335));

    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.72
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4285F4);
    final barStart = Offset(center.dx + ringRadius * 0.06, center.dy);
    final barEnd = Offset(center.dx + ringRadius * 0.72, center.dy);
    canvas.drawLine(barStart, barEnd, barPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleGlyphPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor;
  }
}
