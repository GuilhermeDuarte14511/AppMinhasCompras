import 'package:flutter/material.dart';

/// Presents the approved Stitch signup layout; AuthPage owns registration.
class CreateAccountFormView extends StatelessWidget {
  const CreateAccountFormView({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isBusy,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onCreateAccount,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isBusy;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF20231E) : const Color(0xFFFCFBF7);
    final foreground = dark ? const Color(0xFFF3F1EB) : const Color(0xFF1B1C18);
    final secondary = dark ? const Color(0xFFC4C9B4) : const Color(0xFF424843);
    final outline = dark ? const Color(0xFF60685D) : const Color(0xFFC1C8C1);
    final primary = dark ? const Color(0xFFA9D0B4) : const Color(0xFF1F412D);
    final body = TextStyle(
      fontFamily: 'MercadoPublicSans',
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0,
      color: foreground,
    );
    final label = body.copyWith(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outline),
    );
    final theme = Theme.of(context).copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: .2),
        selectionHandleColor: primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: dark ? const Color(0xFF30312D) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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

    Widget field({
      required String title,
      required String hint,
      required TextEditingController controller,
      required String? Function(String?) validator,
      List<String>? autofill,
      TextInputType? keyboard,
      bool password = false,
      bool obscure = false,
      VoidCallback? toggle,
      bool last = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: label),
        const SizedBox(height: 6),
        Semantics(
          label: title,
          child: TextFormField(
            controller: controller,
            style: body,
            obscureText: obscure,
            keyboardType: keyboard,
            textCapitalization: title == 'Nome completo'
                ? TextCapitalization.words
                : TextCapitalization.none,
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            autofillHints: autofill,
            validator: validator,
            onFieldSubmitted: last ? (_) => onCreateAccount() : null,
            decoration: InputDecoration(
              hintText: hint,
              suffixIconConstraints: password
                  ? const BoxConstraints(minWidth: 44, minHeight: 48)
                  : null,
              suffixIcon: password
                  ? IconButton(
                      tooltip:
                          '${obscure ? 'Mostrar' : 'Ocultar'} ${last ? 'confirmação de senha' : 'senha'}',
                      onPressed: toggle,
                      iconSize: 20,
                      color: secondary,
                      icon: Icon(
                        obscure
                            ? const IconData(
                                0xe8f4,
                                fontFamily: 'MercadoSymbols',
                              )
                            : const IconData(
                                0xe8f5,
                                fontFamily: 'MercadoSymbols',
                              ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );

    final form = Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Criar conta',
            style: TextStyle(
              fontFamily: 'MercadoNewsreader',
              fontSize: 30,
              height: 1.375,
              letterSpacing: -.75,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preencha os dados abaixo para começar a organizar suas compras.',
            style: body.copyWith(color: secondary, height: 1.625),
          ),
          const SizedBox(height: 24),
          field(
            title: 'Nome completo',
            hint: 'Ex.: Maria Clara Silveira',
            controller: nameController,
            autofill: const [AutofillHints.name],
            validator: (value) =>
                (value ?? '').trim().length < 2 ? 'Informe seu nome.' : null,
          ),
          const SizedBox(height: 16),
          field(
            title: 'E-mail',
            hint: 'nome@exemplo.com.br',
            controller: emailController,
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            validator: (value) => (value ?? '').trim().contains('@')
                ? null
                : 'Informe um e-mail válido.',
          ),
          const SizedBox(height: 16),
          field(
            title: 'Senha',
            hint: 'Pelo menos 6 caracteres',
            controller: passwordController,
            password: true,
            obscure: obscurePassword,
            toggle: onTogglePassword,
            autofill: const [AutofillHints.newPassword],
            validator: (value) => (value ?? '').length < 6
                ? 'Senha mínima de 6 caracteres.'
                : null,
          ),
          const SizedBox(height: 16),
          field(
            title: 'Confirmar senha',
            hint: 'Repita a senha criada',
            controller: confirmPasswordController,
            password: true,
            obscure: obscureConfirmPassword,
            toggle: onToggleConfirmPassword,
            last: true,
            autofill: const [AutofillHints.newPassword],
            validator: (value) => (value ?? '') != passwordController.text
                ? 'As senhas não conferem.'
                : null,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: isBusy ? null : onCreateAccount,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F412D),
              foregroundColor: Colors.white,
              textStyle: body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              minimumSize: const Size(double.infinity, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isBusy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: Text('Criando conta...')),
                    ],
                  )
                : const Text('Criar conta'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: foreground,
              side: BorderSide(color: outline),
              textStyle: body.copyWith(fontWeight: FontWeight.w500),
              minimumSize: const Size(double.infinity, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Já tem uma conta? Entrar',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: outline.withValues(alpha: .3)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: outline.withValues(alpha: .4),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: onBack,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                const IconData(
                                  0xe5c4,
                                  fontFamily: 'MercadoSymbols',
                                ),
                                size: 20,
                                color: primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Voltar',
                                style: label.copyWith(color: secondary),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Minhas Compras',
                            style: TextStyle(
                              fontFamily: 'MercadoNewsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 18,
                              height: 28 / 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.45,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                            child: Theme(
                              data: theme,
                              child: DefaultTextStyle(
                                style: body,
                                child: AutofillGroup(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [form],
                                  ),
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
          ),
        ),
      ),
    );
  }
}
