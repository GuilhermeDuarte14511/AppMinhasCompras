# Modo compra no Flutter

Branch: `feat/redesign-login`. Referência: `index.html` e `preview.png`.

## Arquitetura

`market_mode_page.dart` mantém `MarketShoppingSession`, consulta de saldos,
callbacks de atualização, gravação, tentativa após falha e saída protegida.
O novo resumo e as linhas operacionais ficam em
`market_mode/market_editorial_widgets.dart`. A tela usa o tema editorial de
trabalho e mantém a lista em slivers com carregamento de linhas sob demanda.

## Dados e funcionalidades preservados

- Progresso real, quantidade de pendentes/comprados e unidades restantes.
- Valor dos itens pegos, valor pendente e orçamento somente quando definido.
- Busca, mostrar pendentes/todos e ordenação existente por categoria/nome.
- Checkbox, toque na linha e gestos para alternar o estado do item.
- Incremento/decremento de quantidade e edição do preço sem marcar o item.
- Projeção dos meios de pagamento quando há saldos; acesso ao editor no rodapé.
- Consulta de integração financeira, indisponibilidade de saldo e uso offline.
- Estados sem itens e sem resultados, limpar busca e mostrar todos.
- Gravação automática, feedback, nova tentativa e espera pela gravação ao sair.

Concluir mantém o contrato atual: grava e retorna ao editor; não fecha a compra
automaticamente. O fechamento continua no fluxo de revisão existente da lista.
Não foram criadas quantidades fracionárias, unidades em kg ou dados de pagamento
ausentes no modelo para reproduzir conteúdo ilustrativo do Stitch.

## Verificação

`market_mode_page_test.dart` cobre espera pela gravação, falha/nova tentativa,
saldos em tela de 320 px com texto 1,5, operação offline e edição de preço.
`editor_redesign_test.dart` cobre a referência visual e busca/filtros/marcação.
`market_payment_preview_test.dart` cobre a projeção financeira existente.

Captura: `test/presentation/goldens/market_mode_stitch_390.png`.

Regressão desta etapa: 90 testes aprovados. `flutter analyze --no-pub`: nenhum
problema. `git diff --check`: sem erros.
