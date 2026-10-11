# Revisão do fluxo de saldos — telas 59 e 60

## Escopo verificado

Esta revisão cobre `showPaymentBalancesEditorDialog` → seletor do Minhas Finanças (59) → criação de meio (60) → valor reservado → salvar saldos. Não é uma auditoria de todas as telas ou de todos os serviços financeiros.

## Contrato preservado

- A tela 59 carrega nomes, tipos, finais e valores reais do repository; os exemplos do Stitch não são registros do usuário.
- A tela 60 cria um meio remoto com nome, tipo, disponibilidade em centavos e final. Crédito também envia fechamento e vencimento; Débito, VA e VR não enviam esses dias.
- Criar retorna a fonte para o seletor e seleciona sua disponibilidade. A inclusão nos saldos da lista ainda exige **Usar nesta lista** e **Salvar** no diálogo pai.
- A reserva usa `PaymentBalance.id` próprio e conserva `financeSourceId` e `financeSourceKind`. Serializar e restaurar o saldo conserva esses metadados.
- Reservar orçamento não chama `submitPurchasePlan` nem registra pagamento no Minhas Finanças. Fechar/cancelar a criação retorna ao seletor; cancelar o saldo manual não adiciona a fonte anteriormente selecionada.
- Criar no Finanças é uma operação remota: cancelar posteriormente a reserva ou o diálogo de saldos não exclui o meio já criado.

## Diferenças avaliadas e correção

O Stitch usa valores demonstrativos e mostra crédito por padrão. A implementação continua oferecendo os quatro tipos já suportados pelo contrato e valida os campos reais. Não há justificativa para acrescentar novos tipos ou dados fictícios.

A revisão encontrou um risco funcional no envio: uma nova tentativa gerava outro `externalRequestId`. Quando a resposta se perde após a criação remota, isso pode criar outro meio. A tela 60 passa a conservar o identificador para o mesmo pedido e bloquear edição/saída durante o envio. A chave pertence ao contrato existente; não foi necessário alterar Data Connect ou rules.

## Evidência de integração

Os sete testes de `test/presentation/payment_balances_finance_integration_test.dart` passaram com `flutter test --no-pub`, incluindo três novos cenários. Exercitam o diálogo pai e as rotas reais: falha/retentativa conserva a chave do pedido, criação de crédito conserva final/dias/centavos e retorna reserva serializável, cancelar criação conserva o valor da fonte selecionada, e cancelar a alternativa manual não adiciona essa fonte.

Os testes usam repository controlado para verificar o contrato e não comprovam disponibilidade ou idempotência do serviço remoto em produção.
