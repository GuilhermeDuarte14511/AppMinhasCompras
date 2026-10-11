# Login no Flutter

Branch: `feat/redesign-login`.

Referência visual: `index.html`, exportado da tela Stitch
`projects/15729736264095734439/screens/8aad87c6e2504e1ea2989caba236e26c`.

## Arquitetura

- `lib/src/presentation/auth_page.dart` mantém os controllers, validação,
  autenticação via `AuthenticationGateway`, recuperação de senha e navegação.
- `lib/src/presentation/auth/login_form_view.dart` apresenta o layout do Stitch:
  coluna de 390 px, margens de 24 px, cabeçalho, campos, divisores e botões.
- `lib/src/presentation/auth/login_google_icon.dart` desenha os quatro paths
  vetoriais do Google presentes no HTML aprovado.
- Newsreader, Public Sans e o subconjunto de Material Symbols são assets locais,
  com licenças em `assets/fonts`, para renderização sem download de fontes.

O formulário real começa vazio. O e-mail e a senha fictícios do HTML aparecem
somente no teste visual para permitir a comparação com a referência.
O modo escuro, a rolagem com teclado e a ampliação de texto mantêm as ações
acessíveis. A tela de criar conta continua usando sua implementação existente.

## Verificação

`test/presentation/auth_page_test.dart` cobre login com e-mail, falha de
autenticação, login com Google, bloqueio durante carregamento, recuperação de
senha, visibilidade da senha, navegação para criar conta, referência visual
390 × 884 e tela pequena com teclado e texto ampliado.

Imagem Flutter: `test/presentation/goldens/login_stitch_390.png`.

Comandos:

```sh
flutter test --no-pub test/presentation/auth_page_test.dart
flutter analyze --no-pub
```
