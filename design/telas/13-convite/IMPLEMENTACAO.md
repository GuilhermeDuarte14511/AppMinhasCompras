# Convite — implementação Flutter

Referência: `index.html` / `preview.png` da tela 13 no Stitch.

## Implementação

- Modal existente `showSharedInviteSheet`, em `lib/src/presentation/shared_lists_pages.dart`, redesenhado com Mercado Editorial.
- Cabeçalho com retorno, código real em destaque, status ativo derivado da existência do código e ações de copiar/regenerar/revogar.
- Membros apresentados em linhas, com papel, identificação do usuário atual e trecho do UID já usado pelo app. Remoção continua disponível somente ao dono, mediante confirmação.
- Rodapé fixo com a ação existente de abrir a lista, quando o chamador fornece esse callback.
- Conteúdo rolável, altura de 94% para preservar a apresentação como modal, fonte ampliada e tema escuro.
- Carregamento, erro, lista ausente e operação em andamento têm estados explícitos.

## Compatibilidade com o produto atual

O código exibido vem do repositório remoto; operações, confirmação e permissões mantêm os caminhos existentes. O botão de gerar código aparece quando não há código ativo, evitando duplicar a função de regeneração quando já existe um código. O modelo não tem prazo de expiração, nomes pessoais, fotos ou presença online; esses dados não foram introduzidos. O status ativo se refere somente ao código. A política existente de compartilhamento para lista fechada foi preservada.

## Verificação

- `flutter test --no-pub --update-goldens test/presentation/invite_redesign_test.dart --reporter expanded`: 7 testes aprovados.
- Golden: `test/presentation/goldens/invite_stitch_390.png`, renderização Flutter 390 × 884 com fontes locais, inspecionada visualmente contra a referência.
- Cobertura: cópia para clipboard, regeneração, revogação, geração, remoção cancelada/confirmada, proteção do dono, permissões de membro, lista fechada, navegação, erro/lista ausente e 320 × 568 em tema escuro com texto 1,5×.
