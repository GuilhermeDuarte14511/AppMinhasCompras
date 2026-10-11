# Lista detalhada no Flutter

Branch: `feat/redesign-login`. Referência: `index.html` e `preview.png`.

## Arquitetura

`shopping_list_editor_page.dart` mantém estado, persistência e todos os fluxos
existentes. O resumo fica em `editor_editorial_summary.dart`; busca/filtros,
linhas de itens e estados vazios permanecem componentes separados na pasta
`shopping_list_editor/widgets`. O tema `editorial_workspace_theme.dart` deriva
do tema editorial compartilhado com Início e Minhas listas.

A tela usa `CustomScrollView` com itens em `SliverList`: cabeçalho, filtros e
resumo rolam com os produtos, mantendo a criação no rodapé e carregando apenas
as linhas necessárias. A barra inferior abre o mesmo editor de itens e permite
voz quando disponível e importação de cupom fiscal. O scanner permanece no
fluxo existente do editor de item; não foi criado um atalho com comportamento
diferente apenas para reproduzir um ícone do mockup.

## Funcionalidades preservadas

- Total, teto, disponibilidade, excesso, contagens e progresso calculados.
- Busca, filtros por estado/categoria e todas as ordenações existentes.
- Expansão do item, quantidade, marcação, edição, exclusão e histórico de preço.
- Gestos de marcação e ações rápidas, incluindo duplicação.
- Orçamento, lembrete e saldos; consumo por prioridade quando configurado.
- Modo compra, fechamento, catálogo, histórico, compartilhamento e sincronização.
- Bloqueios de edição e reabertura de listas fechadas.
- Estados vazios e recuperação de filtros, movimento reduzido e tema escuro.

Nenhum preço, data, unidade em kg ou categoria ilustrativa do Stitch é usado
como dado real. As quantidades continuam inteiras conforme o modelo do app.
As ações avançadas usam os diálogos e sheets existentes.

As fontes Public Sans e Newsreader da composição principal agora também usam
os assets locais já registrados. O seletor de categoria do formulário existente
foi ajustado para evitar corte em telas pequenas com texto ampliado.

## Verificação

`test/widget_test.dart` mantém os 30 testes dos fluxos do app, com seletores
adaptados aos novos controles. `test/presentation/editor_redesign_test.dart`
cobre as referências visuais, tela de 320 px com texto ampliado e reabertura.

Captura: `test/presentation/goldens/list_editor_stitch_390.png`.

Regressão desta etapa: 90 testes aprovados (telas anteriores, editor, modo
compra, sessão de gravação, projeção financeira, saldos e fechamento).
`flutter analyze --no-pub`: nenhum problema. `git diff --check`: sem erros.
