# 55 — Ações da lista

Implementada a partir do HTML e da prévia do Stitch `4aea34e8de9244819a4f59586c5b62a6`.

## Composição e arquitetura

O editor continua responsável pelos fluxos e pela persistência. O componente `ListEditorActionsSheet`, em `lib/src/presentation/shopping_list_editor/widgets/list_editor_actions_sheet.dart`, apresenta ações e devolve um `ListEditorMenuAction` pelo Navigator; o dispatcher do editor executa os mesmos métodos existentes. Cancelamento devolve null e não salva a lista.

Cabeçalho Newsreader, descrição Public Sans, botão explícito de fechar com 48 dp, três atalhos e linhas de compra/configurações separadas por divisores substituem cores individuais e cartões agrupados. A superfície segue o tema editorial claro/escuro. O atalho principal recebe o verde folha e os demais ficam neutros.

A sheet usa até 88% da altura disponível e mantém cabeçalho/atalhos fixos na orientação vertical comum. Em pouco espaço vertical ou texto grande, o cabeçalho passa a rolar junto com as ações. Atalhos se reorganizam para duas colunas quando necessário. Abrir o menu tira o foco do campo de busca para recolher o teclado.

## Stitch e funcionalidade real

- Todas as ações do Stitch já existiam: fechar compra, importar cupom, modo compra, catálogo, limpar comprados, compartilhar por código, histórico, lembrete, orçamento, saldos, ordem de mercado e renomear. Seus callbacks e confirmações foram preservados.
- O menu continua condicionado pelo estado real. Listas fechadas oferecem reabrir, catálogo, compartilhamento e histórico; não oferecem alterações de itens/preferências.
- O vínculo compartilhado mantém a edição existente e acrescenta as ações já implementadas de abrir compartilhada e sincronizar. O nome interno `isSharedLocked` identifica o vínculo; ele não representa bloqueio geral de edição no editor atual.
- “Limpar comprados” aparece somente quando há itens comprados e continua abrindo a confirmação existente.
- A ordem de mercado mostra ativar/desativar conforme o estado atual. Lembrete usa seu estado real, sem badges inventados.
- Nome, totais e itens ao fundo pertencem à lista aberta. Os dados ilustrativos do mockup não foram copiados.
- A melhoria funcional integrada é o cancelamento explícito no cabeçalho, além da recuperação de espaço com teclado e orientação horizontal. Não houve nova entidade ou necessidade de alterar Data Connect/rules.

## Verificação

- 9 testes próprios: golden com editor real, cancelamento sem gravação, confirmação de limpar comprados, lista fechada/reabertura, ações de vínculo compartilhado, estado de ordenação, atalhos e acessibilidade em 320×568 e 568×320 com texto 1,5×.
- 5 testes de regressão do editor e modo compra: **14 testes aprovados** no conjunto.
- Goldens `list_actions_stitch_390.png` e `list_actions_dark_320.png`, com fontes locais reais. Duas inspeções visuais agrupadas realizadas.
- Análise estática dos arquivos alterados: sem problemas.

Validação integrada de 54/55: 85 testes de apresentação, checkout, editor, menu e fluxos principais aprovados, mais 13 testes de bridge financeiro, divisão e política de sincronização compartilhada (98 no total). Análise estática completa sem problemas; formatação e verificação de diff limpas.

Os testes antigos de cartão de item e barra de filtros foram atualizados para o redesign já existente: categoria/quantidade/preço continuam conferidos separadamente, e busca/filtros/categoria/ordenação são testados nos controles atualmente visíveis com seus callbacks. Nenhum código desses componentes foi alterado nesta dupla. As seis verificações passaram sem avisos de toque.
