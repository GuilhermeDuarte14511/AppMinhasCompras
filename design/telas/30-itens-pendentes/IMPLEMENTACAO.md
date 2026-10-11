# Revisar itens — implementação Flutter

Referência: `index.html` e `preview.png` desta pasta. Implementação: `lib/src/presentation/dialogs/sheets/pending_drafts_review_sheet.dart`.

## Visual e arquitetura

Tema editorial aplicado apenas ao modal, Newsreader no título, Public Sans em conteúdo, superfícies planas, raio superior de 12 dp e linhas contínuas. Quantidades, preços unitários, subtotais e total vêm dos rascunhos recebidos. Valores usam algarismos tabulares. O sheet acompanha a altura do conteúdo até 85% da área disponível; a lista rola mantendo o rodapé acessível. Em telas pequenas ou texto ampliado, os valores passam para uma disposição vertical. Áreas de ação têm pelo menos 48 dp.

## Funcionalidades preservadas e decisão sobre o Stitch

- Cópia local da seleção; alterações comunicadas imediatamente pelo `onChanged` em lista imutável.
- Editar somente preço unitário, preservando nome, quantidade, categoria, código de barras e estado de comprado.
- Modal de preço existente com validação e cancelamento, sem redesenhar a tela 32.
- Excluir um rascunho, seleção vazia, voltar pelo sistema e continuar adicionando.
- Botão de fechar do Stitch incluído: melhora a descoberta do retorno e executa o mesmo fechamento existente. Não descarta alterações já comunicadas e não confirma nem adiciona produtos à lista.
- Nenhum exemplo do HTML foi incorporado como dado de produção; não foram adicionadas novas operações de compra.

## Verificação

Golden `test/presentation/goldens/pending_review_stitch_390.png` com fontes locais e valores ilustrativos restritos ao teste. Cinco testes novos verificam visual, cópia imutável e alteração imediata, fechamento, seleção vazia, nomes longos, 320 × 568 no modo escuro com texto 1,5 e cancelamento do editor de preço com teclado de 210 dp. Regressões existentes exercitam edição de preço, demais campos, exclusão, reentrada no editor e catálogo.
