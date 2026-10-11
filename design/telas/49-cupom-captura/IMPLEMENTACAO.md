# Tela 49 — Captura de cupom fiscal

## Referência e implementação

Referência: `index.html` e `preview.png` desta pasta. Implementação em `lib/src/presentation/dialogs/sheets/fiscal_receipt_import_sheet.dart`, acessada pelo fluxo existente `showFiscalReceiptImportSheet` da lista. A revisão da tela 40 permanece no mesmo componente e retorna `FiscalReceiptReviewSubmission` para aplicação dos itens e eventual fechamento existente.

A captura usa cabeçalho Newsreader com puxador discreto, cantos superiores de 16 dp, subtítulo, ações de colar/galeria/câmera/limpar, campo editável, resumo real e rodapé persistente Cancelar/Revisar. Limpar aparece quando há texto. O botão Fotografar continua usando ImagePicker com `ImageSource.camera`; Escolher foto usa `gallery`. Os três controles de captura ficam desabilitados durante OCR. O texto também fica bloqueado temporariamente para evitar alteração concorrente com a extração.

Em largura compacta ou texto ampliado, ações passam para duas colunas e o rodapé empilha seus botões de pelo menos 48 dp. O corpo rola com teclado aberto, mantendo ações de revisão/cancelamento acessíveis. A revisão mantém seu próprio tamanho e cabeçalho anteriores; os cantos e o puxador novos aplicam-se somente à captura.

## Diferenças funcionais avaliadas

- O Stitch mostra quatro ações já existentes: todas foram integradas à barra. Cancelar já era possível pelo fechamento; agora ganhou ação explícita no rodapé.
- “Linhas detectadas” poderia confundir cabeçalhos e totais com produtos. A interface exibe a quantidade real de linhas não vazias como “linhas de texto”, separada da quantidade de itens reconhecidos.
- O valor ilustrativo do HTML não foi usado. Soma reconhecida e total declarado permanecem distintos, vindos do parser. Total declarado só aparece quando identificado no texto; não é inferido da soma.
- A frase genérica “Texto analisado com sucesso” foi omitida: o parser pode reconhecer somente parte do cupom. A interface orienta revisão antes de aplicar e mostra um estado real quando nenhum item é reconhecido.
- Colagem vazia ou falha de acesso à área de transferência agora produz mensagem de recuperação. O texto já digitado permanece intacto e os caminhos manual/foto continuam disponíveis. Essa correção local evita uma exceção assíncrona não tratada.
- O botão da revisão usa singular/plural real: “Revisar 1 item”, “Revisar 2 itens”.

Não foram necessários novos modelos, persistência, Data Connect ou rules. Nenhum dado adicional está sendo coletado; imagem, OCR local, normalização, parser, correspondência, revisão e callbacks existentes permanecem integrados.

## Validação

15 testes de widget aprovados nos arquivos `receipt_capture_redesign_test.dart`, `fiscal_receipt_redesign_test.dart` e `receipt_review_redesign_test.dart`. Cobrem golden da captura, continuidade da revisão, OCR cancelado/erro, seleção, aplicação sem fechamento, edição inválida, colagem vazia/erro, contagem real, ausência de total inventado e viewport 320 × 568 escuro com texto 1,5 e teclado. Golden de captura atualizado; goldens de revisão continuam compatíveis. Inspeção visual realizada em dois passes limitados e `git diff --check` sem erro nos arquivos editados.

Gate integrado de 48/49: 64 testes de apresentação e fluxos principais aprovados, mais 25 testes de importação, parser, normalização OCR e correspondência de itens (89 no total). Análise estática completa sem problemas; formatação e verificação de diff limpas.
