# Criar conta no Flutter

Branch: `feat/redesign-login`.

Referência: HTML e prévia desta pasta, tela Stitch
`projects/15729736264095734439/screens/b26f75189d3e4b8da68eb01411edd44e`.

## Implementação

`lib/src/presentation/auth/create_account_form_view.dart` apresenta o layout:
coluna de 390 px, barra com Voltar e marca em Newsreader itálico, formulário
centralizado, quatro campos com rótulos externos, botões de cadastro e login.
As fontes e os Material Symbols usados pelo design estão incluídos como assets
locais. Há rolagem para teclado, telas pequenas e texto ampliado, além de cores
para o tema escuro.

`CreateAccountPage`, em `lib/src/presentation/auth_page.dart`, mantém o estado,
controllers, a chamada ao `AuthenticationGateway`, mensagens de falha/sucesso
e retorno à tela anterior. A lógica de autenticação não foi substituída.
Os helpers da aparência anterior foram removidos após a migração das duas telas.

## Ajuste ao contrato atual do app

O HTML do Stitch contém o placeholder “Pelo menos 8 caracteres”. A implementação
exibe “Pelo menos 6 caracteres”, respeitando a regra já existente no app.
Nome, e-mail, confirmação da senha e credenciais enviadas mantêm suas regras
anteriores. Nenhum campo adicional ou provedor de cadastro foi introduzido.
Os placeholders usam contraste legível para os campos vazios.

## Verificação

`test/presentation/create_account_page_test.dart` cobre cadastro válido com senha
de seis caracteres, validações, confirmação divergente, visibilidade independente,
falha de autenticação, bloqueio durante carregamento, retorno seguro, referência
visual e adaptação com modo escuro, teclado e texto ampliado.

Captura Flutter: `test/presentation/goldens/create_account_stitch_390.png`.

```sh
flutter test --no-pub test/presentation/auth_page_test.dart test/presentation/create_account_page_test.dart
flutter analyze --no-pub
```
