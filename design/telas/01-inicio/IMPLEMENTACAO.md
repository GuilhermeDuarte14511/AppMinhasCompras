# Início no Flutter

Branch: `feat/redesign-login`.

Referência: `index.html` e `preview.png` desta pasta.

## Arquitetura

`lib/src/presentation/dashboard_page.dart` mantém os fluxos existentes de criação,
modelos, reposição, catálogo, despensa, histórico, voz, listas compartilhadas,
sincronização, conta e saída. O novo conteúdo visual fica em
`lib/src/presentation/dashboard/dashboard_content.dart`, e os ícones do Stitch em
`dashboard_icons.dart`. Fontes e ícones são assets locais.

A lista aberta mais recentemente atualizada recebe o destaque operacional.
Abrir lista mantém a navegação ao editor. Continuar compra abre o mesmo editor
com `startMarketMode`, que aciona seu modo compra existente após a primeira
renderização, preservando gravação, sincronização e integração financeira.
Uma lista vazia abre o editor para adicionar os produtos antes da compra.

## Dados e funcionalidades preservados

- Contagens de listas abertas/fechadas e produtos do catálogo.
- Valor pendente calculado pelas listas reais; orçamento somente quando definido.
- Atalhos adicionais de voz e convite quando as dependências estão disponíveis.
- Reposição com os itens e preços estimados do mecanismo existente, incluindo
  o fluxo de revisão antes de criar a lista.
- Contagem de estoque e produtos para repor na despensa.
- Listas recentes com estado, data, itens, comprados, unidades e valor.
- Compartilhamento com estados de carregamento, erro, vazio e atualização.
- Estado real da nuvem; acesso às opções e à saída pelo menu de perfil.

Nenhuma data “Atualizado hoje” ou valor do mockup é preenchido automaticamente.
O teto agregado reúne apenas listas abertas com orçamento e é identificado como
“Teto definido”, sem assumir que todas as listas possuam orçamento.

## Verificação

`test/presentation/dashboard_content_test.dart` cobre vazio, callbacks, valores,
orçamento ausente/excedido, referência visual e tela pequena em modo escuro com
texto ampliado. `test/widget_test.dart` cobre os fluxos existentes e a entrada
no modo compra através do novo destaque.

Captura Flutter: `test/presentation/goldens/dashboard_stitch_390.png`.

```sh
flutter test --no-pub test/widget_test.dart test/presentation/dashboard_content_test.dart test/presentation/auth_page_test.dart test/presentation/create_account_page_test.dart test/presentation/onboarding_page_test.dart
flutter analyze --no-pub
```
