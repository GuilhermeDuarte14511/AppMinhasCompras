# Saldos de pagamento — implementação

Referência: `index.html`, `preview.png` e tela Stitch `419df05845b9429e918e781e64e9cb34`.

## Implementação

`lib/src/presentation/dialogs/payment_balances_editor_dialog.dart`, exportado por `dialogs_and_sheets.dart`. Mantém a API pública, a cópia de trabalho, a ordem de prioridade, edição, exclusão, limpeza, cancelamento e resultado imutável ao salvar. Preserva o seletor de fontes financeiras existente e a inclusão manual com nome, tipo e valor BRL. Editar um saldo vinculado preserva seu identificador e origem financeira. Controllers do formulário são descartados pelo ciclo de vida do widget.

Superfície editorial, título Newsreader, controles Public Sans, valores tabulares e ações de pelo menos 48 dp. O conteúdo rola e Novo saldo, Salvar e Cancelar ficam acessíveis no rodapé, inclusive em telas compactas.

## Avaliação das diferenças do Stitch

- Fechar foi incluído: descarta a cópia de trabalho como Cancelar.
- Mantidas as setas de prioridade existentes. A alça e a indicação de arraste foram substituídas por instrução compatível com os controles reais.
- O Salvar duplicado do cabeçalho foi omitido.
- Dados financeiros vêm da lista ou do repositório; valores do mockup não são preenchidos em listas novas.
- Nenhuma nova regra financeira foi introduzida.

## Verificação

Seis testes em `test/presentation/balances_redesign_test.dart`: golden, reordenar/remover/salvar, cancelar/fechar/limpar, validação e inclusão manual, edição com vínculo financeiro e layout escuro 320 × 568 com texto 1,5× e teclado de 210 dp. Três testes de integração com fontes financeiras existentes também aprovados.

Golden: `test/presentation/goldens/balances_stitch_390.png`, conferido visualmente contra a referência.
