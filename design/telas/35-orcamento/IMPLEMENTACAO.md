# Orçamento da lista — implementação

Referência: `index.html`, `preview.png` e tela Stitch `bed6ed3af4c34e24813f44ca4457fc12`.

## Implementação

`lib/src/presentation/dialogs/budget_editor_dialog.dart`, exportado por `dialogs_and_sheets.dart`. A função pública e `BudgetEditorResult` mantêm a integração com listas locais e compartilhadas: salvar retorna `value`, remover retorna `clear: true` e cancelar retorna `null`. Não há alterações de persistência, modelos ou regras de orçamento.

Diálogo central limitado a 390 dp, superfícies editoriais, Newsreader no título, Public Sans nos controles, campo BRL com algarismos tabulares e botões de pelo menos 48 dp. Conteúdo rolável e ações fixas respeitam a redução de espaço pelo teclado. O controller é descartado pelo ciclo de vida do widget.

## Avaliação das diferenças do Stitch

- **Fechar:** incluído. Oferece saída direta sem salvar, equivalente a Cancelar; não requer nova regra de negócio.
- **Remover limite:** preservado somente quando há orçamento inicial. O valor de R$ 250 do mockup não é preenchido para novas listas.
- **Concluir no teclado:** incluído como atalho para a mesma validação e salvamento do botão Salvar.
- **Alça de arraste:** omitida porque este é um diálogo, sem gesto de arrastar.
- **“Definição financeira”:** omitido por repetir o contexto do título.
- Não foram adicionados gráficos, sugestões de valores ou integração financeira inexistentes.
- Valores não finitos são rejeitados para impedir que números acima da capacidade do campo sejam persistidos.

## Verificação

Cinco testes em `test/presentation/budget_redesign_test.dart`: referência visual com orçamento real inicial, salvamento monetário, validação de vazio/zero/não finito e atalho do teclado, remoção e cancelamento pelos dois controles, layout escuro 320 × 568 com texto 1,5× e teclado de 210 dp. As três ações permanecem acima do teclado mesmo com erro de validação.

Golden: `test/presentation/goldens/budget_stitch_390.png`, inspecionado visualmente. Análise estática dos dois arquivos sem problemas.
