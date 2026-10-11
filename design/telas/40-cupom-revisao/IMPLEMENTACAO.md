# 40 — Cupom fiscal: revisão

Implementação em `lib/src/presentation/dialogs/sheets/fiscal_receipt_import_sheet.dart`, etapa `review`. Referência: `index.html` e `preview.png` desta pasta. A captura anterior mantém sua aparência e fluxo.

## Composição

Título Newsreader “Revisar compra”, instrução direta, seleção de linhas, superfícies com contorno e raio de 8 dp, nomes e subtotais alinhados, metadados reais, associação à lista, edição progressiva e quadro de conferência. Rodapé persistente com ações de 48 dp lado a lado em 390 dp; empilhadas em largura pequena ou texto ampliado. Conteúdo rola independentemente do rodapé e respeita teclado.

## Funcionalidades preservadas

- Selecionar individualmente, selecionar todos e desmarcar todos; confirmação indisponível quando não há seleção.
- Editar nome, quantidade inteira e preço unitário; validação dos campos selecionados, total recalculado e retorno à captura para editar texto.
- Correspondência automática com lista e catálogo, confiança calculada e associação manual aos itens planejados. Associação duplicada permanece bloqueada.
- Total declarado, subtotal selecionado, unidades e diferença; mensagens distintas quando total está ausente, diverge ou confere.
- Fechar lista e salvar histórico opcional, inicialmente ativado conforme regra existente; alternativa Aplicar à lista e fechamento sem resultado pelo botão Fechar.

## Avaliação das diferenças do Stitch

- **Categoria no resumo integrada:** usa a categoria já resolvida pelo matcher e atualizada ao associar item planejado. Facilita verificar identificação sem nova regra ou dado artificial.
- **Confiança e edição preservadas:** necessárias para revisar OCR e corrigir dados antes de gravar, embora a ilustração tenha menos controles. Essas informações tornam as linhas mais altas que as ilustradas.
- **Quantidade 1,2 kg omitida:** o domínio trabalha com quantidade inteira e não registra unidade de medida. Acrescentar frações demandaria migração e alteração de parser, preços, estoque e fechamento; não se justifica nesta tela visual.
- **Criar novo versus não associar:** a ação existente sem vínculo já aplica o produto como novo item. Não foram criadas opções com resultado idêntico nem a promessa de ignorar produto selecionado.
- **Alça omitida:** o conteúdo é uma sheet com rolagem interna; não há controle arrastável interno específico. Fechar e Editar texto são operações reais.

## Validação

12 testes aprovados nas suites `receipt_review_redesign_test.dart`, `fiscal_receipt_redesign_test.dart` e `fiscal_receipt_import_sheet_test.dart`. Incluem captura, clipboard, câmera/galeria, seleção, associação, edição, validação, finalização, total ausente, texto 1,5×, modo escuro, viewport 320×568 e teclado de 210 dp. Golden da revisão anterior atualizado para novo título/composição; golden de captura permaneceu igual. Nova referência `receipt_review_stitch_390.png` usa fontes locais. Análise estática dos arquivos alterados sem problemas.
