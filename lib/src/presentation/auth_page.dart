import 'package:flutter/material.dart';

import '../application/authentication.dart';
import 'auth/login_form_view.dart';
import 'auth/create_account_form_view.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.authenticationGateway,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AuthenticationGateway authenticationGateway;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
      await widget.authenticationGateway.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthenticationFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.userMessage, type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível entrar agora. Verifique sua conexão e tente novamente.',
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
      await widget.authenticationGateway.signInWithGoogle();
    } on AuthenticationFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.userMessage, type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível entrar com Google. Tente novamente.',
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
      await widget.authenticationGateway.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      _showSnack(
        'Se existir conta com esse e-mail, enviamos o link de recuperação. Verifique caixa de entrada, spam e lixo eletrônico.',
        type: AppToastType.success,
      );
    } on AuthenticationFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.userMessage, type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível enviar o link. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _openCreateAccount() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => CreateAccountPage(
          authenticationGateway: widget.authenticationGateway,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
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
  Widget build(BuildContext context) => LoginFormView(
    formKey: _formKey,
    emailController: _emailController,
    passwordController: _passwordController,
    obscurePassword: _obscurePassword,
    isBusy: _isBusy,
    isGoogleBusy: _isGoogleBusy,
    onTogglePassword: () =>
        setState(() => _obscurePassword = !_obscurePassword),
    onSignIn: _signInWithEmail,
    onGoogleSignIn: _signInWithGoogle,
    onPasswordReset: _sendPasswordReset,
    onCreateAccount: _openCreateAccount,
  );
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.authenticationGateway,
    required this.onThemeModeChanged,
  });

  final AuthenticationGateway authenticationGateway;
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
      await widget.authenticationGateway.createAccount(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Conta criada com sucesso.', type: AppToastType.success);
      Navigator.of(context).pop();
    } on AuthenticationFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.userMessage, type: AppToastType.error);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível criar a conta. Verifique sua conexão e tente novamente.',
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

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) => CreateAccountFormView(
    formKey: _formKey,
    nameController: _nameController,
    emailController: _emailController,
    passwordController: _passwordController,
    confirmPasswordController: _confirmPasswordController,
    obscurePassword: _obscurePassword,
    obscureConfirmPassword: _obscureConfirmPassword,
    isBusy: _isBusy,
    onTogglePassword: () =>
        setState(() => _obscurePassword = !_obscurePassword),
    onToggleConfirmPassword: () =>
        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
    onCreateAccount: _createAccount,
    onBack: () => Navigator.of(context).pop(),
  );
}
