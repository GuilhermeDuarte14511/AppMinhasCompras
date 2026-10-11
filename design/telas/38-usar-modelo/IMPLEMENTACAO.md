# 38 — Usar lista como modelo

Implementada em `lib/src/presentation/dialogs/sheets/template_picker_sheet.dart`, com a API pública `showTemplatePickerSheet` reexportada pela facade existente. O fluxo de Dashboard e Minhas listas continua selecionando uma lista anterior, pedindo o nome e criando a cópia pelos serviços já existentes.

## Design e funcionalidades

- Sheet editorial com título Newsreader, conteúdo Public Sans, superfície calma, linhas acionáveis com contorno discreto, metadados e chevron do Stitch.
- Nomes, quantidades somadas e valores totais vêm dos `ShoppingListModel` recebidos. Não foram incluídas as informações ilustrativas do HTML no app.
- Ordem recebida preservada; os chamadores fornecem `store.listsByCreatedAt`.
- Seleção imediata retorna a mesma lista real ao fluxo existente, sem alterar a fonte e sem criar outra etapa de confirmação.
- Botão **Fechar** do Stitch foi integrado porque permite cancelar explicitamente. Arrastar, voltar e tocar fora continuam disponíveis.
- Estado vazio explica que não há listas disponíveis. Os fluxos atuais já interceptam esse caso antes da abertura; a própria sheet também o trata.
- Nenhuma busca, seleção por rádio ou ação extra foi adicionada: o layout tem seleção imediata por linha, compatível com o comportamento existente.

## Arquitetura e adaptação

Componente isolado de apresentação e tema editorial local, preservando a API e a persistência existentes. Cabeçalho e fechamento permanecem acessíveis; `CustomScrollView` com `SliverList.separated` constrói as linhas sob demanda. Nomes extensos quebram linha e os metadados usam `Wrap`. Área segura inferior, altura limitada a 85% da tela e largura máxima de 560 dp acomodam mobile e telas maiores. A alça representa o gesto real de arrastar da rota. Controles têm pelo menos 48 dp. Modo escuro usa os tokens do tema.

## Verificação

`test/presentation/template_picker_redesign_test.dart`: **5 testes aprovados** cobrindo golden 390×844 com fontes locais, dados reais e ordem, retorno sem mutação, fechamento/barreira sem seleção, estado vazio e seleção após rolagem de 20 listas em 320×568, modo escuro e texto 1,5×.

Golden: `test/presentation/goldens/template_picker_stitch_390.png`, inspecionado contra `preview.png`. Análise estática dos arquivos da tela e testes: sem problemas. A tela não possui entrada de texto nem solicita teclado.
