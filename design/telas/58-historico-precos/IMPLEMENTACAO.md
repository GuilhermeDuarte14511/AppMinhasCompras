# Implementação — 58 Histórico de preços

## Referência e composição

Referência: `index.html` e `preview.png` desta pasta. Componente: `lib/src/presentation/shopping_list_editor/widgets/editor_price_history_sheet.dart`. Mantida a API `EditorPriceHistorySheet(item: item)` para integração pelo editor.

O histórico foi convertido de cartões com ícone de moeda para linhas editoriais com divisores, título Newsreader 24, conteúdo Public Sans, preços tabulares, nome real do item e indicadores compactos de variação. A altura acompanha o conteúdo e a lista inteira pode rolar quando o espaço ou a escala do texto exigem. O modal mantém o gesto, a barreira e Voltar do wrapper existente.

## Comparação funcional e decisão

- App e Stitch têm preço, data/hora e diferença para o registro cronologicamente anterior. A ordenação permanece decrescente por `recordedAt`, sobre cópia da lista, sem mutar o item.
- O primeiro registro cronológico permanece identificado como Inicial. Variações são calculadas dos dados reais; valores e datas ilustrativos da referência não foram incluídos na produção.
- O Stitch acrescenta um botão explícito de fechar. Integrado porque torna a saída encontrável e acessível no desktop e no leitor de tela, com alvo mínimo de 48 dp e rótulo Fechar histórico de preços.
- Preços iguais recebem Sem alteração e cor neutra, em vez do antigo sinal positivo verde de zero. É uma clarificação de apresentação, preservando os dados e o cálculo.
- Datas reais aparecem por extenso em português quando a locale está disponível; mantém-se o formato numérico existente como fallback.
- O estado vazio real foi preservado. Não foram adicionados edição, remoção, gráficos, loja, média, economia ou consulta remota que a referência não oferece.
- Nenhuma alteração em modelo, persistência, Data Connect ou regras foi necessária: trata-se de leitura do `priceHistory` já existente e saída do modal.

## Evidência

7 testes de widget aprovados em `test/presentation/price_history_redesign_test.dart`: ordenação/valores/deltas/datas reais e imutabilidade, preço igual, vazio, fechar, Voltar, barreira e viewport 320×568 em tema escuro, texto ampliado, teclado e nome longo. Goldens 390×844 e compacto escuro gerados e inspecionados em duas rodadas; ajustes de alinhamento e famílias tipográficas resolvidos na segunda. O texto amplo e as linhas podem ser rolados até o fechamento sem overflow.

Análise estática dos dois arquivos: sem problemas após remover import desnecessário. A integração do modal no editor e testes de persistência do fluxo real são responsabilidade da integração do par 58/59.

## Integração e gates finais do par 58/59

Histórico integrado ao editor com altura máxima de 85%, foco dispensado antes da abertura, arraste/Voltar/barreira e botão explícito de fechar. O fluxo pai do Finanças continua usando o seletor existente, preservando cancelamento, alternativa manual e criação de meio.

**79 testes distintos aprovados:** 68 de apresentação/fluxos do app e 11 de repository/bridge financeiro. A suíte de apresentação encontrou duas expectativas antigas que não rolavam até a ação Criar no Finanças; os testes foram corrigidos para navegar pelo conteúdo rolável e os quatro testes desse fluxo pai passaram novamente. O histórico real não modifica storage; cancelar fonte mantém saldos, usar fonte preserva metadados e criar meio continua integrado.

`flutter analyze --no-pub` sem problemas; sete arquivos formatados sem alterações pendentes de formato; `git diff --check` dos arquivos alterados nesta etapa aprovado. Sem mudanças necessárias em Data Connect ou rules nesta etapa.
