# Tela 54 — Fechamento: pagamento e categoria

## Referência e composição

Fonte: `index.html` e `preview.png` desta pasta. Implementação em `lib/src/presentation/purchase_checkout/checkout_finance_section.dart`, integrada ao diálogo de fechamento existente.

O trecho financeiro usa as linhas de consentimento e divisão com divisores, rótulos externos, seletores com ícones e bordas discretas e a mensagem de impacto sobre superfície neutra. O cabeçalho, itens, totais e rodapé pertencem ao diálogo compartilhado. A compra continua rolável, com confirmação e cancelamento fixos acima do teclado.

## Diferenças entre o Stitch e o produto

- O exemplo Nubank/R$ 3.420,00 e a categoria Alimentação & Mercado são ilustrativos. As opções são exclusivamente as fontes e categorias recebidas do workspace financeiro real. O valor disponível continua explícito, inclusive para nomes extensos.
- O rótulo Automático não foi incluído: o envio depende do consentimento atual e ocorre após confirmar. Desligar a opção permite fechamento local e não envia categoria nem pagamentos.
- O impacto do exemplo crédito/débito só se aplica a essas fontes. Mantido o cálculo textual para VA/VR, combinação mista ou divisão ainda incompleta.
- A categoria é opcional no contrato existente. Foi adicionada a opção **Sem categoria**, permitindo remover a seleção inicial e retornar `financeCategoryId: null`. É útil para não classificar indevidamente uma compra. O primeiro valor continua selecionado inicialmente, preservando o comportamento anterior, e a pessoa pode selecionar outra categoria depois de remover a escolha.
- Sem fontes, conexão ou carregamento válido, o fechamento local permanece disponível. Os controles não inventam meios de pagamento nem categorias.

## Integração e arquitetura

`CheckoutFinanceSection` permanece um widget declarativo: callbacks alteram o estado no `PurchaseCheckoutDialog`; o resultado utiliza os IDs reais e as alocações já existentes. Sem categoria usa `null` no resultado, conforme o modelo e a integração financeira existentes. Não foi necessária alteração no Data Connect, nas rules ou no serviço externo.

Campos têm semântica explícita, foco Material, seleção nativa por teclado e largura adaptativa. Não houve alteração das regras de saldo, cálculo de total ou validação da divisão.

## Verificação

- `checkout_category_redesign_test.dart`: referência visual a 390×884, dados reais, remoção da categoria e retorno, remoção seguida de nova seleção após dividir, uso compacto escuro a 320×568 com texto 1,5 e teclado aberto.
- `checkout_finance_redesign_test.dart`: regressão da tela 44, com sete testes preservando categoria real, fontes, limite disponível, consentimento, divisão, workspace vazio, falha de carga e uso compacto.
- Goldens novos: `checkout_category_stitch_390.png` e `checkout_category_stitch_dark_320.png`. Os dois goldens da seção financeira 44 foram atualizados porque a seção compartilhada recebeu a composição desta tela.
- Inspeção visual em duas rodadas limitadas, incluindo claro e escuro. A captura compacta representa a rolagem até a categoria, com teclado aberto e ações persistentes; não é uma tela completa sem teclado.

As referências compartilhadas `checkout_stitch_390.png` e `checkout_finance_stitch_390.png` também foram atualizadas para a composição da seção financeira. O teste anterior de pagamento passou a esperar o rótulo externo `MEIO DE PAGAMENTO`; as verificações de retorno e alocação foram preservadas.

Validação integrada de 54/55: 85 testes de apresentação, checkout, editor, menu e fluxos principais aprovados, mais 13 testes de bridge financeiro, divisão e política de sincronização compartilhada (98 no total). Análise estática completa sem problemas; formatação e verificação de diff limpas.
