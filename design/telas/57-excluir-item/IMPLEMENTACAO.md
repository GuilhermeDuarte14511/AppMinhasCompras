# 57 — Excluir item

Implementação: `lib/src/presentation/dialogs/delete_item_dialog.dart`.

## Design e integração

O diálogo segue o HTML e a prévia do Stitch: superfície branca no tema claro, largura máxima de 320 dp, borda discreta, raio de 16 dp, título Newsreader de 20 dp, mensagem Public Sans de 15 dp, ações à direita e confirmação em vermelho terroso. Cancelar e Excluir têm pelo menos 48 dp. O tema escuro usa superfície e contraste adequados ao sistema editorial.

`showDeleteItemDialog(context, item: item)` retorna `true` ao confirmar, `false` ao cancelar e `null` ao dispensar pela barreira ou pelo botão Voltar. A exclusão e a gravação permanecem no editor da lista, após a guarda de edição existente; o diálogo apenas recolhe a decisão.

## Diferenças funcionais avaliadas

- A mensagem usa o nome real do item. Café especial, quantidade e preço são exemplos da referência, não dados adicionados ao produto.
- Não foi adicionada promessa de exclusão irreversível, exclusão do catálogo ou do histórico. O comportamento atual remove somente o item da lista editada.
- O fundo permanece a tela real por trás da barreira nativa; não reproduzimos a lista ilustrativa, navegação ou desfoque artificial do HTML.
- Nomes longos aparecem completos com rolagem. As ações usam `Wrap` e continuam acessíveis com texto ampliado, tela compacta e teclado. São melhorias de acessibilidade sem alteração de domínio.
- Nenhuma mudança em Data Connect, modelos ou rules é necessária: a confirmação utiliza a persistência e as permissões já existentes.

## Validação

Sete testes em `test/presentation/delete_item_redesign_test.dart`: golden claro com nome real; confirmação; cancelamento; barreira; Voltar; nome longo completo; tema escuro em 320 × 568 com texto em 150% e teclado. Golden adicional da variante compacta escura. Análise estática dos arquivos novos sem problemas.

## Integração e validação final

Integrado em `shopping_list_editor_page.dart`: o gesto do item abre as ações 56; excluir abre a confirmação 57. A edição, duplicação e remoção usam os métodos e a persistência existentes do editor. O editor dispensa o foco antes de abrir o menu.

Suite final: **65 testes aprovados**, abrangendo os dois componentes, três testes do editor real (duplicação com metadados e novo ID; cancelamento e exclusão somente do item selecionado; abertura do formulário existente), regressões do editor/cartão/menu da lista e fluxos principais do app. `flutter analyze --no-pub` sem problemas; formatação e `git diff --check` aprovados.
