# 53 — Cupom: revisar e fechar compra

## Implementação

A etapa de revisão de `FiscalReceiptImportSheet` recebe o acabamento do Stitch53: sheet com alça e cantos superiores discretos, cabeçalho Revisar compra, edição dos itens selecionados, linhas separadas por divisores, conferência contábil, fechamento destacado e ação persistente com seta. A captura49 permanece igual.

A edição individual continua disponível. Nome, quantidade, preço e vínculo são apresentados ao abrir Editar. O vínculo atual permanece visível na linha fechada; categoria e confiança reais do matcher continuam visíveis. O novo Editar do cabeçalho abre ou conclui a edição dos itens selecionados sem modificar valores; fica desabilitado quando nenhum item está selecionado. Editar texto retorna à captura existente.

## Decisões funcionais

- O fechamento já existia e utiliza `FiscalReceiptReviewSubmission.finalizePurchase`. Ligado, confirma compra; desligado, aplica os selecionados à lista sem finalizar. A integração atual continua responsável por salvar preços, marcar itens e registrar o fechamento.
- Total selecionado, declarado e diferença usam parser e valores editados reais. A diferença continua avisando, sem bloquear o fluxo autorizado. Sem total identificado, a interface informa a falta do dado.
- O mockup mostra 1,2kg e 4,2 unidades. O domínio atual utiliza quantidade inteira; preservamos unidades e não criamos suporte incompleto a pesos fracionários.
- O Stitch reduz controles de vínculo e confiança. Preservamos essas funções reais: resumo visível e dropdown na edição. Sem valores ilustrativos, relações inventadas ou alterações em Data Connect e rules; nenhum novo dado persistido é necessário.

## Validação

22 testes de apresentação aprovados: seis novos de fechamento e dezesseis de revisão40/captura49 anteriores. Cobrem fechamento ligado e desligado, seleção, diferença, total declarado, correspondência, edição sem perda de valores, zero selecionados e layout escuro320×568 com texto1,5 e teclado210px.

Goldens atualizados para a mudança legítima na revisão: `receipt_finalize_stitch_390.png`, `receipt_review_stitch_390.png`, `fiscal_review_stitch_390.png`. Captura continua com seu golden anterior. Duas inspeções visuais executadas, correção em lote de densidade e confirmação final.

Validação integrada de 52/53: 67 testes de apresentação e fluxos principais aprovados, mais 21 testes de importação fiscal, correspondência, bridge financeiro e sincronização dividida (88 no total). Análise estática completa sem problemas; formatação e verificação de diff limpas. Campos recolhidos permanecem no formulário e continuam sujeitos à validação antes de confirmar.
