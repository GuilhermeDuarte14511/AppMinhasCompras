# Selecionar meio de pagamento

Implementação: `lib/src/presentation/payment_source_picker_sheet.dart`.

## Design aplicado

Sheet editorial com Newsreader no título, Public Sans no conteúdo, opções de seleção com rádio e borda verde, saldo disponível e limite quando informado pela integração. Corpo rolável e duas ações persistentes: Usar nesta lista e Adicionar manualmente. Campo de reserva em superfície clara com contorno. O formulário existente de criação também recebe o tema editorial local.

## Compatibilidade

- Mantidos carregamento, conexão, mensagens de erro, cancelamento, alternativa manual e criação no Minhas Finanças.
- Seleção utiliza fontes reais do workspace, inclusive fallback de cartões; o valor reservado continua limitado ao disponível.
- Crédito, débito, VA e VR preservam validações e serialização existentes.
- Nome, saldo, limite e final são dados reais. Metadados ausentes não viram zero ou texto ilustrativo.
- Não adicionados Ajuda nem selo Sincronizado, presentes no HTML sem uma ação ou garantia correspondente no app.
- Seleção visual não define um meio automaticamente: confirma apenas após seleção explícita, como no fluxo anterior.

## Verificação

5 testes novos em `test/presentation/payment_picker_redesign_test.dart`: referência visual e resultado de reserva, excesso do saldo disponível, desconexão e alternativa manual, vazio/cancelamento e compacto escuro 320 px com texto 1,5 e teclado de 210 px. O teste compacto verifica geometricamente a ação acima do teclado.

Golden: `test/presentation/goldens/payment_picker_stitch_390.png`, conferida visualmente.

Regressão de 16 testes aprovada com os testes de integração dos saldos e da tela Minhas Finanças. Análise estática dos dois arquivos sem problemas.
