# 56 — Ações rápidas do item

## Implementação

`lib/src/presentation/shopping_list_editor/widgets/item_actions_sheet.dart` contém `ItemActionsSheet`, o enum `ItemAction` e `showItemActionsSheet(context, item: item)`. O resultado é somente a ação escolhida; a edição, duplicação e exclusão continuam sob responsabilidade do editor, com suas verificações e confirmação de exclusão existentes.

O sheet reproduz as três linhas do Stitch: ícones de contorno, Public Sans, divisórias suaves, exclusão com cor de erro, handle discreto, topo arredondado e scrim de 45%. Os tokens do tema editorial atual são usados também em modo escuro. O conteúdo rola quando necessário, respeita área segura e teclado, e os controles têm altura mínima de 64 dp.

## Comparação funcional

| Stitch | Aplicativo e decisão |
| --- | --- |
| Editar, duplicar e excluir | Exatamente as três ações já existentes; preservadas. |
| Lista ilustrativa, preços e nomes fixos no fundo | O sheet abre sobre a lista real. Nenhum exemplo do HTML é convertido em dado do usuário. |
| Sem título/contexto visível | Hierarquia visual preservada. O nome real do item é informado na semântica e no rótulo de fechar para leitor de tela. |
| Fechamento pelo scrim/arraste | Mantido com resultado nulo, sem mutação do item. |

Não há novo recurso de negócio no mockup. Não foi necessário alterar modelos, persistência, Data Connect ou rules.

## Verificação

Sete testes em `test/presentation/item_actions_redesign_test.dart` aprovados: golden claro, três retornos de ação, cancelamento por scrim e arraste, ativação com Tab/Enter, modo escuro em 320 × 568 com texto ampliado e teclado. Dois goldens inspecionados em uma rodada conjunta. Análise estática do componente e teste sem problemas.

## Integração e validação final

Integrado em `shopping_list_editor_page.dart`: o gesto do item abre as ações 56; excluir abre a confirmação 57. A edição, duplicação e remoção usam os métodos e a persistência existentes do editor. O editor dispensa o foco antes de abrir o menu.

Suite final: **65 testes aprovados**, abrangendo os dois componentes, três testes do editor real (duplicação com metadados e novo ID; cancelamento e exclusão somente do item selecionado; abertura do formulário existente), regressões do editor/cartão/menu da lista e fluxos principais do app. `flutter analyze --no-pub` sem problemas; formatação e `git diff --check` aprovados.
