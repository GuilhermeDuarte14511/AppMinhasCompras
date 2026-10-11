# 43 — Fechamento: itens pendentes

## Implementação

`CheckoutItemsSection`, extraído para `lib/src/presentation/purchase_checkout/checkout_items_section.dart`, integra a conferência existente em `PurchaseCheckoutDialog`. A arquitetura mantém cálculo, seleção de pagamento, divisões e confirmação no estado do diálogo; o componente de apresentação recebe o review e callbacks reais.

A seção segue a composição do Stitch: título Itens, superfície clara contornada, controle de inclusão no topo, divisores entre produtos, ícone de estado e ação Corrigir. Fontes locais Newsreader/Public Sans e cores do tema editorial preservam a identidade. Nomes podem quebrar linha; Corrigir possui área de toque de 48 dp. Quantidade e preço unitário continuam visíveis, com subtotal explícito quando a quantidade é maior que um.

## Diferenças entre Stitch e comportamento funcional

- **Total inconsistente no exemplo do Stitch:** o mockup mostra R$ 82,90 com inclusão desativada, embora os produtos comprados somem R$ 63,80. O app usa `PurchaseCheckoutReview.calculate`: R$ 63,80 com o queijo pendente excluído e R$ 82,90 ao incluí-lo. Copiar o total ilustrativo produziria informação incorreta.
- **Estado prospectivo:** Pendente muda para Será comprado quando a inclusão está ativa. É uma melhoria útil para distinguir a previsão de fechamento do estado persistido: o produto original continua pendente até o resultado ser aplicado pelo fluxo existente.
- **Preço ausente:** badge Sem preço aparece somente para itens incluídos sem preço. A validação existente bloqueia confirmação, permitindo corrigir o item ou informar um valor final válido.
- **Dados e funções preservados:** quantidade × preço unitário, subtotal, correção de quantidade/preço/estado comprado, cancelamento, override do valor final, validação de fundos e alocação financeira continuam usando os dados reais. A referência tem quantidade um e não evidencia o subtotal adicional necessário em quantidades maiores.
- **Cabeçalho e valores:** preservados os componentes já redesenhados nas telas 14/39; o novo layout pertence à seção de itens do mesmo fechamento.
- **Finanças:** mensagem e controles permanecem condicionais ao workspace e aos erros reais. Não se copia a mensagem estática de integração desconectada para usuários conectados.
- **Handle de arraste:** omitido porque o fluxo atual é um diálogo, sem gesto de arraste associado.

## Integração e persistência

Nenhum campo novo de domínio, schema Data Connect ou regra Firebase é necessário. `PurchaseCheckoutResult.markPendingAsPurchased`, `reviewedItems` e `financeAllocations` já representam a operação. A melhoria do rótulo é derivada desses estados existentes, sem persistência redundante. A inclusão continua invalidando divisões anteriores e recalculando fundos antes da confirmação.

## Validação

Sete testes em `test/presentation/checkout_pending_redesign_test.dart` verificam referência visual 390 px, total ao incluir/excluir, resultado e cancelamento sem mutar a fonte, correção de pendente sem preço, override com preservação de preços, validação de fundos e alocação financeira de R$ 82,90, além de 320 × 568 em modo escuro com texto 1,5 e teclado de 180 px.

Os nove testes existentes de checkout e valor final também passam. Referências visuais existentes foram atualizadas exclusivamente pela alteração real na seção Itens. Análise estática dos três arquivos novos/alterados de apresentação e teste sem problemas.

Validação final das telas 42/43: 96 testes aprovados entre revisão/captura de voz, fechamento, valor final, pagamentos, cálculos e fluxos do app. Análise completa com `flutter analyze --no-pub` sem problemas.
