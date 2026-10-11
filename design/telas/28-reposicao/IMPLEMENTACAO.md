# Implementação Flutter — Reposição inteligente

Referência: index.html / preview.png, tela Stitch e4802a8f37b8461b824fe8f6f11c07eb.

## Implementação

- Tema Mercado Editorial local, título Newsreader, conteúdo Public Sans, lista com divisórias, subtotal estimado e ações fixas de 48 dp.
- Mantidos seleção individual, selecionar/desmarcar todos, cancelamento e retorno das sugestões originais ao fluxo de criação da lista.
- Total calculado a partir da quantidade × preço unitário. Preço de linha representa o total do item, mantendo quantidade e preço unitário explícitos abaixo.
- Categoria, última compra, ocorrências e origem reais continuam visíveis. Nenhum valor ilustrativo do HTML é utilizado em produção.
- Fechar e contagem no botão foram incorporados do Stitch: melhoram a saída do modal e tornam explícita a seleção antes da criação, sem acrescentar dados ou alterar persistência.
- O botão Ajuda do mockup foi avaliado e omitido: a origem já é explicada junto de cada produto; não há conteúdo de ajuda aprovado nem uma regra adicional que justifique outro fluxo.
- Empty state sem sugestões e criação desabilitada com seleção vazia. Área de itens rolável; rodapé acessível em 320 × 568, modo escuro e texto 1,5. Não há campos de entrada/teclado nesta tela.

## Verificação

- 5 testes de widget: golden real modal 390 × 844, seleção/subtotal/retorno com barcode, selecionar todos, vazio/cancelamento, fechar e layout compacto escuro com texto ampliado.
- Teste integrado existente de criação de lista a partir de itens recorrentes mantido, ajustando apenas o seletor do novo texto com contagem.
- Teste existente de sugestão recorrente do store preservado.
- Golden: test/presentation/goldens/replenishment_stitch_390.png, com fontes locais.
