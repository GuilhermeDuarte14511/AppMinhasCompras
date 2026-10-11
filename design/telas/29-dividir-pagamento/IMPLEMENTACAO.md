# 29 — Dividir pagamento

## Implementação

`lib/src/presentation/finance_split_payment_editor.dart` mantém o editor embutido na conferência de compra. O resumo mostra total, alocado, restante ou excedente calculados em centavos; os pagamentos usam linhas com divisórias e campos de contorno. Tipografia Newsreader/Public Sans, superfícies marfim, verde folha e suporte ao modo escuro seguem Mercado Editorial.

O fluxo preserva meios sincronizados reais, fonte preferida, até cinco pagamentos, exclusividade de fontes, remoção de linhas e bloqueio por soma incorreta, valor zero ou saldo/limite insuficiente. A confirmação continua no fechamento existente, sem outra etapa que possa gravar a mesma compra.

## Avaliação de recursos do Stitch

- **Usar restante — implementado:** reduz digitação e erros ao combinar meios. Preenche o total menos os valores das outras linhas, excluindo a própria linha do cálculo. Nunca gera valor negativo. Se ultrapassar o saldo/limite, o erro permanece explícito e o fechamento bloqueado; não há redução silenciosa do valor.
- **Resumo e progresso — implementados:** são calculados com os mesmos valores do editor, sem informação externa.
- **Concluir / Confirmar divisão / Cancelar independentes — não adicionados:** o app já oferece confirmação e cancelamento da compra. Duplicar essas ações criaria ambiguidade sem benefício operacional.
- **Novo pagamento separado e lançamentos congelados — adaptados:** todos os valores continuam editáveis nas linhas existentes; mantém correção direta sem estado adicional.
- **Identificação operacional ilustrativa — omitida:** nomes e tipos vêm das fontes reais. Nenhum dado demonstrativo é inserido no app.

## Verificação

- 7 novos testes de widgets: atalho restante, saldo insuficiente, restante não negativo, fechamento real e retorno de alocações, máximo de cinco fontes e remoção, referência visual, tela compacta 320 × 568 com modo escuro, escala 1,5 e teclado.
- 1 teste original do editor e 7 testes de fechamento: 15 aprovados no conjunto.
- Análise estática focada: sem problemas.
- Golden: `test/presentation/goldens/split_payment_stitch_390.png`, inspecionado visualmente.

Sem alterações em modelos, repositórios, persistência ou envio financeiro.
