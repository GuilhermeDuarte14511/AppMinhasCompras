# 60 — Novo meio no Minhas Finanças

Implementação em `lib/src/presentation/payment_source_picker_sheet.dart`, mantendo `showCreatePaymentSourceSheet` e o contrato `FinancePaymentSourceRequest`.

## Visual

Título Newsreader, fechar, contexto da criação externa, divisória, tipos Crédito/Débito/VA/VR, rótulos externos e campos contornados seguem o Stitch. Nome ocupa a largura; final/valor e dias de fechamento/vencimento compartilham linhas quando há espaço. Em 320 px ou texto ampliado, os pares empilham e todo o formulário rola, inclusive cabeçalho e ações, sem esconder campos atrás do teclado. Tema escuro mantém os mesmos controles. A ação principal é Criar e usar; Cancelar foi integrado conforme a referência.

Os dados ilustrativos de nome, final, limite, dias e totais do cenário Stitch não são preenchidos como dados do usuário. Os dias padrão reais 5/10 foram preservados. Crédito exige quatro dígitos e envia os dois dias; Débito/VA/VR aceitam final ausente e enviam dias nulos. Valores são enviados em centavos inteiros.

## Diferenças funcionais e decisões

- Fechar e Cancelar explícitos do Stitch são úteis para abandonar o formulário sem criar um meio: retornam nulo. Voltar e barreira também cancelam quando não há envio.
- A criação já existe no repository externo e continua retornando a fonte real para uso na lista; não foi acrescentado cadastro fictício, fatura, total mensal ou fonte local alternativa.
- Retentativa após resposta perdida precisa usar a idempotência existente. O mesmo payload mantém `externalRequestId`; mudar nome, tipo, final, valor ou dias gera novo ID. O ID continua sendo encaminhado ao endpoint existente `/v1/payment-sources`.
- Durante envio, os campos, seletor e ações ficam desabilitados; `_saving` impede envio duplicado e `PopScope` protege voltar/barreira. Arrastar para descartar está desativado nesse formulário porque o gesto da rota poderia fechar uma operação externa em andamento e perder o resultado. Fora do envio, Fechar, Cancelar, voltar e barreira permanecem disponíveis.
- Valores vazios, zero, inválidos e maiores que o inteiro exato suportado por JSON (`9007199254740991` centavos) não chegam ao repository. Entradas enormes não são passadas ao `NumberFormat`, evitando infinito/overflow. Não foi criado um teto financeiro arbitrário.
- Falha mantém os dados, apresenta erro e libera a retentativa. Nenhuma mudança de backend, Data Connect, regras ou modelos foi necessária.

## Evidência e validação

A prévia exportada do Stitch foi inspecionada antes dos edits. Não existia golden do formulário de criação; a tela59 possui golden separado e não foi alterada. Houve duas rodadas visuais batched: claro390×844 e escuro320×700 com texto1,3/teclado220. A primeira identificou o estilo de borda herdado; a segunda confirmou campos contornados da referência e rolagem compacta. Não houve novas rodadas de polimento.

10 testes standalone aprovados: quatro tipos e payload real, validação/overflow sem chamada externa, envio bloqueando edição e saída, retry com ID estável e mudança de payload, fechar/cancelar/voltar/barreira, golden claro e compacto escuro com teclado. A integração pai foi verificada em arquivo separado pelo segundo agente. Gates finais de análise e regressão executados pelo agente principal.

Goldens: `test/presentation/goldens/create_payment_source_stitch_390.png` e `create_payment_source_dark_keyboard_320.png`.

## Gate final da integração

**49 testes aprovados:** 38 de criação/seletor/saldos/manual e fluxo pai, mais 11 de repository e bridge financeiro. Execução final sem atualização de goldens. `flutter analyze --no-pub` sem problemas; três arquivos formatados e `git diff --check` aprovado. A revisão do fluxo 59→60 está em `design/REVISAO_FLUXO_FINANCAS.md`.
