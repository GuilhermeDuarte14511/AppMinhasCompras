# Tela 50 — Novo saldo

## Implementação

O formulário manual já existente em `payment_balances_editor_dialog.dart` foi redesenhado com o HTML e preview desta pasta: título Newsreader, rótulos externos, campos claros com bordas discretas, raio de 8 dp e ações Cancelar/Salvar de pelo menos 48 dp. O modal segue o raio de 12 dp do sistema editorial. A variante Editar saldo usa o mesmo componente.

O corpo pode rolar com teclado aberto e texto ampliado; as ações permanecem fora da rolagem e podem quebrar em duas linhas. O tema editorial é aplicado explicitamente ao abrir o diálogo filho, incluindo o modo escuro.

## Stitch e funcionalidade atual

- Nome, tipo e saldo disponível são valores reais editáveis. Os valores VR Alelo/R$ 200,00 do preview não são pré-preenchidos no app.
- O Stitch mostra cinco tipos. Foram preservados os oito tipos reais: Crédito, Débito, VA, VR, Pix, Voucher, Dinheiro e Outro; apenas os rótulos deste formulário foram expandidos para leitura. As chaves persistidas continuam iguais.
- Continua exigindo nome não vazio e saldo positivo, conforme a regra existente. Agora também rejeita valor não finito antes de devolver o resultado.
- O botão de conclusão do teclado salva após a mesma validação do botão Salvar.
- Cancelar descarta o formulário. Salvar atualiza somente a cópia de trabalho da tela 36; a confirmação da tela 36 continua necessária para aplicar os saldos na lista.
- Edição mantém id, financeSourceId e financeSourceKind. A seleção/criação de meios pelo Minhas Finanças permanece no fluxo existente.
- O cenário de fundo continua sendo o editor de saldos real da tela 36, sem adicionar os saldos ou total fictícios do Stitch.

## Arquitetura e integração

Estado e controllers permanecem no StatefulWidget existente, com dispose. Não foram alterados modelos, persistência, Data Connect, rules ou contratos de integração: todas as melhorias se limitam à apresentação/validação do formulário e usam o contrato PaymentBalance atual.

## Verificação

Golden `test/presentation/goldens/new_balance_stitch_390.png`, inspecionado contra a referência em duas passagens. Testes cobrem valores reais, nome obrigatório, saldo zero/não finito, tipo Pix e todos os tipos existentes, confirmação pelo teclado, cancelamento, metadata financeira e 320 × 568 com modo escuro, texto 1,5× e teclado. O golden e os testes existentes da tela 36 continuam passando sem alteração da aparência dessa tela.

Validação integrada de 50/51: 82 testes de interface, saldos, conexão, checkout, divisão de pagamento e fluxos principais aprovados; 19 testes de repositório financeiro, bridge e sincronização aprovados (101 no total). Confirmação final da suíte de conexão após os ajustes: 19 testes aprovados. Análise estática completa sem problemas; formatação e verificação de diff limpas.
