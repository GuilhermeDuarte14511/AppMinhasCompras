# 51 — Finanças: conectar

## Referência e composição

Fonte visual: `index.html` e `preview.png` desta pasta. Implementação: `lib/src/presentation/finance_integration_page.dart`. Foram aplicados o título Newsreader em duas linhas no telefone, cabeçalho alinhado conforme a referência, símbolo de carteira de 48 dp, instrução do código temporário, campo com contorno e raio de 8 dp, ação verde de 48 dp e aviso de segurança. O estado conectado da tela 22 mantém sua composição e todas as ações existentes.

O formulário é rolável e se adapta ao teclado, modo escuro e texto ampliado. O campo possui nome semântico, não usa correção automática ou sugestões e permite enviar pelo teclado. Estados de espera desabilitam ações e apresentam progresso real; mensagens de resultado permanecem anunciadas pelo live region existente.

## Stitch e funcionalidade atual

- **Máscara do código:** o HTML já implementava grupos de quatro letras/números. Foi integrado um `TextInputFormatter` local: aceita colagem, remove separadores externos, converte para maiúsculas, limita a 12 caracteres e preserva o cursor ao editar no meio. A validação continua exigindo 12 caracteres e envia `ABCD-EFGH-IJKL` ao contrato existente.
- **Conexão real:** continuam sendo usados `FinanceIntegrationRepository.connect`, `isConnected`, `loadWorkspace` e `pendingPurchaseCount`. Não há casa, titular, saldo ou quantidade inventada antes da conexão.
- **Recuperação depois do pareamento:** o repositório grava a credencial antes de consultar meios. Se essa consulta falhar, a página preserva a conexão confirmada e oferece Atualizar meios, evitando consumir outro código temporário. Uma falha genérica nessa etapa informa problema ao carregar dados, sem dizer que o pareamento falhou. Quando o contrato confirma `NOT_CONNECTED`, limpa o estado de dados e permite reconectar.
- **Falha ao desconectar ou enviar pendências:** exceções genéricas agora produzem mensagem recuperável e liberam os controles. A fila e a conexão permanecem como estavam quando a operação falha; o repositório continua sendo responsável pela persistência e idempotência.
- **Cancelar:** voltar apenas fecha a página, sem conectar ou persistir o código digitado. O código é removido do controlador após pareamento bem-sucedido.
- **Segurança:** o texto de expiração em 10 minutos e armazenamento protegido já existia no app e no Stitch. Foram preservados o intercâmbio `/v1/link/exchange` e o armazenamento seguro existente; não foi criada uma autorização fictícia ou promessa nova. Não há necessidade de alterar Data Connect, regras ou backend para estas melhorias de apresentação e estado.

## Arquitetura

A página continua como `StatefulWidget` com estado transitório de formulário/espera/mensagens e controlador descartado em `dispose`. O formatter não armazena credenciais. Serviços, persistência e operações externas continuam abstraídos pelo repositório já injetado. O tema editorial local mantém a identidade em estados claro e escuro sem alterar o restante do app.

## Verificação

- 11 testes novos em `test/presentation/finance_connect_redesign_test.dart`: golden claro, máscara/colagem/envio, cursor, código expirado e nova tentativa, falha temporária após pareamento, falha genérica de consulta, credencial ausente, falhas recuperáveis de desconexão/envio, cancelamento e modo escuro em 320 × 568 com teclado e texto 1,5×.
- Os 8 testes existentes de `finance_redesign_test.dart` passaram, incluindo tela conectada, detalhes reais de fatura, atualização de meios, criação de pagamento, pendências e layouts compactos.
- Goldens: `finance_connect_51_stitch_390.png`, `finance_connect_51_dark_keyboard_320.png`; referência desconectada anterior atualizada para a nova composição. Referência conectada preservada.
- Análise estática dos arquivos alterados sem problemas. Revisão visual realizada em duas rodadas limitadas, com comparação do preview e capturas reais dos widgets.

Validação integrada de 50/51: 82 testes de interface, saldos, conexão, checkout, divisão de pagamento e fluxos principais aprovados; 19 testes de repositório financeiro, bridge e sincronização aprovados (101 no total). Confirmação final da suíte de conexão após os ajustes: 19 testes aprovados. Análise estática completa sem problemas; formatação e verificação de diff limpas.
