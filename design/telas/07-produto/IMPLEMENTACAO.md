# Produto no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Implementação

`lib/src/presentation/product_details_page.dart` apresenta a ficha editorial:
categoria, uso real, nome, atualização, código disponível, preço atual,
variação do histórico, mínima/média/máxima, gráfico mensal, registros e análise
local. Usa `editorialWorkspaceTheme`, Public Sans e Newsreader locais, superfícies
marfim, divisores e bordas discretas; largura limitada a 600 dp.

A camada de apresentação continua usando o mesmo ShoppingListsStore e as
mesmas classes ProductPriceAnalysis e ProductPriceAdvice. Edição, exclusão
confirmada e atualização de preço continuam pelos callbacks existentes.
O formulário de atualização agora possui um StatefulWidget que mantém seu
TextEditingController até o descarte do diálogo, corrigindo o acesso ao
controlador durante a animação de fechamento.

## Correspondência com os dados existentes

- Uso indica usageCount; não afirma quantas listas distintas utilizaram o produto.
- Datas, preços, variação e contadores vêm dos modelos existentes.
- O gráfico mantém o último preço por mês e o limite de seis meses. Dois registros
  no mesmo mês não viram dois meses fictícios para copiar os exemplos do HTML.
- Sem preço, histórico insuficiente e produto removido possuem estados reais.
- Não foram adicionados certificado de EAN válido, cópia de código, lojas ou
  outros recursos que não existiam nessa tela.
- A análise local permanece disponível depois do histórico.

## Verificação

`test/presentation/product_pantry_redesign_test.dart` cobre referência visual,
atualização de preço com persistência e histórico, ausência de preço, produto
removido e layout escuro de 320 × 568 dp com texto ampliado em 1,5×.

Captura Flutter: `test/presentation/goldens/product_stitch_390.png`.

Regressão desta etapa: 74 testes aprovados. Análise estática sem problemas.
