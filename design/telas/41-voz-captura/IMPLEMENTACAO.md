# 41 — Voz: captura

Referência: `index.html`, `preview.png` e Stitch `aae168ca8030465bb98bce12f2cff7ae`.

## Implementação

A captura existente em `lib/src/presentation/dialogs/sheets/voice_quick_add_sheet.dart` recebe o visual Mercado Editorial: título Newsreader, microfone circular de 80 dp, aro estático de 96 dp durante a escuta, transcrição editável com Public Sans e orientação de sintaxe. A ação **Analisar itens**, com altura mínima de 48 dp, fica no rodapé e permanece acima do teclado. O corpo rola em telas pequenas; a altura respeita o tamanho de texto e o espaço disponível.

O formulário indica foco com borda verde. Estados de preparação, escuta, indisponibilidade e falha vêm do serviço real. A transcrição parcial/final, entrada manual, iniciar/parar, permissões, ausência de conexão, cancelamento e análise pelo parser/matcher existentes permanecem. A revisão e a confirmação já existentes continuam no mesmo fluxo.

## Decisões funcionais

- O microfone do Stitch inicia ou interrompe o serviço existente; o aro só aparece quando a captura está ativa. Não simula volume, gravação nem transcrição.
- O rodapé persistente foi integrado porque mantém a próxima ação acessível com teclado e texto ampliado. A análise é bloqueada durante a inicialização e durante a escuta para evitar processamento enquanto o resultado ainda muda.
- O desenho mantém a digitação quando o reconhecimento está indisponível. Exemplos e itens ilustrativos do HTML não são inseridos nos dados reais.
- Falhas lançadas pelos Futures de inicializar/iniciar/parar também recebem a mensagem de recuperação existente, permitindo digitar ou tentar novamente. Antes, uma exceção podia deixar a preparação ou a escuta presa.
- A alça mantém o gesto real de arrastar da sheet. O indicador de navegação ilustrativo do HTML foi substituído pela área segura real do aparelho.
- O aro é estático: comunica o estado sem animação contínua, mantendo acessibilidade com redução de movimento. Não foi adicionada outra funcionalidade de negócio.

## Verificação

- Cinco novos testes em `test/presentation/voice_capture_redesign_test.dart`: transcrição em tempo real e parar, inicialização pendente/fechamento, falhas dos Futures e recuperação manual, validação vazia e callbacks após descarte, e viewport 320×568 escuro com texto 1,5× e teclado de 210 dp.
- Goldens com fontes locais: captura ativa 390 dp e captura escura compacta com teclado. Golden anterior de captura atualizado por mudança real de composição; revisão preservada.
- Os cinco testes novos e os nove testes de voz existentes passaram juntos: **14 testes aprovados**. Análise estática dos arquivos de captura e testes sem problemas.
- Reconhecimento de áudio físico continua dependente das permissões e do serviço da plataforma; os testes usam o contrato real com um serviço controlado.
- Validação final conjunta: 87 testes aprovados entre interpretação/importação, revisão fiscal, captura e revisão de voz e fluxos do app. Análise completa (`flutter analyze --no-pub`) sem problemas.
