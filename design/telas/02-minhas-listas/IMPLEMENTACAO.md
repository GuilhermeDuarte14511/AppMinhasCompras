# Minhas listas no Flutter

Branch: `feat/redesign-login`.

Referência: `index.html` e `preview.png` desta pasta.

## Arquitetura

`lib/src/presentation/my_lists_page.dart` mantém o estado, os listeners, a
consulta de compartilhamento e os fluxos existentes. A composição visual fica
em `my_lists/my_lists_layout.dart`; cada registro usa `list_ledger_row.dart`.
O tema editorial foi extraído para `theme/mercado_editorial_theme.dart` e é
compartilhado com o Início, mantendo sua aparência anterior. Fontes são locais.

## Funcionalidades e dados preservados

- Busca pelo nome com a normalização existente e filtros Todas, Abertas,
  Fechadas e Compartilhadas com contagens reais.
- Ordenação existente pela data de criação.
- Criação de lista, criação baseada em outra, histórico e reposição inteligente.
- Abertura do editor ou da lista compartilhada, conforme a origem do registro.
- Estado, data real de atualização, progresso, quantidade de unidades,
  previsto, gasto nos itens comprados e teto quando definido.
- Papel e quantidade de membros das listas compartilhadas.
- Reabrir, criar baseada nesta, abrir compartilhamento e excluir pelo menu
  de cada registro, respeitando as condições existentes.
- Seleção múltipla por toque longo ou botão do cabeçalho, selecionar todas,
  exclusão com confirmação, desfazer e lixeira.
- Exportação/importação de backup e opções existentes no menu do cabeçalho.
- Estados vazios e recuperação dos filtros, tema escuro e texto ampliado.

O botão Nova lista substitui visualmente o botão flutuante, usando o mesmo
fluxo de criação. Datas e valores ilustrativos do Stitch não são usados como
dados do app. O resumo previsto continua usando o valor pendente real das
listas. Não foram adicionadas funcionalidades ao modelo ou aos serviços.

## Verificação

`test/presentation/my_lists_page_test.dart` valida busca/filtros, exclusão com
desfazer, reabertura, seleção, referência visual e tela de 320 px em modo escuro
com teclado e escala de texto 1,5. A suíte `test/widget_test.dart` cobre também
a exclusão múltipla e a restauração da lixeira.

Captura Flutter: `test/presentation/goldens/my_lists_stitch_390.png`.

```sh
flutter test --no-pub test/widget_test.dart test/presentation/dashboard_content_test.dart test/presentation/auth_page_test.dart test/presentation/create_account_page_test.dart test/presentation/onboarding_page_test.dart test/presentation/my_lists_page_test.dart
flutter analyze --no-pub
```
