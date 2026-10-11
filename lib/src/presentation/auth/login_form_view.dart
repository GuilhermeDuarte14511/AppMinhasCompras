import 'package:flutter/material.dart';

import 'login_google_icon.dart';

/// Visual translation of design/telas/17-entrar/index.html. Authentication
/// remains in AuthPage; this widget owns only the layout and input affordances.
class LoginFormView extends StatelessWidget {
  const LoginFormView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isBusy,
    required this.isGoogleBusy,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onGoogleSignIn,
    required this.onPasswordReset,
    required this.onCreateAccount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isBusy;
  final bool isGoogleBusy;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onPasswordReset;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF20231E) : const Color(0xFFFCFBF7);
    final foreground = dark ? const Color(0xFFF3F1EB) : const Color(0xFF1B1C18);
    final secondary = dark ? const Color(0xFFC4C9B4) : const Color(0xFF5B604F);
    final outline = dark ? const Color(0xFF60685D) : const Color(0xFFC1C8C1);
    final surface = dark ? const Color(0xFF30312D) : Colors.white;
    final primary = dark ? const Color(0xFFA9D0B4) : const Color(0xFF1F412D);
    final locked = isBusy || isGoogleBusy;
    final body = TextStyle(
      fontFamily: 'MercadoPublicSans',
      fontSize: 14,
      letterSpacing: 0,
      height: 20 / 14,
      color: foreground,
    );
    final label = body.copyWith(fontSize: 12, height: 16 / 12);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outline),
    );
    final fieldTheme = Theme.of(context).copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.2),
        selectionHandleColor: primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
        ),
        hintStyle: body.copyWith(
          color: dark ? secondary : const Color(0xFF727972),
        ),
        errorStyle: label.copyWith(
          color: dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
        ),
      ),
    );
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: surface,
      side: BorderSide(color: outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: body.copyWith(fontWeight: FontWeight.w500),
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: Theme(
                  data: fieldTheme,
                  child: DefaultTextStyle(
                    style: body,
                    child: AutofillGroup(
                      child: Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  const IconData(
                                    0xea19,
                                    fontFamily: 'MercadoSymbols',
                                  ),
                                  size: 20,
                                  color: primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Minhas Compras',
                                  style: TextStyle(
                                    fontFamily: 'MercadoNewsreader',
                                    fontSize: 18,
                                    height: 28 / 18,
                                    letterSpacing: -0.45,
                                    fontWeight: FontWeight.w500,
                                    color: foreground,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, thickness: 1, color: outline),
                            const SizedBox(height: 32),
                            Text(
                              'Entrar',
                              style: TextStyle(
                                fontFamily: 'MercadoNewsreader',
                                fontSize:
                                    MediaQuery.sizeOf(context).width >= 640
                                    ? 36
                                    : 30,
                                height: 1.2,
                                letterSpacing: -0.75,
                                color: foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Acesse suas listas e planeje as compras da semana.',
                              style: body.copyWith(
                                color: secondary,
                                height: 1.625,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'E-mail',
                              style: label.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: emailController,
                              style: body,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'seu@email.com',
                              ),
                              validator: (value) =>
                                  (value ?? '').trim().contains('@')
                                  ? null
                                  : 'Informe um e-mail válido.',
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Senha',
                                  style: label.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _PasswordResetLink(
                                  onPressed: locked ? null : onPasswordReset,
                                  style: label.copyWith(
                                    color: primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: passwordController,
                              style: body,
                              obscureText: obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => onSignIn(),
                              decoration: InputDecoration(
                                hintText: 'Sua senha de acesso',
                                suffixIconConstraints: const BoxConstraints(
                                  minHeight: 44,
                                  minWidth: 44,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: onTogglePassword,
                                  iconSize: 20,
                                  color: secondary,
                                  icon: Icon(
                                    obscurePassword
                                        ? const IconData(
                                            0xe8f5,
                                            fontFamily: 'MercadoSymbols',
                                          )
                                        : const IconData(
                                            0xe8f4,
                                            fontFamily: 'MercadoSymbols',
                                          ),
                                  ),
                                ),
                              ),
                              validator: (value) => (value ?? '').length >= 6
                                  ? null
                                  : 'Senha mínima de 6 caracteres.',
                            ),
                            const SizedBox(height: 32),
                            FilledButton(
                              onPressed: locked ? null : onSignIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF365943),
                                foregroundColor: Colors.white,
                                textStyle: body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: isBusy
                                  ? const _LoginProgress(
                                      label: 'Autenticando...',
                                    )
                                  : const Text('Entrar'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    height: 16,
                                    thickness: 1,
                                    color: dark
                                        ? outline
                                        : const Color(0xFFE2DED4),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'ou continue com',
                                    style: label.copyWith(
                                      color: dark
                                          ? secondary
                                          : const Color(0xFF727972),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    height: 16,
                                    thickness: 1,
                                    color: dark
                                        ? outline
                                        : const Color(0xFFE2DED4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: locked ? null : onGoogleSignIn,
                              style: buttonStyle,
                              child: isGoogleBusy
                                  ? const _LoginProgress(
                                      label: 'Continuar com Google',
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        LoginGoogleIcon(size: 16),
                                        SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'Continuar com Google',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 32),
                            Divider(height: 1, thickness: 1, color: outline),
                            const SizedBox(height: 24),
                            Text(
                              'Ainda não tem conta?',
                              textAlign: TextAlign.center,
                              style: label.copyWith(color: secondary),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: locked ? null : onCreateAccount,
                              style: buttonStyle.copyWith(
                                backgroundColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(double.infinity, 44),
                                ),
                              ),
                              child: const Text('Criar conta'),
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
      ),
    );
  }
}

class _PasswordResetLink extends StatelessWidget {
  const _PasswordResetLink({required this.onPressed, required this.style});
  final VoidCallback? onPressed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: style,
    ),
    child: Text('Recuperar senha', style: style),
  );
}

class _LoginProgress extends StatelessWidget {
  const _LoginProgress({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: DefaultTextStyle.of(context).style.color,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}
