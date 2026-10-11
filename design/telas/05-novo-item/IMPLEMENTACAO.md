# Novo item no Flutter

Branch: `feat/redesign-login`. Referência: `index.html` e `preview.png`.

## Arquitetura

`shopping_item_editor_sheet.dart` mantém validação, controladores, consulta por
nome/código, seleção de sugestões, comparação de preço e retorno dos drafts.
O formulário recebe cabeçalho com fechamento, conteúdo rolável e ações fixas
no rodapé. `item_editor_theme.dart` e `item_editor_category_picker.dart` isolam
tema e seleção visual de categorias.

O seletor oferece todas as 18 categorias reais em duas linhas com rolagem
horizontal. Quantidade, preço unitário e total estimado ficam agrupados; o
total é derivado do preenchimento, sem alterar valores gravados ou validações.
O código opcional permanece disponível depois dos dados principais.

## Funcionalidades preservadas

- Nome obrigatório, bloqueio de duplicatas, quantidade inteira e valor válido.
- Código de barras manual, limpeza, consulta e scanner existente.
- Consulta por nome, sugestões locais, preenchimento e comparação de preços.
- Categoria real e marcação de item comprado.
- Adicionar, adicionar e continuar, revisão dos itens pendentes e conclusão.
- Edição de item/produto e modo de cadastro do catálogo.
- Cancelamento, foco, teclado, texto ampliado e tema escuro.

O ícone de microfone ilustrativo do mockup não foi transformado em uma nova
função no campo: a busca local existente foi preservada. O contexto da lista
não é inventado quando o formulário não recebe esse dado.

`startBarcodeScan` permite ao atalho do Catálogo iniciar o mesmo scanner após
abrir o formulário. A câmera, a consulta e o retorno do código mantêm a
implementação existente; não há novo provedor de reconhecimento.

## Verificação

`item_catalog_redesign_test.dart` cobre referência visual, gravação dos campos,
categoria, total, comprado e rodapé em tela de 320 px com teclado e texto 1,5.
`widget_test.dart` mantém os testes de sugestões, duplicatas, preços,
preenchimento por catálogo e seleção de vários itens.

Captura: `test/presentation/goldens/new_item_stitch_390.png`.

Verificação desta etapa: 98 testes distintos aprovados nas suítes de regressão
e na suíte focada. `flutter analyze --no-pub`: nenhum problema.
Captura real pela câmera permanece dependente do dispositivo; este redesign
preserva o scanner e sua consulta existentes.
