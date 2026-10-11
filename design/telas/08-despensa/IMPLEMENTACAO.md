# Despensa no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Implementação

`lib/src/presentation/pantry_page.dart` usa o tema editorial compartilhado,
resumo com contadores reais, busca, filtros de estado, botão de adicionar do
catálogo e linhas agrupadas por estado. SliverList mantém a construção sob
demanda; o cabeçalho e as linhas rolam juntos. O layout se limita a 600 dp e os
controles de estado se reorganizam quando a largura ou escala de texto exigem.

Cada linha apresenta nome, categoria, preço disponível e última compra quando
existente. Os três controles de estoque reutilizam setPantryStatus do store.
O sheet de estado existente continua acessível ao pressionar um controle por
mais tempo. Adicionar à lista mantém seleção/criação da lista destino, quantidade
sugerida e incremento quando o item já está na lista. Remover continua exigindo
confirmação. O cadastro continua selecionando produtos existentes do catálogo.

## Correspondência com o app

- Não foram adicionados estoque numérico, validade, unidades em kg/pacotes ou
  categoria inexistente que apareça nos exemplos do HTML.
- Adicionar à lista continua disponível para estados que precisam de reposição,
  respeitando a regra existente do app.
- Busca por nome, categoria ou código; filtros e limpar filtros preservados.
- Despensa vazia e busca sem resultados possuem estados distintos.
- Valores e quantidades do mockup não são gravados como dados do usuário.

## Verificação

`test/presentation/product_pantry_redesign_test.dart` cobre captura visual,
busca/filtros, alteração persistida de estoque, reposição e incremento na lista,
cancelamento e confirmação de remoção, inclusão pelo catálogo, estado vazio e
layout escuro de 320 × 568 dp com texto ampliado em 1,5×.

Captura Flutter: `test/presentation/goldens/pantry_stitch_390.png`.

Regressão desta etapa: 74 testes aprovados. Análise estática sem problemas.
