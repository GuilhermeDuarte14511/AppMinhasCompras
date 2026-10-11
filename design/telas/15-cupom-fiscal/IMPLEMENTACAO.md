# Importar cupom fiscal — implementação Flutter

Referência visual: `index.html` e `preview.png` da tela 15 no Stitch.

## Implementação

- `FiscalReceiptImportSheet`, em `lib/src/presentation/dialogs/sheets/fiscal_receipt_import_sheet.dart`, usa Mercado Editorial: papel claro, tinta verde, cabeçalhos Newsreader, campos Public Sans, bordas discretas e rodapé fixo.
- Captura preserva colar texto, selecionar imagem, fotografar cupom, OCR editável, limpar e reconhecimento automático pelo parser existente.
- Revisão apresenta linhas compactas com produto, confiança real, vínculo à lista, quantidade × preço e subtotal. A ação Editar expande os campos existentes de nome, quantidade e preço. Campos permanecem no Form mesmo recolhidos, mantendo a validação de todas as linhas; erro abre a edição inválida.
- Totalizador mostra quantidade de itens/unidades selecionados, soma, total declarado quando identificado, diferença e avisos reais.
- Selecionar/desmarcar todos, correspondência com catálogo/lista, aplicar à lista e opção de fechar/salvar histórico mantêm os callbacks e resultados existentes.
- Cabeçalho fecha o modal; rodapé mantém revisão/confirmação e retorno ao texto. Conteúdo rolável e altura se adapta ao teclado.

## Compatibilidade

As duas etapas reais do app foram mantidas. A referência foi adaptada a essa navegação, com os mesmos dados e controles. Não existe importação de QR nem ajuda dedicada nessa tela atual, portanto esses controles não foram introduzidos. Quantidades continuam inteiras conforme o domínio existente; não foram inventadas quantidades fracionárias do mockup. Total declarado só aparece quando o parser o identifica. Serviços OCR, parser, matcher e aplicação de resultados não foram alterados.

## Verificação

- 8 testes de widget aprovados: 7 novos e o teste existente adaptado à ação Editar.
- Suíte final de parser/aplicação/widget fiscal: 24 testes aprovados com `flutter test --no-pub test/presentation/fiscal_receipt_redesign_test.dart test/presentation/fiscal_receipt_import_sheet_test.dart test/application/fiscal_receipt_import_test.dart test/data/services/fiscal_receipt_parser_test.dart --reporter expanded`.
- Goldens `fiscal_capture_stitch_390.png` e `fiscal_review_stitch_390.png`, renderizações Flutter 390 × 884 com fontes locais inspecionadas contra Stitch.
- Cobertura: clipboard, limpar, seleção câmera/galeria e seus erros/cancelamento, nome/quantidade/preço, correspondência, diferença total, validação, seleção, opção de não finalizar e submissão real.
- Tela compacta 320 × 568, tema escuro, texto 1,5× e teclado com inset de 200 px sem overflow. Seleção de câmera/galeria usa canais nativos simulados nos testes; OCR físico exige dispositivo com os plugins.
