# Compra fechada no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Arquitetura e aparência

`purchase_history/completed_purchase_details_sheet.dart` contém o detalhe,
separado da página de histórico. Recebe o mesmo CompletedPurchase existente e
não modifica o fechamento. O sheet usa 94% da altura disponível, cabeçalho com
fechar persistente, conteúdo rolável, área segura e o tema editorial local.

Nome e data abrem a ficha; o resumo apresenta planejado, pago e informações reais
de produtos, unidades, pendências, orçamento e saldos. Itens usam linhas com
nome, categoria, quantidade, valor unitário, subtotal e estado comprado/pendente.
A ordem continua colocando os comprados primeiro e ordenando nomes normalizados.

## Compatibilidade com o app atual

- Preserva planned total, purchasedValue e spentValue sem atribuir valor fictício.
- Preserva quantidade total, quantidade de produtos e produtos pendentes.
- Orçamento e pagamentos aparecem somente quando presentes no modelo.
- A seção de pagamentos usa paymentUsage existente: nome/tipo de saldo,
  consumo/valor disponível, progresso, restante/esgotado e falta de cobertura.
- Não inventa um cartão de débito como forma de pagamento quando ele não foi salvo.
- Não inclui “Duplicar como nova lista” e “Reabrir lista” ilustrados no HTML:
  o detalhe original é somente leitura e não possuía esses callbacks.
- Os itens pendentes permanecem visíveis; não são apresentados como comprados.

## Verificação

`history_redesign_test.dart` cobre captura, abertura/fechamento do sheet,
itens pendentes, orçamento, valores finais, saldos esgotados e cobertura parcial.
Inclui tela escura de 320 × 568 dp com texto ampliado a 1,5×.

Captura: `test/presentation/goldens/closed_purchase_stitch_390.png`.

Regressão desta etapa: 87 testes aprovados.
`flutter analyze --no-pub`: nenhum problema.
