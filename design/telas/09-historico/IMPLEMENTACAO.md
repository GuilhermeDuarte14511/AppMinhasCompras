# Histórico de compras no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Arquitetura e aparência

`purchase_history_page.dart` mantém busca, agrupamento mensal, consulta e reenvio
ao Finanças, exclusão e limpeza do histórico. Os componentes visuais estão em
`purchase_history/history_ledger_widgets.dart`: cabeçalho de mês, totais e linha
de fechamento. `CustomScrollView` e `SliverList.builder` constroem as linhas sob
demanda; cabeçalho e busca acompanham a rolagem. Largura máxima de 600 dp.

O tema editorial compartilhado aplica fundo marfim, superfícies brancas,
divisórias finas, Newsreader nos títulos e Public Sans nos controles e valores.
As ações de detalhes e excluir aparecem explicitamente na linha, com tooltips;
a linha inteira continua abrindo o detalhe. Limpar permanece no cabeçalho.

## Dados e funcionalidades preservados

- Busca por lista ou produto; meses e totais refletem os resultados filtrados.
- Ordenação mensal e dos fechamentos continua vindo do store existente.
- Total planejado usa totalValue; total pago usa spentValue, incluindo valor
  final informado. Não confunde soma estimada dos itens com o valor efetivamente pago.
- Cada linha mantém data, quantidade comprada, planejado, comprado, valor final
  quando informado, cobertura por saldos e FinancePurchaseSyncPanel.
- Consulta de envio, falha, sincronização parcial, reenvio e busy state preservados.
- Exclusão individual e limpeza global continuam confirmadas e gravadas no store.
  As mensagens sobre lançamentos no Finanças permanecem nas confirmações.
- Histórico vazio permite criar lista; busca sem resultados permite limpar busca.
- Nenhum exemplo de data, preço, estabelecimento ou método de pagamento do
  HTML é usado como dado do usuário.

## Verificação

`history_redesign_test.dart` cobre captura, busca e totais filtrados, exclusão e
limpeza com persistência, criação pelo estado vazio, sincronização parcial e
reenvio. Inclui layout escuro de 320 × 568 dp com texto ampliado a 1,5×.

Captura: `test/presentation/goldens/history_stitch_390.png`.

Regressão desta etapa: 87 testes aprovados.
`flutter analyze --no-pub`: nenhum problema.
