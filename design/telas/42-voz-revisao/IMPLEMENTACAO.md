# 42 — Voz: revisão

## Implementação

Referência: `index.html` e `preview.png` desta pasta. A etapa de revisão de `voice_quick_add_sheet.dart` recebe o título Newsreader **Revise os produtos**, contador de seleção, cartões contábeis com borda de 8 dp, preço total calculado e valor unitário quando quantidade maior que um. A ação única de adicionar fica no rodapé com pelo menos 48 dp. Nome, quantidade, preço, categoria, código associado e indicação de soma à lista vêm dos drafts e da lista real.

A captura 41 permanece no mesmo fluxo. **Ouvir novamente** retorna à frase existente sem apagá-la; em largura reduzida ou texto ampliado usa ícone com tooltip e semântica. Editar abre o editor real e preserva a seleção. O catálogo continua sendo resolvido pelo parser/matcher existentes.

## Comparação funcional com o Stitch

- **Selecionar/Desmarcar todos:** integrado ao estado real. É útil para revisar vários itens e recuperar rapidamente a seleção, sem persistência adicional.
- **Adicionar desabilitado com zero selecionados:** integrado com contagem real e texto explícito; evita confirmação sem resultado. A guarda defensiva em `_submit` permanece.
- **Dropdown de correspondência:** integrado para resultados ambíguos, usando somente as alternativas reais do catálogo. Escolher aplica nome, categoria, código e preço real respeitando o preço falado. O mockup associa um item “da lista”, mas o matcher atual resolve produtos do catálogo; não foi inventada uma associação. O aviso de quantidade somada continua baseado na lista atual.
- Para correspondências seguras, não há dropdown redundante para selecionar novamente o mesmo produto. Os estados reais de confiança e o editor continuam disponíveis.
- **Preço a definir:** mantido visível em vermelho. Um produto selecionado sem preço não pode ser adicionado: mensagem orienta editar o valor; desmarcá-lo permite confirmar os demais. Não mudou a regra de preço positivo existente.
- O exemplo visual “R$ 13,80 (R$ 6,90/un)” virou cálculo real de quantidade × preço, não um valor ilustrativo.
- O retorno continua sendo `List<ShoppingItemDraft>`, integrado ao merger existente. Não são necessários novos campos, entidades, operações Data Connect ou rules: as melhorias atuam na revisão temporária e usam o contrato já existente. Captura, cancelamento e descarte do serviço permanecem reais.

## Validação

Sete novos testes em `voice_review_redesign_test.dart`: golden 390 dp e totais; seleção unitária/todos e resultado; dropdown com preço/categoria/código reais; bloqueio de preço ausente e edição integrada; preservação da frase/cancelamento; aviso de soma com item existente; 320×568 escuro, texto 1,5× e teclado de 180 dp.

Goldens usam as fontes locais Newsreader/Public Sans/Material Icons. O golden anterior da revisão foi atualizado devido à mudança real de composição; captura 41 preservada. Em conjunto, os sete novos testes e os quatorze testes anteriores de captura/revisão passam (**21 testes**). Análise dos arquivos alterados sem problemas. A validação usa serviço controlado e não substitui teste de microfone físico na plataforma.
