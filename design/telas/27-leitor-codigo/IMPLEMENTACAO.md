# 27 — Leitor de código

Implementado em `lib/src/presentation/dialogs/sheets/barcode_scanner_sheet.dart`, seguindo o HTML e a prévia locais do Stitch e o sistema Mercado Editorial.

## Apresentação

- Sheet com raio de 12 dp, cabeçalho serifado, fechamento acessível e fundo editorial.
- Visor 4:3 com cantos de enquadramento e indicação textual da câmera somente quando o controlador confirma execução e permissão.
- Estado de abertura, erro e recuperação com informações reais do controlador. A imagem ilustrativa de código de barras do HTML não foi incorporada.
- Reabrir câmera e Digitar manualmente preservados, com controles de pelo menos 48 dp e rodapé acima do teclado. Trocar câmera continua disponível no visor.
- Conteúdo rolável para telas pequenas e texto ampliado; mensagens de erro também rolam dentro do visor.
- Fullscreen de iOS/web mantém SafeArea, com compensação única do teclado e tamanho baseado nas restrições disponíveis.

## Fluxo preservado

O mesmo `MobileScannerController` mantém detecção sem duplicatas, sanitização de código, retorno via Navigator, início/parada e descarte, tratamento de permissão, troca de câmera e retomada da sessão. O caminho de recuperação web/iOS continua recriando o controlador quando necessário. Digitar manualmente retorna `null` para o formulário existente, sem criar um novo formulário ou código.

## Verificação

9 testes de widget e 5 testes existentes de lifecycle aprovados. Cobrem comparação visual a 390 × 844, início pendente, permissão negada, retomada, troca de câmera, detecção e retorno de código, saída manual, layout escuro 320 × 568 com texto 1,5 e teclado 210 dp, e fullscreen com áreas seguras e teclado.

Golden: `test/presentation/goldens/barcode_scanner_stitch_390.png`. A plataforma de câmera usada nos testes é simulada e existe somente no arquivo de teste. Captura física, permissões do sistema e recuperação Safari/iOS necessitam aparelho real para verificação; a implementação desses fluxos foi preservada.
