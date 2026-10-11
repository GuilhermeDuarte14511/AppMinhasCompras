# Implementação — 26 Abertura

## Correspondência com o Stitch

- `SplashPage` e `LoadingScreen` usam o tema Mercado Editorial localmente.
- Fundo marfim com linhas sutis de caderno, emblema `menu_book` Material Symbols, título Newsreader e indicador linear fino.
- Marca centralizada e estado no rodapé, com áreas seguras, rolagem do miolo quando necessária e variante escura.
- Fonte visual: `index.html` e `preview.png` desta pasta; Stitch `projects/15729736264095734439/screens/8d971e4095d94329bb08e7a27808fff6`.

## Comportamento preservado

- `showReadyHint` continua controlando o estado real “Sincronizando compras”. O estado inicial apresenta “Preparando caderno de compras...”.
- `displayDuration` e `onCompleted` permanecem; o timer dispara uma vez e é cancelado ao sair da tela.
- `LoadingScreen` continua delegando a `SplashPage`; navegação, onboarding e autenticação não foram alterados.
- A sequência de porcentagens e mensagens temporizadas do HTML não foi reproduzida: o app não fornece progresso mensurável. A barra é indeterminada. Com redução de animações, há uma marca estática de atividade sem semântica de porcentagem.
- Imagens da abertura nativa Android permanecem fora desta implementação Flutter.

## Verificação

- 8 testes aprovados: 4 novos e 4 regressões de abertura.
- Golden `test/presentation/goldens/splash_stitch_390.png`, 390 × 844, com fontes locais e inspeção visual.
- Layout 320 × 568 no tema escuro, texto 1,5× e redução de animações verificado sem overflow; identidade e estado permanecem visíveis.
- Testes de duração exata, callback único, cancelamento no dispose e atualização pelo estado real.
- Análise estática dos 3 arquivos Dart alterados sem problemas e `git diff --check` limpo.
