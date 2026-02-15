import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/firebase_auth_service.dart';
import 'launch.dart';

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
      _showSnack(_authService.friendlyError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Não foi possível concluir o login agora.');
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
      _showSnack(_authService.friendlyError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Falha ao entrar com Google.');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleBusy = false;
        });
      }
    }
  }

  Future<void> _openCreateAccount() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAccountPage(
          authService: _authService,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  void _toggleTheme() {
    final nextMode = widget.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    widget.onThemeModeChanged(nextMode);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientScene(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Entrar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: widget.themeMode == ThemeMode.dark
                                    ? 'Usar tema claro'
                                    : 'Usar tema escuro',
                                onPressed: _toggleTheme,
                                icon: Icon(
                                  widget.themeMode == ThemeMode.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Entre com e-mail/senha ou Google para sincronizar suas listas online.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_rounded),
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Informe um e-mail válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(Icons.lock_rounded),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 6) {
                                return 'Senha mínima de 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isBusy ? null : _signInWithEmail,
                              icon: _isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isGoogleBusy
                                  ? null
                                  : _signInWithGoogle,
                              icon: _isGoogleBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata_rounded),
                              label: const Text('Entrar com Google'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No Google, se a conta ainda nao existir, ela sera criada automaticamente.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _openCreateAccount,
                              child: const Text('Criar conta'),
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
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.authService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final FirebaseAuthService authService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      _showSnack('Conta criada com sucesso.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(widget.authService.friendlyError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Não foi possível criar a conta agora.');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _toggleTheme() {
    final nextMode = widget.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    widget.onThemeModeChanged(nextMode);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientScene(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Voltar',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Criar conta',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: widget.themeMode == ThemeMode.dark
                                    ? 'Usar tema claro'
                                    : 'Usar tema escuro',
                                onPressed: _toggleTheme,
                                icon: Icon(
                                  widget.themeMode == ThemeMode.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Informe seu nome, e-mail e senha para criar a conta.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                            validator: (value) {
                              final name = (value ?? '').trim();
                              if (name.length < 2) {
                                return 'Informe seu nome.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_rounded),
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Informe um e-mail válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(Icons.lock_rounded),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 6) {
                                return 'Senha mínima de 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isBusy ? null : _createAccount,
                              icon: _isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Criar conta'),
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
      ),
    );
  }
}
