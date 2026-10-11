# Catálogo no Flutter

Branch: `feat/redesign-login`. Referência: `index.html` e `preview.png`.

## Arquitetura

`catalog_products_page.dart` mantém estado, filtros, ordenação e operações do
store. `catalog/catalog_controls.dart` apresenta criação, scanner, busca e
filtros; `catalog/catalog_product_row.dart` apresenta cada produto e suas ações.
O tema é o mesmo das telas de operação já implementadas. `SliverList` mantém
a construção das linhas sob demanda, com cabeçalho rolável e contador real.

## Funcionalidades preservadas

- Busca por nome, código e categoria.
- Todas as categorias existentes, filtro com código e filtro sem preço.
- Ordenação por atualização, nome, uso e preço; atualização continua padrão.
- Criação manual e criação através do scanner existente no formulário.
- Navegação aos detalhes, edição, atualização de preço e exclusão.
- Adicionar à despensa.
- Seleção por toque longo ou cabeçalho, selecionar visíveis, categoria em lote
  e exclusão em lote com confirmação.
- Estados vazios, limpar filtros, quantidades e datas reais.

O número de uso é rotulado como “Uso”, pois o campo não identifica uma relação
de listas distintas. Preços ausentes continuam como “Sem preço”. Nenhuma
contagem, variação de preço ou data ilustrativa do Stitch é atribuída ao usuário.

As ações de cada produto estão em um menu explícito; a linha abre os detalhes.
O cadastro foi movido do botão flutuante para a faixa de ações do Stitch,
preservando o mesmo callback e retorno.

## Verificação

`item_catalog_redesign_test.dart` cobre referência visual, filtros, seleção,
cancelamento, despensa, cadastro em tela pequena, alteração de categoria e
exclusão em lote com persistência real no store de teste.

Captura: `test/presentation/goldens/catalog_stitch_390.png`.

Verificação desta etapa: 98 testes distintos aprovados nas suítes de regressão
e na suíte focada. `flutter analyze --no-pub`: nenhum problema.
