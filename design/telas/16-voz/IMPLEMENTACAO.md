# Adicionar por voz — implementação Flutter

Referência visual: `index.html` e `preview.png` desta pasta.

## Arquivos

- `lib/src/presentation/dialogs/sheets/voice_quick_add_sheet.dart`: captura e revisão do modal na identidade Mercado Editorial.
- `test/presentation/voice_redesign_test.dart`: reconhecimento simulado, estados, seleção, responsividade e referências visuais.
- `test/presentation/goldens/voice_capture_stitch_390.png` e `voice_review_stitch_390.png`.

## Design

Cabeçalho persistente com título Newsreader e fechamento explícito, superfície de marfim e microfone compacto verde. A frase permanece editável durante a captura. A revisão apresenta a transcrição real, produtos em linhas com divisórias, quantidades, preços unitários, confiança do catálogo, categoria e metadados existentes. Rodapé fixo com Ouvir novamente e adição dos produtos selecionados; ações empilhadas em telas menores ou texto ampliado.

As duas etapas originais foram preservadas: captura → Analisar itens → revisão. O reconhecimento fornece palavras e status; não fornece amplitude sonora. Por isso o indicador de áudio ilustrativo do HTML não foi criado. O status Ouvindo só aparece durante a escuta real. Não foi criado um novo fluxo de Confirmar similar: produtos ambíguos continuam usando as alternativas reais já disponíveis no catálogo.

## Funções preservadas

Inicialização automática/opcional, começar/parar/cancelar reconhecimento, transcrição parcial/final, feedback de permissão/rede/sem correspondência, digitação como alternativa, parser de múltiplos produtos, associação e escolha entre alternativas do catálogo, edição pelo formulário existente, seleção individual, bloqueio de produtos sem preço e retorno dos rascunhos selecionados.

O serviço de voz continua usando seus limites atuais de 45 segundos de escuta e 4 segundos de pausa; nenhuma regra de reconhecimento ou persistência foi alterada. A informação Quantidade será somada continua sendo baseada nos itens reais da lista.

## Verificação

17 testes aprovados: 7 novos de apresentação, 2 existentes do modal e 8 de parser/catálogo/mesclagem.

- Capturas de 390 × 884 para captura e revisão.
- Tema escuro, 320 × 568, escala de texto 1,5 e teclado simulado de 180 pixels.
- Navegação inferior de 40 pixels, com ações acessíveis em ambas as etapas.
- Reconhecimento parcial/final, parar/reiniciar, cancelamento ao fechar, indisponibilidade do microfone, permissão, rede, sem correspondência, timeout/status, remoção da seleção e envio apenas dos produtos escolhidos.
- Análise estática dos arquivos sem problemas.

Comando: `flutter test --no-pub test/presentation/voice_redesign_test.dart test/presentation/voice_quick_add_sheet_test.dart test/application/voice_shopping_test.dart`.
