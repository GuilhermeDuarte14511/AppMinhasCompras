# 39 — Fechamento: valor final

## Implementação

A variante do Stitch foi integrada ao fechamento existente, sem criar outro fluxo de compra. `CheckoutTotalsSection` foi extraído para `lib/src/presentation/purchase_checkout/checkout_amount_section.dart`, mantendo a mesma API e a responsabilidade de estado/validação no `PurchaseCheckoutDialog`.

Valores vêm antes dos itens, com total calculado em algarismos tabulares, controle de alteração, campo BRL com contorno de 8 dp e aviso de diferença real. O fechamento compartilhado recebeu ações de 48 dp, Cancelar com contorno e Fechar à direita. O diálogo mantém a apresentação central do app, com raio de 12 dp e conteúdo rolável; a posição inferior da prévia não criou uma segunda modalidade de navegação.

## Funcionalidades preservadas e decisões

- A alteração do valor já existia. O ajuste usa centavos reais, sem modificar os preços dos itens.
- Desativar o ajuste restaura o cálculo dos itens; reativá-lo conserva o valor digitado. A primeira ativação começa vazia. Esse comportamento existente foi preservado e testado.
- Vazio e zero bloqueiam a confirmação do ajuste. A conversão em centavos agora rejeita números não finitos antes de `round`.
- Itens pendentes, correção de produto, integração financeira e divisão de pagamentos continuam usando as regras existentes. Categorias/fontes e estados financeiros não são simulados.
- Cancelar e Fechar descartam a edição. IME Concluído fecha o teclado, sem finalizar a compra.
- Não foi criada funcionalidade de negócio: todas as ações do Stitch são representáveis no fechamento atual. O puxador decorativo da prévia não foi adicionado porque este é um diálogo, não um painel arrastável.
- Valores e produtos do mockup não foram fixados na interface. O título existente de fechamento foi preservado.

## Verificação

- 5 testes novos em `test/presentation/checkout_value_redesign_test.dart`: referência visual, confirmação com preços preservados, cancelamento/fechamento, ativação/desativação e compacto 320×568 em tema escuro com texto 1,5 e teclado de 180 dp.
- As duas referências visuais de `checkout_redesign_test.dart` foram atualizadas por causa da nova ordem das seções e dos controles compartilhados. Os 4 testes existentes e os 5 novos passaram juntos: 9 testes.
- Análise estática focada nos arquivos de fechamento e no novo teste: sem problemas.
- Prévia Stitch e golden comparados; uma rodada de ajuste e uma confirmação visual. Golden: `test/presentation/goldens/checkout_value_stitch_390.png`.
- Validação final integrada das telas 38 e 39, fechamento financeiro, divisão de pagamentos, Minhas listas e fluxos do app: 64 testes aprovados. `flutter analyze --no-pub`: sem problemas.
