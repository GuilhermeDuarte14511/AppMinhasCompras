# 44 — Fechamento: Finanças

## Referência e implementação

Referência: `index.html` e `preview.png` nesta pasta. O fluxo continua sendo a seção financeira do fechamento existente, em `lib/src/presentation/purchase_checkout/checkout_finance_section.dart`, dentro de `PurchaseCheckoutDialog`.

Aplicados título Newsreader, corpo Public Sans, superfícies editoriais claras/escuras, campos com contorno discreto e consentimento de lançamento antes de divisão e seletores, conforme a ordem do Stitch. O rodapé real de confirmação/cancelamento permanece fixo, inclusive com teclado. A integração funciona com as fontes e categorias reais do workspace; valores do mockup não são dados da pessoa.

## Comparação funcional e decisões

| No Stitch | No app e decisão |
| --- | --- |
| Lançar no Minhas Finanças antes dos campos | Integrado: torna explícito o consentimento antes de escolher fonte/categoria. Ao desligar, esconde os campos e fecha localmente sem enviar alocações ou categoria. |
| Valor disponível associado ao pagamento | Integrado com `FinancePaymentSource.availableCents`, formatado em BRL abaixo do seletor. Ajuda a escolher uma fonte que cobre a compra sem comprimir o nome da conta em telas pequenas. Saldo insuficiente continua bloqueando apenas o fechamento financeiro. |
| Nubank, Banco do Brasil e categorias de exemplo | Substituídos exclusivamente por fontes e categorias retornadas pelo workspace. Nenhum cadastro ou saldo fictício foi incluído. |
| Dinheiro em espécie | Não adicionado como fonte financeira: o contrato de integração com o app externo aceita crédito, débito, VA e VR. Suportar dinheiro exige coordenação com esse contrato externo, não apenas Data Connect/rules locais. A compra em dinheiro já pode ser fechada localmente desligando o lançamento financeiro. |
| “Registra a despesa automaticamente” | Adaptado para envio uma única vez após confirmação. O envio ocorre no fluxo real de fechamento; VA/VR atualizam o benefício, sem afirmar uma despesa ou sincronização já realizada. |
| Dedução de limite/saldo previsto fixa para cartão | Preservada a explicação dinâmica existente: VA/VR, crédito/débito e pagamentos mistos têm impactos diferentes. Divisão incompleta solicita conclusão antes de explicar cada pagamento. |
| Dividir pagamento | Editor real existente mantido: valores BRL, fontes distintas, até cinco pagamentos, igualdade com o total e limite disponível por fonte. Alocações e categoria são devolvidas ao fechamento existente. |
| Categoria da despesa | Categorias reais preservadas, sem inventar novas taxonomias. Campo aparece quando existem categorias. |

Workspace ausente mantém a mensagem de desconexão; falha de carregamento mantém o erro legível e permite fechamento local. Workspace sem meios disponíveis agora explica explicitamente que a compra pode ser fechada sem lançamento financeiro.

Nenhuma mudança de modelo, persistência, Data Connect ou regras foi necessária: a melhoria usa dados já disponibilizados pelo contrato atual. A autorização para mudanças de backend foi avaliada no fluxo completo, mas não há requisito de persistência novo nesta tela.

## Verificação

Sete testes próprios em `test/presentation/checkout_finance_redesign_test.dart`: referência visual com fontes locais; escolha real de VR e categoria e retorno da alocação; saldo insuficiente e fechamento local; divisão real com impacto misto; workspace vazio; erro de carregamento; tela escura 320 × 568, texto 1,5 e teclado de 180 px com rodapé acessível.

Capturas: `checkout_finance_redesign_390.png` e `checkout_finance_redesign_dark_320.png`, em `test/presentation/goldens`. Inspeção em lote das variantes clara/escura contra a referência; o Flutter mantém affordances nativas, áreas de toque e impacto financeiro correto.

Os goldens anteriores de checkout e de pendentes foram atualizados porque a nova ordem/título da seção financeira aparece nesses recortes. Não houve relaxamento de comparadores nem remoção de verificação funcional.

Verificação focada: 30 testes aprovados somando finanças, checkout, valor final, pendentes e integração financeira; análise estática dos dois arquivos próprios sem problemas. A regressão consolidada do par 44/45 é realizada pelo agente principal.

Validação final do par 44/45: 82 testes aprovados (72 de apresentação/fluxos do app e 10 de cálculo/ponte financeira). `flutter analyze --no-pub` sem problemas; formatação e verificação de whitespace aprovadas.
