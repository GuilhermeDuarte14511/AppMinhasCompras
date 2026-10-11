# 48 — Scanner: erro de câmera

Implementado em `lib/src/presentation/dialogs/sheets/barcode_scanner_sheet.dart`, no estado de falha do leitor existente. Referência visual: `index.html` e `preview.png` desta pasta.

## Aparência

- Viewport carvão com cantoneiras discretas, ícone de câmera indisponível, estado textual e mensagem real de falha.
- Tentar novamente com contorno no viewport; Reabrir câmera como ação principal e Digitar manualmente como ação secundária persistente, todos com alvo mínimo de 48 dp.
- Altura do modal de erro reduzida para 560 dp, com conteúdo rolável em telas menores e texto ampliado; fechamento, área segura e compensação do teclado mantidos.
- Controles e golden do scanner ativo preservados. Trocar câmera fica disponível no estado ativo/abertura; na falha as ações de recuperação são mais diretas.

## Diferenças funcionais avaliadas

- O Stitch prescreve o caminho de Ajustes do iOS. Agora a mensagem depende da plataforma real: Android usa Configurações/Aplicativos/Permissões; iOS usa Ajustes; Web orienta liberar a câmera no navegador, sem presumir Safari. É uma correção útil integrada no próprio fluxo de erro.
- Tentar novamente e Reabrir câmera chamam a recuperação já existente. Mantidos ambos pela referência e pela acessibilidade: a primeira ação acompanha a explicação; a segunda permanece alcançável no rodapé mesmo com texto ampliado.
- Nenhum estado de permissão ou funcionamento é simulado. Mensagens de câmera incompatível e falha de inicialização continuam disponíveis.
- Digitar manualmente fecha o leitor com resultado nulo e retorna ao editor de item existente, preservando os dados e seu campo de código de barras. Não cria um código fictício nem um formulário paralelo.
- Preservados leitura/sanitização, parada da câmera, callbacks, ciclo de vida, recuperação de sessão iOS/Web e abertura em tela cheia nessas plataformas. Não foi necessária alteração em modelos, Data Connect ou regras.

## Validação

- 18 testes aprovados: suite existente do scanner ativo, ciclo de vida e nova suite do erro, incluindo golden, mensagens por plataforma, nova tentativa com sucesso, permissão ainda negada, retorno manual e fechamento durante inicialização pendente.
- Golden `test/presentation/goldens/barcode_scanner_error_stitch_390.png` inspecionado; o scanner ativo mantém seu golden anterior.
- Análise estática dos arquivos alterados sem problemas.

Gate integrado de 48/49: 64 testes de apresentação e fluxos principais aprovados, mais 25 testes de importação, parser, normalização OCR e correspondência de itens (89 no total). `flutter analyze --no-pub` completo sem problemas; formatação e verificação de diff limpas.
