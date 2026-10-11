# Fechamento de compra — implementação Flutter

Referência: `index.html` e `preview.png` desta pasta.

## Implementação

- `lib/src/presentation/purchase_checkout_dialog.dart`: janela editorial adaptada ao celular, cabeçalho e confirmação fixos, conteúdo rolável.
- `purchase_checkout/checkout_review_widgets.dart`: itens em linhas de conferência, situação real de compra, quantidade, preço unitário, subtotal e correção; bloco do total em papel claro.
- `purchase_checkout/checkout_finance_section.dart`: seção Pagamento e categoria, seletores reais, divisão de pagamento e envio ao Minhas Finanças ao fim.
- `purchase_checkout/checkout_item_editor_dialog.dart`: correção na mesma identidade editorial, com conteúdo rolável para teclado e fontes ampliadas.

Hierarquia do Stitch: itens comprados → total calculado/valor pago → pagamento e categoria → confirmar fechamento. Newsreader nos títulos e valores; Public Sans em controles, opções e texto de apoio. Superfícies de marfim, verde folha, divisórias discretas e cantos pequenos.

## Compatibilidade funcional

Foram preservados revisão/edição dos itens, inclusão opcional de pendentes, ajuste do total pago sem mudar os preços dos produtos, cálculos em centavos, validações, divisão entre fontes sincronizadas, categoria financeira, seleção da fonte vinculada, saldo insuficiente e fechamento local quando a integração está desconectada ou indisponível.

As marcas de compra nas linhas indicam o estado da revisão. Sua edição continua no atalho Corrigir, onde a opção Item comprado já existia. Os controles de inclusão e ajuste continuam switches nativos. Não foram criados meios de pagamento ou categorias fictícios; Pix/dinheiro e quantidades fracionárias ilustrados pelo HTML não são adicionados ao modelo atual. Nome da lista, mensagens operacionais e Cancelar permanecem acessíveis.

## Verificação

19 testes aprovados: 4 de redesign, 7 do checkout financeiro, 7 da revisão/cálculos e 1 do editor de divisão de pagamentos.

- Referências visuais `test/presentation/goldens/checkout_stitch_390.png` e `checkout_finance_stitch_390.png`, com dados de teste explícitos.
- Viewport de 390 × 884 e viewport compacto escuro de 320 × 568 com escala de texto 1,5 e teclado simulado de 180 pixels, inclusive durante a correção de item.
- Cobertura de cancelamento, resultado da inclusão de pendentes e falha de carregamento financeiro; testes existentes de preços, saldo, VR, cartão e valores finais preservados.

Comando: `flutter test --no-pub test/presentation/checkout_redesign_test.dart test/presentation/purchase_checkout_finance_test.dart test/application/purchase_checkout_review_test.dart test/presentation/finance_split_payment_editor_test.dart`.
