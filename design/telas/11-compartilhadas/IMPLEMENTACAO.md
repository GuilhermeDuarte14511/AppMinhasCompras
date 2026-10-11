# Listas compartilhadas no Flutter

Branch: `feat/redesign-login`. Referências: `index.html` e `preview.png`.

## Implementação e arquitetura

A superfície existente fica dentro de DashboardPage. Esse caminho foi preservado:
não foi adicionada uma rota independente para reproduzir a moldura do HTML.
`shared_lists/widgets/shared_lists_overview.dart` apresenta o botão Entrar com
código, estados de acesso/carregamento/erro/vazio e linhas de listas com bordas
leves, Newsreader e Public Sans. A captura isolada apresenta esse componente.

DashboardPage mantém autenticação, observação do repository, cache da última
resposta e SharedListsRefreshCoordinator. Os callbacks para entrar, atualizar e
abrir uma lista são os mesmos. A quantidade continua limitada às cinco listas
mostradas anteriormente; o contador identifica listas exibidas.

## Dados compatíveis

- Nome, quantidade de membros, dono/membro e estado aberto/fechado vêm do summary.
- Atualização indica updatedAt, sem afirmar que a lista foi sincronizada naquele horário.
- Orçamento aparece somente quando existente.
- O summary não traz preços agregados, itens ou progresso. Os números ilustrativos
  do Stitch não foram fabricados nessa superfície.
- Não foram inventados nomes, fotos ou iniciais de membros a partir de UIDs.
- Entrar com código reaproveita a validação e o fluxo de autenticação existentes.

## Verificação

`shared_redesign_test.dart` cobre captura, abertura e entrada por callbacks,
estados sem login, vazio e erro com nova tentativa. Os testes de Dashboard e
coordenação de atualização continuam incluídos na regressão.

Captura: `test/presentation/goldens/shared_overview_stitch_390.png`.

Regressão desta etapa: 92 testes distintos aprovados; análise estática sem problemas.
